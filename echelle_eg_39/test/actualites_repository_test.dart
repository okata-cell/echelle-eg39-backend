import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echelle_eg_39/actualite.dart';
import 'package:echelle_eg_39/actualites_repository.dart';

Map<String, dynamic> _row({
  required int id,
  required String titre,
  String date = '2026-11-06',
  String? dateFin,
  bool epingle = false,
}) {
  return <String, dynamic>{
    'id': id,
    'titre': titre,
    'description': 'Description de $titre.',
    'date_publication': date,
    'date_fin': dateFin,
    'statut': 'publiee',
    'epingle': epingle,
    'image_url': null,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'met en cache le contenu reçu puis efface le cache si la liste est vide',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var payload = <Map<String, dynamic>>[
        _row(id: 1, titre: 'Nouvelle gamme E800'),
      ];

      final repository = ActualitesRepository(
        fetchPublished: ({int limit = 20}) async => payload,
      );

      var snapshot = await repository.refresh(limit: 3);
      expect(snapshot.items, hasLength(1));
      expect((await repository.readCache()).items, hasLength(1));

      // L'administrateur dépublie ou supprime la dernière actualité.
      payload = <Map<String, dynamic>>[];
      snapshot = await repository.refresh(limit: 3);
      expect(snapshot.items, isEmpty);
      expect((await repository.readCache()).items, isEmpty);
    },
  );

  test('trie l’épinglée en tête, puis la plus récente', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repository = ActualitesRepository(
      fetchPublished: ({int limit = 20}) async => [
        _row(id: 1, titre: 'Récente', date: '2026-11-06'),
        _row(id: 2, titre: 'Ancienne', date: '2026-10-30'),
        _row(id: 3, titre: 'Épinglée', date: '2026-10-01', epingle: true),
      ],
    );

    final snapshot = await repository.refresh();
    expect(snapshot.items.map((actualite) => actualite.titre).toList(), [
      'Épinglée',
      'Récente',
      'Ancienne',
    ]);
  });

  test(
    'ignore une actualité dont la fenêtre de publication est passée',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repository = ActualitesRepository(
        fetchPublished: ({int limit = 20}) async => [
          _row(
            id: 9,
            titre: 'Annonce périmée',
            date: '2020-01-01',
            dateFin: '2020-01-31',
          ),
        ],
      );

      await repository.refresh();
      expect((await repository.readCache()).items, isEmpty);
    },
  );

  test('formate la fenêtre de publication', () {
    final memeMois = Actualite.tryParse(
      _row(id: 1, titre: 'Même mois', dateFin: '2026-11-30'),
    )!;
    expect(memeMois.periodeLabel, 'Du 06 au 30 nov. 2026');
    expect(memeMois.estEnLigneLe(DateTime(2026, 11, 20)), isTrue);
    expect(memeMois.estEnLigneLe(DateTime(2026, 12, 1)), isFalse);
    expect(memeMois.estEnLigneLe(DateTime(2026, 11, 5)), isFalse);

    final autreMois = Actualite.tryParse(
      _row(id: 2, titre: 'Autre mois', dateFin: '2026-12-12'),
    )!;
    expect(autreMois.periodeLabel, 'Du 06 nov. au 12 déc. 2026');

    final sansFin = Actualite.tryParse(_row(id: 3, titre: 'Sans fin'))!;
    expect(sansFin.periodeLabel, '06 nov. 2026');
    expect(sansFin.estEnLigneLe(DateTime(2030, 1, 1)), isTrue);
  });

  test('lit le cache et respecte la limite de l’accueil', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repository = ActualitesRepository(
      fetchPublished: ({int limit = 20}) async => [
        _row(id: 1, titre: 'Une', date: '2026-11-06'),
        _row(id: 2, titre: 'Deux', date: '2026-11-05'),
        _row(id: 3, titre: 'Trois', date: '2026-11-04'),
      ],
    );

    await repository.refresh();
    final cache = await repository.readCache(
      limit: ActualitesRepository.homeLimit,
    );
    expect(cache.fromCache, isTrue);
    expect(cache.items, hasLength(3));
  });
}
