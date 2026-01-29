import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Stockage local : Sauvegarde du profil + tokens pour utilisation hors-ligne.
class UserLocalService {
  static const String userKey = "user_profile";
  static const String accessTokenKey = "access_token";
  static const String refreshTokenKey = "refresh_token";
  static const String fcmTokenKey = "fcm_token";

  /// Sauvegarde le profil utilisateur en cache
  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userKey, user.toRawJson());
  }

  /// Sauvegarde les tokens
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(accessTokenKey, accessToken);
    await prefs.setString(refreshTokenKey, refreshToken);
  }

  /// Sauvegarde le token FCM localement
  Future<void> saveFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(fcmTokenKey, token);
  }

  /// Supprime le token FCM localement
  Future<void> removeFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(fcmTokenKey);
  }

  /// Récupère l'access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(accessTokenKey);
  }

  /// Récupère le refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(refreshTokenKey);
  }

  /// Chargement du profil local
  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(userKey);
    if (jsonString == null) return null;
    return UserModel.fromRawJson(jsonString);
  }

  /// Vérifie si une session existe (utilisateur connecté)
  Future<bool> hasActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(accessTokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Efface tout (déconnexion manuelle)
  /// ✅ La session ne sera effacée QUE si l'utilisateur appuie sur "Déconnexion"
  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(userKey);
    await prefs.remove(accessTokenKey);
    await prefs.remove(refreshTokenKey);
  }
}

