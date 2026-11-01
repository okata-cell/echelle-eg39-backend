import 'package:echelle_eg_39/company_contact.dart';
import 'package:echelle_eg_39/company_location.dart';
import 'package:echelle_eg_39/company_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le message partagé contient les coordonnées et le lien public', () {
    expect(CompanyShare.message, CompanyContact.introduction);
    expect(CompanyShare.fullMessage, contains(CompanyContact.phoneDisplay));
    expect(CompanyShare.fullMessage, contains(CompanyContact.email));
    expect(CompanyShare.fullMessage, contains(CompanyLocation.mapsUrl));
  });

  test('WhatsApp laisse choisir le destinataire avec le message complet', () {
    final uri = CompanyShare.whatsAppUri();
    expect(uri.host, 'wa.me');
    expect(uri.path, '/');
    expect(uri.queryParameters['text'], CompanyShare.fullMessage);
  });

  test('Facebook, Telegram, X et LinkedIn pointent le lien public', () {
    final facebook = CompanyShare.facebookUri();
    expect(facebook.host, 'www.facebook.com');
    expect(facebook.path, '/sharer/sharer.php');
    expect(facebook.queryParameters['u'], CompanyLocation.mapsUrl);

    final telegram = CompanyShare.telegramUri();
    expect(telegram.host, 't.me');
    expect(telegram.queryParameters['url'], CompanyLocation.mapsUrl);

    final x = CompanyShare.xUri();
    expect(x.path, '/intent/tweet');
    expect(x.queryParameters['url'], CompanyLocation.mapsUrl);

    final linkedIn = CompanyShare.linkedInUri();
    expect(linkedIn.path, '/sharing/share-offsite/');
    expect(linkedIn.queryParameters['url'], CompanyLocation.mapsUrl);
  });

  test('l’e-mail part vers la boîte exploitée avec objet et corps', () {
    final uri = CompanyShare.emailUri();
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'admin@echelle-eg39.com');
    expect(uri.queryParameters['subject'], contains('ÉCHELLE EG39'));
    expect(uri.queryParameters['body'], CompanyShare.fullMessage);
  });

  test('Instagram ouvre l’application puis le site en repli', () {
    expect(CompanyShare.instagramAppUri().scheme, 'instagram');
    expect(CompanyShare.instagramWebUri().host, 'www.instagram.com');
    expect(
      CompanyShare.instagramCopiedMessage,
      'Message copié. Collez-le dans Instagram.',
    );
  });
}
