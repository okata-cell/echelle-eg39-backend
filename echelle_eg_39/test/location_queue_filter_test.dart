import 'package:flutter_test/flutter_test.dart';

import 'package:echelle_eg_39/admin/location_queue_filter.dart';

void main() {
  const locations = <Map<String, dynamic>>[
    {'id': 1, 'statut': 'en_attente'},
    {'id': 2, 'statut': 'en_cours'},
    {'id': 3, 'statut': 'termine'},
    {'id': 4, 'statut': 'rejetee'},
    {'id': 5, 'statut': 'annulee'},
    {'id': 6, 'statut': 'cancelled'},
    {'id': 7, 'statut': 'legacy_unknown'},
  ];

  test('classe chaque statut dans le bon onglet', () {
    expect(
      filterLocationsForQueue(
        locations,
        LocationQueueFilter.pending,
      ).map((location) => location['id']),
      [1],
    );
    expect(
      filterLocationsForQueue(
        locations,
        LocationQueueFilter.inProgress,
      ).map((location) => location['id']),
      [2],
    );
    expect(
      filterLocationsForQueue(
        locations,
        LocationQueueFilter.completed,
      ).map((location) => location['id']),
      [3],
    );
    expect(
      filterLocationsForQueue(
        locations,
        LocationQueueFilter.history,
      ).map((location) => location['id']),
      [4, 5, 6],
    );
    expect(
      filterLocationsForQueue(
        locations,
        LocationQueueFilter.all,
      ).map((location) => location['id']),
      [1, 2, 3, 4, 5, 6, 7],
    );
  });

  test('calcule les badges à partir du même classement que les onglets', () {
    expect(countLocationsForQueue(locations, LocationQueueFilter.pending), 1);
    expect(
      countLocationsForQueue(locations, LocationQueueFilter.inProgress),
      1,
    );
    expect(countLocationsForQueue(locations, LocationQueueFilter.completed), 1);
    expect(countLocationsForQueue(locations, LocationQueueFilter.history), 3);
    expect(countLocationsForQueue(locations, LocationQueueFilter.all), 7);
  });
}
