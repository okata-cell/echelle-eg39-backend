import 'package:flutter/material.dart';
import 'data_manager.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.page.dart';

class Equipment {
  final int id;
  final String name;
  final String category;
  final int price;
  final bool available;
  final String imageUrl;

  Equipment({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.available,
    required this.imageUrl,
  });
}

class LocationScreen extends StatefulWidget {
  const LocationScreen({Key? key}) : super(key: key);

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _dataManager = DataManager();

  String _searchQuery = '';
  String _selectedCategory = 'Tous';

  final List<String> _categories = ['Tous', 'GPS', 'Station totale', 'Niveau', 'Mire', 'Trepied' , 'Drone', 'Laser', 'Réflecteur'];

  List<Equipment> get _equipments => _dataManager.appareils.map((a) => Equipment(
    id: int.parse(a.id.substring(4)),
    name: a.nom,
    category: a.type,
    price: a.prixLocation,
    available: a.disponible,
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

  List<Equipment> get _filteredEquipments {
    return _equipments.where((eq) {
      final matchesSearch = eq.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Tous' || eq.category == _selectedCategory;
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
          'Location d\'appareils',
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
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
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
                          selectedColor: const Color(0xFF2563EB),
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredEquipments.length,
              itemBuilder: (context, index) {
                final equipment = _filteredEquipments[index];
                return _buildEquipmentCard(equipment);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentCard(Equipment equipment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          Container(
            width: 128,
            height: 128,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Image.network(
                equipment.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 40, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    equipment.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    equipment.category,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${equipment.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} FCFA/jour',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: equipment.available
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          equipment.available ? 'Disponible' : 'Indisponible',
                          style: TextStyle(
                            fontSize: 12,
                            color: equipment.available
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: equipment.available ? () => _showReservationDialog(equipment) : null,
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: const Text('Réserver', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 209, 216, 231),
                          disabledBackgroundColor: const Color(0xFFD1D5DB),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReservationDialog(Equipment equipment) async {
    // Check if user is authenticated
    final token = await ApiService.getToken();
    if (token == null) {
      // Show dialog to login
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Connexion requise'),
          content: const Text('Veuillez vous connecter pour réserver un appareil.'),
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

    // Get user info
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('userName') ?? 'Client connecté';
    final userEmail = prefs.getString('userEmail') ?? 'client@exemple.com';
    final userPhone = prefs.getString('userPhone') ?? '+228 00 00 00 00';

    DateTime? selectedStartDate;
    DateTime? selectedEndDate;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Réserver ${equipment.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(selectedStartDate == null
                        ? 'Sélectionner date de début'
                        : 'Date de début: ${selectedStartDate!.toLocal().toString().split(' ')[0]}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedStartDate = picked;
                          if (selectedEndDate != null && selectedEndDate!.isBefore(picked)) {
                            selectedEndDate = picked.add(const Duration(days: 1));
                          }
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: Text(selectedEndDate == null
                        ? 'Sélectionner date de fin'
                        : 'Date de fin: ${selectedEndDate!.toLocal().toString().split(' ')[0]}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedStartDate ?? DateTime.now(),
                        firstDate: selectedStartDate ?? DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedEndDate = picked;
                        });
                      }
                    },
                  ),
                  if (selectedStartDate != null && selectedEndDate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Durée: ${(selectedEndDate!.difference(selectedStartDate!).inDays + 1)} jour(s)\n'
                        'Total: ${((selectedEndDate!.difference(selectedStartDate!).inDays + 1) * equipment.price).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} FCFA',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: selectedStartDate != null && selectedEndDate != null
                      ? () async {
                          try {
                            final days = selectedEndDate!.difference(selectedStartDate!).inDays + 1;
                            final total = days * equipment.price;
                            
                            // Try API first, fallback to local storage
                            try {
                              await ApiService.createLocationRequest(
                                equipment.id,
                                selectedStartDate!.toIso8601String(),
                                selectedEndDate!.toIso8601String(),
                                days,
                                total,
                              );
                            } catch (apiError) {
                              // If API fails (no backend), save locally
                              print('API non disponible, sauvegarde locale: $apiError');
                              // Store location request locally in SharedPreferences
                              final locationRequests = prefs.getStringList('local_locations') ?? [];
                              locationRequests.add(
                                '${equipment.id}|${equipment.name}|${selectedStartDate!.toIso8601String()}|${selectedEndDate!.toIso8601String()}|${days}|${total}|${userName}|${userEmail}|${userPhone}'
                              );
                              await prefs.setStringList('local_locations', locationRequests);
                            }
                            
                            if (!mounted) return;
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${equipment.name} réservé avec succès!'),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                            // Refresh the data
                            _dataManager.initialize();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      : null,
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
