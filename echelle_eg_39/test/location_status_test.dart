import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/location_status.dart';

void main() {
  group('normalizeLocationStatus', () {
    test('normalise les statuts de réservation du backend', () {
      expect(normalizeLocationStatus('en_attente'), 'en-attente');
      expect(normalizeLocationStatus('approuvee'), 'approuvee');
      expect(normalizeLocationStatus('en_cours'), 'en-cours');
      expect(normalizeLocationStatus('en_retard'), 'en-retard');
      expect(normalizeLocationStatus('termine'), 'termine');
      expect(normalizeLocationStatus('rejetee'), 'rejetee');
      expect(normalizeLocationStatus('annulee'), 'annulee');
    });

    test('accepte les variantes accentuées, anglaises et les séparateurs', () {
      expect(normalizeLocationStatus(' Approuvée '), 'approuvee');
      expect(normalizeLocationStatus('Annulée'), 'annulee');
      expect(normalizeLocationStatus('cancelled'), 'annulee');
      expect(normalizeLocationStatus('Overdue'), 'en-retard');
    });

    test('ne classe pas les valeurs inconnues comme des demandes en attente', () {
      expect(normalizeLocationStatus(null), 'inconnu');
      expect(normalizeLocationStatus('legacy_unknown'), 'inconnu');
    });
  });
}
