class AlertResponseModel {
  final String id;
  final String? imageUrl;
  final String? videoUrl;
  final String? audioUrl;
  final List<dynamic> attachments;

  AlertResponseModel({
    required this.id,
    this.imageUrl,
    this.videoUrl,
    this.audioUrl,
    required this.attachments,
  });

  factory AlertResponseModel.fromJson(Map<String, dynamic> json) {
    return AlertResponseModel(
      id: json['id'],
      imageUrl: json['imageUrl'],
      videoUrl: json['videoUrl'],
      audioUrl: json['audioUrl'],
      attachments: json['attachments'] ?? [],
    );
  }
}
