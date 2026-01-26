import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour stocker les alertes localement (mode hors-ligne)
class AlertLocalService {
  static const String _pendingAlertsKey = "pending_alerts";
  static const String _draftAlertKey = "draft_alert_form";

  /// Récupère toutes les alertes en attente de synchronisation
  Future<List<Map<String, dynamic>>> getPendingAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_pendingAlertsKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Ajoute une alerte en attente de synchronisation
  Future<void> addPendingAlert(Map<String, dynamic> alertData) async {
    final alerts = await getPendingAlerts();
    
    // Ajouter un timestamp et un ID local
    alertData['localId'] = DateTime.now().millisecondsSinceEpoch.toString();
    alertData['createdOfflineAt'] = DateTime.now().toIso8601String();
    
    alerts.add(alertData);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingAlertsKey, jsonEncode(alerts));
  }

  /// Supprime une alerte après synchronisation réussie
  Future<void> removePendingAlert(String localId) async {
    final alerts = await getPendingAlerts();
    alerts.removeWhere((alert) => alert['localId'] == localId);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingAlertsKey, jsonEncode(alerts));
  }

  /// Compte le nombre d'alertes en attente
  Future<int> getPendingAlertsCount() async {
    final alerts = await getPendingAlerts();
    return alerts.length;
  }

  /// Efface toutes les alertes en attente
  Future<void> clearAllPendingAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingAlertsKey);
  }

  /// Sauvegarde le formulaire d'alerte en tant que brouillon local (pour reprise ultérieure)
  Future<void> saveDraftForm(Map<String, dynamic> draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftAlertKey, jsonEncode(draft));
  }

  /// Récupère le brouillon local s'il existe
  Future<Map<String, dynamic>?> getDraftForm() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_draftAlertKey);
    if (jsonString == null || jsonString.isEmpty) return null;
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Efface le brouillon local
  Future<void> clearDraftForm() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftAlertKey);
  }
}
