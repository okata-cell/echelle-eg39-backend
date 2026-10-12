import 'package:shared_preferences/shared_preferences.dart';

/// Persists exposure independently for each promotion.
///
/// `chaque_ouverture` is intentionally held only for the current app process;
/// daily and once-ever choices survive app restarts per promotion ID.
class PromotionFrequencyPolicy {
  PromotionFrequencyPolicy({
    required this._preferences,
    Set<String>? sessionShownIds,
  }) : _sessionShownIds = sessionShownIds ?? _defaultSessionShownIds;

  static final Set<String> _defaultSessionShownIds = <String>{};
  static const String _dailyKeyPrefix = 'promotion_shown_date_';
  static const String _onceKeyPrefix = 'promotion_shown_once_';

  final SharedPreferences _preferences;
  final Set<String> _sessionShownIds;

  Future<bool> shouldShow({
    required String promotionId,
    required String frequency,
    required DateTime now,
  }) async {
    final id = promotionId.trim();
    if (id.isEmpty) return false;

    switch (frequency) {
      case 'chaque_ouverture':
        return !_sessionShownIds.contains(id);
      case 'une_fois_par_jour':
        final lastShownDate = _preferences.getString('$_dailyKeyPrefix$id');
        return lastShownDate != _dateKey(now);
      case 'une_seule_fois':
        return _preferences.getBool('$_onceKeyPrefix$id') != true;
      default:
        // Legacy/unknown values use the least intrusive supported fallback.
        final lastShownDate = _preferences.getString('$_dailyKeyPrefix$id');
        return lastShownDate != _dateKey(now);
    }
  }

  Future<void> recordShown({
    required String promotionId,
    required String frequency,
    required DateTime now,
  }) async {
    final id = promotionId.trim();
    if (id.isEmpty) return;

    switch (frequency) {
      case 'chaque_ouverture':
        _sessionShownIds.add(id);
        return;
      case 'une_fois_par_jour':
        await _preferences.setString('$_dailyKeyPrefix$id', _dateKey(now));
        return;
      case 'une_seule_fois':
        await _preferences.setBool('$_onceKeyPrefix$id', true);
        return;
      default:
        await _preferences.setString('$_dailyKeyPrefix$id', _dateKey(now));
        return;
    }
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
