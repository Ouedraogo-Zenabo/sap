import 'dart:convert';

/// ------------------------------------------------------------
/// UserModel : représente l'utilisateur connecté.
/// ------------------------------------------------------------
class UserModel {
  final String name;
  final String email;
  final String phone;
  final String commune;

  final int totalAlerts;
  final int alertsThisMonth;
  final int alertsTransmitted;

  UserModel({
    required this.name,
    required this.email,
    required this.phone,
    required this.commune,
    required this.totalAlerts,
    required this.alertsThisMonth,
    required this.alertsTransmitted,
  });

  /// Convertit un JSON venant de l'API en modèle UserModel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] ?? "",
      email: json['email'] ?? "",
      phone: json['phone'] ?? "",
      commune: json['commune'] ?? "",

      totalAlerts: json['total_alerts'] ?? 0,
      alertsThisMonth: json['alerts_this_month'] ?? 0,
      alertsTransmitted: json['alerts_transmitted'] ?? 0,
    );
  }

  /// Convertit le modèle en JSON (pour stockage local)
  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "email": email,
      "phone": phone,
      "commune": commune,
      "total_alerts": totalAlerts,
      "alerts_this_month": alertsThisMonth,
      "alerts_transmitted": alertsTransmitted,
    };
  }

  String toRawJson() => jsonEncode(toJson());

  factory UserModel.fromRawJson(String str) =>
      UserModel.fromJson(jsonDecode(str));
}
