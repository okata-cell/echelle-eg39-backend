import 'package:flutter/material.dart';
import 'transaction.page.dart';



class AdminClientsPage extends StatefulWidget {
  const AdminClientsPage({super.key});

  @override
  State<AdminClientsPage> createState() => _AdminClientsPageState();
}

class _AdminClientsPageState extends State<AdminClientsPage> {

  // 🔹 SOUS-ÉTAPE 4.2 — Liste des clients (TEMPORAIRE)
  final List<Client> clients = [
    Client(clientId: "CLT-001", nom: "Koffi Mensah", telephone: "90000001"),
    Client(clientId: "CLT-002", nom: "Ama Lawson", telephone: "90000002"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Liste des clients (Admin)"),
      ),
      body: ListView.builder(
        itemCount: clients.length,
        itemBuilder: (context, index) {
          final client = clients[index];

          return Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(client.nom),
              subtitle: Text("📞 ${client.telephone}"),
              trailing: Text(client.clientId),
              onTap: () {
                // 👉 plus tard : sélectionner ce client
              },
            ),
          );
        },
      ),
    );
  }
}