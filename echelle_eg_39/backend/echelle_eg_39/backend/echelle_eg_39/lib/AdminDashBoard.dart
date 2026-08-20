
import 'package:flutter/material.dart';
import 'ClientMenuPage.dart';
import 'appareils.page.dart';
import 'LocationsMenu.dart';
import 'admin_ventes_page.dart';

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
    return Scaffold(
      appBar: AppBar(
title: const Row(
          children: [
            Text(
              "ADMIN",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(width: 8),
            Text(
              "EG39 Locations",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        flexibleSpace: const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _showLogoutDialog(context),
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: "Clients",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.center_focus_strong),
            label: "Appareils",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: "Locations",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: "Ventes",
          ),

        ],
      ),
    );
  }
}
