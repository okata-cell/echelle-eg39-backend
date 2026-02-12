
import 'package:echelle_eg_39/login.page.dart';
import 'package:echelle_eg_39/ventes.dart';
import 'package:flutter/material.dart';
import 'location.dart';
import 'LocationsMenu.dart';
import 'admin_ventes_page.dart';  // Import de notre page admin_ventes_page
import 'historique.dart';
import 'service.dart';
import 'profile.dart';

void main() {
  runApp(const EchelleEG39App());
}

class EchelleEG39App extends StatelessWidget {
  const EchelleEG39App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ÉCHELLE EG39',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      ),
      home: const LoginPage(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const LocationScreen(),
    const  VenteScreen(),  // Utilisation de AdminVentesPageFixed qui correspond à admin_ventes_page_fixed.dart
    const HistoriqueScreen(),
    const ProfilScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey[600],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_city,
            color: Color(0xFF00897B),
            ),
            label: 'Location',
            
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart,
            color: Color(0xFF5D4037),
            
            ),
            label: 'Vente',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history,
            color: Color(0xFF6B7280),
            ),
            label: 'Historique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person,
            color: Color(0xFF1E88E5),
            ),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ÉCHELLE EG39',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text(
                              'La qualité dans nos prestations',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFFBFDBFE),
                              ),
                            ),
                            const SizedBox(width: 99),
                            
                          ],
                        ),
                      ],
                    ),
                    
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -16),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      _buildQuickAction(
                        context,
                        'Location',
                        Icons.location_city,
                        const Color(0xFFDBEAFE),
                        const Color(0xFF2563EB),
                        1,
                      ),
                      _buildQuickAction(
                        context,
                        'Vente',
                        Icons.shopping_cart,
                        const Color(0xFFD1FAE5),
                        const Color(0xFF059669),
                        2,
                      ),
                      _buildQuickAction(
                        context,
                        'Historique',
                        Icons.history,
                        const Color(0xFFFEF3C7),
                        const Color(0xFFD97706),
                        3,
                      ),
                      _buildQuickAction(
                        context,
                        'Services',
                        Icons.gps_fixed,
                        const Color(0xFFE9D5FF),
                        const Color(0xFF9333EA),
                        4,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Équipements populaires',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeaturedItem(
                      'Station totale',
                      'Équipement d\'implantation précis',
                      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR8JvlLA3YuTxkT52NdUxC6CBABtE7oL6EFjg&s',
                    ),
                    const SizedBox(height: 12),
                    _buildFeaturedItem(
                      'GPS e-survey',
                      'Technologie GPS avancée',
                      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSn350sHEU6Pt758jxJW724wQBQ-s0b_5GYSw&s',
                    ),
                    const SizedBox(height: 12),
                    _buildFeaturedItem(
                      'Niveaux optiques',
                      'Nivellement de précision',
                      'https://greta-cfa-aquitaine.fr/uploads/topographie.png',
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.location_on, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Besoin d\'aide ?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Contactez-nous pour vos besoins en topographie',
                            style: TextStyle(
                              color: Color(0xFFBFDBFE),
                              fontSize: 12,
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
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String title,
    IconData icon,
    Color backgroundColor,
    Color iconColor,
    int? index,
  ) {
    return GestureDetector(
      onTap: () {

        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) =>  LocationScreen()),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VenteScreen ()),
          );
        } else if (index == 3) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HistoriqueScreen()),
          );
        } else if (index == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ServiceScreen()),
          );
        }
        // Add more navigation logic for other indices if needed
      },
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: iconColor,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedItem(String title, String subtitle, String imageUrl) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Image.network(
              imageUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.image,
                  size: 48,
                  color: Colors.grey,
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}








