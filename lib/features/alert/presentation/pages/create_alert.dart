import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:mobile_app/features/user/data/sources/user_local_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart'; // optionnel mais utile

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:mobile_app/core/network/connectivity_service.dart';
import 'package:mobile_app/features/alert/data/sources/alert_local_service.dart';
import 'package:mobile_app/core/utils/sms_helper.dart';
import 'package:mobile_app/features/alert/data/sources/zones_local_service.dart';
import 'package:mobile_app/core/utils/http_error_helper.dart';
import 'package:mobile_app/core/utils/auth_error_dialog.dart';
const bool isWeb = kIsWeb;

class CreateAlertPage extends StatefulWidget {
  final bool isEditMode;
  final String? alertId;
  final Map<String, dynamic>? existingAlert;

  const CreateAlertPage({
    super.key,
    this.isEditMode = false,
    this.existingAlert,
    this.alertId,
  });


  @override
  State<CreateAlertPage> createState() => _CreateAlertPageState();
  
}

class _CreateAlertPageState extends State<CreateAlertPage> {
  bool loading = false;
  bool zonesLoading = false;
  String? errorMessage;
  String? selectedRegionId;
  String? selectedProvinceId;
  String? selectedCommuneId;
  String? _alertId;
  // Validation errors
  String? _titleError;
  String? _messageError;
  String? _zoneError;
  String? _startDateError;

  List<Map<String, dynamic>> regions = [];
 
  List<Map<String, dynamic>> filteredProvinces = [];
  List<Map<String, dynamic>> filteredCommunes = [];

  final List<PlatformFile> _images = [];
  final List<PlatformFile> _videos = [];


  
  List zones = [];
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _otherTypeController = TextEditingController();
  final TextEditingController _audioDescriptionController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  

  // Audio recording
  AudioRecorder? _audioRecorder;
  AudioPlayer? _audioPlayer;

  String? _audioPath;
  bool _isRecording = false;
  bool _isPlaying = false;
  Duration _recordDuration = Duration.zero;
  String? _audioDescriptionError;
  bool _isBase64Media(String path) {
  return path.startsWith('data:image') || path.startsWith('data:video');
}

 
  
  

  // FORM DATA
  final form = {
    "title": "",
    "message": "",
    "type": "FLOOD",
    "severity": "MODERATE",
    "zoneId": "",
    "startDate": "",
    "startTime": "",
    "endDate": "",
    "endTime": "",
    "instructions": "",
    "actionRequired": false
  };

  final alertTypes = [
    {"value": "FLOOD", "label": "Inondation"},
    {"value": "DROUGHT", "label": "Sécheresse"},
    {"value": "EPIDEMIC", "label": "Épidémie"},
    {"value": "FIRE", "label": "Incendie"},
    {"value": "STORM", "label": "Tempête"},
    {"value": "EARTHQUAKE", "label": "Tremblement de terre"},
    {"value": "SECURITY", "label": "Sécurité/Conflit"},
    {"value": "FAMINE", "label": "Famine"},
    {"value": "LOCUST", "label": "Invasion acridienne"},
    {"value": "OTHER", "label": "Autre"}
  ];

  final severityLevels = [
    {"value": "INFO", "label": "Information"},
    {"value": "LOW", "label": "Faible"},
    {"value": "MODERATE", "label": "Modéré"},
    {"value": "HIGH", "label": "Élevé"},
    {"value": "CRITICAL", "label": "Critique"},
    {"value": "EXTREME", "label": "Extrême"}
  ];

  // Gestion des localisations multiples
List<Map<String, dynamic>> localisations = [
  {
    "region": null,
    "province": null,
    "commune": null,
    "provinces": [],
    "communes": []
  }
];



void _hydrateForm(Map<String, dynamic> alert) {
  form["title"] = alert["title"] ?? "";
  form["message"] = alert["message"] ?? "";
  form["instructions"] = alert["instructions"] ?? "";
  form["type"] = alert["type"];
  form["severity"] = alert["severity"];
  form["zoneId"] = alert["zone"]?["id"] ?? alert["zoneId"];
  form["actionRequired"] = alert["actionRequired"] ?? false;

  _titleController.text = form["title"] as String;
  _messageController.text = form["message"] as String;
  _instructionsController.text = form["instructions"] as String;
}




// Liste pour stocker les régions depuis l'API
List<Map<String, dynamic>> regionsApi = [];


@override
void initState() {
  super.initState();

  _loadZones();
  _loadRegions();

  if (!kIsWeb) {
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  final alert = widget.existingAlert;

  if (widget.isEditMode && alert != null) {
    _hydrateForm(alert);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initLocalisationFromAlert(alert);
    });
  }

  if (alert != null) {
  form["title"] = alert["title"] ?? "";
  form["message"] = alert["message"] ?? "";
  form["instructions"] = alert["instructions"] ?? "";
  form["type"] = alert["type"];
  form["severity"] = alert["severity"];
  form["zoneId"] = alert["zone"]?["id"] ?? alert["zoneId"];
  form["actionRequired"] = alert["actionRequired"] ?? false;
  _titleController.text = form["title"] as String;
  _messageController.text = form["message"] as String;
  _instructionsController.text = form["instructions"] as String;

  if (alert["startDate"] != null) {
    final start = DateTime.tryParse(alert["startDate"]);
    if (start != null) {
      form["startDate"] = start.toIso8601String().split("T")[0];
      _startDateController.text = form["startDate"]?.toString() ?? "";
    }
  }

  if (alert["endDate"] != null) {
    final end = DateTime.tryParse(alert["endDate"]);
    if (end != null) {
      form["endDate"] = end.toIso8601String().split("T")[0];
      _endDateController.text = form["endDate"]?.toString() ?? "";
    }
  }


  

}







 

}

  void _setupAudioPlayer() {
  if (_audioPlayer == null) return;

  _audioPlayer!.onPlayerStateChanged.listen((state) {
    if (mounted) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    }
  });
}


  @override
  void dispose() {
    _startDateController.dispose();
    _startTimeController.dispose();
    _endDateController.dispose();
    _endTimeController.dispose();
    _otherTypeController.dispose();
    _audioDescriptionController.dispose();
    super.dispose();
  }

  Future<String?> _getAccessTokenFromProfile() async {
    try {
      return await UserLocalService().getAccessToken();
    } catch (e) {
      print("Erreur lecture token : $e");
      return null;
    }
  }

    // GET ZONES
  Future<void> _loadZones() async {
    setState(() => zonesLoading = true);

    try {
      // Try local cache first
      final zonesService = ZonesLocalService();
      await zonesService.init();
      final localCommunes = await zonesService.getZonesByType('COMMUNE');
      if (localCommunes.isNotEmpty) {
        setState(() {
          zones = localCommunes;
          if (zones.isNotEmpty && (form["zoneId"] == null || form["zoneId"].toString().isEmpty)) {
            form["zoneId"] = zones[0]["id"];
          }
          zonesLoading = false;
          errorMessage = null;
        });
      }

      // Fetch remote and update cache in background if possible
      final token = await _getAccessTokenFromProfile();
      if (token == null || token.isEmpty) {
        if (localCommunes.isEmpty) {
          setState(() {
            errorMessage = "Token d'authentification manquant";
            zonesLoading = false;
          });
        }
        return;
      }

      // Perform an initial-login sync using the ZonesLocalService.
      try {
        await zonesService.syncZones(token);
        final synced = await zonesService.getZonesByType('COMMUNE');
        if (synced.isNotEmpty) {
          setState(() {
            zones = synced;
            if (zones.isNotEmpty && (form["zoneId"] == null || form["zoneId"].toString().isEmpty)) {
              form["zoneId"] = zones[0]["id"];
            }
            zonesLoading = false;
            errorMessage = null;
          });
          return;
        }
      } catch (e) {
        // If sync fails, we fall back to previously loaded local cache (if any).
        print('Initial zones sync failed: $e');
      }

      // If sync didn't populate anything, leave the existing local zones if present.
      if (zones.isEmpty && localCommunes.isEmpty) {
        setState(() {
          errorMessage = "Aucune zone disponible";
          zonesLoading = false;
        });
      } else {
        setState(() => zonesLoading = false);
      }
    } catch (e, stackTrace) {
      print("❌ Exception: $e");
      print("❌ StackTrace: $stackTrace");
      setState(() {
        if (zones.isEmpty) errorMessage = "Erreur réseau: $e";
        zonesLoading = false;
      });
    }
  }


Future<void> _restoreLocationFromZone(Map<String, dynamic> zone) async {
  final loc = localisations.first;

  // Cas COMMUNE (le plus courant)
  if (zone["type"] == "COMMUNE") {
    final communeId = zone["id"];
    final provinceId = zone["parentId"];

    loc["provinceId"] = provinceId;
    await _loadCommunesForLoc(loc, provinceId);

    loc["communeId"] = communeId;

    final province =
        loc["communes"].firstWhere((c) => c["id"] == communeId);
    final regionId = province["parentId"];

    loc["regionId"] = regionId;
    await _loadProvincesForLoc(loc, regionId);

    if (mounted) setState(() {});
  }
}


Future<void> _loadRegions() async {
  try {
    final zonesService = ZonesLocalService();
    await zonesService.init();

    // Read regions from local DB first
    final localRegions = await zonesService.getRegions();
    if (localRegions.isNotEmpty) {
      setState(() {
        regions = localRegions.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    }

    // If no local regions, or to refresh, attempt sync using token
    final token = await _getAccessTokenFromProfile();
    if (token == null || token.isEmpty) {
      if (localRegions.isEmpty) {
        print("❌ Token manquant pour charger régions");
      }
      return;
    }

    try {
      await zonesService.syncAllZones(token);
      final synced = await zonesService.getRegions();
      if (synced.isNotEmpty) {
        setState(() {
          regions = synced.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) {
      print('Regions sync failed: $e');
    }
  } catch (e) {
    print("❌ Erreur chargement régions: $e");
  }
}




Future<void> _initLocalisationFromAlert(Map<String, dynamic> alert) async {
  final zone = alert["zone"];
  if (zone == null) return;

  final regionId = zone["regionId"]?.toString();
  final provinceId = zone["provinceId"]?.toString();
  final communeId = zone["id"]?.toString();

  if (regionId == null) return;

  localisations = [
    {
      "regionId": regionId,
      "provinceId": provinceId,
      "communeId": communeId,
      "provinces": [],
      "communes": []
    }
  ];

  await _loadProvincesForLoc(localisations[0], regionId);

  if (provinceId != null) {
    await _loadCommunesForLoc(localisations[0], provinceId);
  }

  setState(() {});
}



Future<void> _loadProvincesForLoc(
  Map<String, dynamic> loc,
  String regionId,
) async {
  try {
    final zonesService = ZonesLocalService();
    await zonesService.init();

    // Try local provinces first
    final localProvinces = await zonesService.getProvinces(regionId);
    if (localProvinces.isNotEmpty) {
      setState(() => loc['provinces'] = localProvinces.map((e) => Map<String, dynamic>.from(e)).toList());
      return;
    }

    // Fallback: try syncing and re-read
    final token = await _getAccessTokenFromProfile();
    if (token != null && token.isNotEmpty) {
      try {
        await zonesService.syncAllZones(token);
        final synced = await zonesService.getProvinces(regionId);
        if (synced.isNotEmpty) {
          setState(() => loc['provinces'] = synced.map((e) => Map<String, dynamic>.from(e)).toList());
          return;
        }
      } catch (e) {
        print('Provinces sync error: $e');
      }
    }
  } catch (e) {
    print('Erreur chargement provinces: $e');
  }
}


Future<void> _loadCommunesForLoc(
  Map<String, dynamic> loc,
  String provinceId,
) async {
  try {
    final zonesService = ZonesLocalService();
    await zonesService.init();

    final localCommunes = await zonesService.getCommunes(provinceId);
    if (localCommunes.isNotEmpty) {
      setState(() => loc['communes'] = localCommunes.map((e) => Map<String, dynamic>.from(e)).toList());
      return;
    }

    final token = await _getAccessTokenFromProfile();
    if (token != null && token.isNotEmpty) {
      try {
        await zonesService.syncAllZones(token);
        final synced = await zonesService.getCommunes(provinceId);
        if (synced.isNotEmpty) {
          setState(() => loc['communes'] = synced.map((e) => Map<String, dynamic>.from(e)).toList());
          return;
        }
      } catch (e) {
        print('Communes sync error: $e');
      }
    }
  } catch (e) {
    print('Erreur chargement communes: $e');
  }
}





MediaType? _getMediaType(String filePath) {
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
    case 'webm':
      return MediaType('video', 'webm');
    case 'mov':
      return MediaType('video', 'quicktime');

    // Audio
    case 'mp3':
      return MediaType('audio', 'mpeg');
    case 'm4a':
      return MediaType('audio', 'mp4');
    case 'wav':
      return MediaType('audio', 'wav');
    case 'ogg':
      return MediaType('audio', 'ogg');

    default:
      return MediaType('application', 'octet-stream');
  }
}


    // Audio recording functions
  Future<void> _startRecording() async {
          if (kIsWeb) {
        setState(() => errorMessage = "L'enregistrement audio n'est pas disponible sur le Web");
        return;
      }

    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        setState(() => errorMessage = "Permission microphone refusée");
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder!.start(const RecordConfig(), path: path);
      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });

      // Update duration
      Stream.periodic(const Duration(seconds: 1)).listen((_) {
        if (_isRecording && mounted) {
          setState(() => _recordDuration += const Duration(seconds: 1));
        }
      });
    } catch (e) {
      debugPrint("Error starting recording: $e");
      setState(() => errorMessage = "Erreur lors du démarrage de l'enregistrement: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder!.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
      debugPrint("Recording saved at: $path");
    } catch (e) {
      debugPrint("Error stopping recording: $e");
      setState(() => errorMessage = "Erreur lors de l'arrêt de l'enregistrement: $e");
    }
  }

  Future<void> _playAudio() async {
    if (_audioPath == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.play(DeviceFileSource(_audioPath!));
      }
    } catch (e) {
      debugPrint("Error playing audio: $e");
      setState(() => errorMessage = "Erreur lors de la lecture audio: $e");
    }
  }

  void _deleteAudio() {
    setState(() {
      _audioPath = null;
      _recordDuration = Duration.zero;
      _audioDescriptionController.clear();
      form["audioDescription"] = "";
    });
  }


  // 📅 Sélection de date
Future<void> _pickDate({required bool isStart}) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );

  if (picked != null) {
    final formatted = picked.toIso8601String().split("T")[0];
    setState(() {
      if (isStart) {
        form["startDate"] = formatted;
        _startDateController.text = formatted;
      } else {
        form["endDate"] = formatted;
      }
    });
  }
}

// ⏰ Sélection de l’heure
Future<void> _pickTime({required bool isStart}) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );

  if (picked != null) {
    final formatted =
        "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
    setState(() {
      if (isStart) {
        form["startTime"] = formatted;
      } else {
        form["endTime"] = formatted;
      }
    });
  }
}

/// Galerie images (Web + Mobile)
  Future<void> _pickImages() async {
  if (kIsWeb) {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: true,
    );

    if (result != null) {
      setState(() => _images.addAll(result.files));
    }
    return;
  }

  final picker = ImagePicker();
  final images = await picker.pickMultiImage(imageQuality: 70);

  if (images.isEmpty) return;

  setState(() {
    _images.addAll(
      images.map((img) => PlatformFile(
        name: img.name,
        path: img.path,
        size: 0,
      )),
    );
  });
}



  /// Caméra (Mobile uniquement)
  Future<void> _takePhoto() async {
  if (kIsWeb) {
    setState(() => errorMessage = "Caméra indisponible sur le Web");
    return;
  }

  final status = await Permission.camera.request();
  if (!status.isGranted) {
    setState(() => errorMessage = "Permission caméra refusée");
    return;
  }

  final picker = ImagePicker();
  final XFile? photo = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 70,
  );

  if (photo == null) return;

  setState(() {
    _images.add(
      PlatformFile(
        name: photo.name,
        path: photo.path,
        size: 0,
      ),
    );
  });
}



  /// Vidéos (Web + Mobile)
  Future<void> _pickVideos() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.video,
    withData: kIsWeb,
  );

  if (result == null) return;

  setState(() {
    _videos.addAll(result.files);
  });
}



  // POST alert
  Future<void> _submitAlert(String status) async {
    print("=== DEBUG: _submitAlert appelé avec status=$status ===");
    print("Form data: $form");
    print("canSubmit value: $canSubmit");



    if (!canSubmit) {
      // Set individual field errors
      setState(() {
        if (form["title"].toString().trim().isEmpty) {
          _titleError = "Le titre est obligatoire";
        } else if (form["title"].toString().trim().length < 5) {
          _titleError = "Le titre doit contenir au moins 5 caractères";
        }

        if (form["message"].toString().trim().isEmpty) {
          _messageError = "Le message est obligatoire";
        } else if (form["message"].toString().trim().length < 10) {
          _messageError = "Le message doit contenir au moins 10 caractères";
        }

        if ((form["zoneId"] ?? "").toString().isEmpty) {
          _zoneError = "La région est obligatoire";
        }

        if ((form["startDate"] ?? "").toString().isEmpty) {
          _startDateError = "La date de début est obligatoire";
        }

        errorMessage = "⚠️ Veuillez remplir tous les champs obligatoires marqués d'une étoile (*)";
      });
      if (!mounted) return;

Navigator.pop(context, true);

      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    // Combiner dates et préparer payload
    final startDateTime = _combineDateTime(form["startDate"] as String?, form["startTime"] as String?);
    final endDateTime = (form["endDate"] ?? "").toString().isNotEmpty
        ? _combineDateTime(form["endDate"] as String?, form["endTime"] as String?)
        : null;

    final data = {
      "title": form["title"],
      "message": form["message"],
      "type": form["type"],
      "severity": form["severity"],
      "zoneId": form["zoneId"],
      "startDate": startDateTime,
      if (endDateTime != null) "endDate": endDateTime,  // Optionnel - inclure seulement si présent
      "instructions": form["instructions"],
      "actionRequired": form["actionRequired"],
      "status": status,
    };

    // Vérifier la connectivité et sauvegarder localement si hors-ligne
    final connectivityService = ConnectivityService();
    final hasConnection = await connectivityService.hasConnection();

    if (!hasConnection) {
      try {
        final localService = AlertLocalService();
        await localService.addPendingAlert(data);

        if (mounted) {
          setState(() => loading = false);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📴 Pas de connexion. Alerte sauvegardée localement.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );

          // Proposer d'envoyer par SMS
          try {
            final sendSms = await SmsHelper.showSmsDialog(context, data);
            if (sendSms == true) {
              final smsSent = await SmsHelper.sendSms(
                message: SmsHelper.formatAlertToSms(data),
              );
              if (!smsSent && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Impossible d\'ouvrir l\'application SMS'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } catch (_) {}

          Navigator.pop(context, true);
        }
        return;
      } catch (e) {
        print("ERROR: Erreur sauvegarde locale - $e");
        setState(() => errorMessage = "Erreur sauvegarde locale : $e");
        setState(() => loading = false);
        return;
      }
    }

    print("Sending alert with data: $data");

    final isEdit = widget.isEditMode && widget.existingAlert != null;

final alertId = isEdit
    ? widget.existingAlert!["id"]
    : null;

final url = isEdit
    ? Uri.parse("http://197.239.116.77:3000/api/v1/alerts/$alertId")
    : Uri.parse("http://197.239.116.77:3000/api/v1/alerts");

    try {
      final token = await _getAccessTokenFromProfile();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      form.removeWhere(
  (key, value) => value == null || (value is String && value.trim().isEmpty),
);

data.removeWhere(
  (key, value) => value == null || (value is String && value.trim().isEmpty),
);
if (!widget.isEditMode) {
  data.remove('status');
}

late http.Response response;

if (widget.isEditMode && widget.existingAlert != null) {
  final alertId = widget.existingAlert!['id'].toString();

  response = await http.put(
    Uri.parse("http://197.239.116.77:3000/api/v1/alerts/$alertId"),
    headers: headers,
    body: jsonEncode(data),
  );
} else {
  response = await http.post(
    Uri.parse("http://197.239.116.77:3000/api/v1/alerts"),
    headers: headers,
    body: jsonEncode(data),
  );
}
if (response.statusCode == 200) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Navigator.pop(context);
  });
}

    

      print("API Response status: ${response.statusCode}");
      print("API Response body: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
  final respJson = jsonDecode(response.body);

  final alertData = respJson['data'];
  if (alertData == null || alertData['id'] == null) {
    throw Exception("Alerte créée mais ID manquant");
  }

  final alertId = alertData['id'].toString();

  // 🔴 IMPORTANT : uploader les médias UNIQUEMENT si SUBMITTED
  if (status == "SUBMITTED") {
    await _uploadMediaForAlert(alertId, token!);
  }

  if (mounted) Navigator.pop(context, true);
    if (mounted) Navigator.pop(context, true);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        if (mounted) await showAuthExpiredDialog(context);
      } else {
        setState(() => errorMessage = httpErrorMessage(response.statusCode, response.body));
      }
    } catch (e) {
      print("ERROR: Erreur réseau - $e");
      setState(() => errorMessage = "Erreur réseau : $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
}


    
  
  

  // Upload media for a created alert id
  Future<void> _uploadMediaForAlert(String alertId, String token) async {
    try {
      // Vérifier s'il y a des fichiers
      final hasImage = _images.isNotEmpty;
      final hasVideo = _videos.isNotEmpty;
      final hasAudio = _audioPath != null && _audioPath!.isNotEmpty;

      debugPrint('📊 Média check: hasImage=$hasImage, hasVideo=$hasVideo, hasAudio=$hasAudio');

      if (!hasImage && !hasVideo && !hasAudio) {
        debugPrint('✅ Aucun média à uploader');
        return;
      }

      final mediaUrl = Uri.parse('http://197.239.116.77:3000/api/v1/alerts/$alertId/attachments');
      final request = http.MultipartRequest('POST', mediaUrl);
      request.headers['Authorization'] = 'Bearer $token';

      // Image (prendre la première)
      if (hasImage) {
  final img = _images.first;
  debugPrint('📷 Image: name=${img.name}, path=${img.path}, isWeb=$isWeb');

  // 🌐 WEB → bytes
  if (kIsWeb && img.bytes != null) {
    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        img.bytes!,
        filename: img.name,
        contentType: _getMediaType(img.name),
      ),
    );
  }

  // 📱 MOBILE
  else if (img.path != null) {
    // ✅ BASE64
    if (_isBase64Media(img.path!)) {
      final base64Data = img.path!.split(',').last;
      final bytes = base64Decode(base64Data);

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: img.name,
          contentType: _getMediaType(img.name),
        ),
      );
    }

    // ✅ FICHIER NORMAL
    else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          img.path!,
          contentType: _getMediaType(img.path!),
        ),
      );
    }
  }
}

      

      // Video (prendre la première)
      // ================= VIDEO =================
if (_videos.isNotEmpty) {
  final video = _videos.first;
  debugPrint('🎥 Video: name=${video.name}, path=${video.path}');

  // 🌐 WEB
  if (kIsWeb && video.bytes != null) {
    request.files.add(
      http.MultipartFile.fromBytes(
        'video',
        video.bytes!,
        filename: video.name,
        contentType: _getMediaType(video.name),
      ),
    );
  }

  // 📱 MOBILE
  else if (video.path != null) {
    // ✅ VIDEO BASE64
    if (_isBase64Media(video.path!)) {
      final base64Data = video.path!.split(',').last;
      final bytes = base64Decode(base64Data);

      request.files.add(
        http.MultipartFile.fromBytes(
          'video',
          bytes,
          filename: video.name,
          contentType: _getMediaType(video.name),
        ),
      );
    }

    // ✅ VIDEO FICHIER LOCAL
    else {
      request.files.add(
        await http.MultipartFile.fromPath(
          'video',
          video.path!,
          contentType: _getMediaType(video.path!),
        ),
      );
    }
  }
}

      // Audio (enregistrement local)
      // ================= AUDIO =================
          if (_audioPath != null) {
            debugPrint('🎙️ Audio path=$_audioPath');

            // ✅ AUDIO BASE64
            if (_audioPath!.startsWith('data:audio')) {
              final base64Data = _audioPath!.split(',').last;
              final bytes = base64Decode(base64Data);

              request.files.add(
                http.MultipartFile.fromBytes(
                  'audio',
                  bytes,
                  filename: 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
                  contentType: MediaType('audio', 'm4a'),
                ),
              );
            }

            // ✅ AUDIO FICHIER LOCAL
            else {
              request.files.add(
                await http.MultipartFile.fromPath(
                  'audio',
                  _audioPath!,
                  contentType: MediaType('audio', 'm4a'),
                ),
              );
            }
          }

      debugPrint('📤 Nombre de fichiers à uploader: ${request.files.length}');

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      debugPrint('🎬 Media upload status: ${resp.statusCode}');
      debugPrint('📦 Media upload body: ${resp.body}');
      debugPrint('📋 Request headers: ${request.headers}');
      debugPrint('📋 Request fields: ${request.fields}');
      debugPrint('📋 Files count: ${request.files.length}');

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        // Parse la réponse pour extraire les URLs
        try {
          final respData = jsonDecode(resp.body);
          final alertData = respData['data'] as Map<String, dynamic>? ?? {};
          
          final imageUrl = alertData['imageUrl'] as String?;
          final videoUrl = alertData['videoUrl'] as String?;
          final audioUrl = alertData['audioUrl'] as String?;
          
          // Construire un message de succès avec les URLs
          String mediaMessage = "✅ Médias uploadés avec succès!\n\n";
          
          if (imageUrl != null && imageUrl.isNotEmpty) {
            mediaMessage += "📷 Image: $imageUrl\n";
            debugPrint('✅ Image uploadée: $imageUrl');
          }
          if (videoUrl != null && videoUrl.isNotEmpty) {
            mediaMessage += "🎥 Vidéo: $videoUrl\n";
            debugPrint('✅ Vidéo uploadée: $videoUrl');
          }
          if (audioUrl != null && audioUrl.isNotEmpty) {
            mediaMessage += "🎧 Audio: $audioUrl\n";
            debugPrint('✅ Audio uploadé: $audioUrl');
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mediaMessage),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } catch (e) {
          debugPrint('⚠️ Erreur parsing réponse média: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Médias uploadés avec succès!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        debugPrint('❌ Erreur upload - Status ${resp.statusCode}');
        debugPrint('❌ Response: ${resp.body}');
        setState(() => errorMessage = 'Erreur upload média (${resp.statusCode}): ${resp.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur upload média: ${resp.statusCode}\n${resp.body}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur upload media après création: $e');
      setState(() => errorMessage = 'Erreur upload des médias : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

                    Future<void> _saveDraft() async {
  debugPrint("=== SAVE DRAFT ===");
  debugPrint("Form: $form");

  // 🔴 RÈGLE : description obligatoire si audio existe
  if (_audioPath != null &&
      _audioDescriptionController.text.trim().isEmpty) {
    setState(() {
      _audioDescriptionError =
          "Veuillez décrire le contenu de l'enregistrement audio.";
    });
    return; // ⛔ STOP ici, pas d'appel API
  } else {
    _audioDescriptionError = null;
  }

  setState(() {
    loading = true;
    errorMessage = null;
  });

  // 🔁 Dates combinées (si présentes)
  final startDateTime =
      _combineDateTime(form["startDate"] as String?, form["startTime"] as String?);

  final endDateTime =
      (form["endDate"] ?? "").toString().isNotEmpty
          ? _combineDateTime(form["endDate"] as String?, form["endTime"] as String?)
          : null;

  // 📦 DONNÉES À ENVOYER
  final data = {
    "title": form["title"] ?? "",
    "message": form["message"] ?? "",
    "type": form["type"],
    "severity": form["severity"],
    "zoneId": form["zoneId"],
    "startDate": startDateTime,
    "endDate": endDateTime,
    if ((form["instructions"] ?? "").toString().trim().isNotEmpty)
  "instructions": form["instructions"],

"actionRequired": form["actionRequired"] == true,

// ⚠️ status seulement en édition


    "instructions": form["instructions"],
    "actionRequired": form["actionRequired"],
    "status": "DRAFT",

    // 🎧 Audio (si présent)
    "audioDescription": _audioDescriptionController.text.trim(),
  };

  debugPrint("Draft payload: $data");

  final isEdit = widget.isEditMode && widget.existingAlert != null;

final alertId = isEdit
    ? widget.existingAlert!["id"]
    : null;

final url = isEdit
    ? Uri.parse("http://197.239.116.77:3000/api/v1/alerts/$alertId")
    : Uri.parse("http://197.239.116.77:3000/api/v1/alerts");


  try {
    final token = await _getAccessTokenFromProfile();

    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };

    final response = isEdit
    ? await http.put(
        url,
        headers: headers,
        body: jsonEncode(data),
      )
    : await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );

    debugPrint("Draft response ${response.statusCode}");
    debugPrint(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Brouillon enregistré avec succès"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } else {
      setState(() {
        errorMessage = httpErrorMessage(response.statusCode, response.body);
      });
    }
  } catch (e) {
    setState(() {
      errorMessage = "Erreur réseau : $e";
    });
  } finally {
    if (mounted) {
      setState(() => loading = false);
    }
  }
}


  bool get canSubmit {
    return form["title"].toString().trim().length >= 5 &&
        form["message"].toString().trim().length >= 10 &&
        (form["zoneId"] ?? "").toString().isNotEmpty &&
        (form["startDate"] ?? "").toString().isNotEmpty;
  }

  String? _combineDateTime(String? date, String? time) {
    if ((date ?? "").isEmpty) return null;
    int hour = 0;
    int minute = 0;
    if ((time ?? "").isNotEmpty) {
      final parts = (time ?? "").split(":");
      if (parts.length >= 2) {
        hour = int.tryParse(parts[0]) ?? 0;
        minute = int.tryParse(parts[1]) ?? 0;
      }
    }
    try {
      final parts = date!.split("-");
      if (parts.length >= 3) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        final dt = DateTime(y, m, d, hour, minute);
        return dt.toIso8601String();
      } else {
        final parsed = DateTime.tryParse(date);
        if (parsed != null) {
          final dt = DateTime(parsed.year, parsed.month, parsed.day, hour, minute);
          return dt.toIso8601String();
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final padding = isMobile ? 16.0 : 32.0;
    final maxWidth = 600.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Créer une alerte"),
        leading: const BackButton(),
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    children: [
                      // Error Message
                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: Colors.red[100],
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("❌ Erreur", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              Text(errorMessage!, style: TextStyle(color: Colors.red[900])),
                            ],
                          ),
                        ),
                      // Debug status
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.blue[50],
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          zonesLoading ? "⏳ Chargement des zones..." : "✅ Zones: ${zones.length} chargée(s)",
                          style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                        ),
                      ),
                      // Title
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: "Titre *",
                          hintText: "Ex: Inondation à Ouagadougou",
                          border: const OutlineInputBorder(),
                          errorText: _titleError,
                          helperText: "${form["title"].toString().length}/5 caractères minimum",
                          helperStyle: TextStyle(
                            color: form["title"].toString().length >= 5 ? Colors.green : Colors.grey,
                          ),
                        ),
                        onChanged: (v) {
                          setState(() {
                            form["title"] = v;
                            if (v.trim().isEmpty) {
                              _titleError = "Le titre est obligatoire";
                            } else if (v.trim().length < 5) {
                              _titleError = "Le titre doit contenir au moins 5 caractères";
                            } else {
                              _titleError = null;
                            }
                          });
                        },
                        onEditingComplete: () {
                          if (form["title"].toString().trim().isEmpty) {
                            setState(() => _titleError = "Le titre est obligatoire");
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      
                      
                      

                      // Type & Severity
                      isMobile
                          ? Column(
                              children: [
                                DropdownButtonFormField(
                                  decoration: const InputDecoration(
                                    labelText: "Type d'alerte *",
                                    border: OutlineInputBorder(),
                                  ),
                                  initialValue: form["type"],
                                  items: alertTypes
                                      .map((e) => DropdownMenuItem(
                                          value: e["value"], child: Text(e["label"]!)))
                                      .toList(),
                                  onChanged: (v) => setState(() => form["type"] = v ?? ""),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField(
                                  decoration: const InputDecoration(
                                    labelText: "Sévérité *",
                                    border: OutlineInputBorder(),
                                  ),
                                  initialValue: form["severity"],
                                  items: severityLevels
                                      .map((e) => DropdownMenuItem(
                                          value: e["value"], child: Text(e["label"]!)))
                                      .toList(),
                                  onChanged: (v) => setState(() => form["severity"] = v ?? ""),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField(
                                    decoration: const InputDecoration(
                                      labelText: "Type d'alerte *",
                                      border: OutlineInputBorder(),
                                    ),
                                    initialValue: form["type"],
                                    items: alertTypes
                                        .map((e) => DropdownMenuItem(
                                            value: e["value"], child: Text(e["label"]!)))
                                        .toList(),
                                    onChanged: (v) => setState(() => form["type"] = v ?? ""),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField(
                                    decoration: const InputDecoration(
                                      labelText: "Sévérité *",
                                      border: OutlineInputBorder(),
                                    ),
                                    initialValue: form["severity"],
                                    items: severityLevels
                                        .map((e) => DropdownMenuItem(
                                            value: e["value"], child: Text(e["label"]!)))
                                        .toList(),
                                    onChanged: (v) => setState(() => form["severity"] = v ?? ""),
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 16),
                      // Conditional "Other" type field
                      if (form["type"] == "OTHER") ...[
                        const SizedBox(height: 28),
                        _buildLabel("Spécifiez le type d'alerte *", Icons.edit),
                        const SizedBox(height: 12),
                        _buildTextField(
                          hintText: "Ex: Pollution, Accident routier, etc.",
                          controller: _otherTypeController,
                          onChanged: (v) => setState(() => form["customType"] = v),
                        ),
                      ],
                      const SizedBox(height: 16),


                    ...List.generate(localisations.length, (index) {
                          final loc = localisations[index];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [

                              // REGION
                              DropdownButtonFormField<String>(
  decoration: const InputDecoration(
    labelText: "Région *",
    border: OutlineInputBorder(),
    filled: true,
    fillColor: Colors.white,
  ),
  value: loc["regionId"],
  isExpanded: true,
  items: regions.map<DropdownMenuItem<String>>((r) {
    return DropdownMenuItem<String>(
      value: r["id"],
      child: Text(r["name"]),
    );
  }).toList(),
  onChanged: (regionId) {
    setState(() {
      loc["regionId"] = regionId;

      // reset hiérarchie
      loc["provinceId"] = null;
      loc["communeId"] = null;
      loc["provinces"] = [];
      loc["communes"] = [];

      // utilisé par le backend
      form["zoneId"] = regionId ?? "";


      if (regionId != null) {
        _loadProvincesForLoc(loc, regionId);
      }
    });
  },
),


                              const SizedBox(height: 16),

                              // PROVINCE
                              DropdownButtonFormField<String>(
  decoration: const InputDecoration(
    labelText: "Province *",
    border: OutlineInputBorder(),
  ),
  value: loc["provinceId"],
  items: (loc["provinces"] as List)
      .map<DropdownMenuItem<String>>((p) {
    return DropdownMenuItem<String>(
      value: p["id"],
      child: Text(p["name"]),
    );
  }).toList(),
  onChanged: (provinceId) {
    setState(() {
      loc["provinceId"] = provinceId;
      loc["communeId"] = null;
      loc["communes"] = [];

      if (provinceId != null) {
        _loadCommunesForLoc(loc, provinceId);
      }
    });
  },
),


                              const SizedBox(height: 16),

                              // COMMUNE
                              DropdownButtonFormField<String>(
  decoration: const InputDecoration(
    labelText: "Commune *",
    border: OutlineInputBorder(),
  ),
  value: loc["communeId"],
  items: (loc["communes"] as List)
      .map<DropdownMenuItem<String>>((c) {
    return DropdownMenuItem<String>(
      value: c["id"],
      child: Text(c["name"]),
    );
  }).toList(),
  onChanged: (communeId) {
  setState(() {
    loc["communeId"] = communeId;

    if (communeId != null && communeId.isNotEmpty) {
      form["zoneId"] = communeId; // String non-null ✅
      _zoneError = null;
    } else {
      form.remove("zoneId"); // évite données invalides
    }
  });
},




),

                              const SizedBox(height: 24),

                              if (localisations.length > 1)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => setState(() => localisations.removeAt(index)),
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    label: const Text("Supprimer",
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ),

                              // Show zone error
                              if (_zoneError != null && index == 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _zoneError!,
                                    style: const TextStyle(color: Colors.red, fontSize: 12),
                                  ),
                                ),

                              const Divider(height: 32),
                            ],
                          );
                       }),


                        // Ajouter un autre groupe
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text("Ajouter une autre localisation"),
                            onPressed: () => setState(() => localisations.add({
                              "regionId": null,
  "provinceId": null,
  "communeId": null,
  "provinces": [],
  "communes": []
                            })),
                          ),
                        ),

                      const SizedBox(height: 16),
                      // Period
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Période de l'événement", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          isMobile
                              ? Column(
                                  children: [
                                   TextField(
                                    controller: _startDateController,
                                    readOnly: true,
                                    decoration: InputDecoration(
                                      labelText: "Date début *",
                                      border: const OutlineInputBorder(),
                                      suffixIcon: const Icon(Icons.calendar_today),
                                      errorText: _startDateError,
                                    ),
                                    onTap: () async {
                                      final DateTime? picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );

                                      if (picked != null) {
                                        final formatted =
                                            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                        _startDateController.text = formatted;  // ✅ Met à jour le champ affiché
                                        setState(() {
                                          form["startDate"] = formatted;         // ✅ Met à jour la donnée pour la base
                                          _startDateError = null;  // Clear error
                                        });
                                      } else {
                                        setState(() {
                                          if (_startDateController.text.isEmpty) {
                            _startDateError = "La date de début est obligatoire";
                                          }
                                        });
                                      }
                                    },
                                  ),


                                    const SizedBox(height: 12),
                                   TextField(
                                          controller: _startTimeController,
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                            labelText: "Heure début",
                                            border: OutlineInputBorder(),
                                            suffixIcon: Icon(Icons.access_time),
                                          ),
                                          onTap: () async {
                                            final TimeOfDay? picked = await showTimePicker(
                                              context: context,
                                              initialTime: TimeOfDay.now(),
                                            );

                                            if (picked != null) {
                                              final formatted =
                                                  "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                                              _startTimeController.text = formatted;   // ✅ Met à jour le champ affiché
                                              setState(() {
                                                form["startTime"] = formatted;         // ✅ Met à jour la donnée pour la base
                                              });
                                            }
                                          },
                                        ),


                                    const SizedBox(height: 16),
                                    TextField(
                                  controller: _endDateController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: "Date fin",
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(Icons.calendar_today),
                                  ),
                                  onTap: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2100),
                                    );

                                    if (picked != null) {
                                      final formatted =
                                          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                      _endDateController.text = formatted;    // Affiche la date choisie dans le champ
                                      setState(() {
                                        form["endDate"] = formatted;          // Stocke la date dans ton formulaire
                                      });
                                    }
                                  },
                                ),


                                    const SizedBox(height: 12),
                                    TextField(
                                    controller: _endTimeController,
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: "Heure fin",
                                      border: OutlineInputBorder(),
                                      suffixIcon: Icon(Icons.access_time),
                                    ),
                                    onTap: () async {
                                      final TimeOfDay? picked = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                      );

                                      if (picked != null) {
                                        final formatted =
                                            "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                                        _endTimeController.text = formatted;    // Affiche l'heure choisie dans le champ
                                        setState(() {
                                          form["endTime"] = formatted;          // Stocke l'heure dans ton formulaire
                                        });
                                      }
                                    },
                                  ),

                                  ],
                                )
                              : Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _startDateController,
                                            readOnly: true,
                                            decoration: const InputDecoration(
                                              labelText: "Date début",
                                              border: OutlineInputBorder(),
                                              suffixIcon: Icon(Icons.calendar_today),
                                            ),
                                            onTap: () async {
                                              final DateTime? picked = await showDatePicker(
                                                context: context,
                                                initialDate: DateTime.now(),
                                                firstDate: DateTime(2000),
                                                lastDate: DateTime(2100),
                                              );

                                              if (picked != null) {
                                                final formatted =
                                                    "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                                _startDateController.text = formatted;  // ✅ Met à jour le champ affiché
                                                setState(() {
                                                  form["startDate"] = formatted;         // ✅ Met à jour la donnée pour la base
                                                });
                                              }
                                            },
                                          ),

                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child:TextField(
                                            controller: _startTimeController,
                                            readOnly: true,
                                            decoration: const InputDecoration(
                                              labelText: "Heure début",
                                              border: OutlineInputBorder(),
                                              suffixIcon: Icon(Icons.access_time),
                                            ),
                                            onTap: () async {
                                              final TimeOfDay? picked = await showTimePicker(
                                                context: context,
                                                initialTime: TimeOfDay.now(),
                                              );

                                              if (picked != null) {
                                                final formatted =
                                                    "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                                                _startTimeController.text = formatted;   // ✅ Met à jour le champ affiché
                                                setState(() {
                                                  form["startTime"] = formatted;         // ✅ Met à jour la donnée pour la base
                                                });
                                              }
                                            },
                                          ),


                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child:TextField(
                                            controller: _endDateController,
                                            readOnly: true,
                                            decoration: const InputDecoration(
                                              labelText: "Date fin",
                                              border: OutlineInputBorder(),
                                              suffixIcon: Icon(Icons.calendar_today),
                                            ),
                                            onTap: () async {
                                              final DateTime? picked = await showDatePicker(
                                                context: context,
                                                initialDate: DateTime.now(),
                                                firstDate: DateTime(2000),
                                                lastDate: DateTime(2100),
                                              );

                                              if (picked != null) {
                                                final formatted =
                                                    "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                                _endDateController.text = formatted;    // Affiche la date choisie dans le champ
                                                setState(() {
                                                  form["endDate"] = formatted;          // Stocke la date dans ton formulaire
                                                });
                                              }
                                            },
                                          ),


                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextField(
                                          controller: _endTimeController,
                                          readOnly: true,
                                          decoration: const InputDecoration(
                                            labelText: "Heure fin",
                                            border: OutlineInputBorder(),
                                            suffixIcon: Icon(Icons.access_time),
                                          ),
                                          onTap: () async {
                                            final TimeOfDay? picked = await showTimePicker(
                                              context: context,
                                              initialTime: TimeOfDay.now(),
                                            );

                                            if (picked != null) {
                                              final formatted =
                                                  "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                                              _endTimeController.text = formatted;    // Affiche l'heure choisie dans le champ
                                              setState(() {
                                                form["endTime"] = formatted;          // Stocke l'heure dans ton formulaire
                                              });
                                            }
                                          },
                                        ),

                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Message
                      TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(labelText: "Message *", border: OutlineInputBorder()),
                        maxLines: 5,
                        onChanged: (v) => setState(() => form["message"] = v),
                      ),
                      const SizedBox(height: 16),
                      // Instructions
                      TextField(
                        controller: _instructionsController,
                        decoration: const InputDecoration(labelText: "Instructions", border: OutlineInputBorder()),
                        maxLines: 3,
                        onChanged: (v) => setState(() => form["instructions"] = v),
                      ),
                      // Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: (form["actionRequired"] as bool?) ?? false,
                            onChanged: (val) => setState(() => form["actionRequired"] = val ?? false),
                          ),
                          const Text("Action immédiate requise")
                        ],
                      ),
                      const SizedBox(height: 20),

                      //const SizedBox(height: 16),
                      //const Text("Image (optionnelle)", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _pickImages,
                              icon: const Icon(Icons.photo_library),
                              label: const Text("Ajouter des images (Galerie)"),
                            ),
                          ),
                           const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _takePhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text("Prendre une photo"),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                                onPressed: _pickVideos,
                                icon: const Icon(Icons.videocam),
                                label: const Text("Ajouter des vidéos"),
                              ),
                          ),
                        ],
                      ),

                      if (_images.isNotEmpty)
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, index) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 150,
                                  color: Colors.grey.shade300,
                                  child: _buildImagePreview(_images[index]),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () => setState(() => _images.removeAt(index)),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_videos.isNotEmpty)
                      SizedBox(
                        height: 160,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _videos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, index) => Stack(
                            children: [
                              Container(
                                width: 200,
                                padding: const EdgeInsets.all(8),
                                color: Colors.black12,
                                child: _buildVideoPreview(_videos[index]),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () => setState(() => _videos.removeAt(index)),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),


                    const SizedBox(height: 24),

                    // ================= AUDIO (OPTIONNEL) =================
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                         

                          // Bouton enregistrer / arrêter
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                              label: Text(_isRecording ? "Arrêter l'enregistrement" : "Enregistrer un audio"),
                              onPressed: _isRecording ? _stopRecording : _startRecording,
                            ),
                          ),

                          const SizedBox(height: 8),

                        // Lecture / suppression si audio existe
                        if (_audioPath != null)
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                                onPressed: _playAudio,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: _deleteAudio,
                              ),
                              const Text("Audio enregistré"),
                            ],
                          ),

                        const SizedBox(height: 12),
                      ],
                    ),

                    const SizedBox(height: 12),
                      // Buttons
                      isMobile
                           ? Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: loading ? null : _saveDraft,
                child: const Text("Enregistrer brouillon"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : () => _submitAlert("SUBMITTED"),
                child: Text(
                  widget.isEditMode
                      ? "Modifier et soumettre"
                      : "Créer et soumettre",
                ),
              ),
            ),
          ],
        )
      : Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: loading ? null : _saveDraft,
                child: const Text("Enregistrer brouillon"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: loading ? null : () => _submitAlert("SUBMITTED"),
                child: Text(
                  widget.isEditMode
                      ? "Modifier et soumettre"
                      : "Créer et soumettre",
                ),
              ),
            ),
          ],
        ),
                    ],
                      ),
              ),
            ),
    ));
  }
  
  
}

Widget _buildLabel(String text, IconData icon) {
  return Row(
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    ],
  );
}

Widget _buildImagePreview(PlatformFile image) {
  if (kIsWeb) {
    if (image.bytes == null) {
      return const Icon(Icons.broken_image);
    }
    return Image.memory(image.bytes!, fit: BoxFit.cover);
  }

  return Image(
    image: FileImage(File(image.path!)),
    fit: BoxFit.cover,
  );
}

Widget _buildVideoPreview(PlatformFile video) {
  if (kIsWeb) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.videocam, size: 40),
        const SizedBox(height: 8),
        Text(
          video.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  return _MobileVideoPlayer(file: File(video.path!));
}


Widget _buildTextField({
  required String hintText,
  required TextEditingController controller,
  required Function(String) onChanged,
}) {
  return TextField(
    controller: controller,
    decoration: InputDecoration(
      hintText: hintText,
      border: const OutlineInputBorder(),
    ),
    onChanged: onChanged,
  );
}

class _MobileVideoPlayer extends StatefulWidget {
  final File file;
  const _MobileVideoPlayer({required this.file});

  @override
  State<_MobileVideoPlayer> createState() => _MobileVideoPlayerState();
}

class _MobileVideoPlayerState extends State<_MobileVideoPlayer> {
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
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}

