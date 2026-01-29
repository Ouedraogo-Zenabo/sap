import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/features/alert/presentation/pages/alert_detail.dart';
import 'package:mobile_app/features/user/data/sources/user_local_service.dart';
import 'package:mobile_app/core/utils/http_error_helper.dart';
import 'package:mobile_app/core/utils/auth_error_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AlertsListPage extends StatefulWidget {
  const AlertsListPage({super.key});

  @override
  State<AlertsListPage> createState() => _AlertsListPageState();
}

class _AlertsListPageState extends State<AlertsListPage> {
  bool loading = false;
  String? error;
  List<Map<String, dynamic>> alerts = [];
  int page = 1;
  int limit = 20;
  int total = 0;
  int totalPages = 0;

  String filterType = '';
  String filterSeverity = '';
  String filterStatus = '';
  String filterStart = '';
  String filterEnd = '';

  // Pour les notifications
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  List<String> _previousAlertIds = [];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadAlerts();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidSettings,
    );
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Gérer le tap sur la notification
      },
    );
  }

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
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final data = decoded is Map ? (decoded['data'] ?? decoded) : decoded;
        final access = data is Map ? (data['accessToken'] ?? data['access_token']) : null;
        final refreshOut = data is Map ? (data['refreshToken'] ?? data['refresh_token']) : null;
        if (access is String && access.isNotEmpty) {
          await UserLocalService().saveTokens(access, refreshOut is String && refreshOut.isNotEmpty ? refreshOut : refresh);
          return access;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadAlerts() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      String? token = await _getToken();
      if (token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_alerts_list');
        if (cached != null && cached.isNotEmpty) {
          try {
            final decoded = jsonDecode(cached);
            List<Map<String, dynamic>> items = [];
            if (decoded is List) items = decoded.cast<Map<String, dynamic>>();
            if (items.isNotEmpty) {
              setState(() {
                alerts = items;
                loading = false;
              });
              return;
            }
          } catch (_) {}
        }

        setState(() {
          loading = false;
        });
        return;
      }

      final params = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (filterType.isNotEmpty) 'type': filterType,
        if (filterSeverity.isNotEmpty) 'severity': filterSeverity,
        if (filterStatus.isNotEmpty) 'status': filterStatus,
        if (filterStart.isNotEmpty) 'startDate': filterStart,
        if (filterEnd.isNotEmpty) 'endDate': filterEnd,
      };

      final uri = Uri.http("197.239.116.77:3000", "/api/v1/alerts", params);
      Map<String, String> headers(String t) => {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $t',
          };

      var resp = await http.get(uri, headers: headers(token));

      if (resp.statusCode == 401) {
        final newToken = await _refreshAccessToken();
        if (newToken != null && newToken.isNotEmpty) {
          token = newToken;
          resp = await http.get(uri, headers: headers(token));
        }
      }

      if (resp.statusCode != 200) {
        if (resp.statusCode == 401 || resp.statusCode == 403) {
          if (mounted) await showAuthExpiredDialog(context);
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_alerts_list');
        if (cached != null && cached.isNotEmpty) {
          try {
            final decoded = jsonDecode(cached);
            List<Map<String, dynamic>> items = [];
            if (decoded is List) items = decoded.cast<Map<String, dynamic>>();
            if (items.isNotEmpty) {
              setState(() {
                alerts = items;
                loading = false;
              });
              return;
            }
          } catch (_) {}
        }

        setState(() {
          error = httpErrorMessage(resp.statusCode, resp.body);
          loading = false;
        });
        return;
      }

      final decoded = jsonDecode(resp.body);

      List<Map<String, dynamic>> items = [];
      if (decoded is List) {
        items = decoded.cast<Map<String, dynamic>>();
      } else if (decoded is Map) {
        if (decoded['data'] is List) {
          items = (decoded['data'] as List).cast<Map<String, dynamic>>();
        } else if (decoded['alerts'] is List) {
          items = (decoded['alerts'] as List).cast<Map<String, dynamic>>();
        } else if (decoded['data'] is Map && decoded['data']['items'] is List) {
          items = (decoded['data']['items'] as List).cast<Map<String, dynamic>>();
        }
        final meta = decoded['pagination'] ??
            (decoded['data'] is Map ? (decoded['data']['pagination'] ?? decoded['data']['meta']) : null);
        if (meta is Map) {
          total = (meta['total'] ?? total) is int ? meta['total'] : total;
          totalPages = (meta['totalPages'] ?? meta['pages'] ?? totalPages) is int
              ? (meta['totalPages'] ?? meta['pages'])
              : totalPages;
          page = (meta['page'] ?? page) is int ? meta['page'] : page;
          limit = (meta['limit'] ?? meta['perPage'] ?? limit) is int ? (meta['limit'] ?? meta['perPage']) : limit;
        } else if (decoded['total'] is int && decoded['totalPages'] is int) {
          total = decoded['total'];
          totalPages = decoded['totalPages'];
        }
      }

      // Vérifier les nouvelles alertes
      await _checkForNewAlerts(items);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_alerts_list', jsonEncode(items));
      } catch (_) {}

      setState(() {
        alerts = items;
        loading = false;
      });
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_alerts_list');
        if (cached != null && cached.isNotEmpty) {
          final decoded = jsonDecode(cached);
          List<Map<String, dynamic>> items = [];
          if (decoded is List) items = decoded.cast<Map<String, dynamic>>();
          if (items.isNotEmpty) {
            setState(() {
              alerts = items;
              loading = false;
              error = null;
            });
            return;
          }
        }
      } catch (_) {}

      setState(() {
        error = friendlyNetworkErrorMessage(e);
        loading = false;
      });
    }
  }

  /// Vérifie s'il y a de nouvelles alertes et affiche une notification
  Future<void> _checkForNewAlerts(List<Map<String, dynamic>> newAlerts) async {
    for (var alert in newAlerts) {
      final alertId = (alert['id'] ?? alert['_id'] ?? '').toString();
      
      if (alertId.isEmpty) continue;
      
      if (!_previousAlertIds.contains(alertId)) {
        await _showNotificationForAlert(alert);
      }
    }
    
    _previousAlertIds = newAlerts
        .map((a) => (a['id'] ?? a['_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
  }

  /// Affiche une notification locale pour une nouvelle alerte
  Future<void> _showNotificationForAlert(Map<String, dynamic> alert) async {
    final title = (alert['title'] ?? 'Nouvelle Alerte').toString();
    final message = (alert['message'] ?? 'Une nouvelle alerte a été détectée').toString();
    
    const androidDetails = AndroidNotificationDetails(
      'alerts',
      'Alertes',
      channelDescription: 'Notifications pour les alertes',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

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

  String _formatDate(String? d) {
    if (d == null || d.isEmpty) return '-';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}";
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Toutes les alertes",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAlerts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _filterBar(),
              const SizedBox(height: 8),
              _selectedFiltersChips(),
              const SizedBox(height: 12),
              if (error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 8),
              _alertsList(),
              if (!loading && totalPages > 1 && alerts.isNotEmpty) _paginationBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          const Text("Filtres", style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(
            onPressed: _showFiltersBottomSheet,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text("Modifier"),
          ),
        ],
      ),
    );
  }

  Widget _selectedFiltersChips() {
    final chips = <Widget>[];
    void addChip(String label, VoidCallback onClear) {
      chips.add(InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onDeleted: onClear,
        deleteIconColor: Colors.grey,
      ));
    }
    if (filterType.isNotEmpty) {
      addChip("Type: ${_typeLabel(filterType)}", () => setState(() {
            filterType = '';
            page = 1;
            _loadAlerts();
          }));
    }
    if (filterSeverity.isNotEmpty) {
      addChip("Sévérité: ${_severityLabel(filterSeverity)}", () => setState(() {
            filterSeverity = '';
            page = 1;
            _loadAlerts();
          }));
    }
    if (filterStatus.isNotEmpty) {
      addChip("Statut: ${_statusLabel(filterStatus)}", () => setState(() {
            filterStatus = '';
            page = 1;
            _loadAlerts();
          }));
    }
    if (filterStart.isNotEmpty) {
      addChip("Début: $filterStart", () => setState(() {
            filterStart = '';
            page = 1;
            _loadAlerts();
          }));
    }
    if (filterEnd.isNotEmpty) {
      addChip("Fin: $filterEnd", () => setState(() {
            filterEnd = '';
            page = 1;
            _loadAlerts();
          }));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  void _showFiltersBottomSheet() {
    final tempType = filterType;
    final tempSeverity = filterSeverity;
    final tempStatus = filterStatus;
    final tempStart = filterStart;
    final tempEnd = filterEnd;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        String selType = tempType;
        String selSeverity = tempSeverity;
        String selStatus = tempStatus;
        String selStart = tempStart;
        String selEnd = tempEnd;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text("Filtres", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dropdownFilter(
                      label: "Type",
                      value: selType,
                      items: const [
                        {'': 'Tous les types'},
                        {'FLOOD': 'Inondation'},
                        {'DROUGHT': 'Sécheresse'},
                        {'ATTACK': 'Attaque'},
                        {'EPIDEMIC': 'Épidémie'},
                        {'CONFLICT': 'Conflit'},
                        {'FIRE': 'Incendie'},
                        {'WIND': 'Vents violents'},
                        {'LOCUST': 'Acridiens'},
                        {'OTHER': 'Autre'},
                      ],
                      onChanged: (v) => setModalState(() => selType = v ?? ''),
                      width: double.infinity,
                    ),
                    const SizedBox(height: 10),
                    _dropdownFilter(
                      label: "Sévérité",
                      value: selSeverity,
                      items: const [
                        {'': 'Toutes les sévérités'},
                        {'LOW': 'Faible'},
                        {'MEDIUM': 'Moyen'},
                        {'HIGH': 'Élevé'},
                      ],
                      onChanged: (v) => setModalState(() => selSeverity = v ?? ''),
                      width: double.infinity,
                    ),
                    const SizedBox(height: 10),
                    _dropdownFilter(
                      label: "Statut",
                      value: selStatus,
                      items: const [
                        {'': 'Tous les statuts'},
                        {'DRAFT': 'Brouillon'},
                        {'PENDING': 'En attente'},
                        {'APPROVED': 'Approuvée'},
                        {'REJECTED': 'Rejetée'},
                        {'SENT': 'Envoyée'},
                        {'ACTIVE': 'Active'},
                        {'CANCELLED': 'Annulée'},
                        {'ARCHIVED': 'Archivée'},
                      ],
                      onChanged: (v) => setModalState(() => selStatus = v ?? ''),
                      width: double.infinity,
                    ),
                    const SizedBox(height: 10),
                    _dateFilter(
                      label: "Date début",
                      value: selStart,
                      onChanged: (v) => setModalState(() => selStart = v),
                      width: double.infinity,
                    ),
                    const SizedBox(height: 10),
                    _dateFilter(
                      label: "Date fin",
                      value: selEnd,
                      onChanged: (v) => setModalState(() => selEnd = v),
                      width: double.infinity,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              filterType = '';
                              filterSeverity = '';
                              filterStatus = '';
                              filterStart = '';
                              filterEnd = '';
                              page = 1;
                            });
                            Navigator.pop(ctx);
                            _loadAlerts();
                          },
                          child: const Text("Réinitialiser"),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              filterType = selType;
                              filterSeverity = selSeverity;
                              filterStatus = selStatus;
                              filterStart = selStart;
                              filterEnd = selEnd;
                              page = 1;
                            });
                            Navigator.pop(ctx);
                            _loadAlerts();
                          },
                          child: const Text("Appliquer"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _dropdownFilter({
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value.isEmpty ? null : value,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: items
              .map((m) => DropdownMenuItem<String>(
                    value: m.keys.first.isEmpty ? '' : m.keys.first,
                    child: Text(m.values.first),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ]),
    );
  }

  Widget _dateFilter({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          decoration: InputDecoration(
            hintText: "AAAA-MM-JJ",
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: onChanged,
        ),
      ]),
    );
  }

  Widget _alertsList() {
    if (loading) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: const [
            Icon(Icons.warning_amber_outlined, color: Colors.grey, size: 48),
            SizedBox(height: 12),
            Text("Aucune alerte trouvée", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      children: alerts.map((a) => _alertCard(a)).toList(),
    );
  }

  Widget _alertCard(Map<String, dynamic> a) {
    final id = (a['id'] ?? a['_id'] ?? '').toString();
    final title = (a['title'] ?? 'Alerte SAP').toString();
    final message = (a['message'] ?? '').toString();
    final type = (a['type'] ?? '').toString();
    final zone = (a['zoneName'] ?? (a['zone'] is Map ? a['zone']['name'] : '') ?? '').toString();
    final severity = (a['severity'] ?? '').toString();
    final status = (a['status'] ?? a['state'] ?? '').toString();
    final startDate = (a['startDate'] ?? a['createdAt'] ?? '').toString();
    final affected = (a['affected'] ?? a['peopleAffected'] ?? '').toString();

    return InkWell(
      onTap: () => _openDetail(id),
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
                  _badge(_severityLabel(severity), _severityBg(severity), _severityFg(severity)),
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

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 11)),
    );
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

  void _openDetail(String id) {
    if (id.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => AlertDetailsPage(alertId: id)));
  }

  Widget _paginationBar() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Page $page / $totalPages",
            style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              TextButton(
                onPressed: page > 1
                    ? () => setState(() {
                          page -= 1;
                          _loadAlerts();
                        })
                    : null,
                child: const Text("Précédent"),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: page < totalPages
                    ? () => setState(() {
                          page += 1;
                          _loadAlerts();
                        })
                    : null,
                child: const Text("Suivant"),
              ),
            ],
          )
        ],
      ),
    );
  }
}