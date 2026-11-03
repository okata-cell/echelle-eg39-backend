import 'package:flutter/material.dart';

import 'profile_sheet.dart';

/// Conditions d’utilisation : éditeur, responsabilité, propriété.
class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'Conditions d’utilisation',
      child: ProfileCard(
        dividerInset: 20,
        children: const [
          ProfileDocumentBlock(
            heading: 'Éditeur de l’application',
            paragraphs: ['ÉCHELLE EG39', 'Lomé, Togo', 'SIRET : 123456789'],
          ),
          ProfileDocumentBlock(
            heading: 'Responsabilité',
            paragraphs: [
              'L’application est fournie « en l’état » sans garantie. Nous nous '
                  'efforçons d’assurer l’exactitude des informations mais ne '
                  'pouvons être tenus responsables des erreurs.',
            ],
          ),
          ProfileDocumentBlock(
            heading: 'Propriété intellectuelle',
            paragraphs: [
              'Tous les contenus de l’application sont protégés des droits '
                  'd’auteur.',
            ],
          ),
        ],
      ),
    );
  }
}
