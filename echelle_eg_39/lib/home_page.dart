// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';
import 'appareil_images.dart';
import 'service.dart';
import 'location.dart';
import 'profile.dart';
import 'promotion_popup.dart';
import 'offline_registration_banner.dart';
import 'actualite.dart';
import 'actualites_repository.dart';
import 'actualites_screen.dart';
import 'widgets/actualites_section.dart';

class ModernHomePage extends StatefulWidget {
  const ModernHomePage({super.key});

  @override
  State<ModernHomePage> createState() => _ModernHomePageState();
}

class _ModernHomePageState extends State<ModernHomePage> {
  List<Map<String, dynamic>> _appareils = [];
  bool _isLoadingAppareils = true;
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentCarouselIndex = 0;
  Timer? _carouselTimer;

  // Actualités publiées par l'administrateur : cache local puis réseau.
  final ActualitesRepository _actualitesRepository = ActualitesRepository();
  List<Actualite> _actualites = const <Actualite>[];
  bool _isLoadingActualites = true;

  @override
  void initState() {
    super.initState();
    _loadAppareils();
    _loadActualites();
    _startCarouselAutoScroll();
    // Vérifier et afficher la promotion après un court délai
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) PromotionPopup.checkAndShowPromotion(context);
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startCarouselAutoScroll() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_appareils.isEmpty) return;
      final nextPage = (_currentCarouselIndex + 1) % _appareils.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadAppareils() async {
    setState(() => _isLoadingAppareils = true);
    try {
      final appareils = await ApiService.getAppareils();
      if (mounted) {
        setState(() {
          _appareils = appareils.take(8).toList();
          _isLoadingAppareils = false;
        });
      }
    } catch (e) {
      print('⚠️ Failed to load appareils: $e');
      if (mounted) {
        setState(() => _isLoadingAppareils = false);
      }
    }
  }

  Future<void> _loadActualites({bool force = false}) async {
    // Le cache s'affiche d'abord : la section ne clignote pas au lancement.
    if (!force && _actualites.isEmpty) {
      final cached = await _actualitesRepository.readCache(
        limit: ActualitesRepository.homeLimit,
      );
      if (cached.items.isNotEmpty && mounted) {
        setState(() {
          _actualites = cached.items;
          _isLoadingActualites = false;
        });
      }
    }

    try {
      final snapshot = await _actualitesRepository.refresh(
        limit: ActualitesRepository.homeLimit,
      );
      if (!mounted) return;
      setState(() {
        _actualites = snapshot.items;
        _isLoadingActualites = false;
      });
    } catch (error) {
      // Sans contenu en cache, la section disparaît de l'accueil : un bloc
      // d'erreur permanent n'apporte rien au client.
      debugPrint('Actualités indisponibles : $error');
      if (!mounted) return;
      setState(() => _isLoadingActualites = false);
    }
  }

  /// Le tirer-pour-rafraîchir recharge les appareils et les actualités.
  Future<void> _refreshHome() async {
    await Future.wait([_loadAppareils(), _loadActualites(force: true)]);
  }

  void _openActualites() {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ActualitesScreen(initialItems: _actualites),
          ),
        )
        .then((_) => _loadActualites(force: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshHome,
          child: CustomScrollView(
            slivers: [
              // ── Header avec gradient ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ÉCHELLE EG39',
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'La qualité dans nos prestations',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFBFDBFE),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProfilScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Barre de recherche rapide
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LocationScreen(),
                              ),
                            );
                          },
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: 'Rechercher un équipement...',
                            hintStyle: GoogleFonts.poppins(
                              color: const Color(0xFF9CA3AF),
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xFF2563EB),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Inscription hors ligne en attente de synchronisation ─────
              const SliverToBoxAdapter(child: OfflineRegistrationBanner()),

              // ── Section: Nos appareils disponibles ───────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Nos appareils disponibles',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LocationScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Voir tout'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Carrousel d'appareils ───────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 320,
                  child: _isLoadingAppareils
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2563EB),
                          ),
                        )
                      : _appareils.isEmpty
                      ? _buildEmptyAppareils()
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: _appareils.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentCarouselIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final appareil = _appareils[index];
                            return _buildAppareilCard(appareil, index);
                          },
                        ),
                ),
              ),

              // ── Indicateurs de page ─────────────────────────────────────
              if (_appareils.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _appareils.length > 5 ? 5 : _appareils.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentCarouselIndex == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentCarouselIndex == index
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Section: Nos services topographiques ────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Nos services topographiques',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ServiceScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Voir tout'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 40),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Carrousel de services ───────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 280,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.85),
                    itemCount: _allServices.length,
                    itemBuilder: (context, index) {
                      final service = _allServices[index];
                      return _buildServiceCard(service);
                    },
                  ),
                ),
              ),

              // ── Section: Dernières actualités (rédigées par l'admin) ────
              SliverToBoxAdapter(
                child: ActualitesSection(
                  items: _actualites,
                  isLoading: _isLoadingActualites,
                  onSeeAll: _openActualites,
                ),
              ),

              // ── Espacement final ────────────────────────────────────────
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyAppareils() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun appareil disponible',
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

  Widget _buildAppareilCard(Map<String, dynamic> appareil, int index) {
    final nom = appareil['nom'] as String? ?? 'Appareil';
    final type = appareil['type'] as String? ?? 'Équipement';
    final prixLocation = appareil['prixLocation'] as int? ?? 0;
    final prixVente = appareil['prixVente'] as int? ?? 0;
    final imageUrl = appareil['imageUrl'] as String? ??
        AppareilImages.getImageUrlForType(type.toLowerCase());

    return Container(
      margin: EdgeInsets.only(
        left: index == 0 ? 20 : 8,
        right: index == _appareils.length - 1 ? 20 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image de l'appareil
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2563EB),
                          strokeWidth: 2,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        color: const Color(0xFFF3F4F6),
                        child: Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                      );
                    },
                  ),
                ),
                // Badge de catégorie
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      type,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Informations
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nom,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _getRoleDescription(type),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location / jour',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                          Text(
                            '${prixLocation.toString()} FCFA',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: const Color(0xFFE5E7EB),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Vente',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                          Text(
                            '${prixVente.toString()} FCFA',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleDescription(String type) {
    switch (type.toLowerCase()) {
      case 'gps':
        return 'Positionnement et levés de précision';
      case 'station totale':
        return 'Mesures d\'implantation et de bornage';
      case 'niveau':
        return 'Nivellement et contrôle d\'altitude';
      case 'théodolite':
        return 'Relevés angulaires de haute précision';
      case 'drone':
        return 'Cartographie aérienne et modélisation 3D';
      case 'mire':
        return 'Cibles de mesure pour stations totales';
      case 'trepied':
        return 'Support stable pour instruments';
      case 'canne':
        return 'Support portable pour antenne GPS';
      case 'antenne':
        return 'Réception satellite RTK';
      case 'reflecteur':
        return 'Cible de mesure sans prisme';
      case 'scanner 3d':
        return 'Acquisition 3D et nuages de points';
      default:
        return 'Équipement topographique professionnel';
    }
  }

  Widget _buildServiceCard(Service service) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image du service
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Image.network(
                service.imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2563EB),
                      strokeWidth: 2,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    color: const Color(0xFFF3F4F6),
                    child: Icon(
                      Icons.landscape,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            ),
          ),
          // Informations
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    service.category,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  service.name,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  service.description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF6B7280),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Reuse the catalog shown on the full services page so image URLs stay in sync.
  List<Service> get _allServices => ServiceScreen.catalog;
}
