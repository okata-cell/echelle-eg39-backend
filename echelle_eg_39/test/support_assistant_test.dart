import 'package:echelle_eg_39/company_contact.dart';
import 'package:echelle_eg_39/company_location.dart';
import 'package:echelle_eg_39/support_assistant.dart';
import 'package:echelle_eg_39/support_knowledge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const assistant = SupportAssistant();

  test('la normalisation ignore accents, casse et ponctuation', () {
    expect(
      SupportAssistant.normalize('Où êtes-vous situés ?'),
      'ou etes vous situes',
    );
    expect(SupportAssistant.normalize('HORAIRES'), 'horaires');
  });

  test('les horaires sont reconnus', () {
    final reply = assistant.answer('Quels sont vos horaires ?');
    expect(reply, isNotNull);
    expect(reply!.answer, contains('8h à 18h'));
  });

  test('l’adresse et le lien de localisation sont reconnus', () {
    final reply = assistant.answer('Où se trouve votre agence à Lomé ?');
    expect(reply, isNotNull);
    expect(reply!.answer, contains(CompanyLocation.address));
  });

  test('les coordonnées reprennent le vrai numéro et le vrai e-mail', () {
    final reply = assistant.answer('Je voudrais votre numéro de téléphone');
    expect(reply, isNotNull);
    expect(reply!.answer, contains(CompanyContact.phoneDisplay));
    expect(reply.answer, contains(CompanyContact.email));
  });

  test('les services et la garantie sont reconnus', () {
    final services = assistant.answer('Quels services proposez-vous ?');
    expect(services, isNotNull);
    expect(services!.answer, contains('location'));
    expect(services.answer, contains('formation'));

    final warranty = assistant.answer('La vente est-elle garantie ?');
    expect(warranty, isNotNull);
    expect(warranty!.answer, contains('2 ans'));
  });

  test('les partenaires cités sont ceux du menu', () {
    final reply = assistant.answer('Qui sont vos partenaires ?');
    expect(reply, isNotNull);
    expect(reply!.answer, contains('Leica'));
    expect(reply.answer, contains('e-survey'));
  });

  test('la réservation renvoie vers la section Locations', () {
    final reply = assistant.answer('Comment réserver un équipement ?');
    expect(reply, isNotNull);
    expect(reply!.answer, contains('Locations'));
  });

  test('la question de précision GPS donne la valeur de la FAQ', () {
    final reply = assistant.answer('Quelle est la précision du GPS e-survey ?');
    expect(reply, isNotNull);
    expect(reply!.answer, contains('2 à 5 mm'));
  });

  test('une salutation obtient un accueil, sans escalade', () {
    final reply = assistant.answer('Bonjour');
    expect(reply, isNotNull);
    expect(reply!.matchedLabel, 'Accueil');
    expect(reply.answer, contains('fiche de l’entreprise'));
  });

  test('une question hors fiche ne reçoit aucune réponse inventée', () {
    for (final question in [
      'Quel est le prix du carburant à la pompe ?',
      'Pouvez-vous réparer mon ordinateur portable ?',
      'Quelle est la météo de demain ?',
    ]) {
      expect(
        assistant.answer(question),
        isNull,
        reason: '« $question » doit partir au support humain',
      );
    }
  });

  test('chaque sujet de la base est utilisable et sans doublon', () {
    final questions = kSupportTopics.map((topic) => topic.question).toList();
    expect(questions.toSet(), hasLength(questions.length));
    for (final topic in kSupportTopics) {
      expect(topic.answer.length, greaterThan(30));
      expect(topic.keywords, isNotEmpty);
      expect(
        assistant.answer(topic.question),
        isNotNull,
        reason: 'la question « ${topic.question} » doit être reconnue',
      );
    }
  });
}
