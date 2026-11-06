// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';

import '../profile_api.dart';
import 'profile_sheet.dart';

/// Valeurs du formulaire « Informations personnelles ».
///
/// Les quatre champs de localisation sont facultatifs : un profil sans ville ni
/// pays reste enregistrable.
class PersonalInfoDraft {
  const PersonalInfoDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.company,
    required this.address,
    required this.city,
    required this.country,
    this.currentPassword = '',
  });

  final String firstName;
  final String lastName;
  final String email;
  final String company;
  final String address;
  final String city;
  final String country;
  final String currentPassword;

  factory PersonalInfoDraft.fromProfile(ProfileRecord profile) {
    return PersonalInfoDraft(
      firstName: profile.firstName,
      lastName: profile.lastName,
      email: profile.email,
      company: profile.company,
      address: profile.address,
      city: profile.city,
      country: profile.country,
    );
  }
}

/// Groupes de champs du formulaire, dans l’ordre du sélecteur.
enum PersonalInfoGroup { coordinates, identity, email }

/// Feuille « Informations personnelles ».
///
/// Un seul formulaire et un seul bouton « Enregistrer » : le sélecteur ne fait
/// que montrer un groupe de champs à la fois, sans perdre les valeurs saisies.
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({
    super.key,
    required this.profile,
    required this.onSubmit,
  });

  final ProfileRecord profile;

  /// Enregistre le formulaire complet ; renvoie vrai si le serveur a accepté.
  final Future<bool> Function(PersonalInfoDraft draft) onSubmit;

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final PersonalInfoDraft _initial = PersonalInfoDraft.fromProfile(
    widget.profile,
  );
  late final TextEditingController _firstName = TextEditingController(
    text: _initial.firstName,
  );
  late final TextEditingController _lastName = TextEditingController(
    text: _initial.lastName,
  );
  late final TextEditingController _email = TextEditingController(
    text: _initial.email,
  );
  late final TextEditingController _company = TextEditingController(
    text: _initial.company,
  );
  late final TextEditingController _address = TextEditingController(
    text: _initial.address,
  );
  late final TextEditingController _city = TextEditingController(
    text: _initial.city,
  );
  late final TextEditingController _country = TextEditingController(
    text: _initial.country,
  );
  final TextEditingController _currentPassword = TextEditingController();

  var _group = PersonalInfoGroup.coordinates;
  bool _isSaving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _company.dispose();
    _address.dispose();
    _city.dispose();
    _country.dispose();
    _currentPassword.dispose();
    super.dispose();
  }

  String? _validateFirstName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Saisissez votre prénom.' : null;

  String? _validateLastName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Saisissez votre nom.' : null;

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : 'Saisissez une adresse e-mail valide.';
  }

  /// Le mot de passe n’est demandé que si l’adresse e-mail change.
  String? _validateCurrentPassword(String? value) {
    final changed = _email.text.trim() != _initial.email.trim();
    if (changed && (value ?? '').isEmpty) {
      return 'Saisissez votre mot de passe actuel pour changer l’e-mail.';
    }
    return null;
  }

  bool get _emailChanged => _email.text.trim() != _initial.email.trim();

  /// Après un refus, montre le groupe qui contient l’erreur.
  void _revealInvalidGroup() {
    if (_validateFirstName(_firstName.text) != null ||
        _validateLastName(_lastName.text) != null) {
      setState(() => _group = PersonalInfoGroup.identity);
      return;
    }
    if (_validateEmail(_email.text) != null ||
        (_emailChanged && _currentPassword.text.isEmpty)) {
      setState(() => _group = PersonalInfoGroup.email);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _revealInvalidGroup();
      return;
    }

    setState(() => _isSaving = true);
    final saved = await widget.onSubmit(
      PersonalInfoDraft(
        firstName: _firstName.text,
        lastName: _lastName.text,
        email: _email.text,
        company: _company.text,
        address: _address.text,
        city: _city.text,
        country: _country.text,
        currentPassword: _currentPassword.text,
      ),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSheetScaffold(
      title: 'Informations personnelles',
      bottomBar: ProfileActionBar(
        children: [
          Expanded(
            child: ProfilePillButton(
              key: const ValueKey('personal-info-save'),
              label: 'Enregistrer',
              busy: _isSaving,
              onPressed: _submit,
            ),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileSegmentedControl(
              labels: const ['Coordonnées', 'Identité', 'E-mail'],
              selectedIndex: _group.index,
              onSelected: (index) =>
                  setState(() => _group = PersonalInfoGroup.values[index]),
            ),
            const SizedBox(height: 16),
            IndexedStack(
              index: _group.index,
              alignment: Alignment.topCenter,
              sizing: StackFit.loose,
              children: [
                _buildGroup(
                  key: const ValueKey('personal-info-coordinates'),
                  fields: [
                    ProfileTextField(
                      key: const ValueKey('profile-city'),
                      label: 'Ville',
                      controller: _city,
                      optional: true,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.addressCity],
                    ),
                    ProfileTextField(
                      key: const ValueKey('profile-country'),
                      label: 'Pays',
                      controller: _country,
                      optional: true,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.countryName],
                    ),
                    ProfileTextField(
                      key: const ValueKey('profile-company'),
                      label: 'Entreprise',
                      controller: _company,
                      optional: true,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.organizationName],
                    ),
                    ProfileTextField(
                      key: const ValueKey('profile-address'),
                      label: 'Adresse',
                      controller: _address,
                      optional: true,
                      textCapitalization: TextCapitalization.sentences,
                      autofillHints: const [AutofillHints.streetAddressLine1],
                    ),
                  ],
                ),
                _buildGroup(
                  key: const ValueKey('personal-info-identity'),
                  fields: [
                    ProfileTextField(
                      key: const ValueKey('profile-first-name'),
                      label: 'Prénom',
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.givenName],
                      validator: _validateFirstName,
                    ),
                    ProfileTextField(
                      key: const ValueKey('profile-last-name'),
                      label: 'Nom',
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.familyName],
                      validator: _validateLastName,
                    ),
                  ],
                ),
                _buildGroup(
                  key: const ValueKey('personal-info-email'),
                  fields: [
                    ProfileTextField(
                      key: const ValueKey('profile-email'),
                      label: 'Adresse e-mail',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: _validateEmail,
                    ),
                    ProfileTextField(
                      key: const ValueKey('profile-current-password'),
                      label: 'Mot de passe actuel',
                      controller: _currentPassword,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      helperText: 'Requis si vous changez votre e-mail.',
                      validator: _validateCurrentPassword,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup({required Key key, required List<Widget> fields}) {
    final children = <Widget>[];
    for (var index = 0; index < fields.length; index++) {
      if (index > 0) children.add(const SizedBox(height: 16));
      children.add(fields[index]);
    }

    return ProfileCard(
      key: key,
      divide: false,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}
