String friendlyNetworkErrorMessage(dynamic e) {
  if (e == null) return 'Une erreur est survenue.';
  final msg = e.toString().toLowerCase();
  if (msg.contains('network') || msg.contains('socket') || msg.contains('connection refused')) {
    return 'Pas de connexion réseau. Vérifiez votre connexion internet.';
  }
  if (msg.contains('timeout') || msg.contains('timed out')) {
    return 'Délai d\'attente dépassé. Vérifiez votre connexion et réessayez.';
  }
  if (msg.contains('certificate') || msg.contains('ssl')) {
    return 'Erreur de certificat de sécurité. Réessayez plus tard.';
  }
  return 'Erreur réseau : $e';
}

String httpErrorMessage(int statusCode, [String? body]) {
  switch (statusCode) {
    case 400:
      return 'Requête invalide. Veuillez vérifier les informations fournies.';
    case 401:
      return 'Session expirée ou non authentifiée. Connectez-vous à nouveau.';
    case 403:
      return 'Accès refusé. Vous n\'avez pas les droits nécessaires.';
    case 404:
      return 'Ressource introuvable.';
    case 408:
      return 'La requête a expiré. Vérifiez votre connexion et réessayez.';
    case 429:
      return 'Trop de requêtes. Merci de réessayer plus tard.';
    case 500:
    case 502:
    case 503:
    case 504:
      return 'Erreur serveur. Réessayez dans quelques instants.';
    default:
      if (body != null && body.isNotEmpty) {
        // Try to surface a message from the response body if available
        try {
          // naive extraction: look for "message" key
          final m = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(body);
          if (m != null && m.groupCount >= 1) return m.group(1)!;
        } catch (_) {}
      }
      return 'Erreur serveur ($statusCode).';
  }
}
