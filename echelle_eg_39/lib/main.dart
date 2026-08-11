
import 'package:echelle_eg_39/login.page.dart';
import 'package:echelle_eg_39/ventes.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'location.dart';
import 'historique.dart';
import 'service.dart';
import 'profile.dart';
import 'home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AdminDashBoard.dart';
import 'sync_service.dart';
import 'api_service.dart';

// Variable globale pour suivre l'état de Firebase
bool isFirebaseReady = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Firebase avec timeout
  try {
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        print('⚠️ Firebase initialization timed out');
        throw Exception('Firebase timeout');
      },
    );
    isFirebaseReady = true;
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    isFirebaseReady = false;
    // Continuer quand même si Firebase échoue (mode offline)
  }
  
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
      home: const SplashScreen(),
    );
  }
}

// Écran de démarrage qui vérifie la session utilisateur
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Lancer la vérification de session mais sans bloquer l'affichage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
    });
  }

  // 🔄 Méthode de synchronisation au démarrage (en arrière-plan)
  Future<void> _attemptStartupSync() async {
    try {
      // Vérifier si l'API est disponible avec un timeout court
      final apiAvailable = await SyncService.isApiAvailable().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('⚠️ API check timed out');
          return false;
        },
      );
      
      if (apiAvailable) {
        print('🔄 API disponible au démarrage, vérification synchronisation...');
        
        // Synchroniser les utilisateurs en attente (avec timeout)
        await SyncService.syncPendingUsers().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('⚠️ syncPendingUsers timed out');
            return SyncResult(success: false, syncedCount: 0, message: 'Timeout');
          },
        );
        
        // Synchroniser les utilisateurs locaux (avec timeout)
        await SyncService.syncLocalUsers().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('⚠️ syncLocalUsers timed out');
            return SyncResult(success: false, syncedCount: 0, message: 'Timeout');
          },
        );
        
        print('✅ Synchronisation au démarrage terminée');
      } else {
        print('⚠️ API non disponible au démarrage, synchronisation reportée');
      }
    } catch (e) {
      print('❌ Erreur synchronisation au démarrage: $e');
      // Ne pas bloquer - continuer même en cas d'erreur
    }
  }

  Future<void> _checkSession() async {
    // Lancer la synchronisation en arrière-plan (ne pas attendre)
    _attemptStartupSync();
    
    final prefs = await SharedPreferences.getInstance();
    
    // === CORRECTION: Vérifier d'abord si Firebase Auth a un utilisateur connecté ===
    // Cela permet de restaurer la session même après fermeture de l'app
    // Vérifier que Firebase est prêt avant d'utiliser FirebaseAuth
    if (isFirebaseReady) {
      try {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          // Utilisateur Firebase connecté - restaurer la session
          print('✅ Firebase session found: ${firebaseUser.email}');
          
          String identifier = firebaseUser.email ?? firebaseUser.phoneNumber ?? '';
          String password = prefs.getString('userPassword') ?? '';
          bool isAdmin = prefs.getBool('isAdmin') ?? false;
          
          // Sauvegarder pour restauration permanente (identifiant uniquement, pas le mot de passe)
          if (prefs.getString('saved_identifier') == null) {
            await prefs.setString('saved_identifier', identifier);
            await prefs.setBool('saved_isAdmin', isAdmin);
          }
          
          await prefs.setBool('isLoggedIn', true);
          await prefs.setBool('isAdmin', isAdmin);
          await prefs.setString('userIdentifier', identifier);
          await prefs.setString('userEmail', identifier);
          
          if (!mounted) return;
          
          // Naviguer vers l'écran principal
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => isAdmin ? const AdminDashBoard() : const MainScreen(),
            ),
          );
          return;
        }
      } catch (e) {
        print('⚠️ Error checking Firebase session: $e');
      }
    } else {
      print('⚠️ Firebase not initialized, skipping Firebase session check');
    }
    // === FIN CORRECTION ===
    
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    bool isAdmin = prefs.getBool('isAdmin') ?? false;

    // Vérifier la présence d'un token JWT valide (on ne stocke plus le mot de passe en local)
    final token = await ApiService.getToken();

    // Attendre un peu pour l'effet visuel minimum
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    if (token != null && isLoggedIn) {
      // Token présent → restaurer la session automatiquement
      print('✅ Session restaurée via token JWT');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isAdmin ? const AdminDashBoard() : const MainScreen(),
        ),
      );
    } else {
      // Pas de token (ou expiré) → reconnexion manuelle requise
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.height,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 20),
              Text(
                'ÉCHELLE EG39',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Topographie - BTP',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFFBFDBFE),
                ),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
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
    const ModernHomePage(),
    const LocationScreen(),
    const VenteScreen(),
    const ServiceScreen(),
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
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: const Color(0xFF9CA3AF),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_city_outlined),
            activeIcon: Icon(Icons.location_city),
            label: 'Locations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Ventes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.engineering_outlined),
            activeIcon: Icon(Icons.engineering),
            label: 'Services',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Historique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outlined),
            activeIcon: Icon(Icons.person),
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







