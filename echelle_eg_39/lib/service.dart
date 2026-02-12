import 'package:flutter/material.dart';

class Service {
  final String id;
  final String name;
  final String description;
  final String category;
  final String imageUrl;
  final List<String> features;

  const Service({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.imageUrl,
    required this.features,
  });
}

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({Key? key}) : super(key: key);

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  String _selectedCategory = 'Tous';
  String _searchQuery = '';

  final List<String> _categories = [
    'Tous',
    'Levés topographiques',
    'Travaux cadastraux',
    'Implantation',
    'Nivellement',
    'Cartographie et plans',
    'Cubature et métrés',
    'Géoréférencement GPS',
    'Modélisation 3D',
    'Photogrammétrie et drone',
    'Services spécialisés',
    'Services complémentaires',
  ];

  final List<Service> _allServices = [
    // Levés topographiques
    Service(
      id: '1',
      name: 'Levée de détail',
      description: 'Relevé précis des éléments du terrain avec coordonnées X, Y. Connaissance précise du relief et des limites.',
      category: 'Levés topographiques',
      imageUrl: 'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400',
      features: ['Précision centimétrique', 'Données 3D', 'Format DWG/PDF', 'Rapport détaillé'],
    ),
    Service(
      id: '2',
      name: 'Levée altimétrique',
      description: 'Mesure précise des altitudes et création de courbes de niveau',
      category: 'Levés topographiques',
      imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
      features: ['Courbes de niveau', 'Modèle numérique', 'Équipement GPS RTK', 'Analyse terrain'],
    ),
    Service(
      id: '3',
      name: 'Levé architectural',
      description: 'Relevé détaillé de bâtiments existants pour rénovation, extension, régularisation',
      category: 'Levés topographiques',
      imageUrl: 'https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=400',
      features: ['Plans détaillés', 'Cotes précises', 'État des lieux', 'Plans de rénovation'],
    ),

    // Travaux cadastraux
    Service(
      id: '4',
      name: 'Bornage de terrain',
      description: 'Matérialisation des limites de propriété par des bornes. Délimiter officiellement sa parcelle.',
      category: 'Travaux cadastraux',
      imageUrl: 'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=400',
      features: ['Bornes officielles', 'Documents légaux', 'Plan cadastral', 'Certificat de bornage'],
    ),
    Service(
      id: '5',
      name: 'Plan cadastral',
      description: 'Document officiel représentant la parcelle. Essentiel pour achat/vente, permis de construire.',
      category: 'Travaux cadastraux',
      imageUrl: 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=400',
      features: ['Conformité légale', 'Données numériques', 'Archivage sécurisé', 'Plan officiel'],
    ),
    Service(
      id: '6',
      name: 'Morcellement/Division',
      description: 'Division d\'un terrain en plusieurs parcelles. Utile pour succession, vente partielle, lotissement.',
      category: 'Travaux cadastraux',
      imageUrl: 'https://images.unsplash.com/photo-1487958449943-2429e8be8625?w=400',
      features: ['Division légale', 'Nouveaux titres', 'Plans détaillés', 'Documents administratifs'],
    ),
    Service(
      id: '7',
      name: 'Remembrement',
      description: 'Regroupement de plusieurs parcelles en une seule. Optimisation foncière, projets agricoles.',
      category: 'Travaux cadastraux',
      imageUrl: 'https://images.unsplash.com/photo-1500382017468-9049fed747ef?w=400',
      features: ['Regroupement optimal', 'Nouveau cadastre', 'Économie foncière', 'Simplification administrative'],
    ),
    Service(
      id: '8',
      name: 'Régularisation foncière',
      description: 'Mise en conformité avec le cadastre. Obtenir un titre de propriété légal.',
      category: 'Travaux cadastraux',
      imageUrl: 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=400',
      features: ['Titre légal', 'Conformité', 'Documents officiels', 'Sécurisation foncière'],
    ),

    // Implantation
    Service(
      id: '9',
      name: 'Implantation de bâtiment',
      description: 'Positionnement exact des axes et angles du bâtiment. Démarrer la construction conformément aux plans.',
      category: 'Implantation',
      imageUrl: 'https://images.unsplash.com/photo-1503387837-b154d5074bd2?w=400',
      features: ['Repères permanents', 'Niveaux précis', 'Plans d\'exécution', 'Contrôle qualité'],
    ),
    Service(
      id: '10',
      name: 'Implantation de voirie',
      description: 'Traçage des axes de routes, rues, ronds-points. Construction de routes, lotissements.',
      category: 'Implantation',
      imageUrl: 'https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=400',
      features: ['Axes routiers', 'Réseaux enterrés', 'Repères temporaires', 'Coordonnées précises'],
    ),
    Service(
      id: '11',
      name: 'Implantation de réseaux',
      description: 'Positionnement de canalisations (eau, électricité, assainissement). Installation d\'infrastructures souterraines.',
      category: 'Implantation',
      imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=400',
      features: ['Canalisations', 'Réseaux souterrains', 'Coordonnées GPS', 'Plans techniques'],
    ),
    Service(
      id: '12',
      name: 'Piquetage',
      description: 'Matérialisation de points sur le terrain avec piquets. Repérage visuel pour les travaux.',
      category: 'Implantation',
      imageUrl: 'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400',
      features: ['Repères visuels', 'Points de référence', 'Matérialisation terrain', 'Coordonnées précises'],
    ),

    // Nivellement
    Service(
      id: '13',
      name: 'Nivellement de précision',
      description: 'Mesures altimétriques avec précision millimétrique. Infrastructures sensibles, barrages, ponts.',
      category: 'Nivellement',
      imageUrl: 'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400',
      features: ['Précision 0.1mm', 'Références IGN', 'Étalonnage', 'Rapport d\'erreurs'],
    ),
    Service(
      id: '14',
      name: 'Nivellement de chantier',
      description: 'Contrôle des niveaux pendant les travaux. S\'assurer du respect des cotes de construction.',
      category: 'Nivellement',
      imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400',
      features: ['Contrôle qualité', 'Cotes précises', 'Suivi travaux', 'Rapports réguliers'],
    ),
    Service(
      id: '15',
      name: 'Profils en long et en travers',
      description: 'Coupes altimétriques du terrain. Routes, canalisations, terrassement.',
      category: 'Nivellement',
      imageUrl: 'https://images.unsplash.com/photo-1584464491033-06628f3a6b7b?w=400',
      features: ['Profils détaillés', 'Coupes terrain', 'Données 3D', 'Plans d\'exécution'],
    ),

    // Cartographie et plans
    Service(
      id: '16',
      name: 'Plan de masse',
      description: 'Plan d\'ensemble du projet avec environnement. Permis de construire, dossier administratif.',
      category: 'Cartographie et plans',
      imageUrl: 'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=400',
      features: ['Plan d\'ensemble', 'Environnement', 'Documents administratifs', 'Visuels clairs'],
    ),
    Service(
      id: '17',
      name: 'Plan de situation',
      description: 'Localisation du terrain dans son contexte urbain. Dossiers administratifs.',
      category: 'Cartographie et plans',
      imageUrl: 'https://images.unsplash.com/photo-1487958449943-2429e8be8625?w=400',
      features: ['Localisation précise', 'Contexte urbain', 'Documents officiels', 'Plans détaillés'],
    ),
    Service(
      id: '18',
      name: 'Plan topographique',
      description: 'Représentation graphique complète du terrain. Études de projet, conception.',
      category: 'Cartographie et plans',
      imageUrl: 'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400',
      features: ['Représentation complète', 'Données précises', 'Formats multiples', 'Échelles adaptées'],
    ),
    Service(
      id: '19',
      name: 'Cartographie SIG',
      description: 'Cartes numériques avec bases de données. Gestion territoriale, urbanisme.',
      category: 'Cartographie et plans',
      imageUrl: 'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=400',
      features: ['Données numériques', 'SIG intégré', 'Base de données', 'Analyse territoriale'],
    ),
    Service(
      id: '20',
      name: 'Plans de récolement',
      description: 'Plans "tels que construits" après travaux. Documentation finale, archives.',
      category: 'Cartographie et plans',
      imageUrl: 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=400',
      features: ['Plans finaux', 'Documentation', 'Archives', 'Conformité'],
    ),

    // Cubature et métrés
    Service(
      id: '21',
      name: 'Calcul de volumes',
      description: 'Mesure des volumes de terre (déblais/remblais). Terrassement, carrières, remblaiement.',
      category: 'Cubature et métrés',
      imageUrl: 'https://images.unsplash.com/photo-1598300042247-d088f8ab3a91?w=400',
      features: ['Calculs précis', 'Volumes détaillés', 'Optimisation', 'Économie'],
    ),
    Service(
      id: '22',
      name: 'Métrés de chantier',
      description: 'Quantification des travaux réalisés. Facturation, suivi budgétaire.',
      category: 'Cubature et métrés',
      imageUrl: 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=400',
      features: ['Quantification précise', 'Suivi budgétaire', 'Facturation', 'Contrôle qualité'],
    ),
    Service(
      id: '23',
      name: 'Suivi de l\'avancement',
      description: 'Mesures régulières pour contrôle. Paiements progressifs, planning.',
      category: 'Cubature et métrés',
      imageUrl: 'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400',
      features: ['Mesures régulières', 'Contrôle qualité', 'Paiements progressifs', 'Planning'],
    ),

    // Géoréférencement GPS
    Service(
      id: '24',
      name: 'Levé GPS haute précision',
      description: 'Positionnement par satellite (RTK, DGPS). Grandes surfaces, zones difficiles d\'accès.',
      category: 'Géoréférencement GPS',
      imageUrl: 'https://images.unsplash.com/photo-1446776653964-20c1d3a81b06?w=400',
      features: ['Haute précision', 'RTK/DGPS', 'Grandes surfaces', 'Zones difficiles'],
    ),
    Service(
      id: '25',
      name: 'Géoréférencement de bornes',
      description: 'Coordonnées GPS des limites de propriété. Cadastre moderne, base de données.',
      category: 'Géoréférencement GPS',
      imageUrl: 'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=400',
      features: ['Coordonnées GPS', 'Bornes géoréférencées', 'Base de données', 'Cadastre moderne'],
    ),
    Service(
      id: '26',
      name: 'Canevas de points GPS',
      description: 'Réseau de points géoréférencés. Base pour futurs levés, grands projets.',
      category: 'Géoréférencement GPS',
      imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
      features: ['Réseau de points', 'Géoréférencement', 'Base solide', 'Grands projets'],
    ),

    // Modélisation 3D
    Service(
      id: '27',
      name: 'Modèle Numérique de Terrain',
      description: 'Représentation 3D du relief. Études hydrauliques, visualisation.',
      category: 'Modélisation 3D',
      imageUrl: 'https://images.unsplash.com/photo-1618477247222-acbdb0e159b3?w=400',
      features: ['Représentation 3D', 'Relief détaillé', 'Visualisation', 'Analyses hydrauliques'],
    ),
    Service(
      id: '28',
      name: 'Modèle Numérique d\'Élévation',
      description: 'Modèle 3D incluant végétation et bâtiments. Urbanisme, études d\'impact.',
      category: 'Modélisation 3D',
      imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400',
      features: ['Modèle complet', 'Végétation', 'Bâtiments', 'Urbanisme'],
    ),
    Service(
      id: '29',
      name: 'BIM (Building Information Modeling)',
      description: 'Maquette numérique 3D du bâtiment. Gestion de projet, coordination.',
      category: 'Modélisation 3D',
      imageUrl: 'https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=400',
      features: ['Maquette numérique', 'Gestion projet', 'Coordination', 'Modélisation 3D'],
    ),
    Service(
      id: '30',
      name: 'Scan 3D laser',
      description: 'Numérisation 3D ultra-précise. Patrimoine, bâtiments complexes.',
      category: 'Modélisation 3D',
      imageUrl: 'https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=400',
      features: ['Numérisation 3D', 'Ultra-précision', 'Patrimoine', 'Bâtiments complexes'],
    ),

    // Photogrammétrie et drone
    Service(
      id: '31',
      name: 'Levé par drone',
      description: 'Cartographie aérienne par drone. Grandes surfaces, zones inaccessibles.',
      category: 'Photogrammétrie et drone',
      imageUrl: 'https://images.unsplash.com/photo-1473968512647-3e447244af8f?w=400',
      features: ['Cartographie aérienne', 'Drone professionnel', 'Grandes surfaces', 'Zones inaccessibles'],
    ),
    Service(
      id: '32',
      name: 'Orthophotographie',
      description: 'Photo aérienne géoréférencée. Plans précis, suivis de chantier.',
      category: 'Photogrammétrie et drone',
      imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400',
      features: ['Photos géoréférencées', 'Plans précis', 'Suivi chantier', 'Haute résolution'],
    ),
    Service(
      id: '33',
      name: 'Inspection par drone',
      description: 'Surveillance de structures (toits, ponts, lignes électriques). Maintenance, sécurité.',
      category: 'Photogrammétrie et drone',
      imageUrl: 'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400',
      features: ['Inspection aérienne', 'Maintenance', 'Sécurité', 'Structures élevées'],
    ),

    // Services spécialisés
    Service(
      id: '34',
      name: 'Suivi de tassements',
      description: 'Mesures régulières de l\'affaissement de structures. Bâtiments sensibles, barrages.',
      category: 'Services spécialisés',
      imageUrl: 'https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=400',
      features: ['Mesures régulières', 'Affaissement', 'Structures sensibles', 'Rapports détaillés'],
    ),
    Service(
      id: '35',
      name: 'Suivi de déformations',
      description: 'Contrôle de mouvements de structures. Ponts, ouvrages d\'art.',
      category: 'Services spécialisés',
      imageUrl: 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=400',
      features: ['Contrôle mouvements', 'Ouvrages d\'art', 'Mesures précises', 'Sécurité'],
    ),
    Service(
      id: '36',
      name: 'Expertise judiciaire',
      description: 'Constats et mesures pour litiges. Tribunaux, conflits de voisinage.',
      category: 'Services spécialisés',
      imageUrl: 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=400',
      features: ['Expertise judiciaire', 'Constats', 'Mesures légales', 'Rapports officiels'],
    ),
    Service(
      id: '37',
      name: 'Études hydrauliques',
      description: 'Analyse des écoulements, bassins versants. Gestion des eaux, inondations.',
      category: 'Services spécialisés',
      imageUrl: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=400',
      features: ['Analyse écoulements', 'Bassins versants', 'Gestion eaux', 'Prévention inondations'],
    ),
    Service(
      id: '38',
      name: 'Études de tracé routier',
      description: 'Conception optimale de routes. Projets routiers, pistes.',
      category: 'Services spécialisés',
      imageUrl: 'https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=400',
      features: ['Conception routes', 'Tracé optimal', 'Projets routiers', 'Études techniques'],
    ),
    Service(
      id: '39',
      name: 'Délimitation de zones à risque',
      description: 'Cartographie de zones inondables, glissements. Prévention, urbanisme.',
      category: 'Services spécialisés',
      imageUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400',
      features: ['Zones à risque', 'Cartographie', 'Prévention', 'Urbanisme'],
    ),

    // Services complémentaires
    Service(
      id: '40',
      name: 'Formation et conseil',
      description: 'Formation à l\'utilisation d\'appareils topographiques, conseil en géomatique, accompagnement de projets.',
      category: 'Services complémentaires',
      imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      features: ['Formation appareils', 'Conseil géomatique', 'Accompagnement', 'Expertise'],
    ),
    Service(
      id: '41',
      name: 'Location d\'équipements',
      description: 'GPS RTK, stations totales, niveaux automatiques, drones. Équipements professionnels.',
      category: 'Services complémentaires',
      imageUrl: 'https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400',
      features: ['GPS RTK', 'Stations totales', 'Niveaux automatiques', 'Drones'],
    ),
    Service(
      id: '42',
      name: 'Maintenance',
      description: 'Calibration d\'appareils, réparation, mise à jour logiciels. Maintenance professionnelle.',
      category: 'Services complémentaires',
      imageUrl: 'https://images.unsplash.com/photo-1581094794329-c8112a89af12?w=400',
      features: ['Calibration', 'Réparation', 'Mise à jour', 'Maintenance préventive'],
    ),
  ];

  List<Service> get _filteredServices {
    return _allServices.where((service) {
      final matchesCategory = _selectedCategory == 'Tous' || service.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          service.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          service.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          service.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Services Topographiques',
              style: TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Expertise professionnelle pour tous vos projets',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un service...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
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
                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
            ),
          ),

          // Category Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      backgroundColor: const Color(0xFFF3F4F6),
                      selectedColor: const Color(0xFF2563EB),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF374151),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Services Grid
          Expanded(
            child: _filteredServices.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredServices.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildServiceCard(_filteredServices[index]),
                      );
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
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucun service trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier vos critères de recherche',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Service service) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                service.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.image,
                      size: 48,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(service.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    service.category,
                    style: TextStyle(
                      fontSize: 10,
                      color: _getCategoryColor(service.category),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),

                // Description
                Text(
                  service.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Features
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: service.features.take(2).map((feature) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        feature,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showQuoteDialog(service),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Demander un devis',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Levés topographiques':
        return const Color(0xFF2563EB);
      case 'Travaux cadastraux':
        return const Color(0xFF059669);
      case 'Implantation':
        return const Color(0xFF9333EA);
      case 'Nivellement':
        return const Color(0xFFEA580C);
      case 'Cartographie et plans':
        return const Color(0xFF7C3AED);
      case 'Cubature et métrés':
        return const Color(0xFFDC2626);
      case 'Géoréférencement GPS':
        return const Color(0xFF0891B2);
      case 'Modélisation 3D':
        return const Color(0xFF7C2D12);
      case 'Photogrammétrie et drone':
        return const Color(0xFF365314);
      case 'Services spécialisés':
        return const Color(0xFF6B21A8);
      case 'Services complémentaires':
        return const Color(0xFF0D9488);
      default:
        return const Color(0xFF6B7280);
    }
  }

  void _showQuoteDialog(Service service) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(service.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.build,
                      color: _getCategoryColor(service.category),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demande de devis',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Form Fields
              const Text(
                'Description du projet',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Décrivez votre projet en détail...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Informations de contact',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Votre nom complet',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Téléphone',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Demande de devis envoyée avec succès !'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Envoyer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}