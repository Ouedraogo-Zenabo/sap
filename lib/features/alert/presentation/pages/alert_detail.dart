import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/features/alert/presentation/pages/create_alert.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:mobile_app/features/user/data/sources/user_local_service.dart';
import 'package:mobile_app/core/utils/http_error_helper.dart';

class AlertDetailsPage extends StatefulWidget {
  final String alertId;
  const AlertDetailsPage({super.key, required this.alertId});

  @override
  State<AlertDetailsPage> createState() => _AlertDetailsPageState();
}

class _AlertDetailsPageState extends State<AlertDetailsPage> with SingleTickerProviderStateMixin {
  bool loading = true;
  String? error;
  Map<String, dynamic>? alertData;
  late TabController _tabController;
  
  // Variables pour l'upload de médias
  bool _uploadingMedia = false;
  PlatformFile? _selectedImage;
  PlatformFile? _selectedVideo;
  PlatformFile? _selectedAudio;
  
  // Variables pour l'enregistrement audio
  AudioRecorder? _audioRecorder;
  AudioPlayer? _audioPlayer;
  String? _recordedAudioPath;
  bool _isRecording = false;
  bool _isPlayingRecorded = false;
  Duration _recordDuration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3 onglets : Détails, Médias, Commentaires
    _loadAlert();
    
    // Initialiser l'audio
    if (!kIsWeb) {
      _audioRecorder = AudioRecorder();
      _audioPlayer = AudioPlayer();
      _setupAudioPlayer();
    }
  }

  void _setupAudioPlayer() {
    if (_audioPlayer == null) return;
    _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingRecorded = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Vérifie si l'alerte est encore modifiable
  /// Règle métier : seules les alertes DRAFT/BROUILLON et PENDING peuvent être modifiées
  bool get _isEditable {
  final status = (alertData?['status'] ?? '').toString().toUpperCase();

  // Aligné sur le backend : DRAFT et PENDING uniquement
  const editableStatuses = {'DRAFT', 'BROUILLON', 'PENDING'};
  return editableStatuses.contains(status);
}



  /// Navigation vers la page de création en mode édition
  /// Toutes les données existantes sont transmises
 Future<void> _goToEditAlert() async {
  if (!_isEditable) return;

  final updated = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => CreateAlertPage(
        isEditMode: true,
        existingAlert: alertData!,
      ),
    ),
  );

  // 🔁 Si modification confirmée → reload
  if (updated == true) {
    await _loadAlert();
  }
}




  // ========================== TOKEN / API ==========================
  Future<String?> _getToken() async {
    try {
      return await UserLocalService().getAccessToken();
    } catch (_) {
      return null;
    }
  }

  Future<String?> _refreshAccessToken() async {
    try {
      final refresh = await UserLocalService().getRefreshToken();
      if (refresh == null || refresh.isEmpty) return null;
      final url = Uri.parse("http://197.239.116.77:3000/api/v1/auth/refresh");
      final resp = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refresh}));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final data = decoded['data'] ?? decoded;
        final newAccess = (data is Map) ? (data['accessToken'] ?? data['access_token']) : null;
        final newRefresh = (data is Map) ? (data['refreshToken'] ?? data['refresh_token']) : null;
        if (newAccess is String && newAccess.isNotEmpty) {
          await UserLocalService().saveTokens(newAccess, newRefresh is String ? newRefresh : refresh);
          return newAccess;
        }
      }
    } catch (e) {
      debugPrint('refresh token error: $e');
    }
    return null;
  }

  Future<void> _loadAlert() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      String? token = await _getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          error = "Token manquant - reconnecte toi";
          loading = false;
        });
        return;
      }

      final url = Uri.parse("http://197.239.116.77:3000/api/v1/alerts/${widget.alertId}");
      Map<String, String> headers() => {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
      var resp = await http.get(url, headers: headers());

      if (resp.statusCode == 401) {
        final newToken = await _refreshAccessToken();
        if (newToken != null && newToken.isNotEmpty) {
          token = newToken;
          resp = await http.get(url, headers: headers());
        }
      }

      if (resp.statusCode != 200) {
        setState(() {
          error = httpErrorMessage(resp.statusCode, resp.body);
          loading = false;
        });
        return;
      }

      final decoded = jsonDecode(resp.body);
      Map<String, dynamic>? obj;
      if (decoded is Map) {
        if (decoded['data'] is Map) {
          obj = Map<String, dynamic>.from(decoded['data']);
        } else {
          obj = Map<String, dynamic>.from(decoded);
        }
      }

      setState(() {
        alertData = obj;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = "Erreur réseau: $e";
        loading = false;
      });
    }
  }

  String _formatDate(String? d) {
    if (d == null || d.isEmpty) return '-';
    try {
      final dt = DateTime.tryParse(d);
      if (dt == null) return d;
      return "${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
    } catch (_) {
      return d;
    }
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 6),
      Text(value.isNotEmpty ? value : '—', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    ]);
  }

 
  // =================== VÉRIFICATIONS DE MÉDIAS ===================
  
  bool _hasImages() {
    if (alertData == null) return false;
    
    // Vérifier imageUrl ou images[]
    if (alertData!['imageUrl'] != null && (alertData!['imageUrl'] as String).isNotEmpty) {
      return true;
    }
    
    if (alertData!['images'] is List && (alertData!['images'] as List).isNotEmpty) {
      return true;
    }
    
    return false;
  }

  bool _hasVideos() {
    if (alertData == null) return false;
    
    if (alertData!['videoUrl'] != null && (alertData!['videoUrl'] as String).isNotEmpty) {
      return true;
    }
    
    if (alertData!['videos'] is List && (alertData!['videos'] as List).isNotEmpty) {
      return true;
    }
    
    return false;
  }

  bool _hasAudio() {
    if (alertData == null) return false;
    return alertData!['audioUrl'] != null && (alertData!['audioUrl'] as String).isNotEmpty;
  }

  bool _hasAttachments() {
    if (alertData == null) return false;
    return alertData!['attachments'] is List && (alertData!['attachments'] as List).isNotEmpty;
  }

  // =================== CONSTRUCTION DES WIDGETS DE MÉDIAS ===================

  Widget _buildImageGrid() {
    final List<String> imageUrls = [];
    
    // Image unique
    if (alertData!['imageUrl'] != null && (alertData!['imageUrl'] as String).isNotEmpty) {
      imageUrls.add(alertData!['imageUrl']);
    }
    
    // Liste d'images
    if (alertData!['images'] is List) {
      for (var img in alertData!['images'] as List) {
        if (img is String && img.isNotEmpty) {
          imageUrls.add(img);
        } else if (img is Map && img['url'] != null) {
          imageUrls.add(img['url']);
        }
      }
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: imageUrls.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _showImageFullscreen(imageUrls, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Image non disponible', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showImageFullscreen(List<String> images, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text('${initialIndex + 1} / ${images.length}'),
          ),
          body: PageView.builder(
            itemCount: images.length,
            controller: PageController(initialPage: initialIndex),
            itemBuilder: (context, index) {
              return Center(
                child: InteractiveViewer(
                  child: Image.network(
                    images[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text(
                          'Erreur de chargement',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVideoList() {
    final List<Map<String, dynamic>> videos = [];
    
    // Vidéo unique
    if (alertData!['videoUrl'] != null) {
      videos.add({
        'url': alertData!['videoUrl'],
        'thumbnail': alertData!['videoThumbnail'],
        'name': 'Vidéo',
      });
    }
    
    // Liste de vidéos
    if (alertData!['videos'] is List) {
      for (var vid in alertData!['videos'] as List) {
        if (vid is String) {
          videos.add({'url': vid, 'name': 'Vidéo'});
        } else if (vid is Map) {
          videos.add({
            'url': vid['url'],
            'thumbnail': vid['thumbnail'],
            'name': vid['name'] ?? 'Vidéo',
          });
        }
      }
    }
    
    return Column(
      children: videos.map((video) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: video['thumbnail'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      video['thumbnail'],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.videocam),
                        );
                      },
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.videocam, size: 30),
                  ),
            title: Text(video['name'] ?? 'Vidéo'),
            trailing: const Icon(Icons.play_circle_filled, color: Colors.purple),
            onTap: () {
              // TODO: Ouvrir le lecteur vidéo
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lecteur vidéo à implémenter')),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAudioPlayer() {
    final audioUrl = alertData!['audioUrl'] as String;
    final audioDescription = alertData!['audioDescription'] as String?;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(Icons.mic, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enregistrement audio',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (audioDescription != null && audioDescription.isNotEmpty)
                      Text(
                        audioDescription,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Implémenter le lecteur audio
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lecteur audio à implémenter')),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Écouter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentList() {
    final attachments = alertData!['attachments'] as List;
    
    return Column(
      children: attachments.map((attachment) {
        final name = attachment['filename'] ?? attachment['name'] ?? 'Fichier';
        final size = attachment['size'] ?? 0;
        final url = attachment['url'];
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file, color: Colors.grey),
            title: Text(name),
            subtitle: size > 0 ? Text(_formatFileSize(size)) : null,
            trailing: const Icon(Icons.download),
            onTap: () {
              // TODO: Télécharger le fichier
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Téléchargement de $name')),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // =================== FONCTIONS AUDIO ===================

  Future<void> _startRecording() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enregistrement audio non disponible sur le Web')),
      );
      return;
    }

    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission microphone refusée')),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/alert_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder!.start(const RecordConfig(), path: path);
      
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });

      // Mettre à jour la durée
      Stream.periodic(const Duration(milliseconds: 100)).listen((_) {
        if (_isRecording && mounted) {
          setState(() {
            _recordDuration = Duration(milliseconds: _recordDuration.inMilliseconds + 100);
          });
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder!.stop();
      setState(() {
        _isRecording = false;
        _recordedAudioPath = path;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _playRecordedAudio() async {
    if (_recordedAudioPath == null) return;

    try {
      if (_isPlayingRecorded) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.play(DeviceFileSource(_recordedAudioPath!));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  void _deleteRecordedAudio() {
    setState(() {
      _recordedAudioPath = null;
      _recordDuration = Duration.zero;
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  // =================== FONCTIONS UPLOAD MÉDIAS ===================

  Future<void> _pickImageForUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedImage = result.files.first);
    }
  }

  Future<void> _pickVideoForUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: kIsWeb,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedVideo = result.files.first);
    }
  }

  Future<void> _pickAudioForUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: kIsWeb,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedAudio = result.files.first);
    }
  }

  Future<void> _uploadMediasToAlert() async {
    if (_selectedImage == null && _selectedVideo == null && _selectedAudio == null && _recordedAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner ou enregistrer au moins un média')),
      );
      return;
    }

    setState(() => _uploadingMedia = true);

    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token manquant');
      }

      final url = Uri.parse("http://197.239.116.77:3000/api/v1/alerts/${widget.alertId}/attachments");
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';

      // Ajouter l'image
      if (_selectedImage != null) {
        if (kIsWeb && _selectedImage!.bytes != null) {
          String contentType = 'image/jpeg';
          if (_selectedImage!.name.toLowerCase().endsWith('.png')) {
            contentType = 'image/png';
          } else if (_selectedImage!.name.toLowerCase().endsWith('.gif')) {
            contentType = 'image/gif';
          }
          
          request.files.add(http.MultipartFile.fromBytes(
            'image',
            _selectedImage!.bytes!,
            filename: _selectedImage!.name,
            contentType: http.MediaType.parse(contentType),
          ));
        } else if (!kIsWeb && _selectedImage!.path != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'image',
            _selectedImage!.path!,
            filename: _selectedImage!.name,
          ));
        }
      }

      // Ajouter la vidéo
      if (_selectedVideo != null) {
        if (kIsWeb && _selectedVideo!.bytes != null) {
          String contentType = 'video/mp4';
          if (_selectedVideo!.name.toLowerCase().endsWith('.webm')) {
            contentType = 'video/webm';
          }
          
          request.files.add(http.MultipartFile.fromBytes(
            'video',
            _selectedVideo!.bytes!,
            filename: _selectedVideo!.name,
            contentType: http.MediaType.parse(contentType),
          ));
        } else if (!kIsWeb && _selectedVideo!.path != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'video',
            _selectedVideo!.path!,
            filename: _selectedVideo!.name,
          ));
        }
      }

      // Ajouter l'audio uploadé
      if (_selectedAudio != null) {
        if (kIsWeb && _selectedAudio!.bytes != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'audio',
            _selectedAudio!.bytes!,
            filename: _selectedAudio!.name,
            contentType: http.MediaType.parse('audio/mpeg'),
          ));
        } else if (!kIsWeb && _selectedAudio!.path != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'audio',
            _selectedAudio!.path!,
            filename: _selectedAudio!.name,
          ));
        }
      }

      // Ajouter l'audio enregistré
      if (_recordedAudioPath != null && !kIsWeb) {
        request.files.add(await http.MultipartFile.fromPath(
          'audio',
          _recordedAudioPath!,
          filename: 'recorded_audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
        ));
      }

      print("📤 Upload de ${request.files.length} fichier(s)...");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print("📤 Status: ${response.statusCode}");
      print("📤 Response: ${response.body}");

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Médias uploadés avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Réinitialiser les sélections
          setState(() {
            _selectedImage = null;
            _selectedVideo = null;
            _selectedAudio = null;
            _recordedAudioPath = null;
            _recordDuration = Duration.zero;
          });
          
          // Recharger l'alerte pour afficher les nouveaux médias
          _loadAlert();
        }
      } else {
        throw Exception('Erreur ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  Widget _buildMediaUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =================== AFFICHAGE DES MÉDIAS EXISTANTS ===================
          if (_hasImages() || _hasVideos() || _hasAudio() || _hasAttachments())
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Médias actuels',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // 📸 IMAGES
                if (_hasImages())
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.image, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Photos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildImageGrid(),
                      const SizedBox(height: 24),
                    ],
                  ),

                // 🎥 VIDÉOS
                if (_hasVideos())
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.video_library, color: Colors.purple),
                          SizedBox(width: 8),
                          Text('Vidéos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildVideoList(),
                      const SizedBox(height: 24),
                    ],
                  ),

                // 🎵 AUDIO
                if (_hasAudio())
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.audiotrack, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Audio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildAudioPlayer(),
                      const SizedBox(height: 24),
                    ],
                  ),

                // 📎 ATTACHMENTS
                if (_hasAttachments())
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.attach_file, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('Fichiers joints', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildAttachmentList(),
                      const SizedBox(height: 32),
                    ],
                  ),

                const Divider(thickness: 2),
                const SizedBox(height: 24),
              ],
            ),

          if (!(_hasImages() || _hasVideos() || _hasAudio() || _hasAttachments()))
            Column(
              children: const [
                SizedBox(height: 32),
                Icon(Icons.photo_library, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Aucun média pour l\'instant',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                SizedBox(height: 32),
              ],
            ),

          // =================== AJOUT DE NOUVEAUX MÉDIAS ===================
          if (_isEditable)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ajouter des médias',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Sélection Image
                _buildMediaSelector(
                  title: '📷 Image',
                  file: _selectedImage,
                  onSelect: _pickImageForUpload,
                  onClear: () => setState(() => _selectedImage = null),
                ),
                const SizedBox(height: 16),

                // Sélection Vidéo
                _buildMediaSelector(
                  title: '🎥 Vidéo',
                  file: _selectedVideo,
                  onSelect: _pickVideoForUpload,
                  onClear: () => setState(() => _selectedVideo = null),
                ),
                const SizedBox(height: 16),

                // Sélection Audio
                _buildMediaSelector(
                  title: '🎵 Audio (fichier)',
                  file: _selectedAudio,
                  onSelect: _pickAudioForUpload,
                  onClear: () => setState(() => _selectedAudio = null),
                ),
                const SizedBox(height: 16),

                // Enregistrement Audio
                if (!kIsWeb)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                      color: _isRecording ? Colors.red[50] : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🎤 Enregistrement audio',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (_recordedAudioPath == null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isRecording)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.mic, color: Colors.white),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Enregistrement en cours...',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _formatDuration(_recordDuration),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              if (!_isRecording) const SizedBox.shrink(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isRecording ? _stopRecording : _startRecording,
                                      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                                      label: Text(_isRecording ? 'Arrêter' : 'Enregistrer'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isRecording ? Colors.red : Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        if (_recordedAudioPath != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Audio enregistré ($_formatDuration(_recordDuration))',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _deleteRecordedAudio,
                                    icon: const Icon(Icons.close, color: Colors.red),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _playRecordedAudio,
                                icon: Icon(_isPlayingRecorded ? Icons.pause : Icons.play_arrow),
                                label: Text(_isPlayingRecorded ? 'Pause' : 'Écouter'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // Bouton Upload
                ElevatedButton.icon(
                  onPressed: _uploadingMedia ? null : _uploadMediasToAlert,
                  icon: _uploadingMedia
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_uploadingMedia ? 'Upload en cours...' : 'Uploader les médias'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),

          // Section verrouillée si non éditable
          if (!_isEditable)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Les médias ne peuvent être ajoutés que pour les alertes en statut BROUILLON ou EN ATTENTE',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaSelector({
    required String title,
    required PlatformFile? file,
    required VoidCallback onSelect,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (file == null)
            ElevatedButton.icon(
              onPressed: onSelect,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Choisir un fichier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.black87,
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    file.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
              ],
            ),
        ],
      ),
    );
  }

 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Détails de l'alerte"),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(text: "Détails complets"),
            Tab(text: "Médias"),
            Tab(text: "Commentaires"),
          ],
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    
                    // =================== Onglet Détails complets ===================
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ===== Header card =====
                          Container(
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFE53935)]),
                                    borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.warning_amber_rounded, size: 28, color: Colors.white),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    alertData?['title'] ?? 'Alerte SAP',
                                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text("ID: ${alertData?['id'] ?? alertData?['_id'] ?? ''}", style: const TextStyle(color: Color(0xFFFFEBEE), fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          _badge((alertData?['status'] ?? '').toString(), Colors.white.withOpacity(0.18), Colors.white),
                                          const SizedBox(height: 8),
                                          _badge((alertData?['severity'] ?? '').toString(), Colors.white.withOpacity(0.18), Colors.white),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: _infoTile("Type", (alertData?['type'] ?? '').toString())),
                                          const SizedBox(width: 12),
                                          Expanded(child: _infoTile("Zone", (alertData?['zoneName'] ?? (alertData?['zone'] is Map ? alertData!['zone']['name'] : 'Zone non spécifiée')).toString())),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(child: _infoTile("Début", _formatDate(alertData?['startDate']?.toString()))),
                                          const SizedBox(width: 12),
                                          Expanded(child: _infoTile("Fin", _formatDate(alertData?['endDate']?.toString()))),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(child: _infoTile("Action requise", (alertData?['actionRequired'] == true) ? "Oui" : "Non")),
                                          const SizedBox(width: 12),
                                          Expanded(child: _infoTile("Créée par", ((alertData?['createdBy'] is Map) ? "${alertData!['createdBy']['firstName'] ?? ''} ${alertData!['createdBy']['lastName'] ?? ''}" : (alertData?['createdByName'] ?? '—')).toString())),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ===== Message =====
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text("Message", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text(alertData?['message'] ?? 'Aucun message', style: const TextStyle(fontSize: 14)),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          // ===== Instructions =====
                          if ((alertData?['instructions'] ?? '').toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: const [Icon(Icons.info_outline, color: Colors.orange), SizedBox(width: 8), Text("Instructions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))]),
                                const SizedBox(height: 8),
                                Text(alertData?['instructions'] ?? '', style: const TextStyle(fontSize: 14)),
                              ]),
                            ),
                          const SizedBox(height: 12),
                          // ===== System info =====
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text("Informations système", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: Text("Créée: ${_formatDate(alertData?['createdAt']?.toString())}")),
                                Expanded(child: Text("Dernière modif: ${_formatDate(alertData?['updatedAt']?.toString())}")),
                              ]),
                            ]),
                          ),
                          const SizedBox(height: 16),

                          // =================== BOUTONS ACTIONS (Modifier / Annuler) ===================
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isSmallScreen = constraints.maxWidth < 500;

                              return Row(
                                children: [
                                  // ===== Bouton Modifier =====
                                  if (_isEditable)
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.edit),
                                        label: const Text("Modifier"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: _goToEditAlert,
                                      ),
                                    ),

                                  if (_isEditable) const SizedBox(width: 12),

                                  // ===== Bouton Annuler =====
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.close),
                                      label: const Text("Annuler"),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),

                          

                        ],
                      ),
                    ),

                    // =================== Onglet Médias (Affichage + Upload unifiés) ===================
                    _buildMediaUploadTab(),

          // =================== Onglet Commentaires ===================
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Commentaires", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),

                // Liste des commentaires existants
                if (alertData?['comments'] != null && (alertData!['comments'] as List).isNotEmpty)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: (alertData!['comments'] as List).length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final comment = alertData!['comments'][index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comment['author'] ?? 'Anonyme',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(comment['message'] ?? ''),
                            const SizedBox(height: 4),
                            Text(
                              comment['createdAt'] != null ? _formatDate(comment['createdAt']) : '',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                if (alertData?['comments']?.isEmpty ?? true)
                  const Text("Aucun commentaire."),

                const SizedBox(height: 16),
                // Ajouter un commentaire
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: "Ajouter un commentaire...",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _postComment,
                      child: const Text("Envoyer"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// =================== CONTROLLER ET FONCTIONS ===================
final TextEditingController _commentController = TextEditingController();

Future<void> _postComment() async {
  final message = _commentController.text.trim();
  if (message.isEmpty) return;

  try {
    final token = await _getToken();
    if (token == null) return;

    final url = Uri.parse("http://197.239.116.77:3000/api/v1/alerts/${widget.alertId}/comments");
    final resp = await http.post(url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'message': message}));

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      // Ajouter localement pour refresh immédiat
      setState(() {
        if (alertData?['comments'] == null) alertData!['comments'] = [];
        alertData!['comments'].add({
          'author': 'Moi', // remplacer par l'utilisateur réel si dispo
          'message': message,
          'createdAt': DateTime.now().toIso8601String(),
        });
        _commentController.clear();
      });
    } else {
      debugPrint("Erreur envoi commentaire: ${resp.statusCode}");
    }
  } catch (e) {
    debugPrint("Erreur envoi commentaire: $e");
  }     
} 
}