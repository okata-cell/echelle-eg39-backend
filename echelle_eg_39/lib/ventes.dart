import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data_manager.dart';
import 'appareil_images.dart';
import 'api_service.dart';
import 'login.page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/image_zoom_viewer.dart' show openImageZoom;

class Product {
  final int id;
  final String code;
  final String name;
  final String category;
  final int price;
  final bool inStock;
  final String imageUrl;

  Product({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.price,
    required this.inStock,
    required this.imageUrl,
  });

  /// Identifiant de produit utilisé dans les demandes d'achat
  String get produitId => code;
}

class VenteScreen extends StatefulWidget {
  const VenteScreen({Key? key}) : super(key: key);

  @override
  State<VenteScreen> createState() => _VenteScreenState();
}

class _VenteScreenState extends State<VenteScreen> {
  final _dataManager = DataManager();
  List<Product> _apiProducts = [];  // Products from API
  List<Map<String, dynamic>> _pendingDemandes = []; // Pending purchase requests from API

  String _searchQuery = '';
  String _selectedCategory = 'Tous';

  /// Email de l'utilisateur connecté (sert à identifier ses demandes)
  String _currentUserEmail = '';

  final List<String> _categories = [
    'Tous', 'GPS', 'Station totale', 'Niveau', 'Mire',
    'Drone', 'Laser', 'Réflecteur', 'Canne',
    'Antenne', 'Accessoire'
  ];

  List<Product> get _products => _apiProducts;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadProductsFromAPI();
    _loadPendingDemandesFromAPI();
    // Quand le DG valide/refuse → notifyListeners → setState → bouton se débloque
    _dataManager.addListener(_onDataChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh pending demandes when returning to this page
    _loadPendingDemandesFromAPI();
  }

  /// Charger les demandes d'achat en attente depuis l'API
  Future<void> _loadPendingDemandesFromAPI() async {
    try {
      final token = await ApiService.ensureAuthenticated();
      if (token == null || !mounted) return;
      
      final demandes = await ApiService.getDemandesAchat(statut: 'en_attente');
      if (mounted) {
        setState(() {
          _pendingDemandes = demandes;
        });
        print('📡 Pending demandes loaded: ${demandes.length}');
      }
    } catch (e) {
      print('⚠️ Failed to load pending demandes: $e');
    }
  }

  /// Rafraîchir les demandes en attente (appelé après approbation/rejet)
  Future<void> _refreshPendingDemandes() async {
    await _loadPendingDemandesFromAPI();
  }

  Future<void> _loadProductsFromAPI() async {
    try {
      final appareils = await ApiService.getAppareils();
      if (mounted && appareils.isNotEmpty) {
        setState(() {
        _apiProducts = appareils.map((a) => Product(
id: a['id'] as int,
code: a['code'] as String? ?? '',
name: a['nom'] as String,
category: a['type'] as String,
price: a['prixVente'] as int,
inStock: a['disponible'] as bool? ?? true,
imageUrl: a['imageUrl'] as String? ?? AppareilImages.getImageUrl(
  a['code'] as String? ?? '',
  a['type'] as String? ?? '',
),
)).toList();
        });
      }
    } catch (e) {
      print('⚠️ Failed to load products from API: $e');
    }
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail') ?? '';
    if (mounted) setState(() => _currentUserEmail = email);
  }

  @override
  void dispose() {
    _dataManager.removeListener(_onDataChanged);
    super.dispose();
  }

  List<Product> get _filteredProducts {
    return _products.where((product) {
      final matchesSearch =
          product.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'Tous' || product.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  // ── Vérifie si l'utilisateur a déjà une demande EN ATTENTE pour ce produit ──
  bool _hasPendingDemande(Product product) {
    if (_currentUserEmail.isEmpty) return false;
    
    // First check API pending requests (most up-to-date)
    if (_pendingDemandes.any((d) =>
        d['clientEmail'] == _currentUserEmail &&
        d['appareilId'] == product.code &&
        d['statut'] == 'en_attente')) {
      return true;
    }
    
    // Fallback to local data manager
    return _dataManager.demandesAchat.any((d) =>
        d.clientEmail == _currentUserEmail &&
        d.produitId == product.produitId &&
        d.statut == 'en_attente');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Vente d\'appareils',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _loadProductsFromAPI,
            icon: const Icon(Icons.refresh, color: Color(0xFF059669)),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un appareil...',
                    hintStyle: GoogleFonts.poppins(
                      color: const Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF)),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            category,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = category),
                          backgroundColor: const Color(0xFFF3F4F6),
                          selectedColor: const Color(0xFF059669),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF374151),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredProducts.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductCard(product);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun produit trouvé',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gérer le clic sur "Acheter" ───────────────────────────────────────────

  void _handleAchat(Product product) async {
    // 1. Vérifier l'authentification - avec reconnexion automatique si nécessaire
    final token = await ApiService.ensureAuthenticated();
    if (!mounted) return;

    if (token == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Connexion requise'),
          content:
              const Text('Veuillez vous connecter pour acheter un appareil.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              child: const Text('Se connecter'),
            ),
          ],
        ),
      );
      return;
    }

    // Recharger l'email si nécessaire
    if (_currentUserEmail.isEmpty) await _loadCurrentUser();

    // 2. Vérifier si une demande est déjà en attente pour CE produit
    if (_hasPendingDemande(product)) {
      _showDejaEnAttenteDialog(product);
      return;
    }

    // 3. Tout est bon → afficher le dialog d'achat
    _showAchatDialog(product);
  }

  /// Dialog affiché quand l'utilisateur clique une 2e fois sur Acheter
  void _showDejaEnAttenteDialog(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.hourglass_top, color: Color(0xFFD97706), size: 24),
            SizedBox(width: 8),
            Text('Demande en cours'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vous avez déjà soumis une demande d\'achat pour :',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2,
                      color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Veuillez patienter que le Directeur Général valide votre première demande avant d\'en soumettre une nouvelle.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
            ),
            child: const Text('J\'ai compris'),
          ),
        ],
      ),
    );
  }

  /// Dialog de confirmation d'achat
  void _showAchatDialog(Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? 'Client connecté';
    final userEmail = prefs.getString('userEmail') ?? 'client@exemple.com';
    final userPhone = prefs.getString('userPhone') ?? '+228 00 00 00 00';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Acheter ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(Icons.inventory_2, 'Produit', product.name),
              const SizedBox(height: 8),
              _infoRow(
                Icons.attach_money,
                'Prix',
                '${product.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA',
              ),
              const SizedBox(height: 8),
              _infoRow(
                Icons.circle,
                'Statut',
                product.inStock ? 'En stock' : 'Rupture de stock',
                valueColor: product.inStock
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
              ),
              const Divider(height: 20),
              const Text(
                'Confirmer cette demande d\'achat ?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Envoyer la demande au backend
                try {
                  await ApiService.createDemandeAchat(
                    product.id,
                    1,
                  );
                  // Ajouter aussi en local pour affichage immédiat
                  _dataManager.addDemandeAchat(
                    clientNom: userName,
                    clientEmail: userEmail,
                    clientPhone: userPhone,
                    produitId: product.produitId,
                    produitNom: product.name,
                    produitPrix: product.price,
                    quantite: 1,
                  );
                } catch (e) {
                  // Si l'API échoue, ajouter quand même en local
                  _dataManager.addDemandeAchat(
                    clientNom: userName,
                    clientEmail: userEmail,
                    clientPhone: userPhone,
                    produitId: product.produitId,
                    produitNom: product.name,
                    produitPrix: product.price,
                    quantite: 1,
                  );
                }
                Navigator.of(ctx).pop();
                if (!mounted) return;
                
                // Refresh pending demandes to update button state
                await _refreshPendingDemandes();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Demande envoyée pour ${product.name}. '
                      'En attente de validation du DG.',
                    ),
                    backgroundColor: const Color(0xFF059669),
                    duration: const Duration(seconds: 4),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
              ),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 6),
        Text('$label : ',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF111827),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Carte produit ─────────────────────────────────────────────────────────

  Widget _buildProductCard(Product product) {
    final isPending = _hasPendingDemande(product);
    final canBuy = product.inStock && !isPending;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image (tappable → zoom plein écran)
          GestureDetector(
            onTap: () {
              openImageZoom(
                context,
                imageUrl: product.imageUrl,
              );
            },
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Image.network(
                product.imageUrl,
                width: double.infinity,
                height: 140,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: 140,
                    color: const Color(0xFFF3F4F6),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF059669),
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 140,
                    color: const Color(0xFFF3F4F6),
                    child: Icon(
                      Icons.image_not_supported,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    product.category,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${product.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} FCFA',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Bouton Acheter / En attente / Rupture ──────────────────
                SizedBox(
                  width: double.infinity,
                  child: _buildAchatButton(product, isPending, canBuy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchatButton(Product product, bool isPending, bool canBuy) {
    if (!product.inStock) {
      // Rupture de stock
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.remove_shopping_cart, size: 14),
        label: Text('Rupture', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: const Color(0xFFD1D5DB),
          padding: const EdgeInsets.symmetric(vertical: 8),
          minimumSize: const Size(double.infinity, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    if (isPending) {
      // Demande déjà en attente → bouton orange informatif, tappable pour voir le message
      return ElevatedButton.icon(
        onPressed: () => _showDejaEnAttenteDialog(product),
        icon: const Icon(Icons.hourglass_top, size: 14),
        label: Text('En attente...', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFEF3C7),
          foregroundColor: const Color(0xFFD97706),
          padding: const EdgeInsets.symmetric(vertical: 8),
          minimumSize: const Size(double.infinity, 36),
          elevation: 0,
          side: const BorderSide(color: Color(0xFFFBBF24), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    // Disponible → bouton vert actif
    return ElevatedButton.icon(
      onPressed: () => _handleAchat(product),
      icon: const Icon(Icons.shopping_cart, size: 14),
      label: Text('Acheter', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF059669),
        disabledBackgroundColor: const Color(0xFFD1D5DB),
        padding: const EdgeInsets.symmetric(vertical: 8),
        minimumSize: const Size(double.infinity, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
