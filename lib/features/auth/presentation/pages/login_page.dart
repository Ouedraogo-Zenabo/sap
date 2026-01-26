import 'package:flutter/material.dart';
import 'package:mobile_app/features/user/domain/user_repository.dart';
import '../widgets/login_form.dart';

/// Page d’accueil de l’application : Connexion
class LoginPage extends StatelessWidget {
  final UserRepository userRepository;
  final String token;

  const LoginPage({
    super.key,
    required this.userRepository,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final isLargeScreen = screen.width > 600; // Tablette / Web

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? constraints.maxWidth * 0.25 : 26,
              vertical: 40,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // LOGO
                    Image.asset(
                      'images/logo.jpeg',
                      height: isLargeScreen ? 120 : 80,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: isLargeScreen ? 120 : 80,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // TITRE RESPONSIVE
                    Text(
                      "Système d'Alerte Précoce",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isLargeScreen ? 32 : 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // FORMULAIRE
                    LoginForm(
                      userRepository: userRepository,
                      token: token,
                    ),

                    if (isLargeScreen) const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
