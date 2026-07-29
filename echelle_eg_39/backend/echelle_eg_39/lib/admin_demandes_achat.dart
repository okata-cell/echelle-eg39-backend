import 'package:flutter/material.dart';
import 'data_manager.dart';
import 'models_demande_achat.dart';
import 'package:intl/intl.dart';

class AdminDemandesAchatPage extends StatefulWidget {
  const AdminDemandesAchatPage({Key? key}) : super(key: key);

  @override
  State<AdminDemandesAchatPage> createState() => _AdminDemandesAchatPageState();
}

class _AdminDemandesAchatPageState extends State<AdminDemandesAchatPage> {
  final _dataManager = DataManager();
  String _filtreStatut = 'tous';

  @override
  void initState() {
    super.initState();
    _dataManager.initialize();
    _dataManager.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _dataManager.removeListener(() => setState(() {}));
    super.dispose();
  }

  List<DemandeAchat> get _demandesFiltrees {
    return _dataManager.getDemandesByStatut(_filtreStatut);
  }

  Color _getStatutColor(String statut) {
    switch (statut) {
      case 'en_attente':
        return const Color(0xFFF59E0B);
      case 'approuvee':
        return const Color(0xFF059669);
      case 'rejetee':
        return const Color(0xFFDC2626);
      case 'livree':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatutLabel(String statut) {
    switch (statut) {
      case 'en_attente':
        return 'En attente';
      case 'approuvee':
        return 'Approuvée';
      case 'rejetee':
        return 'Rejetée';
      case 'livree':
        return 'Livrée';
      default:
        return statut;
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombreEnAttente = _dataManager.nombreDemandesEnAttente;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Text(
              'Demandes d\'achat',
              style: TextStyle(color: Color(0xFF111827)),
            ),
            if (nombreEnAttente > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$nombreEnAttente',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Filtres par statut
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFiltre('tous', 'Tous', _dataManager.demandesAchat.length),
                  const SizedBox(width: 8),
                  _buildFiltre('en_attente', 'En attente', nombreEnAttente),
                  const SizedBox(width: 8),
                  _buildFiltre('approuvee', 'Approuvées',
                      _dataManager.getDemandesByStatut('approuvee').length),
                  const SizedBox(width: 8),
                  _buildFiltre('rejetee', 'Rejetées',
                      _dataManager.getDemandesByStatut('rejetee').length),
                  const SizedBox(width: 8),
                  _buildFiltre('livree', 'Livrées',
                      _dataManager.getDemandesByStatut('livree').length),
                ],
              ),
            ),
          ),

          // Liste des demandes
          Expanded(
            child: _demandesFiltrees.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune demande d\'achat',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _demandesFiltrees.length,
                    itemBuilder: (context, index) {
                      final demande = _demandesFiltrees[index];
                      return _buildDemandeCard(demande);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltre(String statut, String label, int count) {
    final isSelected = _filtreStatut == statut;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filtreStatut = statut;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.3) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF374151),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemandeCard(DemandeAchat demande) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec statut
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    demande.produitNom,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatutColor(demande.statut).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatutLabel(demande.statut),
                    style: TextStyle(
                      color: _getStatutColor(demande.statut),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Informations client
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    demande.clientNom,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.email, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    demande.clientEmail,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Text(
                  demande.clientPhone,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Détails de la commande
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quantité',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        '${demande.quantite}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Prix unitaire',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        '${demande.produitPrix.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} FCFA',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        '${demande.total.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} FCFA',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Date de commande
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(
                  'Commandé le ${dateFormat.format(demande.dateCommande)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),

            // Commentaire admin si présent
            if (demande.commentaireAdmin != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.comment, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        demande.commentaireAdmin!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Actions (uniquement pour les demandes en attente)
            if (demande.statut == 'en_attente') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approuverDemande(demande),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approuver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _rejeterDemande(demande),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Rejeter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Action pour marquer comme livré (uniquement pour les demandes approuvées)
            if (demande.statut == 'approuvee') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _marquerLivree(demande),
                  icon: const Icon(Icons.local_shipping, size: 16),
                  label: const Text('Marquer comme livrée'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _approuverDemande(DemandeAchat demande) {
    showDialog(
      context: context,
      builder: (context) {
        final commentaireController = TextEditingController();
        return AlertDialog(
          title: const Text('Approuver la demande'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Approuver la demande d\'achat de ${demande.clientNom} ?'),
              const SizedBox(height: 16),
              TextField(
                controller: commentaireController,
                decoration: const InputDecoration(
                  labelText: 'Commentaire (optionnel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                _dataManager.updateDemandeStatut(
                  demande.id,
                  'approuvee',
                  commentaire: commentaireController.text.isEmpty
                      ? null
                      : commentaireController.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Demande approuvée !'),
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
              ),
              child: const Text('Approuver'),
            ),
          ],
        );
      },
    );
  }

  void _rejeterDemande(DemandeAchat demande) {
    showDialog(
      context: context,
      builder: (context) {
        final commentaireController = TextEditingController();
        return AlertDialog(
          title: const Text('Rejeter la demande'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rejeter la demande d\'achat de ${demande.clientNom} ?'),
              const SizedBox(height: 16),
              TextField(
                controller: commentaireController,
                decoration: const InputDecoration(
                  labelText: 'Raison du rejet',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (commentaireController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez indiquer la raison du rejet'),
                      backgroundColor: Color(0xFFDC2626),
                    ),
                  );
                  return;
                }
                _dataManager.updateDemandeStatut(
                  demande.id,
                  'rejetee',
                  commentaire: commentaireController.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Demande rejetée'),
                    backgroundColor: Color(0xFFDC2626),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text('Rejeter'),
            ),
          ],
        );
      },
    );
  }

  void _marquerLivree(DemandeAchat demande) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la livraison'),
        content: Text('Confirmer que la commande de ${demande.clientNom} a été livrée ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              _dataManager.updateDemandeStatut(
                demande.id,
                'livree',
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Commande marquée comme livrée !'),
                  backgroundColor: Color(0xFF2563EB),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}