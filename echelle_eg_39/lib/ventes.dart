import 'package:flutter/material.dart';
import 'data_manager.dart';
import 'appareil_images.dart';
import 'api_service.dart';
import 'login.page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/image_zoom_viewer.dart' show openImageZoom;

class _VentePalette {
  static const canvas = Color(0xFFF5F5F7);
  static const surface = Colors.white;
  static const ink = Color(0xFF1D1D1F);
  static const secondaryInk = Color(0xFF333333);
  static const mutedInk = Color(0xFF7A7A7A);
  static const hairline = Color(0xFFE0E0E0);
  static const softDivider = Color(0xFFF0F0F0);
  static const actionBlue = Color(0xFF0066CC);
  static const disabled = Color(0xFFE5E5EA);
  static const available = Color(0xFF23865B);
  static const unavailable = Color(0xFFB42318);
  static const pending = Color(0xFF9A6700);
}

String _formatFcfa(int amount) => amount.toString().replaceAllMapped(
  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]} ',
);

typedef VenteProductsLoader = Future<List<Map<String, dynamic>>> Function();
typedef VentePendingDemandesLoader =
    Future<List<Map<String, dynamic>>> Function();
typedef VentePurchaseCreator =
    Future<Map<String, dynamic>> Function(int appareilId, int quantite);

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
  const VenteScreen({
    super.key,
    this.loadProducts,
    this.loadPendingDemandes,
    this.createPurchaseRequest,
  });

  final VenteProductsLoader? loadProducts;
  final VentePendingDemandesLoader? loadPendingDemandes;
  final VentePurchaseCreator? createPurchaseRequest;

  @override
  State<VenteScreen> createState() => _VenteScreenState();
}

class _VenteScreenState extends State<VenteScreen> {
  final _dataManager = DataManager();
  final _searchController = TextEditingController();
  List<Product> _apiProducts = [];
  List<Map<String, dynamic>> _pendingDemandes = [];
  bool _isLoadingProducts = true;
  String? _productsError;

  String _searchQuery = '';
  String _selectedCategory = 'Tous';

  /// Email de l'utilisateur connecté (sert à identifier ses demandes)
  String _currentUserEmail = '';

  final List<String> _categories = [
    'Tous',
    'GPS',
    'Station totale',
    'Niveau',
    'Mire',
    'Drone',
    'Laser',
    'Réflecteur',
    'Canne',
    'Antenne',
    'Accessoire',
  ];

  List<Product> get _products => _apiProducts;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadProductsFromAPI();
    // Quand le DG valide/refuse → notifyListeners → setState → bouton se débloque
    _dataManager.addListener(_onDataChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPendingDemandesFromAPI();
  }

  /// Charger les demandes d'achat en attente depuis l'API
  Future<void> _loadPendingDemandesFromAPI() async {
    try {
      if (widget.loadPendingDemandes == null) {
        final token = await ApiService.ensureAuthenticated();
        if (token == null || !mounted) return;
      }

      final demandes =
          await (widget.loadPendingDemandes?.call() ??
              ApiService.getDemandesAchat(statut: 'en_attente'));
      if (mounted) {
        setState(() {
          _pendingDemandes = demandes;
        });
        debugPrint('Pending purchase requests loaded: ${demandes.length}');
      }
    } catch (error) {
      debugPrint('Failed to load pending purchase requests: $error');
    }
  }

  /// Rafraîchir les demandes en attente (appelé après approbation/rejet)
  Future<void> _refreshPendingDemandes() async {
    await _loadPendingDemandesFromAPI();
  }

  Future<void> _loadProductsFromAPI() async {
    if (mounted) {
      setState(() {
        _isLoadingProducts = true;
        _productsError = null;
      });
    }

    try {
      final appareils =
          await (widget.loadProducts?.call() ?? ApiService.getAppareils());
      if (!mounted) return;

      setState(() {
        _apiProducts = appareils
            .map((appareil) {
              final code = appareil['code']?.toString() ?? '';
              final category = appareil['type']?.toString() ?? '';
              final imageUrl = appareil['imageUrl']?.toString();
              return Product(
                id: (appareil['id'] as num).toInt(),
                code: code,
                name: appareil['nom']?.toString() ?? 'Appareil sans nom',
                category: category,
                price: (appareil['prixVente'] as num).toInt(),
                inStock: appareil['disponible'] as bool? ?? true,
                imageUrl: imageUrl == null || imageUrl.isEmpty
                    ? AppareilImages.getImageUrl(code, category)
                    : imageUrl,
              );
            })
            .toList(growable: false);
      });
    } catch (error) {
      debugPrint('Failed to load products from API: $error');
      if (mounted) {
        setState(() {
          _productsError = 'Impossible de charger les appareils.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
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
    _searchController.dispose();
    _dataManager.removeListener(_onDataChanged);
    super.dispose();
  }

  List<Product> get _filteredProducts {
    return _products
        .where((product) {
          final matchesSearch = product.name.toLowerCase().contains(
            _searchQuery.trim().toLowerCase(),
          );
          final matchesCategory =
              _selectedCategory == 'Tous' ||
              product.category == _selectedCategory;
          return matchesSearch && matchesCategory;
        })
        .toList(growable: false);
  }

  // ── Vérifie si l'utilisateur a déjà une demande EN ATTENTE pour ce produit ──
  bool _hasPendingDemande(Product product) {
    if (_currentUserEmail.isEmpty) return false;

    // First check API pending requests (most up-to-date)
    if (_pendingDemandes.any(
      (d) =>
          d['clientEmail'] == _currentUserEmail &&
          d['appareilId'] == product.code &&
          d['statut'] == 'en_attente',
    )) {
      return true;
    }

    // Fallback to local data manager
    return _dataManager.demandesAchat.any(
      (d) =>
          d.clientEmail == _currentUserEmail &&
          d.produitId == product.produitId &&
          d.statut == 'en_attente',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _VentePalette.canvas,
      appBar: AppBar(
        toolbarHeight: 54,
        backgroundColor: _VentePalette.surface,
        surfaceTintColor: _VentePalette.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        automaticallyImplyLeading: false,
        title: Text(
          'Vente d’appareils',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _VentePalette.ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.45,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoadingProducts ? null : _loadProductsFromAPI,
            tooltip: 'Actualiser les appareils',
            style: IconButton.styleFrom(
              backgroundColor: _VentePalette.canvas,
              foregroundColor: _VentePalette.actionBlue,
              minimumSize: const Size(40, 40),
              maximumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.refresh, size: 21),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: _VentePalette.surface,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              key: const ValueKey('vente-search-field'),
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _VentePalette.secondaryInk,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Rechercher un appareil…',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _VentePalette.mutedInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: _VentePalette.mutedInk,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        key: const ValueKey('vente-clear-search'),
                        tooltip: 'Effacer la recherche',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(
                          Icons.close,
                          color: _VentePalette.mutedInk,
                          size: 18,
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: _VentePalette.hairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: _VentePalette.hairline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(
                    color: _VentePalette.actionBlue,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: _VentePalette.canvas,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          Container(
            height: 50,
            color: _VentePalette.surface,
            padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
            child: ListView.separated(
              key: const ValueKey('vente-category-rail'),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return ChoiceChip(
                  key: ValueKey('vente-category-$category'),
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _selectedCategory = category),
                  backgroundColor: Colors.white,
                  selectedColor: _VentePalette.actionBlue,
                  showCheckmark: false,
                  side: BorderSide(
                    color: isSelected
                        ? _VentePalette.actionBlue
                        : _VentePalette.hairline,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : _VentePalette.secondaryInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  shape: const StadiumBorder(),
                );
              },
            ),
          ),
          Expanded(child: _buildProductContent()),
        ],
      ),
    );
  }

  Widget _buildProductContent() {
    if (_apiProducts.isEmpty && _isLoadingProducts) {
      return const Center(
        child: CircularProgressIndicator(color: _VentePalette.actionBlue),
      );
    }

    if (_apiProducts.isEmpty && _productsError != null) {
      return _buildLoadError();
    }

    if (_apiProducts.isEmpty) {
      return _buildEmptyState(isSearchResult: false);
    }

    final products = _filteredProducts;
    if (products.isEmpty) {
      return _buildEmptyState(isSearchResult: true);
    }

    return Column(
      children: [
        if (_isLoadingProducts)
          const LinearProgressIndicator(
            minHeight: 2,
            color: _VentePalette.actionBlue,
            backgroundColor: _VentePalette.canvas,
          ),
        if (_productsError != null) _buildInlineLoadError(),
        Expanded(
          child: ListView.separated(
            key: const ValueKey('vente-products-list'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildProductCard(products[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: _VentePalette.mutedInk,
            ),
            const SizedBox(height: 14),
            const Text(
              'Impossible de charger les appareils.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _VentePalette.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Vérifiez votre connexion puis réessayez.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _VentePalette.secondaryInk, fontSize: 14),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loadProductsFromAPI,
              style: FilledButton.styleFrom(
                backgroundColor: _VentePalette.actionBlue,
                minimumSize: const Size(144, 44),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineLoadError() {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Actualisation impossible. Les appareils affichés sont conservés.',
                style: TextStyle(
                  color: _VentePalette.secondaryInk,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: _loadProductsFromAPI,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool isSearchResult}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearchResult ? Icons.search_off : Icons.inventory_2_outlined,
              size: 40,
              color: _VentePalette.mutedInk,
            ),
            const SizedBox(height: 14),
            Text(
              isSearchResult
                  ? 'Aucun appareil trouvé'
                  : 'Aucun appareil à vendre',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _VentePalette.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSearchResult
                  ? 'Essayez un autre nom ou effacez les filtres.'
                  : 'Le catalogue ne contient aucun appareil pour le moment.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _VentePalette.secondaryInk,
                fontSize: 14,
              ),
            ),
            if (isSearchResult) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'Tous';
                  });
                },
                child: const Text('Effacer les filtres'),
              ),
            ],
          ],
        ),
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
          content: const Text(
            'Veuillez vous connecter pour acheter un appareil.',
          ),
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.schedule, color: _VentePalette.actionBlue, size: 22),
            SizedBox(width: 8),
            Expanded(child: Text('Demande en attente')),
          ],
        ),
        content: Text(
          'Une demande pour ${product.name} est déjà en cours de validation. '
          'Vous pourrez en envoyer une nouvelle après son traitement.',
          style: const TextStyle(
            color: _VentePalette.secondaryInk,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: _VentePalette.actionBlue,
            ),
            child: const Text('J’ai compris'),
          ),
        ],
      ),
    );
  }

  /// Confirmation avant envoi d'une demande d'achat à l'unité.
  void _showAchatDialog(Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? 'Client connecté';
    final userEmail = prefs.getString('userEmail') ?? 'client@exemple.com';
    final userPhone = prefs.getString('userPhone') ?? '+228 00 00 00 00';

    if (!mounted) return;

    var isSubmitting = false;
    String? submissionError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Confirmer la demande',
            style: TextStyle(
              color: _VentePalette.ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(Icons.inventory_2_outlined, 'Appareil', product.name),
              const SizedBox(height: 10),
              _infoRow(
                Icons.payments_outlined,
                'Prix',
                '${_formatFcfa(product.price)} FCFA',
              ),
              const SizedBox(height: 10),
              _infoRow(Icons.numbers, 'Quantité', '1'),
              const Divider(height: 24, color: _VentePalette.softDivider),
              const Text(
                'Cette demande sera soumise à validation. Aucun paiement n’est effectué ici.',
                style: TextStyle(
                  color: _VentePalette.secondaryInk,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (submissionError != null) ...[
                const SizedBox(height: 12),
                Text(
                  submissionError!,
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              key: const ValueKey('vente-submit-request'),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() {
                        isSubmitting = true;
                        submissionError = null;
                      });

                      try {
                        await (widget.createPurchaseRequest?.call(
                              product.id,
                              1,
                            ) ??
                            ApiService.createDemandeAchat(product.id, 1));
                      } catch (_) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          isSubmitting = false;
                          submissionError =
                              'La demande n’a pas pu être envoyée. Réessayez.';
                        });
                        return;
                      }

                      _dataManager.addDemandeAchat(
                        clientNom: userName,
                        clientEmail: userEmail,
                        clientPhone: userPhone,
                        produitId: product.produitId,
                        produitNom: product.name,
                        produitPrix: product.price,
                        quantite: 1,
                      );

                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                      if (!mounted) return;

                      await _refreshPendingDemandes();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Demande envoyée pour ${product.name}. '
                            'En attente de validation.',
                          ),
                          backgroundColor: _VentePalette.ink,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: _VentePalette.actionBlue,
                minimumSize: const Size(164, 44),
              ),
              child: isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Envoyer la demande'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 17, color: _VentePalette.mutedInk),
        const SizedBox(width: 8),
        Text(
          '$label : ',
          style: const TextStyle(color: _VentePalette.mutedInk, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _VentePalette.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ── Carte produit ─────────────────────────────────────────────────────────

  Widget _buildProductCard(Product product) {
    final isPending = _hasPendingDemande(product);

    return Container(
      key: ValueKey('vente-product-${product.id}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _VentePalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _VentePalette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProductPhoto(product),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _VentePalette.ink,
                          fontSize: 20,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildAvailability(product, isPending),
                  ],
                ),
                if (product.category.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _VentePalette.canvas,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      product.category,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _VentePalette.secondaryInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Prix de vente',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _VentePalette.secondaryInk,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          text: _formatFcfa(product.price),
                          children: const [
                            TextSpan(
                              text: ' FCFA',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _VentePalette.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 12),
                  child: Divider(height: 1, color: _VentePalette.softDivider),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: _buildAchatButton(product, isPending),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductPhoto(Product product) {
    void showZoom() {
      openImageZoom(
        context,
        imageUrl: product.imageUrl,
        fallbackUrl: AppareilImages.getImageUrlForType(product.category),
        title: product.name,
      );
    }

    return AspectRatio(
      key: ValueKey('vente-product-photo-${product.id}'),
      aspectRatio: 1.93,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            button: true,
            label: 'Agrandir la photo de ${product.name}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: showZoom,
              child: Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                semanticLabel: product.name,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: _VentePalette.canvas,
                    alignment: Alignment.center,
                    child: const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        color: _VentePalette.actionBlue,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: _VentePalette.canvas,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 36,
                    color: _VentePalette.mutedInk,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: IconButton(
              key: ValueKey('vente-product-zoom-${product.id}'),
              tooltip: 'Agrandir la photo de ${product.name}',
              onPressed: showZoom,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.94),
                foregroundColor: _VentePalette.ink,
                minimumSize: const Size(40, 40),
                maximumSize: const Size(40, 40),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.zoom_in, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailability(Product product, bool isPending) {
    final label = isPending
        ? 'Demande en attente'
        : product.inStock
        ? 'En stock'
        : 'Rupture de stock';
    final color = isPending
        ? _VentePalette.pending
        : product.inStock
        ? _VentePalette.available
        : _VentePalette.unavailable;

    return Semantics(
      label: 'État du produit : $label',
      child: Container(
        constraints: const BoxConstraints(minHeight: 30, maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _VentePalette.canvas,
          borderRadius: BorderRadius.circular(999),
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _VentePalette.secondaryInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAchatButton(Product product, bool isPending) {
    if (!product.inStock) {
      return ElevatedButton(
        key: ValueKey('vente-request-${product.id}'),
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _VentePalette.actionBlue,
          disabledBackgroundColor: _VentePalette.disabled,
          foregroundColor: Colors.white,
          disabledForegroundColor: _VentePalette.mutedInk,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: const Text('Rupture de stock'),
      );
    }

    if (isPending) {
      return OutlinedButton(
        key: ValueKey('vente-request-${product.id}'),
        onPressed: () => _showDejaEnAttenteDialog(product),
        style: OutlinedButton.styleFrom(
          foregroundColor: _VentePalette.secondaryInk,
          backgroundColor: _VentePalette.canvas,
          side: const BorderSide(color: _VentePalette.hairline),
          shape: const StadiumBorder(),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: const Text('Demande en attente'),
      );
    }

    return ElevatedButton(
      key: ValueKey('vente-request-${product.id}'),
      onPressed: () => _handleAchat(product),
      style: ElevatedButton.styleFrom(
        backgroundColor: _VentePalette.actionBlue,
        disabledBackgroundColor: _VentePalette.disabled,
        foregroundColor: Colors.white,
        disabledForegroundColor: _VentePalette.mutedInk,
        elevation: 0,
        shape: const StadiumBorder(),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: const Text('Demander l’achat'),
    );
  }
}
