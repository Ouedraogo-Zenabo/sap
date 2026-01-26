///  Simule une base de données pour l’authentification.
/// Plus tard : connexion réelle à une API ou Firebase.
class AuthService {
  //  Liste des utilisateurs autorisés
  final Map<String, String> _users = {
    "admin": "admin123",
    "cvd": "cvd123",
    "pfc": "pfc123",
  };

  ///  Vérifie si l’utilisateur existe et si le mot de passe est correct
  bool login(String username, String password) {
    return _users.containsKey(username.trim()) &&
        _users[username.trim()] == password.trim();
  }
}
