import 'dart:async';

import 'package:echelle_eg_39/ventes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> appareil({
  required int id,
  required String code,
  required String nom,
  required String type,
  required int prixVente,
  bool disponible = true,
}) => {
  'id': id,
  'code': code,
  'nom': nom,
  'type': type,
  'prixVente': prixVente,
  'disponible': disponible,
  'imageUrl': 'https://example.test/$code.jpg',
};

void _useMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(375, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _venteApp({
  required VenteProductsLoader loadProducts,
  VentePendingDemandesLoader? loadPendingDemandes,
  VentePurchaseCreator? createPurchaseRequest,
}) {
  return MaterialApp(
    home: VenteScreen(
      loadProducts: loadProducts,
      loadPendingDemandes: loadPendingDemandes ?? () async => [],
      createPurchaseRequest: createPurchaseRequest,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'token': 'test-token',
      'userEmail': 'browse@example.com',
    });
  });

  testWidgets('affiche le catalogue photo-first avec prix et stock lisibles', (
    tester,
  ) async {
    _useMobileViewport(tester);
    await tester.pumpWidget(
      _venteApp(
        loadProducts: () async => [
          appareil(
            id: 2,
            code: 'APP-002',
            nom: 'GPS e-survey E800',
            type: 'GPS',
            prixVente: 1200000,
          ),
          appareil(
            id: 1,
            code: 'APP-001',
            nom: 'GPS e-survey E600',
            type: 'GPS',
            prixVente: 2500000,
            disponible: false,
          ),
          appareil(
            id: 3,
            code: 'APP-003',
            nom: 'Niveau Leica',
            type: 'Niveau',
            prixVente: 1200000,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vente d’appareils'), findsOneWidget);
    expect(find.text('GPS e-survey E800'), findsOneWidget);
    expect(find.text('1 200 000 FCFA'), findsOneWidget);
    expect(find.text('En stock'), findsOneWidget);
    expect(find.text('Demander l’achat'), findsOneWidget);
    expect(
      find.byTooltip('Agrandir la photo de GPS e-survey E800'),
      findsOneWidget,
    );
    final productsList = find.byKey(const ValueKey('vente-products-list'));
    expect(productsList, findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('GPS e-survey E600'),
      260,
      scrollable: find
          .descendant(of: productsList, matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('2 500 000 FCFA'), findsOneWidget);
    expect(find.text('Rupture de stock'), findsNWidgets(2));

    await tester.scrollUntilVisible(
      find.text('Niveau Leica'),
      260,
      scrollable: find
          .descendant(of: productsList, matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('Niveau Leica'), findsOneWidget);
    expect(find.byKey(const ValueKey('vente-product-photo-3')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('recherche, filtres et effacement restent fonctionnels', (
    tester,
  ) async {
    _useMobileViewport(tester);
    await tester.pumpWidget(
      _venteApp(
        loadProducts: () async => [
          appareil(
            id: 2,
            code: 'APP-002',
            nom: 'GPS e-survey E800',
            type: 'GPS',
            prixVente: 1200000,
          ),
          appareil(
            id: 3,
            code: 'APP-003',
            nom: 'Niveau Leica',
            type: 'Niveau',
            prixVente: 1200000,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final search = find.byKey(const ValueKey('vente-search-field'));
    await tester.enterText(search, 'niveau');
    await tester.pumpAndSettle();
    expect(find.text('Niveau Leica'), findsOneWidget);
    expect(find.text('GPS e-survey E800'), findsNothing);

    await tester.tap(find.byTooltip('Effacer la recherche'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    expect(find.text('GPS e-survey E800'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vente-category-GPS')));
    await tester.pumpAndSettle();
    expect(find.text('GPS e-survey E800'), findsOneWidget);
    expect(find.text('Niveau Leica'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('le chargement initial ne montre pas un faux état vide', (
    tester,
  ) async {
    _useMobileViewport(tester);
    final products = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(_venteApp(loadProducts: () => products.future));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Aucun appareil à vendre'), findsNothing);

    products.complete([
      appareil(
        id: 2,
        code: 'APP-002',
        nom: 'GPS e-survey E800',
        type: 'GPS',
        prixVente: 1200000,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('GPS e-survey E800'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('une erreur de chargement peut être relancée', (tester) async {
    _useMobileViewport(tester);
    var loadCalls = 0;
    await tester.pumpWidget(
      _venteApp(
        loadProducts: () async {
          loadCalls++;
          if (loadCalls == 1) throw Exception('offline');
          return [
            appareil(
              id: 2,
              code: 'APP-002',
              nom: 'GPS e-survey E800',
              type: 'GPS',
              prixVente: 1200000,
            ),
          ];
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger les appareils.'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(loadCalls, 2);
    expect(find.text('GPS e-survey E800'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('confirme une demande et bloque les doubles soumissions', (
    tester,
  ) async {
    _useMobileViewport(tester);
    SharedPreferences.setMockInitialValues({
      'token': 'test-token',
      'userEmail': 'purchaser@example.com',
      'userName': 'Client Test',
    });
    final submitRequest = Completer<Map<String, dynamic>>();
    var submitCalls = 0;

    await tester.pumpWidget(
      _venteApp(
        loadProducts: () async => [
          appareil(
            id: 2,
            code: 'APP-002',
            nom: 'GPS e-survey E800',
            type: 'GPS',
            prixVente: 1200000,
          ),
        ],
        createPurchaseRequest: (id, quantity) {
          submitCalls++;
          expect(id, 2);
          expect(quantity, 1);
          return submitRequest.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Demander l’achat'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Cette demande sera soumise à validation. Aucun paiement n’est effectué ici.',
      ),
      findsOneWidget,
    );
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Envoyer la demande'));
    await tester.pump();
    expect(submitCalls, 1);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('vente-submit-request')),
          )
          .onPressed,
      isNull,
    );

    submitRequest.complete({});
    await tester.pumpAndSettle();
    expect(find.textContaining('En attente de validation.'), findsOneWidget);
    expect(find.text('Demande en attente'), findsNWidgets(2));
    expect(submitCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('une erreur d’envoi reste dans le dialogue sans faux succès', (
    tester,
  ) async {
    _useMobileViewport(tester);
    var submitCalls = 0;
    await tester.pumpWidget(
      _venteApp(
        loadProducts: () async => [
          appareil(
            id: 2,
            code: 'APP-002',
            nom: 'GPS e-survey E800',
            type: 'GPS',
            prixVente: 1200000,
          ),
        ],
        createPurchaseRequest: (_, _) async {
          submitCalls++;
          throw Exception('offline');
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Demander l’achat').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer la demande'));
    await tester.pumpAndSettle();

    expect(submitCalls, 1);
    expect(
      find.text('La demande n’a pas pu être envoyée. Réessayez.'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('vente-submit-request')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
