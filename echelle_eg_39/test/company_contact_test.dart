import 'package:echelle_eg_39/company_contact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('l’adresse e-mail affichée est celle exploitée par l’entreprise', () {
    expect(CompanyContact.email, 'admin@echelle-eg39.com');
    expect(CompanyContact.emailUri.scheme, 'mailto');
    expect(CompanyContact.emailUri.path, 'admin@echelle-eg39.com');
  });

  test('le téléphone et WhatsApp gardent le même numéro', () {
    expect(CompanyContact.phoneDisplay, '+228 90 01 43 29');
    expect(CompanyContact.phoneUri.scheme, 'tel');
    expect(CompanyContact.phoneUri.path, '+22890014329');
    expect(CompanyContact.whatsAppUri().host, 'wa.me');
    expect(CompanyContact.whatsAppUri().path, '/22890014329');
  });

  test('le partage libre ne cible aucun destinataire', () {
    final share = CompanyContact.whatsAppShareUri('Bonjour');
    expect(share.path, '/');
    expect(share.queryParameters['text'], 'Bonjour');
  });

  test('le message e-mail pré-remplit objet et corps', () {
    final uri = CompanyContact.emailUriWith(
      subject: 'ÉCHELLE EG39',
      body: CompanyContact.introduction,
    );

    expect(uri.scheme, 'mailto');
    expect(uri.path, 'admin@echelle-eg39.com');
    expect(uri.queryParameters['subject'], 'ÉCHELLE EG39');
    expect(uri.queryParameters['body'], contains('admin@echelle-eg39.com'));
    expect(CompanyContact.introduction, contains('admin@echelle-eg39.com'));
    expect(CompanyContact.introduction, isNot(contains('contact@')));
  });

  test('les messages de repli citent la bonne adresse', () {
    expect(
      CompanyContact.emailFallbackMessage,
      'Aucune application e-mail. Adresse copiée : admin@echelle-eg39.com',
    );
    expect(
      CompanyContact.phoneFallbackMessage,
      'Aucune application d’appel. Numéro copié : +228 90 01 43 29',
    );
  });
}
