import 'package:connectivity_plus/connectivity_plus.dart';

/// Service pour vérifier la connexion internet
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Vérifie si l'appareil a une connexion internet
  Future<bool> hasConnection() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    
    // ConnectivityResult est maintenant toujours une liste
    return connectivityResult.any((result) => 
      result != ConnectivityResult.none
    );
  }

  /// Écoute les changements de connexion
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((result) {
      return result.any((r) => r != ConnectivityResult.none);
    });
  }
}
