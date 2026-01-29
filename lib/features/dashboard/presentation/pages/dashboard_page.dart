// filepath: d:\Nema\ANAM\alert-system-app-main\lib\features\dashboard\presentation\pages\dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/core/services/socket_service.dart';
import 'package:mobile_app/features/alert/presentation/pages/alert_list_page.dart';
import 'package:mobile_app/features/alert/presentation/pages/create_alert.dart';
import 'package:mobile_app/features/notification/notification_bell.dart';
import 'package:mobile_app/features/notification/notification_provider.dart';
import 'package:mobile_app/features/user/domain/user_repository.dart';
import 'package:mobile_app/features/user/presentation/pages/profile_page.dart';
import 'package:mobile_app/features/user/data/sources/user_local_service.dart';
import 'package:mobile_app/features/alert/presentation/pages/alert_detail.dart';
import 'package:mobile_app/features/alert/data/sources/alert_local_service.dart';
import 'package:mobile_app/features/alert/presentation/pages/sync_alerts_page.dart'; 
import 'package:mobile_app/core/utils/http_error_helper.dart';
import 'package:mobile_app/core/utils/auth_error_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DashboardPage extends StatefulWidget {
  final UserRepository userRepository;
  final String token;

  const DashboardPage({
    super.key,
    required this.userRepository,
    required this.token,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    SocketService().connect((data) {
      context.read<NotificationProvider>().increment();

      Fluttertoast.showToast(
        msg: "${data['title']}\n${data['message']}",
        gravity: ToastGravity.BOTTOM,
      );
    });

    _pages = [
      _DashboardHome(userRepository: widget.userRepository, token: widget.token),
      const AlertsListPage(),
      ProfilePage(userRepository: widget.userRepository, token: widget.token),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Accueil"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "Alertes"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }
}

class _DashboardHome extends StatefulWidget {
  final UserRepository userRepository;
  final String token;

  const _DashboardHome({required this.userRepository, required this.token});

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  bool loading = false;
  String? error;
  List<dynamic> alerts = [];
  int pendingAlertsCount = 0;
  String? currentUserId;
  
  // Pour les notifications
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  List<String> _previousAlertIds = [];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadPreviousAlertIds();
    _loadCurrentUser();
    _fetchAlerts();
    _loadPendingAlertsCount();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Gérer le tap sur la notification
      },
    );
  }

  Future<void> _loadPendingAlertsCount() async {
    try {
      final count = await AlertLocalService().getPendingAlertsCount();
      if (mounted) {
        setState(() => pendingAlertsCount = count);
      }
    } catch (e) {
      debugPrint('Erreur chargement count: $e');
    }
  }

  Future<void> _loadPreviousAlertIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('seen_alert_ids_dashboard');
      if (stored != null && stored.isNotEmpty) {
        _previousAlertIds = List<String>.from(jsonDecode(stored));
      }
    } catch (e) {
      debugPrint('Erreur chargement alertes vues: $e');
    }
  }

  Future<void> _savePreviousAlertIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('seen_alert_ids_dashboard', jsonEncode(_previousAlertIds));
    } catch (e) {
      debugPrint('Erreur sauvegarde alertes vues: $e');
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final dynamic repo = widget.userRepository;
      final user = await repo.fetchUserProfile(widget.token); // ignore si absent
      setState(() => currentUserId = user?.id?.toString());
    } catch (_) {
      // pas bloquant si non dispo
    }
  }

  bool _isMine(Map a) {
    final created = a['createdById'] ??
        (a['createdBy'] is Map ? a['createdBy']['id'] : null) ??
        a['creatorId'] ??
        a['userId'];
    if (currentUserId == null || created == null) return false;
    return created.toString() == currentUserId;
  }

  Future<String?> _getToken() async {
    if (widget.token.isNotEmpty) return widget.token;
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
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );
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
      return null;
    } catch (e) {
      // don't crash on refresh error
      debugPrint('Erreur during token refresh: $e');
      return null;
    }
  }

  Future<void> _fetchAlerts() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      String? token = await _getToken();
      if (token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_alerts');
        if (cached != null && cached.isNotEmpty) {
          try {
            final decoded = jsonDecode(cached) as List<dynamic>;
            setState(() {
              alerts = decoded;
              loading = false;
            });
            return;
          } catch (_) {}
        }

        setState(() {
          error = "Token manquant — reconnecte-toi";
          loading = false;
        });
        return;
      }

      final url = Uri.parse("http://197.239.116.77:3000/api/v1/alerts");
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
        if (resp.statusCode == 401 || resp.statusCode == 403) {
          if (mounted) await showAuthExpiredDialog(context);
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_alerts');
        if (cached != null && cached.isNotEmpty) {
          try {
            final decoded = jsonDecode(cached) as List<dynamic>;
            setState(() {
              alerts = decoded;
              loading = false;
            });
            return;
          } catch (_) {}
        }

        setState(() {
          error = httpErrorMessage(resp.statusCode, resp.body);
          loading = false;
        });
        return;
      }

      final decoded = jsonDecode(resp.body);
      List<dynamic> items = [];
      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map) {
        if (decoded['data'] is List) {
          items = List<dynamic>.from(decoded['data']);
        } else if (decoded['alerts'] is List) items = List<dynamic>.from(decoded['alerts']);
        else if (decoded['data'] is Map && decoded['data']['items'] is List) items = List<dynamic>.from(decoded['data']['items']);
        else if (decoded['data'] is Map && decoded['data']['items'] == null && decoded['data'].containsKey('total')) {
          items = decoded['data']['items'] is List ? List<dynamic>.from(decoded['data']['items']) : [];
        }
      }

      // Vérifier les nouvelles alertes et afficher une notification
      await _checkForNewAlerts(items);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_alerts', jsonEncode(items));
      } catch (_) {}

      setState(() {
        alerts = items;
        loading = false;
      });
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_alerts');
        if (cached != null && cached.isNotEmpty) {
          final decoded = jsonDecode(cached) as List<dynamic>;
          setState(() {
            alerts = decoded;
            loading = false;
            error = null;
          });
          return;
        }
      } catch (_) {}

      setState(() {
        error = friendlyNetworkErrorMessage(e);
        loading = false;
      });
    }
  }

  /// Vérifie s'il y a de nouvelles alertes et affiche une notification
  Future<void> _checkForNewAlerts(List<dynamic> newAlerts) async {
    for (var alert in newAlerts) {
      final alertId = (alert['id'] ?? alert['_id'] ?? '').toString();
      
      if (alertId.isEmpty) continue;
      
      // Si c'est une nouvelle alerte (pas dans la liste précédente)
      if (!_previousAlertIds.contains(alertId)) {
        await _showNotificationForAlert(alert);
        _previousAlertIds.add(alertId);
      }
    }
    
    // Sauvegarder les IDs mis à jour
    await _savePreviousAlertIds();
  }

  /// Affiche une notification locale pour une nouvelle alerte
  Future<void> _showNotificationForAlert(dynamic alert) async {
    final title = (alert['title'] ?? 'Nouvelle Alerte').toString();
    final message = (alert['message'] ?? 'Une nouvelle alerte a été détectée').toString();
    final severity = (alert['severity'] ?? '').toString().toUpperCase();
    
    // Déterminer la priorité selon la sévérité
    Importance importance = Importance.defaultImportance;
    Priority priority = Priority.defaultPriority;
    
    if (severity == 'HIGH' || severity == 'CRITICAL' || severity == 'EXTREME') {
      importance = Importance.high;
      priority = Priority.high;
    } else if (severity == 'MEDIUM' || severity == 'MODERATE') {
      importance = Importance.defaultImportance;
      priority = Priority.defaultPriority;
    }

    final androidDetails = AndroidNotificationDetails(
      'alerts',
      'Alertes',
      channelDescription: 'Notifications pour les alertes',
      importance: importance,
      priority: priority,
      showWhen: true,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _localNotifications.show(
        id: alert.hashCode,
        title: '🚨 $title',
        body: message,
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Erreur affichage notification: $e');
    }
  }

  int _countForStatuses(List<String> statuses) {
    final up = statuses.map((s) => s.toUpperCase()).toSet();
    return alerts.where((a) {
      final s = (a?['status'] ?? a?['state'] ?? '').toString().toUpperCase();
      return up.contains(s);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = alerts.length;
    final pendingCount = _countForStatuses(['PENDING', 'WAITING', 'ON_HOLD', 'IN_PROGRESS']);
    final activeCount = _countForStatuses(['ACTIVE']);
    final sentByMeCount = alerts.where((a) {
      final s = (a?['status'] ?? a?['state'] ?? '').toString().toUpperCase();
      return _isMine(a) && (s == 'SENT' || s == 'TRANSMITTED');
    }).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 75,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Point Focal Communal",
              style: TextStyle(
                color: Colors.green,
                fontSize: 14,
              ),
            ),
          ],

        ),
         
        actions: [
          const NotificationBell(),   // push notification
          // Bouton de synchronisation avec badge
          if (pendingAlertsCount > 0)
            Stack(
              children: [
                IconButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SyncAlertsPage()),
                    );
                    if (result == true) {
                      _loadPendingAlertsCount();
                      _fetchAlerts();
                    }
                  },
                  icon: const Icon(Icons.cloud_upload, color: Colors.orange),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$pendingAlertsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            onPressed: () async {
              await _fetchAlerts();
              await _loadPendingAlertsCount();
            },
            icon: const Icon(Icons.refresh, color: Colors.black),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAlerts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatCard(title: "Total alertes", value: totalCount.toString()),
              StatCard(title: "En attente", value: pendingCount.toString()),
              StatCard(title: "Actives", value: activeCount.toString()),
              StatCard(title: "Envoyées", value: sentByMeCount.toString()),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    //builder: (context) => NewAlertStep1Page(alert: AlertModel()),
                    builder: (context) => CreateAlertPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "Créer une alerte",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            "Dernières alertes",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          else if (alerts.isEmpty && !loading)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("Aucune alerte trouvée"),
            )
          else if (loading)
            const Center(child: CircularProgressIndicator())
          else
            ...alerts.take(10).map((a) {
              final id = (a['id'] ?? a['_id'] ?? '').toString();
              final title = (a['title'] ?? 'Alerte SAP').toString();
              final message = (a['message'] ?? '').toString();
              final type = (a['type'] ?? '').toString();
              final zone = (a['zoneName'] ?? (a['zone'] is Map ? a['zone']['name'] : '') ?? '').toString();
              final severity = (a['severity'] ?? '').toString();
              final status = (a['status'] ?? a['state'] ?? '').toString();
              final startDate = (a['startDate'] ?? a['createdAt'] ?? '').toString();
              final affected = (a['affected'] ?? a['peopleAffected'] ?? '').toString();

              return AlertItem(
                id: id,
                title: title,
                message: message,
                type: type,
                zone: zone,
                severity: severity,
                status: status,
                startDate: startDate,
                affected: affected,
              );
            }),
        ]),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;

  const StatCard({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 50) / 2;
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class AlertItem extends StatelessWidget {
  final String id;
  final String title;
  final String message;
  final String type;
  final String zone;
  final String severity;
  final String status;
  final String startDate;
  final String affected;

  const AlertItem({
    super.key,
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.zone,
    required this.severity,
    required this.status,
    required this.startDate,
    required this.affected,
  });

  Color _statusBg(String s) {
    final u = s.toUpperCase();
    if (u == 'DRAFT') return Colors.grey.shade100;
    if (u == 'PENDING') return Colors.yellow.shade100;
    if (u == 'APPROVED') return Colors.green.shade100;
    if (u == 'REJECTED') return Colors.red.shade100;
    if (u == 'SENT') return Colors.blue.shade100;
    if (u == 'ACTIVE') return Colors.purple.shade100;
    if (u == 'CANCELLED') return Colors.orange.shade100;
    if (u == 'ARCHIVED') return Colors.grey.shade100;
    return Colors.grey.shade100;
  }

  Color _statusFg(String s) {
    final u = s.toUpperCase();
    if (u == 'DRAFT') return Colors.grey.shade700;
    if (u == 'PENDING') return Colors.yellow.shade700;
    if (u == 'APPROVED') return Colors.green.shade700;
    if (u == 'REJECTED') return Colors.red.shade700;
    if (u == 'SENT') return Colors.blue.shade700;
    if (u == 'ACTIVE') return Colors.purple.shade700;
    if (u == 'CANCELLED') return Colors.orange.shade700;
    if (u == 'ARCHIVED') return Colors.grey.shade500;
    return Colors.grey.shade700;
  }

  Color _severityBg(String s) {
    final u = s.toUpperCase();
    if (u == 'LOW' || u == 'INFO') return Colors.yellow.shade100;
    if (u == 'MEDIUM' || u == 'MODERATE') return Colors.orange.shade100;
    if (u == 'HIGH' || u == 'CRITICAL' || u == 'EXTREME') return Colors.red.shade100;
    return Colors.grey.shade100;
  }

  Color _severityFg(String s) {
    final u = s.toUpperCase();
    if (u == 'LOW' || u == 'INFO') return Colors.yellow.shade700;
    if (u == 'MEDIUM' || u == 'MODERATE') return Colors.orange.shade700;
    if (u == 'HIGH' || u == 'CRITICAL' || u == 'EXTREME') return Colors.red.shade700;
    return Colors.grey.shade700;
  }

  String _statusLabel(String s) {
    const labels = {
      'DRAFT': 'Brouillon',
      'PENDING': 'En attente',
      'APPROVED': 'Approuvée',
      'REJECTED': 'Rejetée',
      'SENT': 'Envoyée',
      'ACTIVE': 'Active',
      'CANCELLED': 'Annulée',
      'ARCHIVED': 'Archivée',
    };
    return labels[s.toUpperCase()] ?? s;
  }

  String _severityLabel(String s) {
    const labels = {
      'INFO': 'Info',
      'LOW': 'Faible',
      'MEDIUM': 'Moyen',
      'MODERATE': 'Moyen',
      'HIGH': 'Élevé',
      'CRITICAL': 'Critique',
      'EXTREME': 'Extrême',
    };
    return labels[s.toUpperCase()] ?? s;
  }

  String _typeLabel(String t) {
    const labels = {
      'FLOOD': 'Inondation',
      'DROUGHT': 'Sécheresse',
      'ATTACK': 'Attaque',
      'EPIDEMIC': 'Épidémie',
      'CONFLICT': 'Conflit',
      'FIRE': 'Incendie',
      'WIND': 'Vents violents',
      'LOCUST': 'Acridiens',
      'OTHER': 'Autre',
    };
    return labels[t.toUpperCase()] ?? t;
  }

  String _formatDate(String? d) {
    if (d == null || d.isEmpty) return '-';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}";
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (id.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AlertDetailsPage(alertId: id)),
          );
        }
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (message.isNotEmpty)
                          Text(
                            message,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _badge(_statusLabel(status), _statusBg(status), _statusFg(status)),
                  if (severity.isNotEmpty) _badge(_severityLabel(severity), _severityBg(severity), _severityFg(severity)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      zone.isNotEmpty ? zone : "Zone non spécifiée",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(_formatDate(startDate), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (type.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.category, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(_typeLabel(type), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ],
              ),
              if (affected.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.people, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text("$affected personnes affectées", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ],
           ),
         ),
      ),
    );
  }
}
