// Configuration des URLs d'images par type d'appareil
class AppareilImages {
  // Map des URLs d'images par type d'appareil (utilise les mêmes URLs que data_manager)
  static final Map<String, String> imageUrlsByType = {
    'gps': 'https://gms.gumtree.co.za/v2/images/za_ads_134213409_260118_696cd9fe200cfa000a9b8d85?size=l',
    'niveau': 'https://m.media-amazon.com/images/I/61RMLIoYh6L._AC_UF894,1000_QL80_.jpg',
    'station totale': 'https://lh3.googleusercontent.com/proxy/QENf36FM_QOdPL6EZH4wI_mdJVA-cOVzGoCq9YObvGEWYvpGcaRmBsVgTWI3GLlrkGR7jzkRbtBr7cEDfyyur-jmBzWb6cVX2D7mz65KR8Zxj7Ga5zjz-y-ZC0xjf68PoItOFpCRZW6PjvtgIBQ4tX6Jyg',
    'theodolite': 'https://e-prisme.fr/wp-content/uploads//2024/06/IMG_20240530_163035785-scaled.jpg',
    'trepied': 'https://www.lepont.fr/30189-large_default/trepied-leica-cpt103-cpt104-mi-lourd.jpg',
    'mire': 'https://www.scors.fr/medias/photos-catalogue/6/G/G2/MIT.jpg',
    'drone': 'https://m.media-amazon.com/images/I/41B4Q7zJuhL._AC_UF894,1000_QL80_.jpg',
    'embase': 'https://images.unsplash.com/photo-1504917595217-d4dc5ebe6122?w=400',
    'reflecteur': 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTwpQLIsIgCIxYZJ7erX8al95F12_iasdiQ6g&s',
    'canne': 'https://m.media-amazon.com/images/I/61D+67Fr13L.jpg',
    'antenne': 'https://m.media-amazon.com/images/I/41B4Q7zJuhL._AC_UF894,1000_QL80_.jpg',
    'accessoire': 'https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3?w=400',
  };

  // URL d'image par défaut pour les types non définis
  static const String defaultImageUrl = 'https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3?auto=format&fit=crop&w=800&q=80';

  // Fonction pour obtenir l'URL d'image selon le type d'appareil
  static String getImageUrlForType(String type) {
    // Normaliser: retirer accents et mettre en minuscule
    final normalized = _normalizeString(type.toLowerCase().trim());
    
    // Essayer d'abord la correspondance exacte
    if (imageUrlsByType.containsKey(normalized)) {
      return imageUrlsByType[normalized]!;
    }
    // Essayer de trouver un type clé dans le titre (par exemple "gps" dans "GPS S750")
    for (final key in imageUrlsByType.keys) {
      if (normalized.contains(key)) {
        return imageUrlsByType[key]!;
      }
    }
    return defaultImageUrl;
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

  // Fonction pour obtenir l'icône selon le type d'appareil
  static String getIconForType(String type) {
    final normalized = _normalizeString(type.toLowerCase().trim());
    return typeIcons[normalized] ?? '📦';
  }
}
