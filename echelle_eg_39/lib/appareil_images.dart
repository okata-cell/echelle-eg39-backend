// Configuration des URLs d'images par type d'appareil
class AppareilImages {
  // Map des URLs d'images par type d'appareil
  static final Map<String, String> imageUrlsByType = {
    'gps': 'https://images.unsplash.com/photo-1579567761406-4684ee0c75b6?w=400',
    'niveau': 'https://images.unsplash.com/photo-1590650153855-d9e808231d41?w=400',
    'station totale': 'https://images.unsplash.com/photo-1574958269340-fa927503f3dd?w=400',
    'theodolite': 'https://images.unsplash.com/photo-1581092162384-8987c1d64718?w=400',
    'trepied': 'https://images.unsplash.com/photo-1590650046871-92c887180603?w=400',
    'mire': 'https://images.unsplash.com/photo-1590650153855-d9e808231d41?w=400',
    'drone': 'https://images.unsplash.com/photo-1508614589041-895b8c9d755c?w=400',
    'embase': 'https://images.unsplash.com/photo-1504917595217-d4dc5ebe6122?w=400',
    'reflecteur': 'https://images.unsplash.com/photo-1581092160562-40aa08e78837?w=400',
    'canne': 'https://images.unsplash.com/photo-1579567761406-4684ee0c75b6?w=400',
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
    'accessoire': '📦',
  };

  // Fonction pour obtenir l'icône selon le type d'appareil
  static String getIconForType(String type) {
    final normalized = _normalizeString(type.toLowerCase().trim());
    return typeIcons[normalized] ?? '📦';
  }
}
