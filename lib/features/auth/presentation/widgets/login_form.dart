import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/features/user/domain/user_repository.dart';
import 'package:mobile_app/features/user/data/models/user_model.dart';
import 'package:mobile_app/features/alert/data/sources/zones_local_service.dart';
import '../../domain/auth_repository.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';

/// Formulaire Login totalement RESPONSIVE
class LoginForm extends StatefulWidget {
  final UserRepository userRepository;
  final String token;

  const LoginForm({
    super.key,
    required this.userRepository,
    required this.token,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final authRepository = AuthRepository();

  bool _loading = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });

      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      try {
        // Appel API pour la connexion
        final url = Uri.parse('http://197.239.116.77:3000/api/v1/auth/login');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        );

        print("Login Response Status: ${response.statusCode}");
        print("Login Response Body: ${response.body}");

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final data = decoded['data'];

          final accessToken = data['accessToken'] as String?;
          final refreshToken = data['refreshToken'] as String?;
          final user = data['user'];

          // 🔥 SAUVEGARDER LES TOKENS
          if (accessToken != null && accessToken.isNotEmpty) {
            await widget.userRepository.local.saveTokens(accessToken, refreshToken ?? '');
            print("✅ Tokens sauvegardés");
          }

          // Sauvegarder le profil utilisateur
          final userModel = UserModel.fromJson(user);
          await widget.userRepository.local.saveUser(userModel);
          print("✅ Profil utilisateur sauvegardé");

          // Launch zones sync in background so offline selections are available
          try {
            final zonesService = ZonesLocalService();
            await zonesService.init();
            // Fire-and-forget sync; don't block UI navigation
            zonesService.syncAllZones(accessToken ?? '');
            print('Zones sync started');
          } catch (e) {
            print('Failed to start zones sync: $e');
          }

          // Navigation vers le Dashboard
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DashboardPage(
                  userRepository: widget.userRepository,
                  token: accessToken ?? widget.token,
                ),
              ),
            );
          }
        } else {
          final decoded = jsonDecode(response.body);
          setState(() {
            _errorMessage =
                decoded['error']?['message'] ?? "Erreur de connexion (${response.statusCode})";
          });
        }
      } catch (e) {
        print("ERROR: $e");
        setState(() => _errorMessage = "Erreur réseau : $e");
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 400;
    final isTablet = size.width > 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth > 500
            ? 400
            : constraints.maxWidth * 0.9;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: contentWidth.toDouble(),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    /// Logo responsive (hidden)
                    Offstage(
                      offstage: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: SizedBox(
                          width: isTablet ? 150 : 110,
                          height: isTablet ? 150 : 110,
                        ),
                      ),
                    ),
                 

                    /// Message d'erreur
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        color: Colors.red[100],
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[900]),
                        ),
                      ),

                    /// Champ Email
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: "Adresse mail",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Champ obligatoire" : null,
                    ),

                    const SizedBox(height: 16),

                    /// Champ Mot de passe
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_isPasswordVisible,
                      keyboardType: TextInputType.visiblePassword,
                      decoration: InputDecoration(
                        labelText: "Mot de passe",
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Champ obligatoire" : null,
                    ),

                    const SizedBox(height: 24),

                    /// Bouton Connexion Responsive
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                "Se connecter",
                                style: TextStyle(
                                  fontSize: isSmall ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}