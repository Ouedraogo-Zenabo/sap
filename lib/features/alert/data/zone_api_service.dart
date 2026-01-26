// zone_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/zone_model.dart';

class ZoneApiService {
  final String baseUrl;
  final String accessToken;
  ZoneApiService({required this.baseUrl, required this.accessToken});

  /// Récupère la liste des zones (page simple)
  Future<List<ZoneModel>> fetchZones() async {
    final uri = Uri.parse('$baseUrl/zones');
    final res = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    });

    if (res.statusCode == 200) {
      final map = json.decode(res.body) as Map<String, dynamic>;
      final data = map['data'] as Map<String, dynamic>?;
      final zones = data?['zones'] as List<dynamic>? ?? [];
      return zones.map((z) => ZoneModel.fromMap(z as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load zones: ${res.statusCode} ${res.body}');
    }
  }
}
