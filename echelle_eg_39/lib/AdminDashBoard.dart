
import 'package:flutter/material.dart';
import 'ClientMenuPage.dart';
import 'appareils.page.dart';
import 'LocationsMenu.dart';
import 'admin_ventes_page.dart';
import 'admin_prolongations_page.dart';



class AdminDashBoard extends StatefulWidget {
  const AdminDashBoard({super.key});

  @override
  State<AdminDashBoard> createState() => _AdminDashBoardState();
}

class _AdminDashBoardState extends State<AdminDashBoard> {
  int currentIndex = 0;


  final List<Widget> pages = [
    ClientsMenuPage(),
    AdminAppareilsPage(),
    LocationPage(),
    const AdminVentesPageFixed(),
    const AdminProlongationsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "ESPACE DIRECTEUR GENERAL - EG39",
          style: TextStyle(fontSize: 16),
        ),
        flexibleSpace: const SizedBox.shrink(),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.update),
            label: "Prolongations",
          ),
        ],
      ),
    );
  }
}
