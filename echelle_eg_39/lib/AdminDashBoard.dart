
import 'package:flutter/material.dart';
import 'ClientMenuPage.dart';
import 'appareils.page.dart';
import 'LocationsMenu.dart';
import 'admin_ventes_page.dart';
import 'admin_devis.page.dart';
import 'admin_promotions.page.dart';
import 'admin/admin_shell.dart';

import 'login.page.dart';
import 'package:shared_preferences/shared_preferences.dart';



class AdminDashBoard extends StatefulWidget {
  const AdminDashBoard({super.key});

  @override
  State<AdminDashBoard> createState() => _AdminDashBoardState();
}

class _AdminDashBoardState extends State<AdminDashBoard> {
  int currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('🔧 AdminDashboard loaded - currentIndex: $currentIndex');
  }


  final List<Widget> pages = [
    ClientsMenuPage(),
    AdminAppareilsPage(),
    const LocationPage(), // ADMIN LOCATIONS ✅
    const AdminVentesPageFixed(),
    const AdminDevisPage(),
    const AdminPromotionsPage(),
  ];

  /// Afficher le dialogue de confirmation de déconnexion
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  /// Fonction de déconnexion
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('isLoggedIn');
    await prefs.remove('isAdmin');
    await prefs.remove('userEmail');
    await prefs.remove('userPhone');
    await prefs.remove('userName');
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentIndex: currentIndex,
      pages: pages,
      onIndexChanged: (index) {
        setState(() => currentIndex = index);
      },
      onLogout: () => _showLogoutDialog(context),
    );
  }
}
