import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'main.dart';
import 'offline_registration_store.dart';
import 'password_recovery_scaffold.dart';
import 'sync_service.dart';

typedef RegisterAccountRequest =
    Future<Map<String, dynamic>> Function(
      String firstName,
      String lastName,
      String email,
      String phone,
      String password,
    );
typedef OfflineAccountSaver =
    Future<bool> Function(OfflineRegistrationDraft registration);

const _registrationBlue = Color(0xFF0066CC);
const _registrationInk = Color(0xFF1D1D1F);
const _registrationMuted = Color(0xFF646970);
const _registrationBorder = Color(0xFFD5D8D8);
const _registrationError = Color(0xFFAA5141);
const _phonePrefix = '+228';

class _TogoPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.trim().replaceAll(RegExp(r'[\s().-]'), '');
    final local = raw.startsWith(_phonePrefix)
        ? raw.substring(_phonePrefix.length).replaceAll(RegExp(r'\D'), '')
        : raw.replaceAll(RegExp(r'\D'), '');
    final digits = local.length > 9 ? local.substring(0, 9) : local;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    this.registerAccount = ApiService.register,
    this.saveOfflineAccount = SyncService.saveUserForLaterSync,
  });

  final RegisterAccountRequest registerAccount;
  final OfflineAccountSaver saveOfflineAccount;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _firstNameFieldKey = GlobalKey<FormFieldState<String>>();
  final _lastNameFieldKey = GlobalKey<FormFieldState<String>>();
  final _emailFieldKey = GlobalKey<FormFieldState<String>>();
  final _phoneFieldKey = GlobalKey<FormFieldState<String>>();
  final _passwordFieldKey = GlobalKey<FormFieldState<String>>();
  final _confirmPasswordFieldKey = GlobalKey<FormFieldState<String>>();

  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  late final AnimationController _entranceController;
  late final Animation<double> _entranceFade;
  late final Animation<Offset> _entranceSlide;
  Timer? _navigationTimer;

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    final easedEntrance = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _entranceFade = easedEntrance;
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.075),
      end: Offset.zero,
    ).animate(easedEntrance);
    _entranceController.forward();
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _entranceController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  String? _validateName(String? value, String label) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Le $label est requis.';
    if (name.length > 100) return '100 caractères maximum.';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'L’adresse e-mail est requise.';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email)) {
      return 'Vérifiez le format de l’adresse e-mail.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final digits = value?.trim() ?? '';
    if (digits.length != 8 && digits.length != 9) {
      return 'Entrez 8 ou 9 chiffres après +228.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Le mot de passe est requis.';
    if (!RegExp(r'^\d{4}[A-Z]{4}$').hasMatch(value)) {
      return '4 chiffres puis 4 lettres majuscules (ex. 1234AZER).';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirmez votre mot de passe.';
    }
    if (value != _passwordController.text) {
      return 'Les mots de passe ne correspondent pas.';
    }
    return null;
  }

  Future<void> _focusFirstInvalidField() async {
    final fields = <(GlobalKey<FormFieldState<String>>, FocusNode)>[
      (_firstNameFieldKey, _firstNameFocus),
      (_lastNameFieldKey, _lastNameFocus),
      (_emailFieldKey, _emailFocus),
      (_phoneFieldKey, _phoneFocus),
      (_passwordFieldKey, _passwordFocus),
      (_confirmPasswordFieldKey, _confirmPasswordFocus),
    ];

    for (final (key, focusNode) in fields) {
      if (key.currentState?.hasError != true) continue;
      focusNode.requestFocus();
      final fieldContext = key.currentContext;
      if (fieldContext != null) {
        await Scrollable.ensureVisible(
          fieldContext,
          alignment: 0.25,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      await _focusFirstInvalidField();
      return;
    }

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = '$_phonePrefix${_phoneController.text.trim()}';
    final password = _passwordController.text;

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      await widget.registerAccount(firstName, lastName, email, phone, password);
      if (!mounted) return;

      // ApiService stores the JWT on 201; only non-secret account details are
      // persisted here. Session-cache failures must not undo a server success.
      try {
        await _saveSessionDetails(
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: phone,
          hasOnlineToken: true,
        );
      } catch (_) {
        // Account creation has already succeeded on the server; do not report
        // a local cache failure as a failed registration.
      }
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      _showMessage(
        'Compte créé. Vous pouvez maintenant accéder à vos services.',
        color: const Color(0xFF18794E),
      );
      _scheduleHomeNavigation();
    } on ApiException catch (error) {
      if (!mounted) return;
      final isOffline =
          error.type == ApiErrorType.network ||
          (error.type == ApiErrorType.serverUnavailable &&
              error.statusCode == null);
      if (isOffline) {
        await _saveOfflineRegistration(
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: phone,
          password: password,
        );
      } else {
        setState(() {
          _isSubmitting = false;
          _submissionError = error.message;
        });
      }
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _isSubmitting = false;
        _submissionError = message.isEmpty
            ? 'Impossible de créer le compte. Réessayez.'
            : message;
      });
    }
  }

  Future<void> _saveOfflineRegistration({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final saved = await widget.saveOfflineAccount(
        OfflineRegistrationDraft(
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: phone,
          password: password,
        ),
      );
      if (!mounted) return;
      if (!saved) {
        setState(() {
          _isSubmitting = false;
          _submissionError =
              'Un compte utilisant cet e-mail ou ce téléphone est déjà enregistré sur cet appareil.';
        });
        return;
      }

      try {
        await _saveSessionDetails(
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: phone,
          hasOnlineToken: false,
        );
      } catch (_) {
        // The encrypted pending record remains the source of truth.
      }
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      _showMessage(
        'Inscription enregistrée sur cet appareil. Synchronisation en attente.',
        color: const Color(0xFF355E7D),
      );
      _scheduleHomeNavigation();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submissionError =
            'Impossible de protéger l’inscription sur cet appareil. Réessayez.';
      });
    }
  }

  Future<void> _saveSessionDetails({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required bool hasOnlineToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_identifier', email);
    await prefs.setBool('saved_isAdmin', false);
    await prefs.setBool('isAdmin', false);
    await prefs.setBool('isLoggedIn', hasOnlineToken);
    await prefs.setString('userIdentifier', email);
    await prefs.setString('userEmail', email);
    await prefs.setString('userPhone', phone);
    await prefs.setString('userName', '$firstName $lastName'.trim());
    if (!hasOnlineToken) await prefs.remove('token');
  }

  void _scheduleHomeNavigation() {
    _navigationTimer?.cancel();
    _navigationTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    });
  }

  void _showMessage(String message, {required Color color}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins(fontSize: 12)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: const Color(0xFF85898D),
        fontSize: 13,
      ),
      prefixIcon: prefix,
      prefixIconConstraints: prefix == null
          ? null
          : const BoxConstraints(minWidth: 54, minHeight: 48),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: border(_registrationBorder),
      enabledBorder: border(_registrationBorder),
      focusedBorder: border(_registrationBlue, 1.7),
      errorBorder: border(_registrationError),
      focusedErrorBorder: border(_registrationError, 1.7),
      errorStyle: GoogleFonts.poppins(
        color: _registrationError,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(
              text: ' *',
              style: GoogleFonts.poppins(
                color: const Color(0xFF91C4FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required GlobalKey<FormFieldState<String>> fieldKey,
    required FocusNode focusNode,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    String? autocomplete,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onFieldSubmitted,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        TextFormField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          enabled: !_isSubmitting,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autocomplete == null ? null : [autocomplete],
          maxLength: maxLength,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted == null
              ? (_) => FocusScope.of(context).nextFocus()
              : (_) => onFieldSubmitted(controller.text),
          scrollPadding: const EdgeInsets.only(bottom: 180),
          style: GoogleFonts.poppins(
            color: _registrationInk,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: _fieldDecoration(hint: hint),
        ),
      ],
    );
  }

  Widget _passwordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required GlobalKey<FormFieldState<String>> fieldKey,
    required FocusNode focusNode,
    required String? Function(String?) validator,
    required bool isConfirmation,
  }) {
    final isObscured = isConfirmation ? _obscureConfirmation : _obscurePassword;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        TextFormField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          enabled: !_isSubmitting,
          obscureText: isObscured,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: isConfirmation
              ? TextInputAction.done
              : TextInputAction.next,
          onFieldSubmitted: (_) =>
              isConfirmation ? _submit() : _confirmPasswordFocus.requestFocus(),
          scrollPadding: const EdgeInsets.only(bottom: 180),
          validator: validator,
          style: GoogleFonts.poppins(
            color: _registrationInk,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: _fieldDecoration(
            hint: hint,
            suffix: IconButton(
              tooltip: isObscured
                  ? 'Afficher le mot de passe'
                  : 'Masquer le mot de passe',
              onPressed: _isSubmitting
                  ? null
                  : () => setState(() {
                      if (isConfirmation) {
                        _obscureConfirmation = !_obscureConfirmation;
                      } else {
                        _obscurePassword = !_obscurePassword;
                      }
                    }),
              icon: Icon(
                isObscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: _registrationMuted,
              ),
            ),
          ),
        ),
        if (!isConfirmation)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text.rich(
              TextSpan(
                text: '4 chiffres puis 4 lettres majuscules. Exemple : ',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 11,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '1234AZER.',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Téléphone'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 49,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFECEEEC),
                border: Border.all(color: _registrationBorder),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(9),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _phonePrefix,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF30353A),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: TextFormField(
                key: _phoneFieldKey,
                controller: _phoneController,
                focusNode: _phoneFocus,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                maxLength: 9,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                inputFormatters: [_TogoPhoneInputFormatter()],
                scrollPadding: const EdgeInsets.only(bottom: 180),
                validator: _validatePhone,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                style: GoogleFonts.poppins(
                  color: _registrationInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                decoration: _fieldDecoration(hint: '90000000').copyWith(
                  hintStyle: GoogleFonts.poppins(
                    color: const Color(0xFF9DA3AA),
                    fontSize: 13,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(9),
                    ),
                    borderSide: BorderSide(color: _registrationBorder),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(9),
                    ),
                    borderSide: BorderSide(color: _registrationBorder),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(9),
                    ),
                    borderSide: BorderSide(
                      color: _registrationBlue,
                      width: 1.7,
                    ),
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(9),
                    ),
                    borderSide: BorderSide(color: _registrationError),
                  ),
                  focusedErrorBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(9),
                    ),
                    borderSide: BorderSide(
                      color: _registrationError,
                      width: 1.7,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: _registrationBlue,
                size: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Saisissez 8 ou 9 chiffres après +228, sans espaces.',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(double height) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 62),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Retour à la connexion',
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.maybePop(context),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(
                      0xFF10161D,
                    ).withValues(alpha: 0.3),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Text(
                  'ÉCHELLE EG39',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              'TOPOGRAPHIE · BTP',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Créer un compte client',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w800,
                height: 1.18,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Accédez aux services et suivez vos demandes en un seul endroit.',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormTray() {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vos coordonnées',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.3,
                letterSpacing: -0.35,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Renseignez les informations de votre compte.',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _textField(
                      label: 'Prénom',
                      hint: 'Votre prénom',
                      controller: _firstNameController,
                      fieldKey: _firstNameFieldKey,
                      focusNode: _firstNameFocus,
                      validator: (value) => _validateName(value, 'prénom'),
                      autocomplete: AutofillHints.givenName,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 13),
                    _textField(
                      label: 'Nom',
                      hint: 'Votre nom',
                      controller: _lastNameController,
                      fieldKey: _lastNameFieldKey,
                      focusNode: _lastNameFocus,
                      validator: (value) => _validateName(value, 'nom'),
                      autocomplete: AutofillHints.familyName,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 13),
                    _textField(
                      label: 'Email',
                      hint: 'nom@entreprise.com',
                      controller: _emailController,
                      fieldKey: _emailFieldKey,
                      focusNode: _emailFocus,
                      validator: _validateEmail,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocomplete: AutofillHints.email,
                    ),
                    const SizedBox(height: 13),
                    _buildPhoneField(),
                    const SizedBox(height: 13),
                    _passwordField(
                      label: 'Mot de passe',
                      hint: 'Choisissez un mot de passe',
                      controller: _passwordController,
                      fieldKey: _passwordFieldKey,
                      focusNode: _passwordFocus,
                      validator: _validatePassword,
                      isConfirmation: false,
                    ),
                    const SizedBox(height: 13),
                    _passwordField(
                      label: 'Confirmer le mot de passe',
                      hint: 'Saisissez-le une seconde fois',
                      controller: _confirmPasswordController,
                      fieldKey: _confirmPasswordFieldKey,
                      focusNode: _confirmPasswordFocus,
                      validator: _validateConfirmation,
                      isConfirmation: true,
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: _submissionError == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBEEEB),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: _registrationError.withValues(
                                      alpha: 0.24,
                                    ),
                                  ),
                                ),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _submissionError!,
                                    style: GoogleFonts.poppins(
                                      color: _registrationError,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        key: const ValueKey('register-submit-button'),
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _registrationBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _registrationBlue.withValues(
                            alpha: 0.7,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text(
                          _isSubmitting
                              ? 'Création du compte…'
                              : 'Créer mon compte',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 13),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Déjà un compte ? ',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('register-login-link'),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.maybePop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF91C4FF),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(
                      'Se connecter',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(
                          0xFF91C4FF,
                        ).withValues(alpha: 0.65),
                        decorationThickness: 1.4,
                        decorationStyle: TextDecorationStyle.solid,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final compactHeaderHeight = media.size.height < 760 ? 252.0 : 292.0;

    return Scaffold(
      backgroundColor: const Color(0xFF111820),
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PasswordRecoveryPhotoBackdrop(),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.only(
                    bottom: media.viewInsets.bottom + 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        children: [
                          _buildHeader(compactHeaderHeight),
                          Transform.translate(
                            offset: const Offset(0, -44),
                            child: FadeTransition(
                              opacity: _entranceFade,
                              child: SlideTransition(
                                key: const ValueKey('register-form-entrance'),
                                position: _entranceSlide,
                                child: _buildFormTray(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
