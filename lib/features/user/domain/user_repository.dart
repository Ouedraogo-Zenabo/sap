import '../data/models/user_model.dart';
import '../data/sources/user_api_service.dart';
import '../data/sources/user_local_service.dart';

/// ------------------------------------------------------------
/// UserRepository : centralise les opérations entre API + Cache.
/// ------------------------------------------------------------
class UserRepository {
  final UserApiService api;
  final UserLocalService local;

  UserRepository({
    required this.api,
    required this.local,
  });

  /// Récupère le profil utilisateur :
  /// 1️⃣ depuis l'API
  /// 2️⃣ puis le sauvegarde en local
  Future<UserModel> getUserProfile(String token) async {
    final user = await api.fetchUserProfile(token);
    await local.saveUser(user);
    return user;
  }

  /// Charge les données depuis le cache local
  Future<UserModel?> getUserLocal() async {
    return await local.getUser();
  }

  /// Déconnexion
  Future<void> logout() async {
    await local.clearUser();
  }
}
