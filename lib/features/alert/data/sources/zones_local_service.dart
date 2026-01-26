import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ZonesLocalService {
  static final ZonesLocalService _instance = ZonesLocalService._internal();
  factory ZonesLocalService() => _instance;
  ZonesLocalService._internal();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'zones.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE zones (
            id TEXT PRIMARY KEY,
            name TEXT,
            type TEXT,
            parentId TEXT,
            updatedAt TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  Future<void> saveZones(List<Map<String, dynamic>> zones) async {
    if (_db == null) await init();
    final db = _db!;

    await db.transaction((txn) async {
      for (final z in zones) {
        final id = z['id']?.toString() ?? z['_id']?.toString();
        if (id == null) continue;
        final name = (z['name'] ?? z['label'] ?? z['title'] ?? '').toString();
        final type = (z['type'] ?? '').toString();
        final parentId = (z['parentId'] ?? z['parent_id'] ?? '').toString();
        final updatedAt = (z['updatedAt'] ?? z['updated_at'] ?? '').toString();

        await txn.insert(
          'zones',
          {
            'id': id,
            'name': name,
            'type': type,
            'parentId': parentId,
            'updatedAt': updatedAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Sync zones from remote API and persist to local DB.
  Future<void> syncZones(String token) async {
    if (_db == null) await init();
    try {
      final url = Uri.parse('http://197.239.116.77:3000/api/v1/zones?type=COMMUNE&limit=200');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List zonesData = [];
        if (decoded is List) {
          zonesData = decoded;
        } else if (decoded is Map) {
          if (decoded['zones'] is List) {
            zonesData = decoded['zones'];
          } else if (decoded['data'] is List) zonesData = decoded['data'];
          else if (decoded['data'] is Map && decoded['data']['zones'] is List) zonesData = decoded['data']['zones'];
          else if (decoded['success'] == true && decoded['data'] is Map) zonesData = decoded['data']['zones'] ?? [];
        }

        if (zonesData.isNotEmpty) {
          // Ensure each record has the correct type when persisting
          final List<Map<String, dynamic>> withType = zonesData.map<Map<String, dynamic>>((e) {
            final m = Map<String, dynamic>.from(e as Map);
            m['type'] = m['type'] ?? 'COMMUNE';
            return m;
          }).toList();
          await saveZones(withType);
          await setMeta('zones_last_sync', DateTime.now().toIso8601String());
        }
      }
    } catch (e) {
      print('Zones sync error: $e');
    }
  }

  /// Sync all zone types (REGION, PROVINCE, COMMUNE) from remote API.
  Future<void> syncAllZones(String token) async {
    final types = ['REGION', 'PROVINCE', 'COMMUNE'];
    for (final t in types) {
      try {
        final url = Uri.parse('http://197.239.116.77:3000/api/v1/zones?type=$t&limit=1000');
        final headers = <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        };

        final response = await http.get(url, headers: headers);
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          List zonesData = [];
          if (decoded is List) {
            zonesData = decoded;
          } else if (decoded is Map) {
            if (decoded['zones'] is List) {
              zonesData = decoded['zones'];
            } else if (decoded['data'] is List) zonesData = decoded['data'];
            else if (decoded['data'] is Map && decoded['data']['zones'] is List) zonesData = decoded['data']['zones'];
            else if (decoded['success'] == true && decoded['data'] is Map) zonesData = decoded['data']['zones'] ?? [];
          }

          if (zonesData.isNotEmpty) {
            // Ensure each record has the correct type when persisting
            final List<Map<String, dynamic>> withType = zonesData.map<Map<String, dynamic>>((e) {
              final m = Map<String, dynamic>.from(e as Map);
              m['type'] = m['type'] ?? t;
              return m;
            }).toList();
            await saveZones(withType);
          }
        }
      } catch (e) {
        // ignore per-type errors
        print('syncAllZones error for $t: $e');
      }
    }
    await setMeta('zones_last_sync', DateTime.now().toIso8601String());
  }

  Future<List<Map<String, dynamic>>> getZonesByType(String type) async {
    if (_db == null) await init();
    final db = _db!;
    final maps = await db.query('zones', where: 'type = ?', whereArgs: [type]);
    // Normalize to expected shape: id, name, parentId, type
    final List<Map<String, dynamic>> normalized = maps.map((m) {
      return {
        'id': m['id'],
        'name': m['name'],
        'parentId': m['parentId'],
        'type': m['type'],
      };
    }).toList();
    return normalized;
  }

  Future<List<Map<String, dynamic>>> getRegions() async {
    return getZonesByType('REGION');
  }

  Future<List<Map<String, dynamic>>> getProvinces(String regionId) async {
    if (_db == null) await init();
    final db = _db!;
    final rows = await db.query('zones', where: 'type = ? AND parentId = ?', whereArgs: ['PROVINCE', regionId], orderBy: 'name');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> getCommunes(String provinceId) async {
    if (_db == null) await init();
    final db = _db!;
    final rows = await db.query('zones', where: 'type = ? AND parentId = ?', whereArgs: ['COMMUNE', provinceId], orderBy: 'name');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> clearAll() async {
    if (_db == null) await init();
    await _db!.delete('zones');
  }

  Future<String?> getMeta(String key) async {
    if (_db == null) await init();
    final rows = await _db!.query('metadata', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    if (_db == null) await init();
    await _db!.insert('metadata', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
