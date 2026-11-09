import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/actualite.dart';

void main() {
  test('la fin se compte à compter du début', () {
    final debut = DateTime(2026, 11, 6);

    expect(actualiteFinParDefaut(debut), DateTime(2026, 12, 6));
    expect(actualiteDureeDiffusionDefaut, 30);
  });

  test('compte les jours affichés, bornes comprises', () {
    expect(
      actualiteJoursDiffusion(DateTime(2026, 11, 6), DateTime(2026, 11, 30)),
      25,
    );
    expect(
      actualiteJoursDiffusion(DateTime(2026, 11, 6), DateTime(2026, 11, 6)),
      1,
    );
    expect(actualiteJoursDiffusion(DateTime(2026, 11, 6), null), 0);
  });

  test('déplacer le début décale la fin sans changer la durée', () {
    final debut = DateTime(2026, 11, 6);
    final fin = DateTime(2026, 12, 6);
    final nouveauDebut = DateTime(2026, 11, 20);

    final nouvelleFin = actualiteFinApresDeplacement(
      ancienDebut: debut,
      ancienneFin: fin,
      nouveauDebut: nouveauDebut,
    );

    expect(nouvelleFin, DateTime(2026, 12, 20));
    expect(
      actualiteJoursDiffusion(nouveauDebut, nouvelleFin),
      actualiteJoursDiffusion(debut, fin),
    );
  });

  test('une fenêtre incohérente repart sur la durée par défaut', () {
    final nouvelleFin = actualiteFinApresDeplacement(
      ancienDebut: DateTime(2026, 11, 20),
      ancienneFin: DateTime(2026, 11, 10),
      nouveauDebut: DateTime(2026, 12, 1),
    );

    expect(nouvelleFin, DateTime(2026, 12, 31));
  });
}
