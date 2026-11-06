// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';

import 'profile_sheet.dart';

/// Catalogue des services proposés, sans action de réservation.
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  static const List<({String name, String detail})> _services = [
    (name: 'Vente', detail: 'Équipements neufs avec garantie 2 ans'),
    (
      name: 'Location',
      detail: 'GPS, théodolites, niveaux et stations totales',
    ),
    (name: 'Formation', detail: 'Initiation et perfectionnement'),
    (name: 'Réparation', detail: 'Service après-vente et maintenance'),
    (
      name: 'Mise à jour des logiciels',
      detail: 'Logiciels de calcul et de CAO',
    ),
    (name: 'Support technique', detail: 'Assistance 24h/24 et 7j/7'),
  ];

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'Services',
      child: ProfileCard(
        children: [
          for (final service in _services)
            ProfileSheetRow(
              key: ValueKey('service-${service.name}'),
              title: service.name,
              subtitle: service.detail,
              minHeight: 72,
            ),
        ],
      ),
    );
  }
}
