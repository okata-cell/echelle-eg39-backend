import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';
import 'client_mes_devis.dart';
import 'login.page.dart';

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
  const ServiceScreen({super.key});

  /// Shared catalog used by the full listing and the home-page carousel.
  static List<Service> get catalog => _ServiceScreenState.catalog;

  /// Resolves a quote's service ID to the exact image used in the catalogue.
  static String? imageUrlForId(Object? serviceId) {
    final id = serviceId?.toString().trim();
    if (id == null || id.isEmpty) return null;

    for (final service in catalog) {
      if (service.id == id) return service.imageUrl;
    }
    return null;
  }

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

  static const List<Service> catalog = [
    // Levés topographiques
    Service(
      id: '1',
      name: 'Levée de détail',
      description:
          'Relevé précis des éléments du terrain avec coordonnées X, Y. Connaissance précise du relief et des limites.',
      category: 'Levés topographiques',
      imageUrl:
          'https://5.imimg.com/data5/SELLER/Default/2023/1/DE/NG/JE/161228699/road-inventory-survey-services-1000x1000.jpg',
      features: [
        'Précision centimétrique',
        'Données 3D',
        'Format DWG/PDF',
        'Rapport détaillé',
      ],
    ),
    Service(
      id: '2',
      name: 'Levée altimétrique',
      description:
          'Mesure précise des altitudes et création de courbes de niveau',
      category: 'Levés topographiques',
      imageUrl:
          'https://img2.oastatic.com/img2/606509008/1080x410r/variant.png',
      features: [
        'Courbes de niveau',
        'Modèle numérique',
        'Équipement GPS RTK',
        'Analyse terrain',
      ],
    ),
    Service(
      id: '3',
      name: 'Levé architectural',
      description:
          'Relevé détaillé de bâtiments existants pour rénovation, extension, régularisation',
      category: 'Levés topographiques',
      imageUrl:
          'https://pro-couvreur.com/wp-content/uploads/2025/03/releve-architectural.jpg',
      features: [
        'Plans détaillés',
        'Cotes précises',
        'État des lieux',
        'Plans de rénovation',
      ],
    ),

    // Travaux cadastraux
    Service(
      id: '4',
      name: 'Bornage de terrain',
      description:
          'Matérialisation des limites de propriété par des bornes. Délimiter officiellement sa parcelle.',
      category: 'Travaux cadastraux',
      imageUrl:
          'https://www.proantic.com/galerie/renaissance-concepts/img/1406468-66f39e5517090.jpg',
      features: [
        'Bornes officielles',
        'Documents légaux',
        'Plan cadastral',
        'Certificat de bornage',
      ],
    ),
    Service(
      id: '5',
      name: 'Plan cadastral',
      description:
          'Document officiel représentant la parcelle. Essentiel pour achat/vente, permis de construire.',
      category: 'Travaux cadastraux',
      imageUrl: 'https://www.archifacile.fr/plan/a7a77c9366afc4a4-750E750.jpg',
      features: [
        'Conformité légale',
        'Données numériques',
        'Archivage sécurisé',
        'Plan officiel',
      ],
    ),
    Service(
      id: '6',
      name: 'Morcellement/Division',
      description:
          'Division d\'un terrain en plusieurs parcelles. Utile pour succession, vente partielle, lotissement.',
      category: 'Travaux cadastraux',
      imageUrl:
          'https://www.hexagon.ma/wp-content/uploads/2022/05/morcellement-partage-maroc.jpg',
      features: [
        'Division légale',
        'Nouveaux titres',
        'Plans détaillés',
        'Documents administratifs',
      ],
    ),
    Service(
      id: '7',
      name: 'Remembrement',
      description:
          'Regroupement de plusieurs parcelles en une seule. Optimisation foncière, projets agricoles.',
      category: 'Travaux cadastraux',
      imageUrl:
          'https://journals.openedition.org/histoiremesure/docannexe/image/3961/img-1.jpg',
      features: [
        'Regroupement optimal',
        'Nouveau cadastre',
        'Économie foncière',
        'Simplification administrative',
      ],
    ),
    Service(
      id: '8',
      name: 'Régularisation foncière',
      description:
          'Mise en conformité avec le cadastre. Obtenir un titre de propriété légal.',
      category: 'Travaux cadastraux',
      imageUrl:
          'https://plus.unsplash.com/premium_photo-1681690860621-57d749a22f34?fm=jpg&q=60&w=3000&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MTN8fGNoYW50aWVyJTIwZGUlMjBjb25zdHJ1Y3Rpb258ZW58MHx8MHx8fDA%3D',
      features: [
        'Titre légal',
        'Conformité',
        'Documents officiels',
        'Sécurisation foncière',
      ],
    ),

    // Implantation
    Service(
      id: '9',
      name: 'Implantation de bâtiment',
      description:
          'Positionnement exact des axes et angles du bâtiment. Démarrer la construction conformément aux plans.',
      category: 'Implantation',
      imageUrl:
          'https://images.squarespace-cdn.com/content/v1/6048dc56dee854516007e87c/1615931226672-5EG82VF3BL71LDAZDTB3/20161202+-+Ardooie+Vandenbroucke+kopie.jpg',
      features: [
        'Repères permanents',
        'Niveaux précis',
        'Plans d\'exécution',
        'Contrôle qualité',
      ],
    ),
    Service(
      id: '10',
      name: 'Implantation de voirie',
      description:
          'Traçage des axes de routes, rues, ronds-points. Construction de routes, lotissements.',
      category: 'Implantation',
      imageUrl:
          'https://www.etudedeterrassement.com/wp-content/uploads/2025/10/Calcul-dImplantation-dun-Axe-de-Voirie.webp',
      features: [
        'Axes routiers',
        'Réseaux enterrés',
        'Repères temporaires',
        'Coordonnées précises',
      ],
    ),
    Service(
      id: '11',
      name: 'Implantation de réseaux',
      description:
          'Positionnement de canalisations (eau, électricité, assainissement). Installation d\'infrastructures souterraines.',
      category: 'Implantation',
      imageUrl:
          'https://whp-tiefbau.de/wp-content/uploads/2021/10/rohrbau_01.jpg',
      features: [
        'Canalisations',
        'Réseaux souterrains',
        'Coordonnées GPS',
        'Plans techniques',
      ],
    ),
    Service(
      id: '12',
      name: 'Piquetage',
      description:
          'Matérialisation de points sur le terrain avec piquets. Repérage visuel pour les travaux.',
      category: 'Implantation',
      imageUrl:
          'https://betonimprime42.fr/wp-content/uploads/2026/03/Marquage-et-piquetage-de-chantier-reglementaire-avant-terrassement-1.jpg',
      features: [
        'Repères visuels',
        'Points de référence',
        'Matérialisation terrain',
        'Coordonnées précises',
      ],
    ),

    // Nivellement
    Service(
      id: '13',
      name: 'Nivellement de précision',
      description:
          'Mesures altimétriques avec précision millimétrique. Infrastructures sensibles, barrages, ponts.',
      category: 'Nivellement',
      imageUrl:
          'https://imgv2-1-f.scribdassets.com/img/document/888241251/original/4013edac79/1?v=1',
      features: [
        'Précision 0.1mm',
        'Références IGN',
        'Étalonnage',
        'Rapport d\'erreurs',
      ],
    ),
    Service(
      id: '14',
      name: 'Nivellement de chantier',
      description:
          'Contrôle des niveaux pendant les travaux. S\'assurer du respect des cotes de construction.',
      category: 'Nivellement',
      imageUrl:
          'https://soumissionsterrain.ca/wp-content/uploads/2023/06/pente-niveler-prix-1024x683.jpg',
      features: [
        'Contrôle qualité',
        'Cotes précises',
        'Suivi travaux',
        'Rapports réguliers',
      ],
    ),
    Service(
      id: '15',
      name: 'Profils en long et en travers',
      description:
          'Coupes altimétriques du terrain. Routes, canalisations, terrassement.',
      category: 'Nivellement',
      imageUrl:
          'https://4.bp.blogspot.com/-tsIjiKCQY48/V8yOvxqU8oI/AAAAAAAAARk/ec2ZL_TLt34yNqwSm2BnMScO9fkeMFIjQCLcB/s1600/IMG%2B32.jpg',
      features: [
        'Profils détaillés',
        'Coupes terrain',
        'Données 3D',
        'Plans d\'exécution',
      ],
    ),

    // Cartographie et plans
    Service(
      id: '16',
      name: 'Plan de masse',
      description:
          'Plan d\'ensemble du projet avec environnement. Permis de construire, dossier administratif.',
      category: 'Cartographie et plans',
      imageUrl:
          'https://www.bati-solar.fr/wp-content/uploads/2018/10/logiciel-plan-de-masse-design-de-maison-plan-de-masse-maison-4962-x-3508-pixels-1024x724.jpg',
      features: [
        'Plan d\'ensemble',
        'Environnement',
        'Documents administratifs',
        'Visuels clairs',
      ],
    ),
    Service(
      id: '17',
      name: 'Plan de situation',
      description:
          'Localisation du terrain dans son contexte urbain. Dossiers administratifs.',
      category: 'Cartographie et plans',
      imageUrl:
          'https://sicc-vrd.fr/wp-content/uploads/2024/01/plan-composition.png',
      features: [
        'Localisation précise',
        'Contexte urbain',
        'Documents officiels',
        'Plans détaillés',
      ],
    ),
    Service(
      id: '18',
      name: 'Plan topographique',
      description:
          'Représentation graphique complète du terrain. Études de projet, conception.',
      category: 'Cartographie et plans',
      imageUrl:
          'https://www.ibbs-zt.at/wp-content/uploads/2021/03/UFGN-AS-UB01SP-01-1001-F00_Lageplan_Bild01-scaled.jpg',
      features: [
        'Représentation complète',
        'Données précises',
        'Formats multiples',
        'Échelles adaptées',
      ],
    ),
    Service(
      id: '19',
      name: 'Cartographie SIG',
      description:
          'Cartes numériques avec bases de données. Gestion territoriale, urbanisme.',
      category: 'Cartographie et plans',
      imageUrl:
          'https://www.osterhus.de/wp-content/uploads/2021/06/GIS-EWE_001-2048x1268.jpg',
      features: [
        'Données numériques',
        'SIG intégré',
        'Base de données',
        'Analyse territoriale',
      ],
    ),
    Service(
      id: '20',
      name: 'Plans de récolement',
      description:
          'Plans "tels que construits" après travaux. Documentation finale, archives.',
      category: 'Cartographie et plans',
      imageUrl:
          'https://www.petite-bricole.fr/wp-content/uploads/2026/01/plan-de-recolement-travaux-e1769252212801.webp',
      features: ['Plans finaux', 'Documentation', 'Archives', 'Conformité'],
    ),

    // Cubature et métrés
    Service(
      id: '21',
      name: 'Calcul de volumes',
      description:
          'Mesure des volumes de terre (déblais/remblais). Terrassement, carrières, remblaiement.',
      category: 'Cubature et métrés',
      imageUrl:
          'https://th.bing.com/th/id/R.257312f0e5f807e0aed2617850ee90dd?rik=iG%2f693u3CKYZaA&riu=http%3a%2f%2fnotech.franceserv.info%2ffondations%2fcubature-terrassement-3.jpg&ehk=d8GTkbARvjU8%2f8pvJ2d43sOLFjyDGcz4iDFu6FOfbrI%3d&risl=&pid=ImgRaw&r=0',
      features: [
        'Calculs précis',
        'Volumes détaillés',
        'Optimisation',
        'Économie',
      ],
    ),
    Service(
      id: '22',
      name: 'Métrés de chantier',
      description:
          'Quantification des travaux réalisés. Facturation, suivi budgétaire.',
      category: 'Cubature et métrés',
      imageUrl:
          'https://construirevaudois.ch/wp-content/uploads/2024/11/metre-et-casque-de-chantier-1024x683.jpeg',
      features: [
        'Quantification précise',
        'Suivi budgétaire',
        'Facturation',
        'Contrôle qualité',
      ],
    ),
    Service(
      id: '23',
      name: 'Suivi de l\'avancement',
      description:
          'Mesures régulières pour contrôle. Paiements progressifs, planning.',
      category: 'Cubature et métrés',
      imageUrl:
          'https://cdn.prod.website-files.com/65980672498e084577064464/69281fbf3364770acf61566f_portrait-d-un-ingenieur-sur-le-chantier-pendant-les-heures-de-travail%20(1).jpg',
      features: [
        'Mesures régulières',
        'Contrôle qualité',
        'Paiements progressifs',
        'Planning',
      ],
    ),

    // Géoréférencement GPS
    Service(
      id: '24',
      name: 'Levé GPS haute précision',
      description:
          'Positionnement par satellite (RTK, DGPS). Grandes surfaces, zones difficiles d\'accès.',
      category: 'Géoréférencement GPS',
      imageUrl: 'https://cdn.geo-matching.com/6oJxKmnv.jpg',
      features: [
        'Haute précision',
        'RTK/DGPS',
        'Grandes surfaces',
        'Zones difficiles',
      ],
    ),
    Service(
      id: '25',
      name: 'Géoréférencement de bornes',
      description:
          'Coordonnées GPS des limites de propriété. Cadastre moderne, base de données.',
      category: 'Géoréférencement GPS',
      imageUrl:
          'https://www.terrain-construction.com/content/wp-content/uploads/2017/12/bornage-terrain-borne-2-e1523006580389.jpg',
      features: [
        'Coordonnées GPS',
        'Bornes géoréférencées',
        'Base de données',
        'Cadastre moderne',
      ],
    ),
    Service(
      id: '26',
      name: 'Canevas de points GPS',
      description:
          'Réseau de points géoréférencés. Base pour futurs levés, grands projets.',
      category: 'Géoréférencement GPS',
      imageUrl:
          'https://emicantero-cloud.storage.googleapis.com/almansa/vertice-cuchillo-alto-almansa.jpg',
      features: [
        'Réseau de points',
        'Géoréférencement',
        'Base solide',
        'Grands projets',
      ],
    ),

    // Modélisation 3D
    Service(
      id: '27',
      name: 'Modèle Numérique de Terrain',
      description:
          'Représentation 3D du relief. Études hydrauliques, visualisation.',
      category: 'Modélisation 3D',
      imageUrl:
          'https://www.bonobosworld.org/images/glossaire/nmt__representation.png',
      features: [
        'Représentation 3D',
        'Relief détaillé',
        'Visualisation',
        'Analyses hydrauliques',
      ],
    ),
    Service(
      id: '28',
      name: 'Modèle Numérique d\'Élévation',
      description:
          'Modèle 3D incluant végétation et bâtiments. Urbanisme, études d\'impact.',
      category: 'Modélisation 3D',
      imageUrl:
          'https://portal.agleader.com/community/servlet/rtaImage?eid=ka05G000000PApP&feoid=00Nf4000009wUoA&refid=0EM5G000007rsaw',
      features: ['Modèle complet', 'Végétation', 'Bâtiments', 'Urbanisme'],
    ),
    Service(
      id: '29',
      name: 'BIM (Building Information Modeling)',
      description:
          'Maquette numérique 3D du bâtiment. Gestion de projet, coordination.',
      category: 'Modélisation 3D',
      imageUrl:
          'https://hmd-solution.fr/wp-content/uploads/2024/10/maquette-BIM-definition.jpg',
      features: [
        'Maquette numérique',
        'Gestion projet',
        'Coordination',
        'Modélisation 3D',
      ],
    ),
    Service(
      id: '30',
      name: 'Courbe de Niveau',
      description:
          'Numérisation Courbe de Niveau . Patrimoine, Terrain complexes.',
      category: 'Modélisation 3D',
      imageUrl:
          'https://uncailloudanslachaussure.ch/wp-content/uploads/2019/02/ContourLines.png',
      features: [
        'Numérisation Courbe de Niveau',
        'Ultra-précision',
        'Patrimoine',
        'Terrain complexes',
      ],
    ),

    // Photogrammétrie et drone
    Service(
      id: '31',
      name: 'Levé par drone',
      description:
          'Cartographie aérienne par drone. Grandes surfaces, zones inaccessibles.',
      category: 'Photogrammétrie et drone',
      imageUrl:
          'https://images.unsplash.com/photo-1473968512647-3e447244af8f?w=400',
      features: [
        'Cartographie aérienne',
        'Drone professionnel',
        'Grandes surfaces',
        'Zones inaccessibles',
      ],
    ),
    Service(
      id: '32',
      name: 'Orthophotographie',
      description:
          'Photo aérienne géoréférencée. Plans précis, suivis de chantier.',
      category: 'Photogrammétrie et drone',
      imageUrl:
          'https://geodronexpert.com/wp-content/uploads/2024/11/othophoto-2-2.jpg',
      features: [
        'Photos géoréférencées',
        'Plans précis',
        'Suivi chantier',
        'Haute résolution',
      ],
    ),
    Service(
      id: '33',
      name: 'Inspection par drone',
      description:
          'Surveillance de structures (toits, ponts, lignes électriques). Maintenance, sécurité.',
      category: 'Photogrammétrie et drone',
      imageUrl:
          'https://img.freepik.com/premium-photo/drone-operators-monitor-screens-hand-conduct-aerial-inspections-power-lines-improving-infrastr_964444-12876.jpg?w=2000',
      features: [
        'Inspection aérienne',
        'Maintenance',
        'Sécurité',
        'Structures élevées',
      ],
    ),

    // Services spécialisés
    Service(
      id: '34',
      name: 'Suivi de tassements',
      description:
          'Mesures régulières de l\'affaissement de structures. Bâtiments sensibles, barrages.',
      category: 'Services spécialisés',
      imageUrl:
          'https://grandouestfacades.fr/wp-content/uploads/2020/08/Capture_decran_2019-07-20_a_16.01.37.png',
      features: [
        'Mesures régulières',
        'Affaissement',
        'Structures sensibles',
        'Rapports détaillés',
      ],
    ),
    Service(
      id: '35',
      name: 'Suivi de déformations',
      description:
          'Contrôle de mouvements de structures. Ponts, ouvrages d\'art.',
      category: 'Services spécialisés',
      imageUrl:
          'https://forums.autodesk.com/t5/image/serverpage/image-id/140451iA554C250F828740E?v=v2',
      features: [
        'Contrôle mouvements',
        'Ouvrages d\'art',
        'Mesures précises',
        'Sécurité',
      ],
    ),
    Service(
      id: '36',
      name: 'Expertise judiciaire',
      description:
          'Constats et mesures pour litiges. Tribunaux, conflits de voisinage.',
      category: 'Services spécialisés',
      imageUrl:
          'https://www.im.nrw/sites/default/files/styles/slider_main_16_9_960/public/IMNRW-Vermessung-190619-241.JPG?h=e2df536c&itok=IhWtWpog',
      features: [
        'Expertise judiciaire',
        'Constats',
        'Mesures légales',
        'Rapports officiels',
      ],
    ),
    Service(
      id: '37',
      name: 'Études hydrauliques',
      description:
          'Analyse des écoulements, bassins versants. Gestion des eaux, inondations.',
      category: 'Services spécialisés',
      imageUrl:
          'https://www.smdva.fr/public/retaille.php?chemin_img=https://www.smdva.fr/public/Medias/bv.png&haut_ret=574&larg_ret=911&quality=70&move_to=/public/Thumbs/Medias/bv-w911-h574_resizefill.png&method=resize&fill&original_file=https://www.smdva.fr/public/Medias/bv.png',
      features: [
        'Analyse écoulements',
        'Bassins versants',
        'Gestion eaux',
        'Prévention inondations',
      ],
    ),
    Service(
      id: '38',
      name: 'Études de tracé routier',
      description: 'Conception optimale de routes. Projets routiers, pistes.',
      category: 'Services spécialisés',
      imageUrl:
          'https://tpdemain.com/wp-content/uploads/2023/02/786e5c34-aeb9-4fe2-a3a3-22725bb753c3.png',
      features: [
        'Conception routes',
        'Tracé optimal',
        'Projets routiers',
        'Études techniques',
      ],
    ),
    Service(
      id: '39',
      name: 'Délimitation de zones à risque',
      description:
          'Cartographie de zones inondables, glissements. Prévention, urbanisme.',
      category: 'Services spécialisés',
      imageUrl:
          'https://smbgp.com/wp-content/uploads/2023/03/SITEINTERNEt-1080x675.jpeg',
      features: ['Zones à risque', 'Cartographie', 'Prévention', 'Urbanisme'],
    ),

    // Services complémentaires
    Service(
      id: '40',
      name: 'Formation et conseil',
      description:
          'Formation à l\'utilisation d\'appareils topographiques, conseil en géomatique, accompagnement de projets.',
      category: 'Services complémentaires',
      imageUrl:
          'https://angouleme.cesi.fr/wp-content/uploads/sites/24/2025/02/Formation-topographie-1-scaled.jpeg',
      features: [
        'Formation appareils',
        'Conseil géomatique',
        'Accompagnement',
        'Expertise',
      ],
    ),
    Service(
      id: '41',
      name: 'Location d\'équipements',
      description:
          'GPS RTK, stations totales, niveaux automatiques, drones. Équipements professionnels.',
      category: 'Services complémentaires',
      imageUrl:
          'https://www.agro-precision.es/wp-content/uploads/2023/12/TOPOGRAFIA-GENERAL-CON-GPS-DE-PRECISION-1280x1707.jpg',
      features: [
        'GPS RTK',
        'Stations totales',
        'Niveaux automatiques',
        'Drones',
      ],
    ),
    Service(
      id: '42',
      name: 'Maintenance',
      description:
          'Calibration d\'appareils, réparation, mise à jour logiciels. Maintenance professionnelle.',
      category: 'Services complémentaires',
      imageUrl: 'https://www.mamtus.ng/media/wysiwyg/Leica_Products_1.jpeg',
      features: [
        'Calibration',
        'Réparation',
        'Mise à jour',
        'Maintenance préventive',
      ],
    ),
  ];

  List<Service> get _filteredServices {
    return ServiceScreen.catalog.where((service) {
      final matchesCategory =
          _selectedCategory == 'Tous' || service.category == _selectedCategory;
      final matchesSearch =
          _searchQuery.isEmpty ||
          service.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          service.description.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
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
        elevation: 0,
        title: Text(
          'Services Topographiques',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.info_outline, color: Color(0xFF2563EB)),
            tooltip: 'Informations',
          ),
        ],
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
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                      label: Text(
                        category,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
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
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF374151),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
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
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Service service) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
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
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFFF3F4F6),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2563EB),
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFFF3F4F6),
                    child: Icon(Icons.image, size: 48, color: Colors.grey[400]),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(
                      service.category,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    service.category,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getCategoryColor(service.category),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  service.name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  service.description,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Features
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: service.features.take(3).map((feature) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        feature,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: const Color(0xFF6B7280),
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
                    onPressed: () => _startQuoteRequest(service),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'Demander un devis',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

  Future<void> _promptQuoteSignIn() async {
    final shouldSignIn = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Connexion requise'),
        content: const Text(
          'Connectez-vous pour envoyer une demande de devis et la retrouver dans « Mes devis ».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
    if (!mounted || shouldSignIn != true) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<void> _startQuoteRequest(Service service) async {
    final token = await ApiService.ensureAuthenticated();
    if (!mounted) return;

    if (token == null) {
      await _promptQuoteSignIn();
      return;
    }

    try {
      final profile = await ApiService.getMe();
      if (!mounted) return;
      if (profile['role'] != 'client') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Un compte client est requis pour demander un devis.',
            ),
          ),
        );
        return;
      }
      _showQuoteDialog(service);
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 401) {
        await ApiService.removeToken();
        if (mounted) await _promptQuoteSignIn();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vérification de la session impossible : $error'),
        ),
      );
    }
  }

  void _showQuoteDialog(Service service) {
    final descriptionCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    final telephoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    // Capturés avant tout await : le context du dialogue est invalide après pop.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
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
                            color: _getCategoryColor(
                              service.category,
                            ).withValues(alpha: 0.1),
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
                    TextFormField(
                      controller: descriptionCtrl,
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La description est requise';
                        }
                        if (value.trim().length < 10) {
                          return 'Décrivez votre projet en détail (min. 10 caractères)';
                        }
                        return null;
                      },
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
                    TextFormField(
                      controller: nomCtrl,
                      decoration: InputDecoration(
                        hintText: 'Votre nom complet *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom est requis';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: telephoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Téléphone *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le téléphone est requis';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isNotEmpty) {
                          final emailRegex = RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$',
                          );
                          if (!emailRegex.hasMatch(email)) {
                            return 'Email invalide';
                          }
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(context),
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
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (formKey.currentState!.validate()) {
                                      setDialogState(() => isSubmitting = true);
                                      try {
                                        await ApiService.createDevis(
                                          serviceId: service.id,
                                          serviceName: service.name,
                                          description: descriptionCtrl.text
                                              .trim(),
                                          nom: nomCtrl.text.trim(),
                                          telephone: telephoneCtrl.text.trim(),
                                          email: emailCtrl.text.trim().isEmpty
                                              ? null
                                              : emailCtrl.text.trim(),
                                        );
                                        if (mounted) {
                                          navigator.pop();
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Demande de devis envoyée avec succès !',
                                              ),
                                              backgroundColor: Colors.green,
                                              action: SnackBarAction(
                                                label: 'Suivre',
                                                textColor: Colors.white,
                                                onPressed: () {
                                                  navigator.push(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          ClientMesDevisPage(
                                                            serviceImageResolver:
                                                                ServiceScreen
                                                                    .imageUrlForId,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Erreur: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setDialogState(
                                            () => isSubmitting = false,
                                          );
                                        }
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Envoyer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
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
        },
      ),
    );
  }
}
