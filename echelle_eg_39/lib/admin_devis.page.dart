import 'package:flutter/material.dart';
import 'api_service.dart';

class AdminDevisPage extends StatefulWidget {
  const AdminDevisPage({super.key});

  @override
  State<AdminDevisPage> createState() => _AdminDevisPageState();
}

class _AdminDevisPageState extends State<AdminDevisPage> {
  List<Map<String, dynamic>> _devis = [];
  bool _isLoading = false;
  String _filterStatut = 'tous';

  @override
  void initState() {
    super.initState();
    _loadDevis();
  }

  Future<void> _loadDevis() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final devis = await ApiService.getDevis(
        statut: _filterStatut == 'tous' ? null : _filterStatut,
      );
      if (mounted) {
        setState(() {
          _devis = devis;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateStatut(int devisId, String newStatut) async {
    try {
      await ApiService.updateDevisStatut(devisId, newStatut);
      if (mounted) {
        _loadDevis();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut mis à jour: $newStatut'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDevis(int devisId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text(
            'Êtes-vous sûr de vouloir supprimer cette demande de devis ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteDevis(devisId);
        if (mounted) {
          _loadDevis();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Devis supprimé'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Devis'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevis,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Text('Filtrer: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('tous', 'Tous'),
                        _buildFilterChip('nouveau', 'Nouveau'),
                        _buildFilterChip('en_cours', 'En cours'),
                        _buildFilterChip('envoye', 'Envoyé'),
                        _buildFilterChip('termine', 'Terminé'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _devis.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucune demande de devis',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _devis.length,
                        itemBuilder: (context, index) {
                          final devis = _devis[index];
                          return _buildDevisCard(devis);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String valeur, String label) {
    final isSelected = _filterStatut == valeur;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _filterStatut = valeur);
          _loadDevis();
        },
        selectedColor: Colors.blue.shade600,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildDevisCard(Map<String, dynamic> devis) {
    final statut = devis['statut'] as String? ?? 'nouveau';
    Color statutColor;
    switch (statut) {
      case 'nouveau':
        statutColor = Colors.blue;
        break;
      case 'en_cours':
        statutColor = Colors.orange;
        break;
      case 'envoye':
        statutColor = Colors.purple;
        break;
      case 'termine':
        statutColor = Colors.green;
        break;
      default:
        statutColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        devis['serviceName'] ?? 'Service inconnu',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Par: ${devis['nom']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statutColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statut.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: statutColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (devis['description'] != null &&
                devis['description'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                devis['description'],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (devis['email'] != null && devis['email'].isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '📧 ${devis['email']}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            if (devis['telephone'] != null &&
                devis['telephone'].isNotEmpty) ...[
              Text(
                '📞 ${devis['telephone']}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                // Bouton de changement de statut
                Expanded(
                  child: PopupMenuButton<String>(
                    onSelected: (value) =>
                        _updateStatut(devis['id'], value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'nouveau', child: Text('Nouveau')),
                      const PopupMenuItem(
                          value: 'en_cours', child: Text('En cours')),
                      const PopupMenuItem(
                          value: 'envoye', child: Text('Envoyé')),
                      const PopupMenuItem(
                          value: 'termine', child: Text('Terminé')),
                    ],
                    child: const Icon(Icons.edit,
                        color: Colors.blue, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete,
                      color: Colors.red, size: 20),
                  onPressed: () => _deleteDevis(devis['id']),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}