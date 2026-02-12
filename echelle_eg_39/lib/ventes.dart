import 'package:flutter/material.dart';
import 'data_manager.dart';

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

  final List<String> _categories = ['Tous', 'GPS', 'Station totale', 'Niveau'];

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
                    hintText: 'Rechercher un produit...',
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
  void _handleAchat(Product product) {
    // Informations client fictives (à remplacer par les vraies infos du client connecté)
    // Dans une vraie application, vous récupéreriez ces infos depuis le profil de l'utilisateur
    const String clientNom = 'Utilisateur';
    const String clientEmail = 'user@exemple.com';
    const String clientPhone = '+228 90 01 43 29';

    // Enregistrer la demande d'achat
    final demandeId = _dataManager.addDemandeAchat(
      clientNom: clientNom,
      clientEmail: clientEmail,
      clientPhone: clientPhone,
      produitId: 'APP-${product.id.toString().padLeft(3, '0')}',
      produitNom: product.name,
      produitPrix: product.price,
      quantite: 1,
    );

    // Afficher une confirmation au client
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Demande d\'achat envoyée pour ${product.name}'),
        backgroundColor: const Color(0xFF059669),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
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

  
