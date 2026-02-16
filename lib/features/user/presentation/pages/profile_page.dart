import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/features/user/domain/user_repository.dart';
import 'package:mobile_app/features/user/data/sources/user_local_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/features/auth/presentation/pages/login_page.dart';
import 'package:mobile_app/core/utils/http_error_helper.dart';

class ProfilePage extends StatefulWidget {
  final UserRepository userRepository;
  final String token;

  const ProfilePage({
    super.key,
    required this.userRepository,
    required this.token,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool loading = true;
  String? error;

  // Données utilisateur
  String name = "";
  String email = "";
  String phone = "";
  String commune = "";
  String role = "Point Focal Communal";

  // Statistiques
  int totalAlerts = 0;
  int alertsThisMonth = 0;
  int alertsTransmitted = 0;
  List<int> monthlyStats = [0, 0, 0, 0]; // 4 derniers mois

  // Paramètres
  bool notificationsEnabled = true;
  bool darkModeEnabled = false;
  bool autoSyncEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadSettings();
  }

  Future<String?> _getToken() async {
    try {
      return await UserLocalService().getAccessToken();
    } catch (_) {
      return widget.token;
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
        final access = data is Map
            ? (data['accessToken'] ?? data['access_token'])
            : null;
        final refreshOut = data is Map
            ? (data['refreshToken'] ?? data['refresh_token'])
            : null;
        if (access is String && access.isNotEmpty) {
          await UserLocalService().saveTokens(
            access,
            refreshOut is String && refreshOut.isNotEmpty
                ? refreshOut
                : refresh,
          );
          return access;
        }
      }
    } catch (e) {
      debugPrint('Refresh token error: $e');
    }
    return null;
  }

  Future<void> _loadProfile() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      String? token = await _getToken();
      if (token == null || token.isEmpty) {
        // Try to load cached profile when token missing
        try {
          final prefs = await SharedPreferences.getInstance();
          final cached = prefs.getString('cached_profile');
          if (cached != null && cached.isNotEmpty) {
            final userData = jsonDecode(cached) as Map<String, dynamic>;
            setState(() {
              name =
                  "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}"
                      .trim();
              if (name.isEmpty)
                name =
                    userData['name'] ?? userData['username'] ?? "Utilisateur";
              email = userData['email'] ?? "";
              phone = userData['phone'] ?? userData['phoneNumber'] ?? "";
              commune =
                  userData['commune'] ??
                  userData['communeName'] ??
                  userData['zoneName'] ??
                  "";
              role = userData['role'] ?? "Point Focal Communal";
              totalAlerts = (userData['totalAlerts'] ?? 0) as int;
              alertsThisMonth = (userData['alertsThisMonth'] ?? 0) as int;
              alertsTransmitted = (userData['alertsTransmitted'] ?? 0) as int;
              if (userData['monthlyStats'] is List)
                monthlyStats = (userData['monthlyStats'] as List).cast<int>();
              loading = false;
            });
            return;
          }
        } catch (_) {}

        setState(() {
          error = "Token manquant";
          loading = false;
        });
        return;
      }

      final url = Uri.parse("http://197.239.116.77:3000/api/v1/auth/profile");
      Map<String, String> headers(String t) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $t',
      };

      var resp = await http.get(url, headers: headers(token));

      if (resp.statusCode == 401) {
        final newToken = await _refreshAccessToken();
        if (newToken != null && newToken.isNotEmpty) {
          token = newToken;
          resp = await http.get(url, headers: headers(token));
        }
      }

      if (resp.statusCode != 200) {
        // Try to fallback to cached profile when available
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_profile');
        if (cached != null && cached.isNotEmpty) {
          try {
            final decodedCache = jsonDecode(cached) as Map<String, dynamic>;
            final userData = decodedCache;
            setState(() {
              name =
                  "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}"
                      .trim();
              if (name.isEmpty)
                name =
                    userData['name'] ?? userData['username'] ?? "Utilisateur";
              email = userData['email'] ?? "";
              phone = userData['phone'] ?? userData['phoneNumber'] ?? "";
              commune =
                  userData['commune'] ??
                  userData['communeName'] ??
                  userData['zoneName'] ??
                  "";
              role = userData['role'] ?? "Point Focal Communal";

              totalAlerts = (userData['totalAlerts'] ?? 0) as int;
              alertsThisMonth = (userData['alertsThisMonth'] ?? 0) as int;
              alertsTransmitted = (userData['alertsTransmitted'] ?? 0) as int;
              if (userData['monthlyStats'] is List)
                monthlyStats = (userData['monthlyStats'] as List).cast<int>();
              loading = false;
            });
            return;
          } catch (_) {
            // fallthrough to error handling
          }
        }

        setState(() {
          error = httpErrorMessage(resp.statusCode, resp.body);
          loading = false;
        });
        return;
      }

      final decoded = jsonDecode(resp.body);
      Map<String, dynamic>? userData;

      if (decoded is Map) {
        userData =
            (decoded['data'] ?? decoded['user'] ?? decoded)
                as Map<String, dynamic>?;
      }

      if (userData != null) {
        // Save cached profile
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_profile', jsonEncode(userData));
        } catch (_) {}

        setState(() {
          name = "${userData!['firstName'] ?? ''} ${userData['lastName'] ?? ''}"
              .trim();
          if (name.isEmpty)
            name = userData['name'] ?? userData['username'] ?? "Utilisateur";
          email = userData['email'] ?? "";
          phone = userData['phone'] ?? userData['phoneNumber'] ?? "";
          commune =
              userData['commune'] ??
              userData['communeName'] ??
              userData['zoneName'] ??
              "";
          role = userData['role'] ?? "Point Focal Communal";

          // Stats (adapter selon votre API)
          totalAlerts = (userData['totalAlerts'] ?? 0) as int;
          alertsThisMonth = (userData['alertsThisMonth'] ?? 0) as int;
          alertsTransmitted = (userData['alertsTransmitted'] ?? 0) as int;

          // Stats mensuelles (si disponibles)
          if (userData['monthlyStats'] is List) {
            monthlyStats = (userData['monthlyStats'] as List).cast<int>();
          }

          loading = false;
        });
      } else {
        setState(() {
          error = "Format de réponse invalide";
          loading = false;
        });
      }
    } catch (e) {
      // Try to fallback to cached profile on network error
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_profile');
        if (cached != null && cached.isNotEmpty) {
          final userData = jsonDecode(cached) as Map<String, dynamic>;
          setState(() {
            name =
                "${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}"
                    .trim();
            if (name.isEmpty)
              name = userData['name'] ?? userData['username'] ?? "Utilisateur";
            email = userData['email'] ?? "";
            phone = userData['phone'] ?? userData['phoneNumber'] ?? "";
            commune =
                userData['commune'] ??
                userData['communeName'] ??
                userData['zoneName'] ??
                "";
            role = userData['role'] ?? "Point Focal Communal";
            totalAlerts = (userData['totalAlerts'] ?? 0) as int;
            alertsThisMonth = (userData['alertsThisMonth'] ?? 0) as int;
            alertsTransmitted = (userData['alertsTransmitted'] ?? 0) as int;
            if (userData['monthlyStats'] is List)
              monthlyStats = (userData['monthlyStats'] as List).cast<int>();
            loading = false;
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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      darkModeEnabled = prefs.getBool('dark_mode_enabled') ?? false;
      autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Déconnexion"),
        content: const Text("Êtes-vous sûr de vouloir vous déconnecter ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Déconnexion"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        String? token = await _getToken();
        if (token != null && token.isNotEmpty) {
          final url = Uri.parse(
            "http://197.239.116.77:3000/api/v1/auth/logout",
          );
          await http
              .post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $token',
                },
              )
              .timeout(const Duration(seconds: 5));
        }

        // Supprimer les tokens
        await UserLocalService().clearUser();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('cached_profile');
        } catch (_) {}

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) =>
                  LoginPage(userRepository: widget.userRepository, token: ""),
            ),
            (route) => false,
          );
        }
      } catch (e) {
        debugPrint('Logout error: $e');
        if (mounted) {
          // Forcer la suppression locale des tokens même en cas d'erreur
          await UserLocalService().clearUser();
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('cached_profile');
          } catch (_) {}
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) =>
                  LoginPage(userRepository: widget.userRepository, token: ""),
            ),
            (route) => false,
          );
        }
      }
    }
  }

  String _getInitials() {
    if (name.isEmpty) return "?";
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text("Profil"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.3,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text("Profil"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0.3,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                child: const Text("Réessayer"),
              ),
            ],
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Profil"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.3,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadProfile),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. CARTE PROFIL
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: width * 0.12,
                      backgroundColor: Colors.white,
                      child: Text(
                        _getInitials(),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      name.isNotEmpty ? name : "Utilisateur",
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      role,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. INFORMATIONS PERSONNELLES
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.black12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Informations personnelles",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (phone.isNotEmpty)
                      _infoRow(
                        icon: Icons.phone_outlined,
                        title: "Téléphone",
                        value: phone,
                      ),
                    if (phone.isNotEmpty) const SizedBox(height: 15),
                    if (email.isNotEmpty)
                      _infoRow(
                        icon: Icons.email_outlined,
                        title: "Email",
                        value: email,
                      ),
                    if (email.isNotEmpty) const SizedBox(height: 15),
                    if (commune.isNotEmpty)
                      _infoRow(
                        icon: Icons.location_on_outlined,
                        title: "Commune",
                        value: commune,
                      ),
                    if (phone.isEmpty && email.isEmpty && commune.isEmpty)
                      const Text(
                        "Aucune information disponible",
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // 3. STATISTIQUES
              // Container(
              //   width: double.infinity,
              //   padding: const EdgeInsets.all(18),
              //   decoration: BoxDecoration(
              //     color: Colors.white,
              //     borderRadius: BorderRadius.circular(12),
              //     boxShadow: [
              //       BoxShadow(
              //         blurRadius: 10,
              //         color: Colors.black12,
              //         offset: const Offset(0, 4),
              //       )
              //     ],
              //   ),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       const Text(
              //         "Statistiques personnelles",
              //         style: TextStyle(
              //           fontSize: 17,
              //           fontWeight: FontWeight.bold,
              //         ),
              //       ),
              //       const SizedBox(height: 15),
              //       if (monthlyStats.isNotEmpty && monthlyStats.any((v) => v > 0))
              //         SizedBox(
              //           height: 120,
              //           child: Row(
              //             crossAxisAlignment: CrossAxisAlignment.end,
              //             children: [
              //               if (monthlyStats.length > 3)
              //                 _bar(label: "J-3", value: monthlyStats[0].toDouble()),
              //               if (monthlyStats.length > 2)
              //                 _bar(label: "J-2", value: monthlyStats[1].toDouble()),
              //               if (monthlyStats.length > 1)
              //                 _bar(label: "J-1", value: monthlyStats[2].toDouble()),
              //               if (monthlyStats.isNotEmpty)
              //                 _bar(label: "Mois", value: monthlyStats[3].toDouble()),
              //             ],
              //           ),
              //         ),
              //       if (monthlyStats.isEmpty || !monthlyStats.any((v) => v > 0))
              //         const SizedBox(
              //           height: 120,
              //           child: Center(
              //             child: Text(
              //               "Aucune donnée mensuelle disponible",
              //               style: TextStyle(color: Colors.grey),
              //             ),
              //           ),
              //         ),
              //       const Divider(height: 30),
              //       Row(
              //         mainAxisAlignment: MainAxisAlignment.spaceAround,
              //         children: [
              //           _statNumber(label: "Total", value: totalAlerts.toString()),
              //           _statNumber(label: "Ce mois", value: alertsThisMonth.toString()),
              //           _statNumber(label: "Transmises", value: alertsTransmitted.toString()),
              //         ],
              //       )
              //     ],
              //   ),
              // ),
              // const SizedBox(height: 25),

              // 4. PARAMÈTRES
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.black12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Paramètres",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _settingSwitch(
                      icon: Icons.notifications_none,
                      title: "Notifications",
                      subtitle: "Recevoir les notifications push",
                      value: notificationsEnabled,
                      onChanged: (v) {
                        setState(() => notificationsEnabled = v);
                        _saveSetting('notifications_enabled', v);
                      },
                    ),
                    // _settingSwitch(
                    //   icon: Icons.dark_mode_outlined,
                    //   title: "Mode sombre",
                    //   subtitle: "Thème de l'application",
                    //   value: darkModeEnabled,
                    //   onChanged: (v) {
                    //     setState(() => darkModeEnabled = v);
                    //     _saveSetting('dark_mode_enabled', v);
                    //   },
                    // ),
                    _settingSwitch(
                      icon: Icons.sync_outlined,
                      title: "Synchronisation auto",
                      subtitle: "Synchroniser automatiquement",
                      value: autoSyncEnabled,
                      onChanged: (v) {
                        setState(() => autoSyncEnabled = v);
                        _saveSetting('auto_sync_enabled', v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // 5. BOUTON DÉCONNEXION
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    "Déconnexion",
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _logout,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.grey.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar({required String label, required double value}) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 20,
            height: value > 0 ? (value * 10).clamp(10, 100) : 0,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _statNumber({required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _settingSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 25, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15)),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
