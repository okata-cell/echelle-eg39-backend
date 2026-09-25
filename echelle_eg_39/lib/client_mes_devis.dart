import 'package:flutter/material.dart';

import 'api_service.dart';

typedef DevisLoader = Future<List<Map<String, dynamic>>> Function();

/// Suivi des demandes de devis rattachées au compte connecté.
/// Chaque demande est servie par GET /api/devis/me, déjà filtrée côté serveur
/// sur l'identifiant du compte : aucun filtrage local n'est nécessaire.
class ClientMesDevisPage extends StatefulWidget {
  const ClientMesDevisPage({super.key, this.loadDevis});

  final DevisLoader? loadDevis;

  @override
  State<ClientMesDevisPage> createState() => _ClientMesDevisPageState();
}

class _ClientMesDevisPageState extends State<ClientMesDevisPage> {
  List<Map<String, dynamic>> _devis = [];
  bool _isLoading = true;
  String? _error;

  // Étapes affichées au client, dans l'ordre d'avancement.
  static const _etapes = ['Demande envoyée', 'Acceptée', 'En cours', 'Terminée'];

  static const _indexParStatut = <String, int>{
    'en_attente': 0,
    'approuvee': 1,
    'en_cours': 2,
    'envoye': 2,
    'termine': 3,
  };

  @override
  void initState() {
    super.initState();
    _loadDevis();
  }

  Future<void> _loadDevis() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final loader = widget.loadDevis ?? ApiService.getMyDevis;
      final devis = await loader();
      if (!mounted) return;
      setState(() {
        _devis = devis;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageErreur(error);
        _isLoading = false;
      });
    }
  }

  String _messageErreur(Object error) {
    if (error is ApiException) return error.message;
    final text = error.toString();
    if (text.startsWith('Exception: ')) return text.substring(11);
    return text;
  }

  String _valeur(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatDate(Object? value) {
    final raw = _valeur(value);
    if (raw.isEmpty) return '';
    try {
      final date = DateTime.tryParse(raw);
      if (date == null) return raw;
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return raw;
    }
  }

  String _libelleStatut(String statut) {
    switch (statut) {
      case 'en_attente':
        return 'En attente';
      case 'approuvee':
        return 'Acceptée';
      case 'rejetee':
        return 'Refusée';
      case 'en_cours':
        return 'En cours';
      case 'envoye':
        return 'Devis envoyé';
      case 'termine':
        return 'Terminée';
      default:
        return statut.replaceAll('_', ' ');
    }
  }

  Color _couleurStatut(String statut) {
    switch (statut) {
      case 'en_attente':
        return const Color(0xFFF59E0B);
      case 'approuvee':
      case 'termine':
        return const Color(0xFF059669);
      case 'rejetee':
        return const Color(0xFFDC2626);
      case 'en_cours':
      case 'envoye':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _iconeStatut(String statut) {
    switch (statut) {
      case 'en_attente':
        return Icons.pending_actions;
      case 'approuvee':
        return Icons.thumb_up_outlined;
      case 'rejetee':
        return Icons.cancel_outlined;
      case 'en_cours':
        return Icons.autorenew;
      case 'envoye':
        return Icons.send_outlined;
      case 'termine':
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildBadge(String statut) {
    final color = _couleurStatut(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconeStatut(statut), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _libelleStatut(statut),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgression(String statut) {
    if (statut == 'rejetee') {
      return Row(
        children: [
          const Icon(Icons.cancel, size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Demande refusée par l\'administration',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
        ],
      );
    }

    final indexActuel = _indexParStatut[statut] ?? 0;
    final color = _couleurStatut(statut);

    return Row(
      children: List.generate(_etapes.length, (index) {
        final atteinte = index <= indexActuel;
        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: atteinte ? color : const Color(0xFFE5E7EB),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      atteinte ? Icons.check : Icons.circle,
                      size: atteinte ? 12 : 8,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _etapes[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1.2,
                      fontWeight: atteinte ? FontWeight.w700 : FontWeight.w400,
                      color: atteinte ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              if (index < _etapes.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 16, left: 2, right: 2),
                    color: index < indexActuel ? color : const Color(0xFFE5E7EB),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDevisCard(Map<String, dynamic> devis) {
    final id = _valeur(devis['id'], fallback: '?');
    final serviceName = _valeur(devis['serviceName'], fallback: 'Service non renseigné');
    final description = _valeur(devis['description']);
    final commentaire = _valeur(devis['commentaireAdmin']);
    final createdAt = _formatDate(devis['createdAt']);
    final updatedAt = _formatDate(devis['updatedAt']);
    final statut = _valeur(devis['statut'], fallback: 'en_attente');

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Devis #$id${createdAt.isEmpty ? '' : ' · $createdAt'}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildBadge(statut),
              ],
            ),
            const SizedBox(height: 16),
            _buildProgression(statut),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
                ),
              ),
            ],
            if (commentaire.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _couleurStatut(statut).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _couleurStatut(statut).withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statut == 'rejetee' ? 'Motif du refus' : 'Message de l\'administration',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _couleurStatut(statut),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      commentaire,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF111827), height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
            if (updatedAt.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Dernière mise à jour le $updatedAt',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.request_quote_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Aucune demande de devis',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rendez-vous dans l\'onglet Services pour demander un devis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mes devis',
          style: TextStyle(color: Color(0xFF111827)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2563EB)),
            tooltip: 'Actualiser',
            onPressed: _isLoading ? null : _loadDevis,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Color(0xFFDC2626)),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDevis,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : _devis.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadDevis,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _devis.length,
                        itemBuilder: (context, index) => _buildDevisCard(_devis[index]),
                      ),
                    ),
    );
  }
}
