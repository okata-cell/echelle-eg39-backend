import 'package:flutter/material.dart';

class AdminVentesPageSimple extends StatelessWidget {
  const AdminVentesPageSimple({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestion des Ventes ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart,
              size: 80,
              color: Colors.indigo,
            ),
            SizedBox(height: 20),
            Text(
              'Page Ventes Admin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Fonctionnalité en cours de développement',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
