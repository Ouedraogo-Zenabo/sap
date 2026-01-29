import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mobile_app/services/push_notification_service.dart';
import 'package:mobile_app/features/alert/presentation/pages/create_alert.dart';
import 'package:mobile_app/features/notification/notification_provider.dart';
import 'package:provider/provider.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'package:mobile_app/features/dashboard/presentation/pages/dashboard_page.dart';

// IMPORTS POUR LE USER
import 'package:mobile_app/features/user/data/sources/user_api_service.dart';
import 'package:mobile_app/features/user/data/sources/user_local_service.dart';
import 'package:mobile_app/features/user/domain/user_repository.dart';
  

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and push service before app start
  await Firebase.initializeApp();

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(PushNotificationService.firebaseMessagingBackgroundHandler);

  // Initialize push service (local notifications + token)
  await PushNotificationService().initialize();

  // Initialisation des services User
  final apiService = UserApiService(
    baseUrl: "http://197.239.116.77:3000/api",
  );

  final localService = UserLocalService();

  final userRepository = UserRepository(
    api: apiService,
    local: localService,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => NotificationProvider(),
      child: MyApp(userRepository: userRepository),
    ),
  );
}

class MyApp extends StatefulWidget {
  final UserRepository userRepository;

  const MyApp({super.key, required this.userRepository});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _accessToken;
  Timer? _tokenRefreshTimer;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    super.dispose();
  }

  /// Vérifie au démarrage si l'utilisateur est déjà connecté
  Future<void> _checkLoginStatus() async {
    try {
      final token = await widget.userRepository.local.getAccessToken();
      
      if (token != null && token.isNotEmpty) {
        // Token existe, vérifier s'il est valide (optionnel)
        setState(() {
          _isLoggedIn = true;
          _accessToken = token;
          _isLoading = false;
        });
        // Démarrer le refresh automatique du token
        _startTokenRefreshTimer();
      } else {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur vérification token: $e");
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  /// Démarre un Timer qui refresh le token toutes les 30 minutes
  /// (refresh passif, seulement si la session est active)
  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    
    // Refresh toutes les 30 minutes pour maintenir la session valide
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 30), (timer) async {
      await _refreshAccessToken();
    });
  }

  /// Appelle l'API pour refresh le token
  /// ✅ La session persiste jusqu'à déconnexion manuelle
  Future<void> _refreshAccessToken() async {
    try {
      final refreshToken = await widget.userRepository.local.getRefreshToken();
      
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint("Pas de refresh token disponible");
        return;
      }

      // Appeler l'API refresh
      final tokens = await widget.userRepository.api.refreshToken(refreshToken);
      
      // Sauvegarder les nouveaux tokens
      await widget.userRepository.local.saveTokens(
        tokens['accessToken']!,
        tokens['refreshToken']!,
      );

      setState(() {
        _accessToken = tokens['accessToken'];
      });

      debugPrint("✅ Token maintenu actif");
    } catch (e) {
      debugPrint("⚠️ Refresh token échoué: $e");
      // On n'efface pas la session en cas d'erreur
      // L'utilisateur reste connecté et peut retry
    }
  }

  @override
  Widget build(BuildContext context) {
    // Affiche un loader pendant la vérification
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Systeme d\'Alerte Precoce',

      // REDIRECTION AUTOMATIQUE selon l'etat de connexion
      home: _isLoggedIn
          ? DashboardPage(
              userRepository: widget.userRepository,
              token: _accessToken ?? "",
            )
          : LoginPage(
              userRepository: widget.userRepository,
              token: "",
            ),

      routes: {
        "/login": (context) => LoginPage(
              userRepository: widget.userRepository,
              token: "",
            ),
        "/dashboard": (context) => DashboardPage(
              userRepository: widget.userRepository,
              token: _accessToken ?? "",
            ),
        "/create-alert": (context) => CreateAlertPage(),
      },
    );
  }
}
