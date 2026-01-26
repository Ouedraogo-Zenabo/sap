import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = "http://197.239.116.77:3000/api/v1";

  static Future<http.Response> get(String endpoint) async {
    return _request("GET", endpoint);
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    return _request("POST", endpoint, body: body);
  }

  static Future<http.Response> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String accessToken = prefs.getString('accessToken') ?? '';

    http.Response response;

    final uri = Uri.parse("$baseUrl$endpoint");

    if (method == "POST") {
      response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } else {
      response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );
    }

    // ⬇️ ICI EST LA MAGIE 🔥
    if (response.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        return _request(method, endpoint, body: body);
      }
    }

    return response;
  }

  static Future<bool> _refreshToken() async {
    final prefs = await SharedPreferences.getInstance();

    // Récupérer le refreshToken stocké
    final refreshToken = prefs.getString('refreshToken');
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/refresh"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        final newAccess = (data is Map) ? (data['accessToken'] ?? data['access_token']) : null;
        final newRefresh = (data is Map) ? (data['refreshToken'] ?? data['refresh_token']) : null;
        
        if (newAccess is String && newAccess.isNotEmpty) {
          await prefs.setString('accessToken', newAccess);
          if (newRefresh is String && newRefresh.isNotEmpty) {
            await prefs.setString('refreshToken', newRefresh);
          }
          return true;
        }
      }
    } catch (e) {
      print('Erreur refresh token: $e');
    }

    return false;
  }
}
