import 'package:flutter/material.dart';
import 'dart:math';
import 'data_manager.dart' as dm;


class ClientsMenuPage extends StatefulWidget {
  @override
  _ClientsMenuPageState createState() => _ClientsMenuPageState();
}

class _ClientsMenuPageState extends State<ClientsMenuPage> {
  final _formKey = GlobalKey<FormState>();
  String clientName = '';
  String clientEmail = '';
  String clientPhone = '';
  String clientID = '';
  
  // Instance du gestionnaire de données global
  final dm.DataManager _dataManager = dm.DataManager();

  @override
  void initState() {
    super.initState();
    // Initialiser avec les clients par défaut
    _dataManager.initialize();
  }

  @override
  void dispose() {
    // Appeler super.dispose() pour libérer les ressources du widget
    super.dispose();
  }

  // Fonction pour générer un ClientID aléatoire
  String generateClientID() {
    var rand = Random();
    return 'C-${rand.nextInt(9999).toString().padLeft(4, '0')}';
  }

  // Ajouter un client
  
void addClient() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      
      // Validation : nom ne doit pas être vide
      if (clientName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Le nom du client est obligatoire')),
        );
        return;
      }

      // Validation : au moins un des deux (email ou téléphone) doit être rempli
      if (clientEmail.isEmpty && clientPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veuillez fournir au moins un contact (email ou téléphone)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      setState(() {
        clientID = generateClientID();
        // Utiliser le gestionnaire de données global
        _dataManager.addClient(
          dm.Client(
            id: clientID,
            name: clientName,
            email: clientEmail.isNotEmpty ? clientEmail : null,
            phone: clientPhone.isNotEmpty ? clientPhone : null,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Client $clientName ajouté avec ID $clientID')),
      );
    }
  }

  // Modifier un client
  void editClient(int index) {
    final clients = _dataManager.clients;
    TextEditingController nameController =
        TextEditingController(text: clients[index].name);
    TextEditingController emailController =
        TextEditingController(text: clients[index].email ?? '');
    TextEditingController phoneController =
        TextEditingController(text: clients[index].phone ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Modifier Client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Nom'),
            ),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email (optionnel)'),
            ),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: 'Téléphone (optionnel)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              final updatedClient = dm.Client(
                id: clients[index].id,
                name: nameController.text,
                email: emailController.text.isNotEmpty ? emailController.text : null,
                phone: phoneController.text.isNotEmpty ? phoneController.text : null,
              );
              _dataManager.updateClient(index, updatedClient);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Client modifié avec succès')),
              );
            },
            child: Text('Enregistrer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
        ],
      ),
    );
  }

  // Supprimer un client
  void deleteClient(int index) {
    final clients = _dataManager.clients;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer le client "${clients[index].name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              _dataManager.removeClient(index);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Client supprimé avec succès'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = _dataManager.clients;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestion des Clients',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.indigo.withValues(alpha: 0.3),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: const Icon(Icons.people, size: 24),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              // FORM SECTION
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person_add,
                          color: Colors.indigo.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Enregistrer un nouveau client',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Nom complet',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.indigo.shade600,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                value!.isEmpty ? 'Veuillez entrer un nom' : null,
                            onSaved: (value) => clientName = value!,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Email (optionnel)',
                              prefixIcon: Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.indigo.shade600,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              // Email optionnel mais doit être valide si fourni
                              if (value!.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Format d\'email invalide';
                              }
                              return null;
                            },
                            onSaved: (value) => clientEmail = value!,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Téléphone (optionnel)',
                              prefixIcon: Icon(Icons.phone),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.indigo.shade600,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              // Téléphone optionnel mais doit être valide si fourni
                              if (value!.isNotEmpty && value.length < 8) {
                                return 'Numéro de téléphone invalide';
                              }
                              return null;
                            },
                            onSaved: (value) => clientPhone = value!,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: addClient,
                              icon: const Icon(Icons.add_circle),
                              label: const Text(
                                'Ajouter Client',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // CLIENTS LIST SECTION
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.people_alt,
                              color: Colors.indigo.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Liste des Clients (${clients.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: clients.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Aucun client enregistré',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                itemCount: clients.length,
                                itemBuilder: (context, index) {
                                  final client = clients[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Card(
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.all(12),
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              Colors.indigo.shade100,
                                          child: Text(
                                            client.name[0].toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.indigo.shade700,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          client.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: Colors.blue.shade200,
                                                  ),
                                                ),
                                                child: Text(
                                                  'ID: ${client.id}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.blue.shade700,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              if (client.email != null &&
                                                  client.email!.isNotEmpty)
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.email,
                                                      size: 12,
                                                      color: Colors
                                                          .grey.shade600,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Expanded(
                                                      child: Text(
                                                        client.email!,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              if (client.phone != null &&
                                                  client.phone!.isNotEmpty)
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.phone,
                                                      size: 12,
                                                      color: Colors
                                                          .grey.shade600,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Expanded(
                                                      child: Text(
                                                        client.phone!,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit,
                                                color: Colors.orange.shade600,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  editClient(index),
                                              tooltip: 'Modifier',
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete,
                                                color: Colors.red.shade600,
                                                size: 20,
                                              ),
                                              onPressed: () =>
                                                  deleteClient(index),
                                              tooltip: 'Supprimer',
                                            ),
                                          ],
                                        ),

                                        onTap: () {
                                          // Historique du client
                                          showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              title: Text(
                                                  'Historique de ${client.name}'),
                                              content: const Text(
                                                  'Ici, vous pourrez afficher l\'historique complet du client.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('Fermer'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
