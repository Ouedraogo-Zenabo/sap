import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/network/connectivity_service.dart';
import 'package:mobile_app/core/utils/sms_helper.dart';
import 'package:mobile_app/features/user/data/sources/user_local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/sources/alert_local_service.dart';

/// Page de synchronisation des alertes hors-ligne
class SyncAlertsPage extends StatefulWidget {
  const SyncAlertsPage({super.key});

  @override
  State<SyncAlertsPage> createState() => _SyncAlertsPageState();
}

class _SyncAlertsPageState extends State<SyncAlertsPage> {
  final AlertLocalService _localService = AlertLocalService();
  final ConnectivityService _connectivityService = ConnectivityService();
  List<Map<String, dynamic>> _pendingAlerts = [];
  bool _loading = true;
  bool _syncing = false;
  bool _autoSyncEnabled = true;
  final Map<String, String> _syncStatus = {}; // localId -> status message
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadAutoSyncSetting();
    await _loadPendingAlerts();
    _startConnectivityListener();
    await _maybeAutoSync();
  }

  Future<void> _loadAutoSyncSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? true;
    });
  }

  void _startConnectivityListener() {
    _connectivitySub ??= _connectivityService.onConnectivityChanged.listen((hasConnection) {
      if (!mounted) return;
      if (hasConnection) {
        _maybeAutoSync();
      }
    });
  }

  Future<void> _maybeAutoSync() async {
    if (!_autoSyncEnabled || _syncing || _pendingAlerts.isEmpty) return;

    final hasConnection = await _connectivityService.hasConnection();
    if (!hasConnection) return;

    // Lance la synchro automatique si des alertes sont en attente
    await _syncAllAlerts();
  }

  Future<void> _loadPendingAlerts() async {
    setState(() => _loading = true);
    try {
      final alerts = await _localService.getPendingAlerts();
      setState(() {
        _pendingAlerts = alerts;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement: $e')),
        );
      }
    }
  }

  Future<void> _syncAllAlerts() async {
    if (_syncing) return;

    setState(() {
      _syncing = true;
      _syncStatus.clear();
    });

    final token = await UserLocalService().getAccessToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token manquant. Veuillez vous reconnecter.')),
        );
      }
      setState(() => _syncing = false);
      return;
    }

    int successCount = 0;
    int failCount = 0;

    for (var alert in List.from(_pendingAlerts)) {
      final localId = alert['localId'] as String;
      
      setState(() {
        _syncStatus[localId] = 'Synchronisation...';
      });

      try {
        final success = await _syncSingleAlert(alert, token);
        
        if (success) {
          await _localService.removePendingAlert(localId);
          setState(() {
            _syncStatus[localId] = '✅ Synchronisé';
            _pendingAlerts.removeWhere((a) => a['localId'] == localId);
          });
          successCount++;
        } else {
          setState(() {
            _syncStatus[localId] = '❌ Échec';
          });
          failCount++;
        }
      } catch (e) {
        setState(() {
          _syncStatus[localId] = '❌ Erreur: $e';
        });
        failCount++;
      }

      // Petit délai entre chaque alerte
      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() => _syncing = false);

    if (mounted) {
      final message = successCount > 0
          ? '$successCount alerte(s) synchronisée(s)${failCount > 0 ? ", $failCount échec(s)" : ""}'
          : 'Aucune alerte synchronisée';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: successCount > 0 ? Colors.green : Colors.orange,
        ),
      );

      // Si tout est synchronisé, retour
      if (_pendingAlerts.isEmpty) {
        Navigator.pop(context, true);
      }
    }
  }

  Future<bool> _syncSingleAlert(Map<String, dynamic> alertData, String token) async {
    try {
      // Préparer les données pour l'API (enlever les champs locaux)
      final apiData = Map<String, dynamic>.from(alertData);
      final mediaData = apiData.remove('mediaData') as Map<String, dynamic>?;
      apiData.remove('localId');
      apiData.remove('createdOfflineAt');

      final url = Uri.parse('http://197.239.116.77:3000/api/v1/alerts');
      
      // 📝 ÉTAPE 1: Créer l'alerte avec JSON
      print("\n🔵 ÉTAPE 1: Création de l'alerte (JSON)...");
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(apiData),
      );

      print("POST /alerts status: ${response.statusCode}");
      print("Response: ${response.body}");

      if (response.statusCode != 200 && response.statusCode != 201) {
        return false;
      }

      final responseData = jsonDecode(response.body);
      final alertId = responseData['data']?['id'];
      if (alertId == null) {
        print("❌ Pas d'ID dans la réponse");
        return false;
      }

      print("✅ Alerte créée avec ID: $alertId");

      // 📤 ÉTAPE 2: Uploader les médias si présents
      if (mediaData != null && mediaData.isNotEmpty) {
        print("\n🔵 ÉTAPE 2: Upload des médias...");
        final mediaUrl = Uri.parse('http://197.239.116.77:3000/api/v1/alerts/$alertId/attachments');
        
        final request = http.MultipartRequest('POST', mediaUrl);
        request.headers['Authorization'] = 'Bearer $token';
        
        // 📷 Image
        if (mediaData['imagePath'] != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'image',
            mediaData['imagePath'],
            filename: 'image.jpg',
          ));
        }
        
        // 🎥 Vidéo
        if (mediaData['videoPath'] != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'video',
            mediaData['videoPath'],
            filename: 'video.mp4',
          ));
        }
        
        // 🎧 Audio
        if (mediaData['audioPath'] != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'audio',
            mediaData['audioPath'],
            filename: 'audio.m4a',
          ));
        }

        final streamedResponse = await request.send();
        final mediaResponse = await http.Response.fromStream(streamedResponse);

        print("POST /alerts/{id}/attachments status: ${mediaResponse.statusCode}");
        
        if (mediaResponse.statusCode != 200) {
          print("⚠️ Upload médias échoué mais alerte créée");
        } else {
          print("✅ Médias uploadés avec succès");
        }
      } else {
        print("✅ Pas de médias à uploader");
      }

      return true;
    } catch (e) {
      debugPrint('Erreur sync alerte: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchronisation'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pendingAlerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_done, size: 80, color: Colors.green.shade300),
                      const SizedBox(height: 20),
                      const Text(
                        'Toutes les alertes sont synchronisées',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Retour'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // En-tête
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: Colors.orange.shade50,
                      child: Column(
                        children: [
                          Icon(Icons.cloud_upload, size: 50, color: Colors.orange.shade700),
                          const SizedBox(height: 10),
                          Text(
                            '${_pendingAlerts.length} alerte(s) en attente',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Ces alertes ont été créées hors-ligne',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                    // Liste des alertes
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pendingAlerts.length,
                        itemBuilder: (context, index) {
                          final alert = _pendingAlerts[index];
                          final localId = alert['localId'] as String;
                          final status = _syncStatus[localId];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange.shade100,
                                child: Icon(
                                  Icons.warning_amber,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              title: Text(
                                alert['type'] ?? 'Alerte sans type',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(alert['title'] ?? alert['message'] ?? 'Sans description'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Créée: ${_formatDate(alert['createdOfflineAt'])}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  if (status != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: status.contains('✅')
                                              ? Colors.green
                                              : status.contains('❌')
                                                  ? Colors.red
                                                  : Colors.blue,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: status == null || status.contains('❌')
                                  ? PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) async {
                                        if (value == 'sms') {
                                          final sendSms = await SmsHelper.showSmsDialog(context, alert);
                                          if (sendSms == true) {
                                            await SmsHelper.sendSms(
                                              message: SmsHelper.formatAlertToSms(alert),
                                            );
                                          }
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'sms',
                                          child: Row(
                                            children: [
                                              Icon(Icons.sms, size: 20, color: Colors.blue),
                                              SizedBox(width: 10),
                                              Text('Envoyer par SMS'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : status.contains('✅')
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Bouton de synchronisation
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 5,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _syncing ? null : _syncAllAlerts,
                          icon: _syncing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.sync),
                          label: Text(
                            _syncing ? 'Synchronisation...' : 'Synchroniser tout',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Date inconnue';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Date invalide';
    }
  }
}
