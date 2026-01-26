import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/features/user/data/sources/user_local_service.dart';
import 'package:http_parser/http_parser.dart';

/// ============================================================
import 'package:mobile_app/core/utils/http_error_helper.dart';
/// ONGLET MÉDIAS — VERSION STABLE & WEB SAFE
/// ============================================================

class AlertMediaTab extends StatefulWidget {
  final List<PlatformFile>? initialMedias;
  final bool canEdit; // 👈 IMPORTANT
  final String alertId; // 👈 NOUVEAU - ID de l'alerte pour l'upload
  const AlertMediaTab({
    super.key,
    this.initialMedias,
    this.canEdit = true,
    required this.alertId,
  });


  @override
  State<AlertMediaTab> createState() => _AlertMediaTabState();
}

class _AlertMediaTabState extends State<AlertMediaTab>
    with AutomaticKeepAliveClientMixin {
  final List<PlatformFile> _medias = [];
  bool _isUploading = false;
  String? _uploadError;
  
  List<PlatformFile> get newMedias =>
    _medias.where((m) => !_isRemoteMedia(m)).toList();

  List<String> get existingMediaUrls =>
    _medias
        .where(_isRemoteMedia)
        .map((m) => m.path!)
        .toList();


  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.initialMedias != null) {
      _medias.addAll(widget.initialMedias!);
    }
  }

MediaType _getMediaType(String filePath) {
  final ext = filePath.split('.').last.toLowerCase();

  switch (ext) {
    // Images
    case 'png':
      return MediaType('image', 'png');
    case 'jpg':
    case 'jpeg':
      return MediaType('image', 'jpeg');
    case 'gif':
      return MediaType('image', 'gif');

    // Vidéos
    case 'mp4':
      return MediaType('video', 'mp4');
    case 'mov':
      return MediaType('video', 'quicktime');
    case 'avi':
      return MediaType('video', 'x-msvideo');
    case 'mkv':
      return MediaType('video', 'x-matroska');

    // Audio (au cas où)
    case 'mp3':
      return MediaType('audio', 'mpeg');
    case 'wav':
      return MediaType('audio', 'wav');

    default:
      return MediaType('application', 'octet-stream');
  }
}


String _getBackendFieldName(PlatformFile file) {
  final ext = file.extension?.toLowerCase();

  if (['png', 'jpg', 'jpeg', 'gif'].contains(ext)) {
    return 'image';
  }

  if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
    return 'video';
  }

  if (['mp3', 'wav', 'm4a', 'ogg'].contains(ext)) {
    return 'audio';
  }

  // fallback
  return 'file';
}


  /// ------------------------------------------------------------
  /// PICK MEDIA
  /// ------------------------------------------------------------
  Future<void> _pickMedia() async {
  if (!widget.canEdit) return;

  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.media,
    withData: kIsWeb,
  );

  if (result == null) return;

  setState(() {
    _medias.addAll(result.files);
  });
}


  bool _isVideo(PlatformFile file) {
    final ext = file.extension?.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
  }

  bool _isRemoteMedia(PlatformFile file) {
  return file.path != null && file.path!.startsWith('http');
}

  /// ============================================================
  /// UPLOAD MEDIA TO SERVER
  /// ============================================================
  Future<void> _uploadMedias() async {
    if (newMedias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun nouveau média à uploader")),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final token = await UserLocalService().getAccessToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _uploadError = "Token d'authentification manquant";
          _isUploading = false;
        });
        return;
      }

      final url = Uri.parse(
        "http://197.239.116.77:3000/api/v1/alerts/${widget.alertId}/attachments",
      );

      // Créer une requête multipart
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';

     // Ajouter chaque fichier
for (var file in newMedias) {
  final fieldName = _getBackendFieldName(file);

  if (kIsWeb) {
    // 🌐 WEB → bytes
    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          file.bytes!,
          filename: file.name,
          contentType: _getMediaType(file.name),
        ),
      );
    }
  } else {
    // 📱 MOBILE → path
    if (file.path != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          file.path!,
          contentType: _getMediaType(file.path!),
        ),
      );
    }
  }
}


      // Envoyer la requête
      final response = await request.send();
      final respBody = await response.stream.bytesToString();
      final decoded = jsonDecode(respBody);

      debugPrint("Upload response status: ${response.statusCode}");
      debugPrint("Upload response body: $respBody");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Récupérer les URLs des médias uploadés
        List<dynamic> uploadedMedia = [];
        if (decoded is Map) {
          if (decoded['data'] is List) {
            uploadedMedia = decoded['data'];
          } else if (decoded['attachments'] is List) {
            uploadedMedia = decoded['attachments'];
          } else if (decoded['media'] is List) {
            uploadedMedia = decoded['media'];
          }
        }

        // Ajouter les URLs aux médias existants
        setState(() {
          for (var media in uploadedMedia) {
            _medias.add(
              PlatformFile(
                name: media['name'] ?? media['filename'] ?? 'media',
                size: 0,
                path: media['url'], // L'URL du fichier uploadé
              ),
            );
          }
          
          // Supprimer les fichiers locaux (déjà uploadés)
          _medias.removeWhere((m) => !_isRemoteMedia(m));
          
          _isUploading = false;
          _uploadError = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ ${newMedias.length} média(s) uploadé(s) avec succès"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _uploadError = httpErrorMessage(response.statusCode, respBody);
          _isUploading = false;
        });
      }
    } catch (e) {
      debugPrint("Upload error: $e");
      setState(() {
        _uploadError = "Erreur lors de l'upload: $e";
        _isUploading = false;
      });
    }
  }


  /// ------------------------------------------------------------
  /// IMAGE PREVIEW SAFE (WEB + MOBILE)
  /// ------------------------------------------------------------
  Widget _buildImagePreview(PlatformFile media,
      {BoxFit fit = BoxFit.cover}) {
    if (kIsWeb) {
      if (media.bytes == null) {
        return const Center(child: Icon(Icons.broken_image));
      }
      return Image.memory(
        media.bytes as Uint8List,
        fit: fit,
      );
    } else {
      return Image.file(
        File(media.path!),
        fit: fit,
      );
    }
  }

  /// ------------------------------------------------------------
  /// SUPPRIMER
  /// ------------------------------------------------------------
  void _removeMedia(int index) {
    setState(() {
      _medias.removeAt(index);
    });
  }

  /// ------------------------------------------------------------
  /// VISUALISER
  /// ------------------------------------------------------------
  void _viewMedia(PlatformFile file) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: _isVideo(file)
            ? kIsWeb
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Icon(Icons.videocam, size: 80),
                  )
                : _VideoPlayerDialog(file: File(file.path!))
            : InteractiveViewer(
                child: _buildImagePreview(file, fit: BoxFit.contain),
              ),
      ),
    );
  }

  /// ------------------------------------------------------------
  /// TELECHARGER
  /// ------------------------------------------------------------
  Future<void> _downloadMedia(PlatformFile file) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Téléchargement non supporté sur Web")),
      );
      return;
    }

    final dir = await getDownloadsDirectory();
    if (dir == null) return;

    final newFile = File('${dir.path}/${file.name}');
    await File(file.path!).copy(newFile.path);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Fichier téléchargé")),
    );
  }

  /// ------------------------------------------------------------
  /// UI
  /// ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final width = MediaQuery.of(context).size.width;
    final itemWidth = width < 600 ? width / 1.3 : 200;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔴 Afficher les erreurs
              if (_uploadError != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "❌ Erreur d'upload",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _uploadError!,
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ],
                  ),
                ),

              if (_medias.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _medias.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 12),
                    itemBuilder: (_, index) {
                      final media = _medias[index];

                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: itemWidth.toDouble(),
                              color: Colors.grey.shade300,
                              child: _isVideo(media)
                                  ? const Center(
                                      child: Icon(
                                        Icons.play_circle_fill,
                                        size: 50,
                                      ),
                                    )
                                  : _buildImagePreview(media),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: PopupMenuButton<_MediaAction>(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.white),
                              onSelected: (action) {
                                if (action == _MediaAction.view) {
                                  _viewMedia(media);
                                } else if (action ==
                                    _MediaAction.delete) {
                                  _removeMedia(index);
                                } else {
                                  _downloadMedia(media);
                                }
                              },
                              itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: _MediaAction.view,
                                child: ListTile(
                                  leading: Icon(Icons.visibility),
                                  title: Text("Visualiser"),
                                ),
                              ),
                                PopupMenuItem(
                                  value: _MediaAction.download,
                                  child: ListTile(
                                    leading:
                                        Icon(Icons.download),
                                    title: Text("Télécharger"),
                                  ),
                                ),
                                if (!_isRemoteMedia(media))
                                  const PopupMenuItem(
                                    value: _MediaAction.delete,
                                    child: ListTile(
                                      leading: Icon(Icons.delete, color: Colors.red),
                                      title: Text("Supprimer"),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              if (widget.canEdit) ...[
              const SizedBox(height: 24),

              const Text(
                "Ajouter des médias",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: _pickMedia,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.image_outlined, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        "Glissez-déposez des photos ou vidéos",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _pickMedia,
                        child: const Text("Parcourir les fichiers"),
                      ),
                    ],
                  ),
                ),
              ),

              // 🔥 BOUTON UPLOAD si y'a des nouveaux médias
              if (newMedias.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _uploadMedias,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(
                      _isUploading
                          ? "Upload en cours..."
                          : "Uploader ${newMedias.length} média(s)",
                    ),
                  ),
                ),
              ],
            ],

            ],
          ),
        ),
      ],
    );
  }
}

/// ============================================================
/// VIDEO PLAYER DIALOG (MOBILE ONLY)
/// ============================================================
class _VideoPlayerDialog extends StatefulWidget {
  final File file;
  const _VideoPlayerDialog({required this.file});

  @override
  State<_VideoPlayerDialog> createState() =>
      _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
        : const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          );
  }
}

enum _MediaAction { view, download, delete }
