// Configuration des URLs d'images par appareil
class AppareilImages {
  // Map des URLs d'images par type d'appareil (fallback si pas d'URL personnalisée)
  static final Map<String, String> imageUrlsByType = {
    'gps': 'https://dodacvienthong.com/site/pictures/content/may-dinh-vi-ve-tinh-2-tan-so-gps-rtk-e-survey-e300-pro-imu.jpg',
    'niveau': 'https://www.leica-geosystems.com/-/media/Images/Products/Levels/Digilevel/Leica-Digilevel-750/Leica-Digilevel-750_01.jpg',
    'station totale': 'https://www.leica-geosystems.com/-/media/Images/Products/Total-Stations/TS-Series/Leica-TS16/Leica-TS16_01.jpg',
    'theodolite': 'https://www.leica-geosystems.com/-/media/Images/Products/Total-Stations/TS-Series/Leica-TS16/Leica-TS16_01.jpg',
    'trepied': 'https://www.leica-geosystems.com/-/media/Images/Products/Accessories/Tripods/Leica-Tripod/Leica-Tripod_01.jpg',
    'mire': 'https://geosurvey.co.uk/wp-content/uploads/2018/03/leica-style-single-prism-2-1.jpg',
    'drone': 'https://geo-sud-ouest.fr/wp-content/uploads/2023/03/topographie-drone.png',
    'embase': 'https://www.leica-geosystems.com/-/media/Images/Products/Accessories/Bases/Leica-Base/Leica-Base_01.jpg',
    'reflecteur': 'https://geosurvey.co.uk/wp-content/uploads/2018/03/leica-style-single-prism-2-1.jpg',
    'canne': 'https://ats-topographie.fr/1206-large_default/canne-gps-carbone-2-m.jpg',
    'antenne': 'https://dodacvienthong.com/site/pictures/content/may-dinh-vi-ve-tinh-2-tan-so-gps-rtk-e-survey-e300-pro-imu.jpg',
    'accessoire': 'https://www.leica-geosystems.com/-/media/Images/Products/Accessories/Leica-Accessory_01.jpg',
    'scanner 3d': 'https://www.leica-geosystems.com/-/media/Images/Products/3D-Scanners/Leica-ScanStation/Leica-ScanStation_01.jpg',
  };

  // Map des URLs d'images par ID d'appareil - MODIFIEZ LES URLs ICI
  // Chaque appareil a sa PROPRE image (distincte des autres du même type).
  // Les URLs ci-dessous sont des placeholders affichant le nom du modèle :
  // remplacez-les par les vraies photos téléchargées sur internet.
  static final Map<String, String> imageUrlsByAppareilId = {
    // APP-001 - GPS e-survey E600
    'APP-001': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQTlVzq9M2O4UdhLRKr_LiPJL2znDfNA0IhQOHGmGSDPQ&s=10',
    // APP-002 - GPS e-survey E800
    'APP-002': 'https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEhjR_4BJQ0fmscREL8LByktseSta-ZO9ORsSk6LgL_FWzUtYHvmv-Yn6XiQqgCls34QmkdEG7MWljx8b49grSVeGrI-h3k2inpUbSkM9msXqTUQUiB1i--e9_lnlnP4Aq6ycMAn749Qlcdxd_PjF1_o2OCXJtJrx5gMB4Nl5-HJxnHP20C58RoAIlt2CHQi/s720/eSurvey-e800.jpg',
    // APP-003 - Niveau Leica
    'APP-003': 'https://placehold.co/600x400/43a047/ffffff?text=APP-003+Niveau+Leica',
    // APP-004 - Niveau Electronique Leica
    'APP-004': 'https://placehold.co/600x400/43a047/ffffff?text=APP-004+Niveau+Electronique+Leica',
    // APP-005 - Theodolite
    'APP-005': 'https://placehold.co/600x400/8e24aa/ffffff?text=APP-005+Theodolite',
    // APP-006 - Station Totale Leica TS06
    'APP-006': 'https://placehold.co/600x400/fb8c00/ffffff?text=APP-006+Station+Totale+Leica+TS06',
    // APP-007 - GPS e-survey E300
    'APP-007': 'https://placehold.co/600x400/1e88e5/ffffff?text=APP-007+GPS+e-survey+E300',
    // APP-008 - Trepied Leica
    'APP-008': 'https://placehold.co/600x400/00897b/ffffff?text=APP-008+Trepied+Leica',
    // APP-009 - Mire Stadimetrique
    'APP-009': 'https://placehold.co/600x400/6d4c41/ffffff?text=APP-009+Mire+Stadimetrique',
    // APP-010 - Antenne GPS RTK
    'APP-010': 'https://placehold.co/600x400/00acc1/ffffff?text=APP-010+Antenne+GPS+RTK',
    // APP-011 - Canne GPS
    'APP-011': 'https://placehold.co/600x400/00acc1/ffffff?text=APP-011+Canne+GPS',
    // APP-012 - Reflecteur Leica
    'APP-012': 'https://placehold.co/600x400/3949ab/ffffff?text=APP-012+Reflecteur+Leica',
    // APP-013 - Drone topographique
    'APP-013': 'https://placehold.co/600x400/d81b60/ffffff?text=APP-013+Drone+Topographique',
    // APP-014 - GPS Trimble R10
    'APP-014': 'https://placehold.co/600x400/1e88e5/ffffff?text=APP-014+GPS+Trimble+R10',
    // APP-015 - GPS Leica GS18 T
    'APP-015': 'https://placehold.co/600x400/1e88e5/ffffff?text=APP-015+GPS+Leica+GS18+T',
    // APP-016 - GPS Topcon Hiper VR
    'APP-016': 'https://placehold.co/600x400/1e88e5/ffffff?text=APP-016+GPS+Topcon+Hiper+VR',
    // APP-017 - GPS Spectra SP80
    'APP-017': 'https://placehold.co/600x400/1e88e5/ffffff?text=APP-017+GPS+Spectra+SP80',
    // APP-018 - Niveau Automatique Leica NA720
    'APP-018': 'https://placehold.co/600x400/43a047/ffffff?text=APP-018+Niveau+Auto+Leica+NA720',
    // APP-019 - Niveau Numérique Leica DNA03
    'APP-019': 'https://placehold.co/600x400/43a047/ffffff?text=APP-019+Niveau+Numerique+Leica+DNA03',
    // APP-020 - Niveau Topcon AT-B2
    'APP-020': 'https://placehold.co/600x400/43a047/ffffff?text=APP-020+Niveau+Topcon+AT-B2',
    // APP-021 - Station Totale Leica TS16
    'APP-021': 'https://placehold.co/600x400/fb8c00/ffffff?text=APP-021+Station+Totale+Leica+TS16',
    // APP-022 - Station Totale Topcon GT-1200
    'APP-022': 'https://placehold.co/600x400/fb8c00/ffffff?text=APP-022+Station+Totale+Topcon+GT-1200',
    // APP-023 - Station Totale Sokkia IX-1000
    'APP-023': 'https://placehold.co/600x400/fb8c00/ffffff?text=APP-023+Station+Totale+Sokkia+IX-1000',
    // APP-024 - Théodolite Électronique Leica TPS1200
    'APP-024': 'https://placehold.co/600x400/8e24aa/ffffff?text=APP-024+Theodolite+Leica+TPS1200',
    // APP-025 - Réflecteur Sphérique Leica GPR121
    'APP-025': 'https://placehold.co/600x400/3949ab/ffffff?text=APP-025+Reflecteur+Spherique+GPR121',
    // APP-026 - Mire à Prismes Leica GMP101
    'APP-026': 'https://placehold.co/600x400/6d4c41/ffffff?text=APP-026+Mire+Prismes+GMP101',
    // APP-027 - Canne Télescopique Leica GLS121
    'APP-027': 'https://placehold.co/600x400/00acc1/ffffff?text=APP-027+Canne+Telescopique+GLS121',
    // APP-028 - Antenne GPS Externe Leica AX1200G
    'APP-028': 'https://placehold.co/600x400/00acc1/ffffff?text=APP-028+Antenne+GPS+AX1200G',
    // APP-029 - Batterie GPS Leica GEV240
    'APP-029': 'https://placehold.co/600x400/757575/ffffff?text=APP-029+Batterie+GPS+GEV240',
    // APP-030 - Chargeur GPS Leica GEV242
    'APP-030': 'https://placehold.co/600x400/757575/ffffff?text=APP-030+Chargeur+GPS+GEV242',
    // APP-031 - Housse de Protection GPS
    'APP-031': 'https://placehold.co/600x400/757575/ffffff?text=APP-031+Housse+Protection+GPS',
    // APP-032 - Drone DJI Phantom 4 RTK
    'APP-032': 'https://placehold.co/600x400/d81b60/ffffff?text=APP-032+Drone+DJI+Phantom+4+RTK',
    // APP-033 - Drone DJI Matrice 300 RTK
    'APP-033': 'https://placehold.co/600x400/d81b60/ffffff?text=APP-033+Drone+DJI+Matrice+300+RTK',
  };

  // URL d'image par défaut pour les types non définis
  static const String defaultImageUrl = 'https://dodacvienthong.com/site/pictures/content/may-dinh-vi-ve-tinh-2-tan-so-gps-rtk-e-survey-e300-pro-imu.jpg';

  // Fonction pour obtenir l'URL d'image selon l'ID de l'appareil (prioritaire)
  static String getImageUrlForAppareilId(String appareilId) {
    if (imageUrlsByAppareilId.containsKey(appareilId)) {
      return imageUrlsByAppareilId[appareilId]!;
    }
    return defaultImageUrl;
  }

  // Fonction pour obtenir l'URL d'image selon le type d'appareil
  static String getImageUrlForType(String type) {
    final normalized = _normalizeString(type.toLowerCase().trim());
    if (imageUrlsByType.containsKey(normalized)) {
      return imageUrlsByType[normalized]!;
    }
    for (final key in imageUrlsByType.keys) {
      if (normalized.contains(key)) {
        return imageUrlsByType[key]!;
      }
    }
    return defaultImageUrl;
  }

  // Fonction générique : cherche d'abord par ID, puis par type
  // Si customImageUrl est fourni et non vide, elle est utilisée en priorité
  static String getImageUrl(String appareilId, String type, {String? customImageUrl}) {
    // Si une URL personnalisée est fournie, l'utiliser directement
    if (customImageUrl != null && customImageUrl.isNotEmpty) {
      return customImageUrl;
    }
    final urlById = getImageUrlForAppareilId(appareilId);
    if (urlById != defaultImageUrl) {
      return urlById;
    }
    return getImageUrlForType(type);
  }

  // Helper pour normaliser les strings (retirer accents)
  static String _normalizeString(String input) {
    return input
        .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e')
        .replaceAll('à', 'a').replaceAll('â', 'a')
        .replaceAll('î', 'i').replaceAll('ï', 'i')
        .replaceAll('ô', 'o').replaceAll('ö', 'o')
        .replaceAll('û', 'u').replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }

  // Fonction pour obtenir l'icône selon le type d'appareil
  static const Map<String, String> typeIcons = {
    'gps': '📍',
    'niveau': '📏',
    'station totale': '⚙️',
    'theodolite': '⚙️',
    'trepied': '🎯',
    'mire': '📐',
    'drone': '🚁',
    'embase': '🔴',
    'reflecteur': '⚙️',
    'canne': '📍',
    'antenne': '📡',
    'accessoire': '📦',
  };

  static String getIconForType(String type) {
    final normalized = _normalizeString(type.toLowerCase().trim());
    return typeIcons[normalized] ?? '📦';
  }
}
