import 'package:flutter/material.dart';


class Client {
  final String clientId;
  final String nom;
  final String telephone;

  Client({required this.clientId, required this.nom, required this.telephone});
}

class CreateTransactionPage extends StatefulWidget {
  const CreateTransactionPage({super.key});

  @override
  State<CreateTransactionPage> createState() => _CreateTransactionPageState();
}

class _CreateTransactionPageState extends State<CreateTransactionPage> {
  Client? selectedClient;
  final TextEditingController montantController = TextEditingController();

  final List<Client> clients = [
    Client(clientId: "CLT-001", nom: "Koffi Mensah", telephone: "90000001"),
    Client(clientId: "CLT-002", nom: "Ama Lawson", telephone: "90000002"),
  ];

  void validerTransaction() {
    if (selectedClient == null || montantController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez choisir un client et un montant")),
      );
      return;
    }

    // 🔴 DONNÉES ENVOYÉES AU SERVEUR
    final Map<String, dynamic> data = {
      "clientId": selectedClient!.clientId,
      "type": "location", // ou "vente"
      "montant": int.parse(montantController.text),
      "appareil": "GPS E600",
    };

    debugPrint("Transaction envoyée : $data");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Transaction enregistrée")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nouvelle location / vente")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 👤 CHOIX DU CLIENT
            DropdownButtonFormField<Client>(
              hint: const Text("Choisir le client"),
              value: selectedClient,
              items: clients.map((client) {
                return DropdownMenuItem(
                  value: client,
                  child: Text("${client.nom} (${client.telephone})"),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedClient = value;
                });
              },
            ),

            const SizedBox(height: 20),

            // 💰 MONTANT
            TextField(
              controller: montantController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Montant (FCFA)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            // ✅ VALIDER
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: validerTransaction,
                child: const Text("VALIDER"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}