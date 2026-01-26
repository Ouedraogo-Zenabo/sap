class AlertCreateModel {
  final String title;
  final String message;
  final String type;
  final String severity;
  final String zoneId;
  final DateTime startDate;
  final DateTime? endDate;
  final String? comment;
  final String? instructions;
  final bool? actionRequired;
  final String? imageUrl;

  AlertCreateModel({
    required this.title,
    required this.message,
    required this.type,
    required this.severity,
    required this.zoneId,
    required this.startDate,
    this.endDate,
    this.comment,
    this.instructions,
    this.actionRequired,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "message": message,
      "type": type,
      "severity": severity,
      "zoneId": zoneId,
      "startDate": startDate.toUtc().toIso8601String(),
      "endDate": endDate?.toUtc().toIso8601String(),
      "comment": comment,
      "instructions": instructions,
      "actionRequired": actionRequired,
      "imageUrl": imageUrl,
    };
  }
}
