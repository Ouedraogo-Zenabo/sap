import 'package:file_picker/file_picker.dart';

enum MediaType { image, video }

class ZoneModel {
  final String id;
  final String name;
  final String code;
  final String type;
  final double? latitude;
  final double? longitude;
  final int? population;
  final String? parentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  

  // Médias optionnels
  final MediaType? typeme;
  final PlatformFile? file;

  ZoneModel({
    required this.id,
    required this.name,
    required this.code,
    required this.type,

    this.latitude,
    this.longitude,
    this.population,
    this.parentId,
    this.createdAt,
    this.updatedAt,
    this.typeme,
    this.file,
  });

  factory ZoneModel.fromMap(Map<String, dynamic> m) {
    return ZoneModel(
      id: m['id'] as String,
      name: m['name'] as String? ?? '',
      code: m['code'] as String? ?? '',
      type: m['type'] as String? ?? '',
      latitude: m['latitude'] != null ? (m['latitude'] as num).toDouble() : null,
      longitude: m['longitude'] != null ? (m['longitude'] as num).toDouble() : null,
      population: m['population'] != null ? (m['population'] as num).toInt() : null,
      parentId: m['parentId'] as String?,
      createdAt: m['createdAt'] != null ? DateTime.parse(m['createdAt']) : null,
      updatedAt: m['updatedAt'] != null ? DateTime.parse(m['updatedAt']) : null,
      typeme: m['typeme'] != null
          ? MediaType.values.firstWhere((e) => e.toString() == 'MediaType.${m['typeme']}')
          : null,
      file: m['file'] != null
          ? PlatformFile(
              name: m['file']['name'],
              path: m['file']['path'],
              size: m['file']['size'],
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'population': population,
      'parentId': parentId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'typeme': typeme?.toString().split('.').last,
      'file': file != null
          ? {
              'name': file!.name,
              'path': file!.path,
              'size': file!.size,
            }
          : null,
    };
  }
}
