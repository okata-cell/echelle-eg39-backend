/// Base de connaissances de l’assistant support.
///
/// Chaque entrée ne contient que des faits vérifiables sur ÉCHELLE EG39 :
/// services, partenaires, équipe, horaires, coordonnées, équipements,
/// FAQ et glossaire. Aucune réponse n’est inventée par un modèle.
class SupportTopic {
  const SupportTopic({
    required this.question,
    required this.answer,
    required this.keywords,
  });

  /// Formulation de la question, réutilisée comme suggestion.
  final String question;

  /// Réponse affichée dans le chat.
  final String answer;

  /// Mots-clés déjà normalisés (minuscules, sans accents).
  final List<String> keywords;
}

const List<SupportTopic> kSupportTopics = [
  SupportTopic(
    question: 'Quels sont vos horaires ?',
    answer:
        'Nos horaires : lundi à vendredi de 8h à 18h, samedi sur demande. '
        'Le dimanche, l’agence est fermée.',
    keywords: [
      'horaire',
      'heures',
      'heure',
      'ouvert',
      'ouverture',
      'ferme',
      'fermeture',
      'samedi',
      'dimanche',
      '8h',
      '18h',
    ],
  ),
  SupportTopic(
    question: 'Où se trouve l’agence ?',
    answer:
        'Nous sommes à Lomé, Rue des frères franciscains, après les rails '
        '(plus code 55PH+CR6). L’itinéraire exact est disponible dans le menu '
        'Profil › Nous localiser.',
    keywords: [
      'adresse',
      'situe',
      'situez',
      'localisation',
      'localiser',
      'trouver',
      'lome',
      'agence',
      'rails',
      'franciscains',
      'plan',
      'maps',
      'carte',
    ],
  ),
  SupportTopic(
    question: 'Comment vous joindre ?',
    answer:
        'Par téléphone ou WhatsApp au +228 90 01 43 29, ou par e-mail à '
        'admin@echelle-eg39.com. Vous pouvez aussi écrire ici : le message '
        'est transmis à l’équipe.',
    keywords: [
      'telephone',
      'appel',
      'appeler',
      'numero',
      'joindre',
      'contacter',
      'whatsapp',
      'contact',
      'coordonnees',
    ],
  ),
  SupportTopic(
    question: 'Quels services proposez-vous ?',
    answer:
        'Vente d’équipements neufs (garantie 2 ans), location, formation, '
        'réparation et service après-vente, mise à jour des logiciels de '
        'calcul et de CAO, et support technique.',
    keywords: [
      'service',
      'services',
      'proposez',
      'propose',
      'offrez',
      'faites',
      'prestations',
      'vente',
      'achat',
      'location',
      'formation',
      'reparation',
      'maintenance',
      'mise a jour',
      'logiciel',
      'support technique',
    ],
  ),
  SupportTopic(
    question: 'La vente est-elle garantie ?',
    answer:
        'Les équipements neufs vendus par ÉCHELLE EG39 sont garantis 2 ans. '
        'Les réparations relèvent du service après-vente.',
    keywords: ['garantie', 'garanti', 'neuf', 'neuve', 'sav', 'apres vente'],
  ),
  SupportTopic(
    question: 'Qui sont vos partenaires ?',
    answer:
        'Nous travaillons avec Leica (équipements de précision suisses) et '
        'e-survey (GPS de nouvelle génération).',
    keywords: [
      'partenaire',
      'partenaires',
      'marque',
      'marques',
      'leica',
      'esurvey',
      'e-survey',
      'survey',
    ],
  ),
  SupportTopic(
    question: 'Qui compose votre équipe ?',
    answer:
        'Une direction experte en topographie, une responsable commerciale '
        'spécialiste GPS, un technicien SAV, un formateur théodolites et une '
        'responsable administrative pour le support client. Les profils sont '
        'détaillés dans À propos › Notre équipe.',
    keywords: [
      'equipe',
      'technicien',
      'techniciens',
      'directeur',
      'patron',
      'commercial',
      'commerciale',
      'formateur',
      'qui travaille',
      'personnel',
      'staff',
    ],
  ),
  SupportTopic(
    question: 'Quels équipements vendez-vous ou louez-vous ?',
    answer:
        'Niveaux, stations totales, théodolites, GPS, trépieds, embases et '
        'accessoires. La section Locations affiche le tarif par jour, la '
        'section Ventes le prix de vente et la disponibilité.',
    keywords: [
      'equipement',
      'equipements',
      'materiel',
      'appareil',
      'appareils',
      'niveau',
      'station totale',
      'theodolite',
      'gps',
      'trepied',
      'accessoire',
      'catalogue',
    ],
  ),
  SupportTopic(
    question: 'Combien coûte une location ou un achat ?',
    answer:
        'Les tarifs sont affichés dans l’application : prix par jour dans '
        'Locations, prix de vente dans Ventes. Pour un devis précis ou une '
        'offre sur plusieurs appareils, contactez notre responsable '
        'commerciale au +228 90 01 43 29.',
    keywords: [
      'prix',
      'tarif',
      'tarifs',
      'cout',
      'coute',
      'combien',
      'fcfa',
      'devis',
      'budget',
    ],
  ),
  SupportTopic(
    question: 'Comment réserver un équipement ?',
    answer:
        'Ouvrez la section Locations, choisissez vos dates, vérifiez la '
        'disponibilité puis validez la réservation depuis l’application.',
    keywords: [
      'reserver',
      'reservation',
      'louer',
      'disponibilite',
      'disponible',
      'dates',
      'jours',
    ],
  ),
  SupportTopic(
    question: 'Où suivre mes locations et mes achats ?',
    answer:
        'La section Historique regroupe vos locations et vos achats avec leur '
        'statut. Chaque partie se recharge séparément en cas d’erreur.',
    keywords: [
      'historique',
      'commande',
      'commandes',
      'achats',
      'mes locations',
      'statut',
      'suivi',
    ],
  ),
  SupportTopic(
    question: 'Comment calibrer un GPS de précision ?',
    answer:
        'Placez-vous en zone dégagée, sans masque au-dessus de l’antenne, et '
        'suivez la procédure de calibrage du manuel de l’appareil avant de '
        'lancer vos mesures.',
    keywords: [
      'calibrer',
      'calibrage',
      'calibration',
      'initialiser',
      'gps precision',
      'rtk',
    ],
  ),
  SupportTopic(
    question: 'Quelle est la précision des GPS e-survey ?',
    answer:
        'Les GPS e-survey atteignent une précision de 2 à 5 mm en mode RTK.',
    keywords: ['precision', 'precis', 'mm', 'marge erreur', 'exactitude'],
  ),
  SupportTopic(
    question: 'Comment régler un théodolite ?',
    answer:
        'La mise en station demande une mise à niveau précise avec les vis '
        'calantes, puis le calage sur le point de station avant toute mesure.',
    keywords: [
      'regler',
      'reglage',
      'theodolite',
      'mise en station',
      'vis calantes',
      'niveau bulle',
    ],
  ),
  SupportTopic(
    question: 'Que signifie « station totale » ?',
    answer:
        'Une station totale combine un théodolite et un distancemètre : elle '
        'mesure les angles et les distances en une seule opération.',
    keywords: [
      'station totale',
      'distancemetre',
      'glossaire',
      'definition',
      'signifie',
    ],
  ),
  SupportTopic(
    question: 'Que signifie « bornage » ?',
    answer:
        'Le bornage est la délimitation officielle d’une propriété. Le '
        'glossaire du centre d’aide définit aussi l’altimétrie, l’azimut, le '
        'cadastre, le gisement et le nivellement.',
    keywords: [
      'bornage',
      'bornage',
      'cadastre',
      'altimetrie',
      'azimut',
      'gisement',
      'nivellement',
      'terme',
      'termes',
    ],
  ),
  SupportTopic(
    question: 'Comment obtenir l’application ?',
    answer:
        'L’application ÉCHELLE EG39 est en cours de publication sur Google '
        'Play et l’App Store. En attendant, l’équipe vous transmet '
        'directement le fichier d’installation : écrivez-nous au '
        '+228 90 01 43 29.',
    keywords: [
      'telecharger',
      'installer',
      'application',
      'app',
      'apk',
      'play store',
      'app store',
      'iphone',
      'android',
      'lien',
    ],
  ),
  SupportTopic(
    question: 'Comment vous signaler un problème ?',
    answer:
        'Décrivez le problème dans ce chat : s’il ne relève pas de la fiche de '
        'l’entreprise, le message est transmis à l’équipe. Vous pouvez aussi '
        'appeler le +228 90 01 43 29.',
    keywords: [
      'probleme',
      'bug',
      'erreur',
      'panne',
      'signaler',
      'plainte',
      'marche pas',
      'fonctionne pas',
    ],
  ),
];
