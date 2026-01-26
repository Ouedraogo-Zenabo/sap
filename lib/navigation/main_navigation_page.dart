// lib/core/navigation/main_navigation_page.dart
import 'package:flutter/material.dart';
import 'package:mobile_app/features/alert/presentation/pages/alert_list_page.dart';
import 'package:mobile_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:mobile_app/features/user/presentation/pages/profile_page.dart';
import 'package:mobile_app/features/user/domain/user_repository.dart';

class MainNavigationPage extends StatefulWidget {
  // On reçoit les dépendances ici (UserRepository + token)
  final UserRepository userRepository;
  final String token;

  const MainNavigationPage({
    super.key,
    required this.userRepository,
    required this.token,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Crée la liste des pages à l'intérieur de build afin de pouvoir
    // utiliser widget.userRepository et widget.token.
    final List<Widget> pages = [
       DashboardPage(
        userRepository: widget.userRepository,
        token: widget.token,
      ),
      const AlertsListPage(),
      // ProfilePage nécessite userRepository et token -> on les passe
      ProfilePage(
        userRepository: widget.userRepository,
        token: widget.token,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Accueil"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "Alertes"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }
}
