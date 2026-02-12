import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'extensions_manager.dart';
import 'demo_flags.dart';
import 'admin_prolongations_page.dart';
import 'client_mes_demandes.dart';
import 'data_manager.dart';
import 'dart:async';

class Transaction {
  final int id;
  final String type;
  final String title;
  final String date;
  final String? dateRetour;
  final int amount;
  final String status;
  final bool isPaid;
  final String? equipmentId;
  final String? invoiceNumber;
  final int dailyRate; // Nouveau champ pour stocker le tarif journalier
  final List<String> extensionIds; // IDs des prolongations
  final int extensionCount; // Nombre de prolongations
  final int unpaidExtensionAmount; // Montant des prolongations non payées

  Transaction({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    this.dateRetour,
    required this.amount,
    required this.status,
    this.isPaid = true,
    this.equipmentId,
    this.invoiceNumber,
    int? dailyRate,
    List<String>? extensionIds,
    this.extensionCount = 0,
    this.unpaidExtensionAmount = 0,
  })  : dailyRate = dailyRate ?? 0,
        extensionIds = extensionIds ?? [];

  // Méthode pour copier la transaction avec des modifications
  Transaction copyWith({
    int? id,
    String? type,
    String? title,
    String? date,
    String? dateRetour,
    int? amount,
    String? status,
    bool? isPaid,
    String? equipmentId,
    String? invoiceNumber,
    int? dailyRate,
    List<String>? extensionIds,
    int? extensionCount,
    int? unpaidExtensionAmount,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      date: date ?? this.date,
      dateRetour: dateRetour ?? this.dateRetour,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      isPaid: isPaid ?? this.isPaid,
      equipmentId: equipmentId ?? this.equipmentId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      dailyRate: dailyRate ?? this.dailyRate,
      extensionIds: extensionIds ?? this.extensionIds,
      extensionCount: extensionCount ?? this.extensionCount,
      unpaidExtensionAmount: unpaidExtensionAmount ?? this.unpaidExtensionAmount,
    );
  }
}

class HistoriqueScreen extends StatefulWidget {
  const HistoriqueScreen({Key? key}) : super(key: key);

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  String _selectedFilter = 'Tous';
  
  // Gestionnaire des prolongations
  final ExtensionsManager _extensionsManager = ExtensionsManager();
  final DataManager _dataManager = DataManager();
  StreamSubscription? _extSub;

  List<Transaction> _allTransactions = [
    Transaction(
      id: 1,
      type: 'location',
      title: 'GPS e-survey E600',
      date: '2025-12-01',
      dateRetour: '2025-12-10',
      amount: 75000,
      status: 'en-cours',
      isPaid: true,
      equipmentId: 'GPS-E600-001',
      invoiceNumber: 'INV-2025-001',
      dailyRate: 8333, // 75000 / 9 jours
    ),
    Transaction(
      id: 2,
      type: 'achat',
      title: 'Niveau automatique Leica',
      date: '2025-11-25',
      amount: 1200000,
      status: 'termine',
      isPaid: true,
      invoiceNumber: 'INV-2025-002',
    ),
    Transaction(
      id: 3,
      type: 'service',
      title: 'Levé topographique',
      date: '2025-11-20',
      amount: 150000,
      status: 'termine',
      isPaid: true,
      invoiceNumber: 'INV-2025-003',
    ),
    Transaction(
      id: 4,
      type: 'location',
      title: 'Théodolite Leica',
      date: '2025-11-15',
      dateRetour: '2025-11-20',
      amount: 90000,
      status: 'termine',
      isPaid: true,
      equipmentId: 'THEO-LCA-002',
      invoiceNumber: 'INV-2025-004',
      dailyRate: 18000,
    ),
    Transaction(
      id: 5,
      type: 'service',
      title: 'Plan cadastral',
      date: '2025-11-10',
      amount: 120000,
      status: 'en-attente',
      isPaid: false,
      invoiceNumber: 'INV-2025-005',
    ),
  ];

  List<Transaction> get _filteredTransactions {
    if (_selectedFilter == 'Tous') return _allTransactions;
    return _allTransactions.where((t) {
      if (_selectedFilter == 'En cours') return t.status == 'en-cours';
      if (_selectedFilter == 'Terminés') return t.status == 'termine';
      if (_selectedFilter == 'En attente') return t.status == 'en-attente';
      return true;
    }).toList();
  }

  Map<String, dynamic> get _statistics {
    int totalDepenses = _allTransactions.fold(0, (sum, t) => sum + t.amount);
    int locationsActives = _allTransactions.where((t) => t.type == 'location' && t.status == 'en-cours').length;
    int commandesTerminees = _allTransactions.where((t) => t.status == 'termine').length;
    int paiementsEnAttente = _allTransactions.where((t) => !t.isPaid || t.unpaidExtensionAmount > 0).length;

    return {
      'totalDepenses': totalDepenses,
      'locationsActives': locationsActives,
      'commandesTerminees': commandesTerminees,
      'paiementsEnAttente': paiementsEnAttente,
    };
  }

  @override
  void initState() {
    super.initState();
    _dataManager.initialize();
    _dataManager.addListener(() {
      if (mounted) setState(() {});
    });

    if (kDemoPaymentsEnabled) {
      _extSub = _extensionsManager.events.listen((event) {
        if (event.type == 'transactionUpdated') {
          final idx = _allTransactions.indexWhere((t) => t.id == event.transactionId);
          if (idx != -1) {
            final unpaid = _extensionsManager.computeUnpaidForTransaction(event.transactionId);
            final updated = _allTransactions[idx].copyWith(unpaidExtensionAmount: unpaid);
            if (mounted) {
              setState(() {
                _allTransactions[idx] = updated;
              });
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _extSub?.cancel();
    _dataManager.removeListener(() => setState(() {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _statistics;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Historique & Suivi',
              style: TextStyle(color: Color(0xFF111827), fontSize: 18),
            ),
            Text(
              'Gérez vos commandes et locations',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag, color: Color(0xFF059669)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ClientMesDemandesPage()),
                  );
                },
                tooltip: 'Mes demandes d\'achat',
              ),
              if (_dataManager.getDemandesByClient('user@exemple.com').isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF059669),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_dataManager.getDemandesByClient('user@exemple.com').length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          if (kDemoPaymentsEnabled)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Color(0xFF2563EB)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminProlongationsPage()),
                );
              },
              tooltip: 'Admin Prolongations',
            ),
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF2563EB)),
            onPressed: _exportHistorique,
            tooltip: 'Exporter l\'historique',
          ),
          IconButton(
            icon: const Icon(Icons.dashboard, color: Color(0xFF2563EB)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            },
            tooltip: 'Tableau de bord',
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Cards
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total dépensé',
                        '${_formatNumber(stats['totalDepenses'])} FCFA',
                        Icons.account_balance_wallet,
                        const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Locations actives',
                        '${stats['locationsActives']}',
                        Icons.inventory_2,
                        const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Terminées',
                        '${stats['commandesTerminees']}',
                        Icons.check_circle,
                        const Color(0xFF9333EA),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'En attente',
                        '${stats['paiementsEnAttente']}',
                        Icons.access_time,
                        const Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Tous', 'En cours', 'Terminés', 'En attente'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      backgroundColor: const Color(0xFFF3F4F6),
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF374151),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Transactions List
          Expanded(
            child: _filteredTransactions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _filteredTransactions[index];
                      return _buildEnhancedTransactionCard(transaction);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _exportHistorique() {
    // TODO: Implement export functionality
  }

  String _formatNumber(int number) {
    // Simple formatting, you might want to use intl package for better formatting
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    ).trim();
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Aucune transaction trouvée',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTypeConfig(String type) {
    switch (type) {
      case 'location':
        return {
          'bgColor': const Color(0xFFDBEAFE),
          'icon': Icons.inventory_2,
          'iconColor': const Color(0xFF2563EB),
        };
      case 'achat':
        return {
          'bgColor': const Color(0xFFF0FDF4),
          'icon': Icons.shopping_cart,
          'iconColor': const Color(0xFF059669),
        };
      case 'service':
        return {
          'bgColor': const Color(0xFFF3E8FF),
          'icon': Icons.build,
          'iconColor': const Color(0xFF9333EA),
        };
      default:
        return {
          'bgColor': const Color(0xFFF3F4F6),
          'icon': Icons.help,
          'iconColor': const Color(0xFF6B7280),
        };
    }
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'en-cours':
        return {
          'bgColor': const Color(0xFFDBEAFE),
          'icon': Icons.access_time,
          'textColor': const Color(0xFF2563EB),
          'label': 'En cours',
        };
      case 'termine':
        return {
          'bgColor': const Color(0xFFF0FDF4),
          'icon': Icons.check_circle,
          'textColor': const Color(0xFF059669),
          'label': 'Terminé',
        };
      case 'en-attente':
        return {
          'bgColor': const Color(0xFFFEF3C7),
          'icon': Icons.hourglass_empty,
          'textColor': const Color(0xFFD97706),
          'label': 'En attente',
        };
      default:
        return {
          'bgColor': const Color(0xFFF3F4F6),
          'icon': Icons.help,
          'textColor': const Color(0xFF6B7280),
          'label': 'Inconnu',
        };
    }
  }

  Map<String, dynamic> _getLateInfo(Transaction transaction) {
    if (transaction.dateRetour == null || transaction.status != 'en-cours') {
      return {'isLate': false, 'daysLate': 0, 'penalty': 0};
    }
    final returnDate = DateTime.parse(transaction.dateRetour!);
    final now = DateTime.now();
    if (now.isAfter(returnDate)) {
      final daysLate = now.difference(returnDate).inDays;
      // Penalty: 10% per day late
      final penalty = (transaction.amount * 0.1 * daysLate).round();
      return {'isLate': true, 'daysLate': daysLate, 'penalty': penalty};
    }
    return {'isLate': false, 'daysLate': 0, 'penalty': 0};
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: const Size(0, 32),
        textStyle: const TextStyle(fontSize: 11),
      ),
    );
  }

  Future<void> _downloadInvoice(Transaction transaction) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Echelle EG39 - Facture',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Numéro de facture: ${transaction.invoiceNumber ?? 'N/A'}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'Date: ${_formatDate(transaction.date)}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Transaction Details
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Détails de la Transaction',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text('Type: ${transaction.type}'),
                        ),
                        pw.Expanded(
                          child: pw.Text('Statut: ${transaction.status}'),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('Description: ${transaction.title}'),
                    pw.SizedBox(height: 10),
                    if (transaction.dateRetour != null)
                      pw.Text('Date de retour: ${_formatDate(transaction.dateRetour!)}'),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Montant: ${_formatNumber(transaction.amount)} FCFA',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.grey)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Merci pour votre confiance !',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Conditions: Tout retard de retour peut entraîner des frais supplémentaires.',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save and open PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'facture_${transaction.invoiceNumber ?? transaction.id}.pdf',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Facture téléchargée avec succès !'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Nouvelle fonction améliorée pour prolonger la location
  Future<void> _prolongerLocation(Transaction transaction) async {
    if (transaction.dateRetour == null) return;

    // Vérifier le nombre de prolongations (maximum 3)
    if (transaction.extensionCount >= 3) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Limite atteinte'),
            ],
          ),
          content: const Text(
            'Désolé, cette location a déjà été prolongée 3 fois. '
            'Veuillez contacter le service client pour plus d\'informations.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
      return;
    }

    // Vérifier si des prolongations sont impayées
    if (transaction.unpaidExtensionAmount > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Paiement requis'),
            ],
          ),
          content: Text(
            'Vous avez ${_formatNumber(transaction.unpaidExtensionAmount)} FCFA '
            'de prolongations non payées. Veuillez régler ce montant avant de prolonger à nouveau.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _payerExtension(transaction);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Payer maintenant'),
            ),
          ],
        ),
      );
      return;
    }

    final currentReturnDate = DateTime.parse(transaction.dateRetour!);
    final dailyRate = transaction.dailyRate;

    // Dialogue unique avec calcul en temps réel
    DateTime? selectedDate;
    int additionalDays = 0;
    int additionalCost = 0;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.update, color: Color(0xFF059669)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Prolonger la Location',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.title,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informations actuelles
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Color(0xFF6B7280)),
                              const SizedBox(width: 8),
                              const Text(
                                'Informations actuelles',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow('Date de retour actuelle', _formatDate(transaction.dateRetour!)),
                          _buildInfoRow('Tarif journalier', '${_formatNumber(dailyRate)} FCFA'),
                          _buildInfoRow('Prolongations déjà faites', '${transaction.extensionCount}/3'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sélection de la nouvelle date
                    const Text(
                      'Nouvelle date de retour',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: currentReturnDate.add(const Duration(days: 1)),
                          firstDate: currentReturnDate.add(const Duration(days: 1)),
                          lastDate: currentReturnDate.add(const Duration(days: 30)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF059669),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                            additionalDays = picked.difference(currentReturnDate).inDays;
                            additionalCost = additionalDays * dailyRate;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Color(0xFF059669)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                selectedDate != null
                                    ? _formatDate(selectedDate!.toIso8601String().split('T')[0])
                                    : 'Cliquez pour sélectionner',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: selectedDate != null ? Colors.black : Colors.grey,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Maximum 30 jours de prolongation',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),

                    // Calcul en temps réel
                    if (selectedDate != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF059669), width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.calculate, size: 16, color: Color(0xFF059669)),
                                SizedBox(width: 8),
                                Text(
                                  'Calcul de la prolongation',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            _buildCalculRow('Jours supplémentaires', '$additionalDays jours'),
                            _buildCalculRow(
                              'Coût par jour',
                              '${_formatNumber(dailyRate)} FCFA',
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Coût total prolongation',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_formatNumber(additionalCost)} FCFA',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.yellow.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.yellow.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info, size: 14, color: Colors.orange.shade700),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Nouveau total: ${_formatNumber(transaction.amount + additionalCost)} FCFA',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    // Note importante
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Une facture séparée sera générée pour cette prolongation. Le paiement devra être effectué avant la nouvelle date de retour.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton.icon(
                  onPressed: selectedDate == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _confirmerProlongation(
                            transaction,
                            selectedDate!,
                            additionalDays,
                            additionalCost,
                          );
                        },
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmer la prolongation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Fonction pour confirmer et enregistrer la prolongation
  void _confirmerProlongation(
    Transaction transaction,
    DateTime newReturnDate,
    int additionalDays,
    int additionalCost,
  ) {
    // Générer un ID et un numéro de facture pour la prolongation
    final extensionId = 'EXT-${DateTime.now().millisecondsSinceEpoch}';
    final extensionInvoiceNumber = 'INV-EXT-${transaction.id}-${transaction.extensionCount + 1}';

    // Créer l'objet de prolongation
    final extension = LocationExtension(
      extensionId: extensionId,
      transactionId: transaction.id,
      clientName: 'Client XYZ', // TODO: Remplacer par le vrai nom du client
      equipmentName: transaction.title,
      oldReturnDate: transaction.dateRetour!,
      newReturnDate: newReturnDate.toIso8601String().split('T')[0],
      additionalDays: additionalDays,
      additionalCost: additionalCost,
      createdAt: DateTime.now(),
      isPaid: false,
      invoiceNumber: extensionInvoiceNumber,
    );

    // Stocker la prolongation dans le gestionnaire global
    _extensionsManager.addExtension(extension);

    // Mettre à jour la transaction
    final index = _allTransactions.indexOf(transaction);
    if (index != -1) {
      final updatedExtensionIds = List<String>.from(transaction.extensionIds)..add(extensionId);
      
      _allTransactions[index] = transaction.copyWith(
        dateRetour: newReturnDate.toIso8601String().split('T')[0],
        amount: transaction.amount + additionalCost,
        extensionIds: updatedExtensionIds,
        extensionCount: transaction.extensionCount + 1,
        unpaidExtensionAmount: _extensionsManager.computeUnpaidForTransaction(transaction.id),
      );

      setState(() {});

      // Afficher la confirmation avec option de télécharger la facture
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Prolongation confirmée !'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✓ Nouvelle date de retour: ${_formatDate(newReturnDate.toIso8601String().split('T')[0])}'),
              const SizedBox(height: 8),
              Text('✓ Prolongation: $additionalDays jours'),
              const SizedBox(height: 8),
              Text('✓ Facture N°: $extensionInvoiceNumber'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'À payer: ${_formatNumber(additionalCost)} FCFA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '⚠️ Rappel: Le paiement de cette prolongation doit être effectué avant la nouvelle date de retour.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _downloadExtensionInvoice(extension, transaction);
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('Télécharger facture'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            ),
          ],
        ),
      );
    }
  }

  // Fonction pour télécharger la facture de prolongation
  Future<void> _downloadExtensionInvoice(LocationExtension extension, Transaction transaction) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ECHELLE EG39 - Facture de Prolongation',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Numéro: ${extension.invoiceNumber}',
                      style: pw.TextStyle(fontSize: 14, color: PdfColors.white),
                    ),
                    pw.Text(
                      'Date: ${_formatDate(extension.createdAt.toIso8601String().split('T')[0])}',
                      style: pw.TextStyle(fontSize: 14, color: PdfColors.white),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Details
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Détails de la Prolongation',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Text('Équipement: ${transaction.title}'),
                    pw.SizedBox(height: 8),
                    pw.Text('Ancienne date de retour: ${_formatDate(extension.oldReturnDate)}'),
                    pw.Text('Nouvelle date de retour: ${_formatDate(extension.newReturnDate)}'),
                    pw.SizedBox(height: 8),
                    pw.Text('Jours supplémentaires: ${extension.additionalDays}'),
                    pw.SizedBox(height: 15),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green50,
                        border: pw.Border.all(color: PdfColors.green),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Montant à payer:',
                            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            '${_formatNumber(extension.additionalCost)} FCFA',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.grey)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Merci pour votre confiance !',
                      style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Contact DG: +2290014329 / +22890897654',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'prolongation_${extension.invoiceNumber}.pdf',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Facture de prolongation téléchargée avec succès !'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Fonction pour payer les prolongations impayées (UTILISATEUR)
  void _payerExtension(Transaction transaction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.payment, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Paiement Prolongation', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Équipement: ${transaction.title}'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Montant à payer:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '${_formatNumber(transaction.unpaidExtensionAmount)} FCFA',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2563EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        children: [
                          Icon(Icons.info, size: 18, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Instructions de paiement',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Contactez le Directeur General EG39',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '2. Effectuez le paiement en cash ou par transfert',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '3. Le DG validera votre paiement dans son espace',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '4. Vous recevrez une notification de confirmation',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Contacts du Directeur General:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: const [
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Color(0xFF059669)),
                          SizedBox(width: 8),
                          Text('99001166', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Color(0xFF059669)),
                          SizedBox(width: 8),
                          Text('90897654', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // Simuler l'appel
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Appel vers 99001166...'),
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              },
              icon: const Icon(Icons.call),
              label: const Text('Appeler 99001166'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _relouer(Transaction transaction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Relouer l\'équipement',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Voulez-vous relouer "${transaction.title}" ?',
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Vous serez redirigé vers la page de location.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Navigate to location page with equipment pre-selected
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Redirection vers location de "${transaction.title}"'),
                    action: SnackBarAction(
                      label: 'Aller',
                      onPressed: () {
                        // Here would be navigation to location page
                        // Navigator.push(context, MaterialPageRoute(builder: (context) => LocationScreen()));
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9333EA),
              ),
              child: const Text('Relouer'),
            ),
          ],
        );
      },
    );
  }

  void _evaluerService(Transaction transaction) {
    int _rating = 0;
    final TextEditingController _commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Évaluer le service',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Comment évaluez-vous "${transaction.title}" ?',
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        onPressed: () {
                          setState(() {
                            _rating = index + 1;
                          });
                        },
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: _rating > 0 ? () {
                    Navigator.of(context).pop();
                    // TODO: Save rating and comment
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Merci pour votre évaluation de $_rating étoile(s) !'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                  ),
                  child: const Text('Évaluer'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      _commentController.dispose();
    });
  }

  void _payerFacture(Transaction transaction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Paiement de Facture',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Veuillez contacter le Directeur General EG39 au 99001166 ou au 90897654 pour faire votre versement.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Merci',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // Appeler 99001166
                // Using url_launcher
                // But since it's not imported, for now just show message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appel vers 99001166...')),
                );
              },
              icon: const Icon(Icons.call),
              label: const Text('99001166'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appel vers 90897654...')),
                );
              },
              icon: const Icon(Icons.call),
              label: const Text('90897654'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTransactionCard(Transaction transaction) {
    final typeConfig = _getTypeConfig(transaction.type);
    final statusConfig = _getStatusConfig(transaction.status);
    final lateInfo = _getLateInfo(transaction);
    final isLate = lateInfo['isLate'] as bool;
    
    // Récupérer les prolongations de cette transaction depuis le gestionnaire
    final transactionExtensions = transaction.extensionIds
        .map((id) => _extensionsManager.getExtension(id))
        .where((ext) => ext != null)
        .cast<LocationExtension>()
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isLate ? Border.all(color: Colors.red, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: typeConfig['bgColor'],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeConfig['icon'], color: typeConfig['iconColor'], size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              transaction.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 80),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusConfig['bgColor'],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusConfig['icon'], size: 10, color: statusConfig['textColor']),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    statusConfig['label'],
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: statusConfig['textColor'],
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(transaction.date),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          if (transaction.dateRetour != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(transaction.dateRetour!),
                              style: TextStyle(
                                fontSize: 12,
                                color: isLate ? Colors.red : Colors.grey[600],
                                fontWeight: isLate ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${_formatNumber(transaction.amount)} FCFA',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!transaction.isPaid)
                            Container(
                              constraints: const BoxConstraints(maxWidth: 60),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Non payé',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (transaction.unpaidExtensionAmount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Prolong. impayée',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (transaction.invoiceNumber != null) ...[
                            const Spacer(),
                            Text(
                              transaction.invoiceNumber!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      // Afficher l'historique des prolongations
                      if (transactionExtensions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF059669), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history, size: 12, color: Color(0xFF059669)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Prolongations (${transactionExtensions.length}/3)',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...transactionExtensions.map((ext) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: ext.isPaid ? Colors.green : Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${_formatDate(ext.oldReturnDate)} → ${_formatDate(ext.newReturnDate)} (+${ext.additionalDays}j)',
                                          style: const TextStyle(fontSize: 9),
                                        ),
                                      ),
                                      Text(
                                        '${_formatNumber(ext.additionalCost)} F',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: ext.isPaid ? Colors.green : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                      
                      if (isLate)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning, size: 14, color: Colors.red[700]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'RETARD ! ${lateInfo['daysLate']}j - Pén. ${_formatNumber(lateInfo['penalty'])} FCFA',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Retour immédiat pour éviter pénalités',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.red[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Action Buttons
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                // Télécharger facture
                _buildActionButton(
                  'Facture',
                  Icons.receipt_long,
                  const Color(0xFF2563EB),
                  () => _downloadInvoice(transaction),
                ),

                // Actions spécifiques selon le type et statut
                if (transaction.status == 'en-cours' && transaction.type == 'location')
                  _buildActionButton(
                    'Prolonger',
                    Icons.update,
                    const Color(0xFF059669),
                    () => _prolongerLocation(transaction),
                  ),

                if (transaction.status == 'termine')
                  _buildActionButton(
                    'Relouer',
                    Icons.replay,
                    const Color(0xFF9333EA),
                    () => _relouer(transaction),
                  ),

                // Évaluer (si terminé)
                if (transaction.status == 'termine')
                  _buildActionButton(
                    'Évaluer',
                    Icons.star_outline,
                    const Color(0xFFEA580C),
                    () => _evaluerService(transaction),
                  ),

                // Payer (si non payé)
                if (!transaction.isPaid)
                  _buildActionButton(
                    'Payer',
                    Icons.payment,
                    Colors.red,
                    () => _payerFacture(transaction),
                  ),
                  
                // Payer les prolongations
                if (transaction.unpaidExtensionAmount > 0)
                  _buildActionButton(
                    'Payer prolong.',
                    Icons.payment,
                    Colors.orange,
                    () => _payerExtension(transaction),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Placeholder for DashboardScreen - you need to define this class elsewhere or import it
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Dashboard Screen'),
      ),
    );
  }
}