// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../api_service.dart';
import '../models_admin_activity.dart';

/// Source unique de l'activité cliente pour l'atelier admin.
///
/// Deux canaux complémentaires, aucun service externe :
/// * le flux SSE du backend, qui pousse chaque demande en moins d'une seconde ;
/// * la relecture de `GET /api/admin/activity`, appelée au démarrage, au retour
///   de veille et toutes les 20 s lorsque le flux est muet.
class AdminActivityService extends ChangeNotifier with WidgetsBindingObserver {
  AdminActivityService();

  static final AdminActivityService instance = AdminActivityService();

  static const Duration _intervalleRepli = Duration(seconds: 20);
  static const Duration _delaiReconnexion = Duration(seconds: 5);
  static const int _plafond = 80;

  final List<AdminActivityEvent> _evenements = <AdminActivityEvent>[];
  final Map<String, int> _nonLus = <String, int>{
    'location': 0,
    'vente': 0,
    'devis': 0,
  };

  http.Client? _client;
  StreamSubscription<String>? _abonnement;
  Timer? _repli;
  Timer? _reconnexion;

  bool _demarre = false;
  bool _fluxOuvert = false;
  bool _connexionEnCours = false;
  bool _refreshing = false;
  bool _horsLigne = false;
  DateTime? _derniereActivite;

  /// Notifié lorsqu'une demande arrive pendant que l'app est ouverte : l'écran
  /// admin s'en sert pour la vibration courte.
  ValueChanged<AdminActivityEvent>? onNouvelEvenement;

  List<AdminActivityEvent> get evenements =>
      List<AdminActivityEvent>.unmodifiable(_evenements);

  /// Total des demandes non consultées, tous modules confondus.
  int get total => _nonLus.values.fold<int>(0, (somme, n) => somme + n);

  int nonLusDe(String kind) => _nonLus[kind] ?? 0;

  /// Vrai tant que le flux temps réel est connecté.
  bool get fluxEnDirect => _fluxOuvert;

  /// Vrai après un échec réseau : l'écran l'annonce sans bloquer la lecture.
  bool get horsLigne => _horsLigne;

  DateTime? get derniereActivite => _derniereActivite;

  List<AdminActivityJour> get sections => grouperParJour(_evenements);

  Future<void> demarrer() async {
    if (_demarre) return;
    _demarre = true;

    WidgetsBinding.instance.addObserver(this);

    await rafraichir();
    unawaited(_ouvrirFlux());

    _repli = Timer.periodic(_intervalleRepli, (_) {
      if (!_fluxOuvert) unawaited(rafraichir());
    });
  }

  void arreter() {
    if (!_demarre) return;
    _demarre = false;

    WidgetsBinding.instance.removeObserver(this);
    _abonnement?.cancel();
    _abonnement = null;
    _repli?.cancel();
    _repli = null;
    _reconnexion?.cancel();
    _reconnexion = null;
    _client?.close();
    _client = null;
    _fluxOuvert = false;
    _connexionEnCours = false;
    onNouvelEvenement = null;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // L'app a pu être suspendue pendant des heures : on rattrape d'abord, puis
    // on rouvre le flux s'il est tombé pendant la veille.
    unawaited(rafraichir());
    if (!_fluxOuvert) unawaited(_ouvrirFlux());
  }

  /// Relecture du journal : la référence reste le serveur.
  ///
  /// Volontairement sans curseur : le registre doit montrer l'historique récent,
  /// pas seulement ce qui est arrivé après la dernière consultation. Un `since`
  /// calculé à l'ouverture précédente masquait les demandes encore non traitées.
  Future<void> rafraichir() async {
    if (_refreshing) return;
    _refreshing = true;

    try {
      final data = await ApiService.getAdminActivity();
      _horsLigne = false;
      _appliquer(data);
    } catch (_) {
      _horsLigne = true;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  /// Acquitte une demande ouverte : la pastille baisse pour tous les admins.
  Future<void> marquerLu(AdminActivityEvent evenement) async {
    if (!evenement.nonLu) return;

    final index = _evenements.indexWhere((item) => item.id == evenement.id);
    if (index >= 0) _evenements[index] = evenement.marqueLu(DateTime.now());
    _decrementer(evenement.kind);
    notifyListeners();

    try {
      await ApiService.markAdminActivityRead(evenement.id);
    } catch (_) {
      // Le serveur reste la référence : le prochain rafraîchissement réaligne.
    }
  }

  /// Solde la file d'un coup (fin de journée, reprise d'activité).
  Future<void> toutMarquerLu() async {
    if (total == 0 && _evenements.every((item) => !item.nonLu)) return;

    final maintenant = DateTime.now();
    for (var index = 0; index < _evenements.length; index++) {
      if (_evenements[index].nonLu) {
        _evenements[index] = _evenements[index].marqueLu(maintenant);
      }
    }
    for (final kind in _nonLus.keys.toList()) {
      _nonLus[kind] = 0;
    }
    notifyListeners();

    try {
      await ApiService.markAllAdminActivityRead();
    } catch (_) {
      // Idem : un échec réseau ne doit pas faire remonter d'erreur à l'écran.
    }
  }

  /// Injecte un état connu (tests et écrans de prévisualisation).
  @visibleForTesting
  void injecter(
    List<AdminActivityEvent> evenements, {
    Map<String, int>? nonLus,
  }) {
    _evenements
      ..clear()
      ..addAll(evenements.take(_plafond));
    if (nonLus != null) {
      for (final entry in nonLus.entries) {
        _nonLus[entry.key] = entry.value;
      }
    }
    notifyListeners();
  }

  void _appliquer(Map<String, dynamic> data) {
    final bruts = data['events'];
    if (bruts is List) {
      final recus = bruts
          .whereType<Map>()
          .map(
            (brut) =>
                AdminActivityEvent.fromJson(Map<String, dynamic>.from(brut)),
          )
          .toList(growable: false);
      _fusionner(recus);
    }

    final unread = data['unread'];
    if (unread is Map) {
      for (final kind in _nonLus.keys.toList()) {
        _nonLus[kind] = num.tryParse('${unread[kind] ?? 0}')?.toInt() ?? 0;
      }
    }
  }

  void _fusionner(List<AdminActivityEvent> recus) {
    if (recus.isEmpty) return;

    final parId = <int, AdminActivityEvent>{
      for (final evenement in _evenements) evenement.id: evenement,
    };

    for (final evenement in recus) {
      final connu = parId[evenement.id];
      // Un acquittement local ne doit pas être annulé par une réponse plus
      // ancienne du serveur.
      parId[evenement.id] = connu != null && connu.readAt != null
          ? evenement.marqueLu(connu.readAt!)
          : evenement;
    }

    final liste = parId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _evenements
      ..clear()
      ..addAll(liste.take(_plafond));
  }

  void _ajouter(AdminActivityEvent evenement) {
    if (_evenements.any((item) => item.id == evenement.id)) return;

    _evenements.insert(0, evenement);
    if (_evenements.length > _plafond) _evenements.removeLast();

    _nonLus[evenement.kind] = (_nonLus[evenement.kind] ?? 0) + 1;
    _derniereActivite = evenement.createdAt;

    notifyListeners();
    onNouvelEvenement?.call(evenement);
  }

  void _decrementer(String kind) {
    final actuel = _nonLus[kind] ?? 0;
    if (actuel > 0) _nonLus[kind] = actuel - 1;
  }

  Future<void> _ouvrirFlux() async {
    if (!_demarre || _connexionEnCours || _abonnement != null) return;

    final token = await ApiService.getToken();
    if (token == null) return;

    _connexionEnCours = true;
    final client = _client ??= http.Client();

    try {
      final requete =
          http.Request(
              'GET',
              Uri.parse('${ApiService.baseUrl}/admin/activity/stream'),
            )
            ..headers['Authorization'] = 'Bearer $token'
            ..headers['Accept'] = 'text/event-stream'
            ..headers['Cache-Control'] = 'no-cache';

      final reponse = await client
          .send(requete)
          .timeout(const Duration(seconds: 12));

      if (reponse.statusCode != 200) {
        _connexionEnCours = false;
        _planifierReconnexion();
        return;
      }

      _connexionEnCours = false;
      _fluxOuvert = true;
      _horsLigne = false;
      notifyListeners();

      _abonnement = reponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _lireLigne,
            onError: (_) => _couperFlux(),
            onDone: _couperFlux,
            cancelOnError: true,
          );
    } catch (_) {
      _connexionEnCours = false;
      _planifierReconnexion();
    }
  }

  void _lireLigne(String ligne) {
    if (!ligne.startsWith('data:')) return;

    final charge = ligne.substring(5).trim();
    if (charge.isEmpty) return;

    try {
      final decode = jsonDecode(charge);
      if (decode is! Map<String, dynamic>) return;

      if (decode.containsKey('reference')) {
        _ajouter(AdminActivityEvent.fromJson(decode));
        return;
      }

      final unread = decode['unread'];
      if (unread is Map) {
        for (final kind in _nonLus.keys.toList()) {
          _nonLus[kind] = num.tryParse('${unread[kind] ?? 0}')?.toInt() ?? 0;
        }
        notifyListeners();
      }
    } catch (_) {
      // Une ligne illisible ne doit pas couper le flux.
    }
  }

  void _couperFlux() {
    _abonnement?.cancel();
    _abonnement = null;
    if (_fluxOuvert) {
      _fluxOuvert = false;
      notifyListeners();
    }
    _planifierReconnexion();
  }

  void _planifierReconnexion() {
    if (!_demarre || _reconnexion != null) return;
    _reconnexion = Timer(_delaiReconnexion, () {
      _reconnexion = null;
      if (_demarre) unawaited(_ouvrirFlux());
    });
  }

  @override
  void dispose() {
    arreter();
    super.dispose();
  }
}
