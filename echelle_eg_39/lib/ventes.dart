import 'package:flutter/material.dart';
import 'data_manager.dart';
import 'api_service.dart';
import 'login.page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Product {
  final int id;
  final String name;
  final String category;
  final int price;
  final bool inStock;
  final String imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.inStock,
    required this.imageUrl,
  });
}

class VenteScreen extends StatefulWidget {
  const VenteScreen({Key? key}) : super(key: key);

  @override
  State<VenteScreen> createState() => _VenteScreenState();
}

class _VenteScreenState extends State<VenteScreen> {
  final _dataManager = DataManager();

  String _searchQuery = '';
  String _selectedCategory = 'Tous';

  final List<String> _categories = ['Tous', 'GPS', 'Station totale', 'Niveau', 'Mire', 'Drone', 'Laser', 'Réflecteur'];

  List<Product> get _products => _dataManager.appareils.map((a) => Product(
    id: int.parse(a.id.substring(4)),
    name: a.nom,
    category: a.type,
    price: a.prixVente,
    inStock: a.disponible,
    imageUrl: a.imageUrl,
  )).toList();

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

  List<Product> get _filteredProducts {
    return _products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Tous' || product.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Vente d\'appareils',
          style: TextStyle(color: Color(0xFF111827)),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Rechercher un appareil...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
                    ),
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
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          backgroundColor: const Color(0xFFF3F4F6),
                          selectedColor: const Color(0xFF059669),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF374151),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
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

  // Gérer l'achat d'un produit
  void _handleAchat(Product product) async {
    // Vérifier si l'utilisateur est connecté
    final token = await ApiService.getToken();
    if (token == null) {
      // Afficher un dialogue pour se connecter
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Connexion requise'),
          content: const Text('Veuillez vous connecter pour acheter un appareil.'),
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

    // Si connecté, afficher la boîte de dialogue d'achat
    _showAchatDialog(product);
  }

  // Boîte de dialogue pour confirmer l'achat
  void _showAchatDialog(Product product) async {
    // Récupérer les infos utilisateur depuis SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? 'Client connecté';
    final userEmail = prefs.getString('userEmail') ?? 'client@exemple.com';
    final userPhone = prefs.getString('userPhone') ?? '+228 00 00 00 00';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Acheter ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Produit: ${product.name}'),
              const SizedBox(height: 8),
              Text('Prix: ${product.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')}FCFA'),
              const SizedBox(height: 8),
              Text('Statut: ${product.inStock ? "En stock" : "Rupture de stock"}'),
              const SizedBox(height: 16),
              const Text(
                'Voulez-vous confirmer cette demande d\'achat ?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                // Enregistrer la demande d'achat avec les infos utilisateur
                _dataManager.addDemandeAchat(
                  clientNom: userName,
                  clientEmail: userEmail,
                  clientPhone: userPhone,
                  produitId: 'APP-${product.id.toString().padLeft(3, '0')}',
                  produitNom: product.name,
                  produitPrix: product.price,
                  quantite: 1,
                );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Demande d\'achat envoyée pour ${product.name}'),
                    backgroundColor: const Color(0xFF059669),
                    duration: const Duration(seconds: 3),
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

  Widget _buildProductCard(Product product) {
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

          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.image, size: 40, color: Colors.grey),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  product.category,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} FCFA',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: product.inStock ? () => _handleAchat(product) : null,
                    icon: const Icon(Icons.shopping_cart, size: 10),
                    label: Text(
                      product.inStock ? 'Acheter' : 'Rupture',
                      style: const TextStyle(fontSize: 9),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      disabledBackgroundColor: const Color(0xFFD1D5DB),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      minimumSize: const Size(double.infinity, 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

  
