// Configuration des URLs d'images par type d'appareil
class AppareilImages {
  // Map des URLs d'images par type d'appareil
  static final Map<String, String> imageUrlsByType = {
    'gps': 'https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3?auto=format&fit=crop&w=800&q=80',
    'niveau': 'https://images.unsplash.com/photo-1590650153855-d9e808231d41?auto=format&fit=crop&w=800&q=80',
    'station totale': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=800&q=80',
    'theodolite': 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=800&q=80',
    'trepied': 'https://images.unsplash.com/photo-1590650153855-d9e808231d41?auto=format&fit=crop&w=800&q=80',
    'mire': 'https://images.unsplash.com/photo-1590650153855-d9e808231d41?auto=format&fit=crop&w=800&q=80',
    'drone': 'https://images.unsplash.com/photo-1506941433948-8f0958e3c0f1?auto=format&fit=crop&w=800&q=80',
    'laser': 'https://images.unsplash.com/photo-1562654501-a0ccc81d82d5?auto=format&fit=crop&w=800&q=80',
  };

  // URL d'image par défaut pour les types non définis
  static const String defaultImageUrl = 'https://images.unsplash.com/photo-1581092334494-8b6a8c3a52f3?auto=format&fit=crop&w=800&q=80';

  // Fonction pour obtenir l'URL d'image selon le type d'appareil
  static String getImageUrlForType(String type) {
    final normalizedType = type.toLowerCase().trim();
    return imageUrlsByType[normalizedType] ?? defaultImageUrl;
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
    'laser': '🔴',
  };

  // Fonction pour obtenir l'icône selon le type d'appareil
  static String getIconForType(String type) {
    final normalizedType = type.toLowerCase().trim();
    return typeIcons[normalizedType] ?? '⚙️';
  }
}
