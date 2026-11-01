import 'package:echelle_eg_39/app_links.dart';
import 'package:echelle_eg_39/company_contact.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const _androidUrl =
    'https://play.google.com/store/apps/details?id=com.okata.echelleeg39';
const _iosUrl = 'https://apps.apple.com/app/id1234567890';

void main() {
  test('l’application est annoncée comme non publiée par défaut', () {
    expect(AppLinks.isPublished, isFalse);
    expect(AppLinks.storeLinks, isEmpty);
    expect(
      AppLinks.unavailableNotice,
      contains('n’est pas encore publiée sur Google Play'),
    );
  });

  test('le message d’invitation reprend les liens fournis', () {
    final message = AppLinks.inviteMessage(
      androidUrl: _androidUrl,
      iosUrl: _iosUrl,
    );

    expect(message, contains(CompanyContact.name));
    expect(message, contains('Android (Google Play) : $_androidUrl'));
    expect(message, contains('iPhone (App Store) : $_iosUrl'));
  });

  test('le message ne cite que les stores déjà publiés', () {
    final androidOnly = AppLinks.inviteMessage(
      androidUrl: _androidUrl,
      iosUrl: '',
    );

    expect(androidOnly, contains('Android (Google Play)'));
    expect(androidOnly, isNot(contains('App Store')));
  });

  test('les liens sont ordonnés Android puis iPhone', () {
    final links = AppLinks.buildStoreLinks(
      androidUrl: _androidUrl,
      iosUrl: _iosUrl,
    );

    expect(links, hasLength(2));
    expect(links.first.platform, StorePlatform.android);
    expect(links.first.name, 'Google Play');
    expect(links.last.platform, StorePlatform.ios);
    expect(links.last.name, 'App Store');
  });

  test('chaque téléphone reçoit le lien de son store', () {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      expect(
        AppLinks.storeUrlForThisDevice(
          androidUrl: _androidUrl,
          iosUrl: _iosUrl,
        ),
        _iosUrl,
      );
    } else {
      expect(
        AppLinks.storeUrlForThisDevice(
          androidUrl: _androidUrl,
          iosUrl: _iosUrl,
        ),
        _androidUrl,
      );
    }

    // Si un seul store existe, on renvoie celui-là quel que soit l’appareil.
    expect(
      AppLinks.storeUrlForThisDevice(androidUrl: '', iosUrl: _iosUrl),
      _iosUrl,
    );
    expect(AppLinks.storeUrlForThisDevice(androidUrl: '', iosUrl: ''), isNull);
  });
}
