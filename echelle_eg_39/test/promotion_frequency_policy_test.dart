import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:echelle_eg_39/promotion_frequency_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'une fréquence quotidienne est mémorisée séparément par promotion',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final policy = PromotionFrequencyPolicy(preferences: preferences);
      final today = DateTime(2026, 10, 11, 9);

      expect(
        await policy.shouldShow(
          promotionId: '18',
          frequency: 'une_fois_par_jour',
          now: today,
        ),
        isTrue,
      );
      await policy.recordShown(
        promotionId: '18',
        frequency: 'une_fois_par_jour',
        now: today,
      );
      expect(
        await policy.shouldShow(
          promotionId: '18',
          frequency: 'une_fois_par_jour',
          now: DateTime(2026, 10, 11, 21),
        ),
        isFalse,
      );
      expect(
        await policy.shouldShow(
          promotionId: '19',
          frequency: 'une_fois_par_jour',
          now: today,
        ),
        isTrue,
        reason: 'une nouvelle promotion doit pouvoir s’afficher le même jour',
      );
      expect(
        await policy.shouldShow(
          promotionId: '18',
          frequency: 'une_fois_par_jour',
          now: DateTime(2026, 10, 12),
        ),
        isTrue,
      );
    },
  );

  test('une seule fois est mémorisée pour chaque identifiant', () async {
    final preferences = await SharedPreferences.getInstance();
    final policy = PromotionFrequencyPolicy(preferences: preferences);
    final today = DateTime(2026, 10, 11);

    await policy.recordShown(
      promotionId: '18',
      frequency: 'une_seule_fois',
      now: today,
    );
    expect(
      await policy.shouldShow(
        promotionId: '18',
        frequency: 'une_seule_fois',
        now: DateTime(2027, 1, 1),
      ),
      isFalse,
    );
    expect(
      await policy.shouldShow(
        promotionId: '19',
        frequency: 'une_seule_fois',
        now: today,
      ),
      isTrue,
    );
  });

  test('à chaque ouverture ne persiste pas après la session', () async {
    final preferences = await SharedPreferences.getInstance();
    final session = <String>{};
    final policy = PromotionFrequencyPolicy(
      preferences: preferences,
      sessionShownIds: session,
    );
    final now = DateTime(2026, 10, 11);

    expect(
      await policy.shouldShow(
        promotionId: '18',
        frequency: 'chaque_ouverture',
        now: now,
      ),
      isTrue,
    );
    await policy.recordShown(
      promotionId: '18',
      frequency: 'chaque_ouverture',
      now: now,
    );
    expect(
      await policy.shouldShow(
        promotionId: '18',
        frequency: 'chaque_ouverture',
        now: now,
      ),
      isFalse,
    );
    expect(preferences.getKeys(), isEmpty);
    expect(
      await PromotionFrequencyPolicy(
        preferences: preferences,
        sessionShownIds: <String>{},
      ).shouldShow(promotionId: '18', frequency: 'chaque_ouverture', now: now),
      isTrue,
    );
  });
}
