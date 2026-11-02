import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_avatar_image.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_links.dart';
import 'company_contact.dart';
import 'company_location.dart';
import 'login.page.dart';
import 'profile_api.dart';
import 'support_assistant.dart';
import 'team.dart';
import 'widgets/invite_app_dialog.dart';
import 'widgets/share_company_dialog.dart';

/// Fil de messages du support, conservé localement à l’écran et transmis à l’API.
class ChatSupportDialog extends StatefulWidget {
  const ChatSupportDialog({super.key, required this.profileApi});

  final ProfileApi profileApi;

  @override
  State<ChatSupportDialog> createState() => _ChatSupportDialogState();
}

class _ChatSupportDialogState extends State<ChatSupportDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          'Bonjour. Écrivez votre demande : elle sera transmise à l’équipe ÉCHELLE EG39.',
      isBot: true,
      timestamp: DateTime.now(),
    ),
  ];
  bool _isSending = false;
  String? _sendError;

  /// Répondeur local : répond avec les faits de l’entreprise, sans réseau.
  final SupportAssistant _assistant = const SupportAssistant();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    final answer = _assistant.answer(messageText);

    setState(() {
      _isSending = true;
      _sendError = null;
      _messages.add(
        ChatMessage(text: messageText, isBot: false, timestamp: DateTime.now()),
      );
      if (answer != null) {
        _messages.add(
          ChatMessage(
            text: answer.answer,
            isBot: true,
            timestamp: DateTime.now(),
          ),
        );
      }
    });
    _messageController.clear();
    _scrollToLatest();

    // Réponse trouvée dans la fiche de l’entreprise : rien à transmettre.
    if (answer != null) {
      if (mounted) setState(() => _isSending = false);
      return;
    }

    try {
      await widget.profileApi.submitSupportMessage(message: messageText);
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text:
                'Je n’ai pas cette information dans la fiche de l’entreprise. '
                'Votre message a été transmis au support : l’équipe vous '
                'recontactera via les coordonnées de votre compte.',
            isBot: true,
            timestamp: DateTime.now(),
          ),
        );
        _sendError = null;
      });
      _scrollToLatest();
    } on ProfileApiException catch (error) {
      if (mounted) setState(() => _sendError = error.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: 500,
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildMessagesList()),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent,
              color: Color(0xFF2563EB),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support ÉCHELLE EG39',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Votre message sera envoyé au support',
                  style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isBot
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isBot) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: message.isBot
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF059669),
                shape: BoxShape.circle,
              ),
              child: Icon(
                message.isBot ? Icons.support_agent : Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: message.isBot
                    ? const Color(0xFFF3F4F6)
                    : const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isBot
                          ? const Color(0xFF111827)
                          : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${message.timestamp.hour.toString().padLeft(2, '0')}:'
                    '${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: message.isBot
                          ? const Color(0xFF6B7280)
                          : const Color(0xFFBFDBFE),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!message.isBot) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: message.isBot
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF059669),
                shape: BoxShape.circle,
              ),
              child: Icon(
                message.isBot ? Icons.support_agent : Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _sendError!,
                  style: const TextStyle(
                    color: Color(0xFFB42318),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  readOnly: _isSending,
                  decoration: InputDecoration(
                    hintText: 'Tapez votre message…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF2563EB),
                child: IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  tooltip: 'Envoyer le message au support',
                  icon: _isSending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modèle pour les messages du chat
class ChatMessage {
  final String text;
  final bool isBot;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isBot,
    required this.timestamp,
  });
}

/// Écran de profil utilisateur connecté.
typedef ProfileAvatarPicker = Future<XFile?> Function(ImageSource source);
typedef ProfileAvatarNormalizer =
    Future<NormalizedProfileAvatar> Function(Uint8List sourceBytes);
typedef ProfileGoogleMapsLauncher = Future<bool> Function(Uri uri);
typedef ProfileContactLauncher = Future<bool> Function(Uri uri);

/// Jetons visuels de l’écran Profil.
///
/// Reprend le langage déjà utilisé par l’écran Location et la fiche agence :
/// fond parchemin, cartes blanches à filet fin, un seul bleu d’action.
class _ProfileTokens {
  const _ProfileTokens._();

  static const Color canvas = Color(0xFFF5F5F7);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF5F7FA);
  static const Color ink = Color(0xFF1D1D1F);
  static const Color muted = Color(0xFF7A7A7A);
  static const Color border = Color(0xFFE6E6E6);
  static const Color divider = Color(0xFFF0F0F0);
  static const Color primary = Color(0xFF0066CC);
  static const Color chevron = Color(0xFFC7C7CC);
  static const Color danger = Color(0xFFB42318);

  static const double radiusCard = 18;
  static const double pagePadding = 16;
  static const double avatarSize = 64;
  static const double touchTarget = 44;
}

/// Styles de texte de l’écran Profil (échelle 400 / 600 / 700).
class _ProfileText {
  const _ProfileText._();

  static TextStyle _style(
    double size,
    FontWeight weight, {
    Color color = _ProfileTokens.ink,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle get pageTitle =>
      _style(28, FontWeight.w700, height: 1.1, letterSpacing: -0.6);

  static TextStyle get name =>
      _style(21, FontWeight.w700, height: 1.15, letterSpacing: -0.4);

  static TextStyle get email => _style(14, FontWeight.w400, color: _ProfileTokens.muted);

  static TextStyle get identityStrong => _style(14, FontWeight.w600, height: 1.35);

  static TextStyle get identityMuted =>
      _style(14, FontWeight.w400, color: _ProfileTokens.muted, height: 1.35);

  static TextStyle get sectionTitle =>
      _style(17, FontWeight.w700, letterSpacing: -0.2);

  static TextStyle get rowTitle =>
      _style(16, FontWeight.w600, height: 1.2, letterSpacing: -0.2);

  static TextStyle get rowSubtitle =>
      _style(12, FontWeight.w400, color: _ProfileTokens.muted, height: 1.3);

  static TextStyle get rowValue =>
      _style(12, FontWeight.w600, height: 1.3, letterSpacing: -0.1);

  static TextStyle get appName => _style(15, FontWeight.w700, letterSpacing: -0.15);

  static TextStyle get appVersion =>
      _style(13, FontWeight.w400, color: _ProfileTokens.muted);

  static TextStyle get actionLabel => _style(15, FontWeight.w600);
}

/// Filet de séparation entre deux lignes d’une même carte.
class _ProfileRowDivider extends StatelessWidget {
  const _ProfileRowDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: _ProfileTokens.pagePadding),
      color: _ProfileTokens.divider,
    );
  }
}

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({
    super.key,
    this.profileApi,
    this.pickAvatarImage,
    this.normalizeAvatarImage,
    this.launchGoogleMaps,
    this.launchContactUri,
    this.companyLocationCardBuilder,
  });

  final ProfileApi? profileApi;
  final ProfileAvatarPicker? pickAvatarImage;
  final ProfileAvatarNormalizer? normalizeAvatarImage;
  final ProfileGoogleMapsLauncher? launchGoogleMaps;

  /// Remplace l'ouverture du composeur téléphone / e-mail (tests).
  final ProfileContactLauncher? launchContactUri;

  /// Remplace la carte affichée sous « Nous localiser » (tests, hors ligne).
  final WidgetBuilder? companyLocationCardBuilder;

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  static const _profileCacheKey = 'profile_cache';

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _personalFirstNameController =
      TextEditingController();
  final TextEditingController _personalLastNameController =
      TextEditingController();
  final TextEditingController _personalEmailController =
      TextEditingController();
  final TextEditingController _personalPasswordController =
      TextEditingController();
  late final ProfileApi _profileApi = widget.profileApi ?? ProfileApi();
  ProfileRecord? _profile;
  Uint8List? _selectedAvatarBytes;
  bool _isLoadingProfile = true;
  bool _isSavingProfile = false;
  String? _profileError;
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _personalFirstNameController.dispose();
    _personalLastNameController.dispose();
    _personalEmailController.dispose();
    _personalPasswordController.dispose();
    if (widget.profileApi == null) _profileApi.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });

    try {
      final profile = await _profileApi.loadProfile();
      await _applyProfile(profile, cache: true);
      if (mounted) setState(() => _isLoadingProfile = false);
    } on ProfileApiException catch (error) {
      await _loadCachedProfile();
      if (!mounted) return;
      setState(() {
        _profileError = error.message;
        _isLoadingProfile = false;
      });
    } catch (_) {
      await _loadCachedProfile();
      if (!mounted) return;
      setState(() {
        _profileError = 'Impossible de lire les données du profil.';
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _applyProfile(
    ProfileRecord profile, {
    required bool cache,
  }) async {
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _userName = profile.fullName;
      _userEmail = profile.email;
      _userPhone = profile.phone;
      _selectedAvatarBytes = profile.avatarData == null
          ? null
          : base64Decode(profile.avatarData!);
    });

    if (cache) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _profileCacheKey,
        jsonEncode({
          'id': profile.id,
          'firstName': profile.firstName,
          'lastName': profile.lastName,
          'email': profile.email,
          'phone': profile.phone,
          'company': profile.company,
          'address': profile.address,
          'city': profile.city,
          'country': profile.country,
          'role': profile.role,
        }),
      );
      await prefs.setString('userName', profile.fullName);
      await prefs.setString('userEmail', profile.email);
      await prefs.setString('userPhone', profile.phone);
    }
  }

  Future<void> _loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_profileCacheKey);
    if (cached == null) return;
    try {
      final decoded = jsonDecode(cached);
      if (decoded is Map<String, dynamic>) {
        await _applyProfile(ProfileRecord.fromJson(decoded), cache: false);
      }
    } on FormatException {
      await prefs.remove(_profileCacheKey);
    } catch (_) {
      await prefs.remove(_profileCacheKey);
    }
  }

  Future<bool> _saveProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? company,
    String? currentPassword,
    required String successMessage,
  }) async {
    final profile = _profile;
    if (profile == null || _isSavingProfile) return false;

    setState(() {
      _isSavingProfile = true;
      _profileError = null;
    });
    try {
      final updated = await _profileApi.updateProfile(
        firstName: firstName ?? profile.firstName,
        lastName: lastName ?? profile.lastName,
        email: email ?? profile.email,
        phone: phone ?? profile.phone,
        company: company ?? profile.company,
        address: profile.address,
        city: profile.city,
        country: profile.country,
        currentPassword: currentPassword,
      );
      await _applyProfile(updated, cache: true);
      if (mounted) _showProfileMessage(successMessage);
      return true;
    } on ProfileApiException catch (error) {
      if (mounted) _showProfileMessage(error.message, isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  void _showProfileMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? const Color(0xFFB42318)
              : const Color(0xFF1D1D1F),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ProfileTokens.canvas,
      body: SafeArea(
        child: _isLoadingProfile && _profile == null
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              )
            : _profile == null
            ? _buildProfileLoadError()
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(),
                    if (_profileError != null) _buildProfileErrorBanner(),
                    if (_isLoadingProfile)
                      const LinearProgressIndicator(minHeight: 2),
                    _buildContent(context),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProfileLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(height: 12),
            Text(
              _profileError ?? 'Impossible de charger votre profil.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileErrorBanner() {
    return Material(
      color: const Color(0xFFFEF3F2),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Synchronisation impossible. Les données déjà sauvegardées restent visibles.',
                style: const TextStyle(color: Color(0xFFB42318), fontSize: 13),
              ),
            ),
            TextButton(onPressed: _loadProfile, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  /// Construit l'en-tête : titre de page puis fiche d'identité compacte.
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text('Profil', style: _ProfileText.pageTitle),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _ProfileTokens.pagePadding,
          ),
          child: _buildIdentityCard(),
        ),
      ],
    );
  }

  /// Fiche blanche : avatar modifiable et informations du compte connecté.
  Widget _buildIdentityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _ProfileTokens.surface,
        borderRadius: BorderRadius.circular(_ProfileTokens.radiusCard),
        border: Border.all(color: _ProfileTokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(),
          const SizedBox(width: 14),
          Expanded(child: _buildUserInfo()),
        ],
      ),
    );
  }

  /// Construit l'avatar utilisateur
  Widget _buildAvatar() {
    return GestureDetector(
      key: const ValueKey('profile-avatar'),
      onTap: _showImagePickerDialog,
      child: SizedBox(
        width: 70,
        height: 70,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: _ProfileTokens.avatarSize,
              height: _ProfileTokens.avatarSize,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _ProfileTokens.surfaceMuted,
                shape: BoxShape.circle,
                border: Border.all(color: _ProfileTokens.border),
              ),
              child: _selectedAvatarBytes != null
                  ? Image.memory(
                      _selectedAvatarBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.person,
                        size: 32,
                        color: _ProfileTokens.primary,
                      ),
                    )
                  : Center(
                      child: Text(
                        _userInitials,
                        style: GoogleFonts.poppins(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: _ProfileTokens.primary,
                        ),
                      ),
                    ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _ProfileTokens.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: _ProfileTokens.surface, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Initiales affichées quand aucune photo n'est choisie.
  String get _userInitials {
    final name = _userName.trim();
    if (name.isEmpty) return '…';
    return name
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();
  }

  /// Affiche le dialog pour choisir entre galerie et caméra
  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choisir une photo de profil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImagePickerOption(
                    icon: Icons.photo_library,
                    label: 'Galerie',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                  _buildImagePickerOption(
                    icon: Icons.camera_alt,
                    label: 'Caméra',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                  if (_selectedAvatarBytes != null)
                    _buildImagePickerOption(
                      icon: Icons.delete_outline,
                      label: 'Supprimer',
                      onTap: _deleteProfileImage,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Construit une option de sélection d'image
  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 30, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Sélectionne une image depuis la source spécifiée
  Future<void> _pickImage(ImageSource source) async {
    try {
      // Passing size bounds lets image_picker use the platform decoder to
      // convert formats such as HEIC before the Dart normalizer processes them.
      final image = widget.pickAvatarImage != null
          ? await widget.pickAvatarImage!(source)
          : await _picker.pickImage(
              source: source,
              maxWidth: 1200,
              maxHeight: 1200,
              imageQuality: 100,
            );
      if (image == null || !mounted) return;

      final sourceBytes = await image.readAsBytes();
      final normalized =
          await (widget.normalizeAvatarImage ?? normalizeProfileAvatar)(
            sourceBytes,
          );
      if (!mounted) return;

      setState(() => _isSavingProfile = true);
      try {
        final profile = await _profileApi.updateAvatar(
          bytes: normalized.bytes,
          mimeType: normalized.mimeType,
        );
        await _applyProfile(profile, cache: true);
        if (mounted) _showProfileMessage('Photo de profil enregistrée.');
      } on ProfileApiException catch (error) {
        if (mounted) _showProfileMessage(error.message, isError: true);
      } finally {
        if (mounted) setState(() => _isSavingProfile = false);
      }
    } on ProfileAvatarImageException catch (error) {
      if (mounted) _showProfileMessage(error.message, isError: true);
    } catch (_) {
      if (mounted) {
        _showProfileMessage(
          'Impossible de sélectionner cette photo.',
          isError: true,
        );
      }
    }
  }

  Future<void> _deleteProfileImage() async {
    try {
      await _profileApi.deleteAvatar();
      if (!mounted) return;
      setState(() => _selectedAvatarBytes = null);
      _showProfileMessage('Photo de profil supprimée.');
    } on ProfileApiException catch (error) {
      if (mounted) _showProfileMessage(error.message, isError: true);
    }
  }

  /// Construit les informations réelles renvoyées par le compte connecté.
  Widget _buildUserInfo() {
    final role = _roleLabel;
    final company = _profile?.company.trim() ?? '';
    final place = _placeLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _userName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _ProfileText.name,
                ),
              ),
            ),
            const SizedBox(width: 4),
            _buildEditProfileButton(),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _userEmail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _ProfileText.email,
        ),
        if (role != null) ...[
          const SizedBox(height: 10),
          Text(role, style: _ProfileText.identityStrong),
        ],
        if (company.isNotEmpty)
          Text(company, style: _ProfileText.identityStrong),
        if (place != null) ...[
          const SizedBox(height: 2),
          Text(place, style: _ProfileText.identityMuted),
        ],
      ],
    );
  }

  /// Crayon d'édition des informations personnelles.
  Widget _buildEditProfileButton() {
    return IconButton(
      tooltip: 'Modifier les informations personnelles',
      onPressed: () => _showPersonalInfoDialog(context),
      style: IconButton.styleFrom(
        backgroundColor: _ProfileTokens.surfaceMuted,
        foregroundColor: _ProfileTokens.primary,
        minimumSize: const Size(
          _ProfileTokens.touchTarget,
          _ProfileTokens.touchTarget,
        ),
        maximumSize: const Size(
          _ProfileTokens.touchTarget,
          _ProfileTokens.touchTarget,
        ),
        padding: EdgeInsets.zero,
      ),
      icon: const Icon(Icons.edit_outlined, size: 16),
    );
  }

  /// Rôle lisible : les comptes ordinaires portent « client » en base.
  String? get _roleLabel {
    final raw = (_profile?.role ?? '').trim();
    if (raw.isEmpty) return null;
    return switch (raw.toLowerCase()) {
      'client' => 'Compte client',
      'admin' || 'administrateur' => 'Administrateur',
      _ => '${raw[0].toUpperCase()}${raw.substring(1)}',
    };
  }

  /// Ville et pays du compte, quand ils sont renseignés.
  String? get _placeLabel {
    final parts = [
      (_profile?.city ?? '').trim(),
      (_profile?.country ?? '').trim(),
    ].where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  /// Construit le contenu principal de l'écran
  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _ProfileTokens.pagePadding,
        24,
        _ProfileTokens.pagePadding,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAccountSection(context),
          const SizedBox(height: 24),
          _buildSupportSection(context),
          const SizedBox(height: 24),
          _buildAppInfo(),
          const SizedBox(height: 16),
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  /// Section "Mon compte"
  Widget _buildAccountSection(BuildContext context) {
    return _buildSection('Mon compte', [
      _buildMenuItem(
        context,
        Icons.person_outline,
        'Informations personnelles',
        () => _showPersonalInfoDialog(context),
        subtitle: 'Votre nom et votre adresse e-mail',
      ),
      _buildMenuItem(
        context,
        Icons.phone_outlined,
        'Numéro de téléphone',
        () => _showPhoneDialog(context),
        subtitle: 'Joignable sur ce numéro',
        trailing: _userPhone,
      ),
      _buildMenuItem(
        context,
        Icons.lock_outline,
        'Mot de passe',
        () => _showPasswordDialog(context),
        subtitle: 'Sécuriser l’accès au compte',
        trailing: '••••••••',
      ),
    ]);
  }

  /// Section "Support"
  Widget _buildSupportSection(BuildContext context) {
    return _buildSection('Support', [
      _buildMenuItem(
        context,
        Icons.chat_bubble_outline,
        'Chat Support',
        () => _showChatSupportDialog(context),
        subtitle: 'Écrire directement à l’équipe',
      ),
      _buildMenuItem(
        context,
        Icons.help_outline,
        'Centre d\'aide',
        () => _showHelpCenterDialog(context),
        subtitle: 'FAQ, glossaire et contact',
      ),

      _buildMenuItem(
        context,
        Icons.info_outline,
        'À propos',
        () => _showAboutDialog(context),
        subtitle: 'ÉCHELLE EG39 et ses services',
      ),
      _buildCompanyLocationEntry(context),
    ]);
  }

  /// Dernière entrée du menu : « Nous localiser » introduit la carte de
  /// l'agence, affichée en permanence juste en dessous.
  Widget _buildCompanyLocationEntry(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStaticMenuItem(
          icon: Icons.place_outlined,
          title: 'Nous localiser',
          subtitle: 'Agence ÉCHELLE EG39',
        ),
        Container(
          key: const ValueKey('company-location-inline'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _buildCompanyLocationCard(context),
        ),
      ],
    );
  }

  Widget _buildCompanyLocationCard(BuildContext context) {
    final builder = widget.companyLocationCardBuilder;
    if (builder != null) return builder(context);
    return const CompanyLocationCard(
      embedded: true,
      hours: CompanyContact.hours,
    );
  }

  /// Informations de l'application
  Widget _buildAppInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _ProfileTokens.surface,
        borderRadius: BorderRadius.circular(_ProfileTokens.radiusCard),
        border: Border.all(color: _ProfileTokens.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 20,
            color: _ProfileTokens.primary,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ÉCHELLE EG39', style: _ProfileText.appName),
              const SizedBox(height: 2),
              Text('Version 1.0.0', style: _ProfileText.appVersion),
            ],
          ),
        ],
      ),
    );
  }

  /// Action secondaire de déconnexion : pilule discrète, jamais dominante.
  Widget _buildLogoutButton(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Se déconnecter',
      child: Material(
        color: _ProfileTokens.surface,
        shape: StadiumBorder(
          side: BorderSide(color: _ProfileTokens.border),
        ),
        child: InkWell(
          onTap: () => _showLogoutDialog(context),
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.logout,
                  size: 17,
                  color: _ProfileTokens.danger,
                ),
                const SizedBox(width: 8),
                Text('Se déconnecter', style: _ProfileText.actionLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Fonction pour se déconnecter et supprimer la session
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Supprimer toutes les données de session
    await prefs.remove('token');
    await prefs.remove('isLoggedIn');
    await prefs.remove('isAdmin');
    await prefs.remove('userIdentifier');
    await prefs.remove('userPassword');
    await prefs.remove('userEmail');
    await prefs.remove('userPhone');
    await prefs.remove('userName');
    await prefs.remove('temp_reset_token');
    await prefs.remove(_profileCacheKey);

    debugPrint('User session cleared');

    if (!mounted) return;

    // Naviguer vers la page de connexion en supprimant l'historique
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Déconnexion réussie !'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Affiche la dialog de confirmation de déconnexion
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Appeler la fonction de déconnexion
              logout();
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  /// Affiche le dialog de support chat
  void _showChatSupportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => ChatSupportDialog(profileApi: _profileApi),
    );
  }

  /// Construit une section : intitulé puis carte blanche à filet fin.
  ///
  /// Les lignes sont séparées par un filet inséré entre elles, jamais
  /// après la dernière.
  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(title, style: _ProfileText.sectionTitle),
        ),
        const SizedBox(height: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _ProfileTokens.surface,
            borderRadius: BorderRadius.circular(_ProfileTokens.radiusCard),
            border: Border.all(color: _ProfileTokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0) const _ProfileRowDivider(),
                items[index],
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Construit un élément de menu cliquable
  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? subtitle,
    String? trailing,
  }) {
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title. $subtitle',
      child: InkWell(
        key: ValueKey('profile-menu-$title'),
        onTap: onTap,
        child: _buildMenuRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          trailingWidget: const Icon(
            Icons.chevron_right,
            color: _ProfileTokens.chevron,
            size: 17,
          ),
        ),
      ),
    );
  }

  /// Intitulé non cliquable, utilisé pour introduire un bloc de contenu.
  Widget _buildStaticMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailing,
    Widget? trailingWidget,
  }) {
    return Semantics(
      header: true,
      label: subtitle == null ? title : '$title. $subtitle',
      child: _buildMenuRow(
        key: ValueKey('profile-menu-$title'),
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        trailingWidget: trailingWidget,
      ),
    );
  }

  Widget _buildMenuRow({
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailing,
    Widget? trailingWidget,
  }) {
    return Container(
      key: key,
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Icon(icon, color: _ProfileTokens.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _ProfileText.rowTitle,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _ProfileText.rowSubtitle,
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          trailing,
                          maxLines: 1,
                          textAlign: TextAlign.right,
                          style: _ProfileText.rowValue,
                        ),
                      ],
                    ],
                  ),
                ] else if (trailing != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    trailing,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ProfileText.rowValue,
                  ),
                ],
              ],
            ),
          ),
          if (trailingWidget != null) ...[
            const SizedBox(width: 8),
            trailingWidget,
          ],
        ],
      ),
    );
  }

  // Dialogs pour les nouvelles fonctionnalités

  Future<void> _showPersonalInfoDialog(BuildContext context) async {
    final profile = _profile;
    if (profile == null) return;

    final firstNameController = _personalFirstNameController
      ..text = profile.firstName;
    final lastNameController = _personalLastNameController
      ..text = profile.lastName;
    final emailController = _personalEmailController..text = profile.email;
    final passwordController = _personalPasswordController..clear();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Informations personnelles'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      key: const ValueKey('profile-first-name'),
                      controller: firstNameController,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Saisissez votre prénom.'
                          : null,
                    ),
                    TextFormField(
                      key: const ValueKey('profile-last-name'),
                      controller: lastNameController,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Saisissez votre nom.'
                          : null,
                    ),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Adresse e-mail',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(email)
                            ? null
                            : 'Saisissez une adresse e-mail valide.';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe actuel',
                        helperText: 'Requis si vous changez votre e-mail.',
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        final contactChanged =
                            emailController.text.trim() != profile.email;
                        if (contactChanged && passwordController.text.isEmpty) {
                          _showProfileMessage(
                            'Saisissez votre mot de passe actuel pour changer l’e-mail.',
                            isError: true,
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        final saved = await _saveProfile(
                          firstName: firstNameController.text,
                          lastName: lastNameController.text,
                          email: emailController.text,
                          currentPassword: passwordController.text,
                          successMessage:
                              'Informations personnelles enregistrées.',
                        );
                        if (dialogContext.mounted && saved) {
                          Navigator.pop(dialogContext);
                        }
                        if (dialogContext.mounted && !saved) {
                          setDialogState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        );
      },
    );
    passwordController.clear();
  }

  Future<void> _showPhoneDialog(BuildContext context) async {
    final profile = _profile;
    if (profile == null) return;
    final phoneController = TextEditingController(text: profile.phone);
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Numéro de téléphone'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      final digits = (value ?? '').replaceAll(
                        RegExp(r'[^0-9+]'),
                        '',
                      );
                      return digits.length >= 8 && digits.length <= 20
                          ? null
                          : 'Saisissez un numéro valide.';
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Indiquez l’indicatif pays; le numéro sert à vos coordonnées de compte.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe actuel',
                      helperText: 'Requis si vous changez votre numéro.',
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        final contactChanged =
                            phoneController.text.trim() != profile.phone;
                        if (contactChanged && passwordController.text.isEmpty) {
                          _showProfileMessage(
                            'Saisissez votre mot de passe actuel pour changer le numéro.',
                            isError: true,
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        final saved = await _saveProfile(
                          phone: phoneController.text,
                          currentPassword: passwordController.text,
                          successMessage: 'Numéro de téléphone enregistré.',
                        );
                        if (dialogContext.mounted && saved) {
                          Navigator.pop(dialogContext);
                        }
                        if (dialogContext.mounted && !saved) {
                          setDialogState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        );
      },
    );
    phoneController.dispose();
    passwordController.dispose();
  }

  Future<void> _showPasswordDialog(BuildContext context) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Changer le mot de passe'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe actuel',
                      ),
                      obscureText: true,
                      validator: (value) => value == null || value.isEmpty
                          ? 'Saisissez votre mot de passe actuel.'
                          : null,
                    ),
                    TextFormField(
                      controller: newPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        helperText:
                            '6 caractères minimum, avec une lettre et un chiffre.',
                      ),
                      obscureText: true,
                      validator: (value) {
                        final password = value ?? '';
                        if (password.length < 6 ||
                            !RegExp(r'[a-zA-Z]').hasMatch(password) ||
                            !RegExp(r'[0-9]').hasMatch(password)) {
                          return 'Ajoutez au moins 6 caractères, une lettre et un chiffre.';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                      ),
                      obscureText: true,
                      validator: (value) => value != newPasswordController.text
                          ? 'Les mots de passe ne correspondent pas.'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        try {
                          await _profileApi.changePassword(
                            currentPassword: currentPasswordController.text,
                            newPassword: newPasswordController.text,
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          Navigator.pop(dialogContext);
                          if (mounted) {
                            _showProfileMessage('Mot de passe modifié.');
                          }
                        } on ProfileApiException catch (error) {
                          if (mounted) {
                            _showProfileMessage(error.message, isError: true);
                          }
                          if (dialogContext.mounted) {
                            setDialogState(() => isSubmitting = false);
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        );
      },
    );
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  // Méthodes pour le centre d'aide - Déclarées d'abord pour éviter les erreurs

  /// Construit un élément du centre d'aide
  Widget _buildHelpCenterItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  /// FAQ consultable : chaque question révèle sa réponse au toucher.
  Widget _buildFAQItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [Text(answer)],
      ),
    );
  }

  /// Terme de glossaire en lecture seule (pas de faux bouton d’action).
  Widget _buildGlossaryItem(String term, String definition) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.menu_book_outlined, color: Color(0xFF059669)),
        title: Text(term, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(definition),
      ),
    );
  }

  /// Construit un élément de contact
  Widget _buildContactItem(
    IconData icon,
    String label,
    String value,
    VoidCallback? onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2563EB)),
        title: Text(label),
        subtitle: Text(value),
        trailing: onTap == null ? null : const Icon(Icons.open_in_new),
        onTap: onTap,
      ),
    );
  }

  /// Affiche le dialog du centre d'aide
  void _showHelpCenterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.help_center, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Centre d\'aide'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildHelpCenterItem(
                  context,
                  Icons.help_outline,
                  'FAQ dynamique',
                  'Questions fréquentes organisées par catégories',
                  () {
                    Navigator.of(context).pop();
                    _showFAQDialog(context);
                  },
                ),
                _buildHelpCenterItem(
                  context,
                  Icons.g_translate,
                  'Glossaire',
                  'Définitions des termes techniques',
                  () {
                    Navigator.of(context).pop();
                    _showGlossaryDialog(context);
                  },
                ),
                _buildHelpCenterItem(
                  context,
                  Icons.contact_phone,
                  'Contact direct',
                  'Téléphone, email, WhatsApp (+228 90 01 43 29)',
                  () {
                    Navigator.of(context).pop();
                    _showDirectContactDialog(context);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog FAQ dynamique
  void _showFAQDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('FAQ Dynamique'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildFAQItem(
                  'Comment calibrer un GPS de précision ?',
                  'Pour calibrer un GPS de précision, placez-vous en zone dégagée et suivez les instructions du manuel.',
                ),
                _buildFAQItem(
                  'Quelle est la précision des GPS e-survey ?',
                  'Les GPS e-survey ont une précision de 2-5mm en mode RTK.',
                ),
                _buildFAQItem(
                  'Comment régler un théodolite ?',
                  'Le réglage d\'un théodolite nécessite une mise à niveau précise avec les vis calantes.',
                ),
                _buildFAQItem(
                  'Comment réserver un équipement ?',
                  'Utilisez la section Location de l\'application pour vérifier la disponibilité et réserver.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog Glossaire
  void _showGlossaryDialog(BuildContext context) {
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Glossaire'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Rechercher un terme',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _buildGlossaryItem(
                        'Altimétrie',
                        'Mesure des altitudes et des hauteurs',
                      ),
                      _buildGlossaryItem(
                        'Azimut',
                        'Angle horizontal mesuré dans le sens horaire',
                      ),
                      _buildGlossaryItem(
                        'Bornage',
                        'Délimitation d\'une propriété',
                      ),
                      _buildGlossaryItem(
                        'Cadastre',
                        'Enregistrement public des propriétés foncières',
                      ),
                      _buildGlossaryItem(
                        'Gisement',
                        'Angle horizontal mesuré à partir du nord',
                      ),
                      _buildGlossaryItem(
                        'Nivellement',
                        'Détermination des différences d\'altitude',
                      ),
                      _buildGlossaryItem(
                        'Station totale',
                        'Instrument combinant théodolite et distancemètre',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  /// Ouvre le composeur système correspondant au lien.
  ///
  /// Aucun pré-contrôle `canLaunchUrl` : sur iOS il dépend de
  /// `LSApplicationQueriesSchemes` et sur Android 11+ de `<queries>`, ce qui
  /// faisait échouer `tel:` et `mailto:` alors que les applications existent.
  /// Si rien ne s'ouvre (simulateur sans app Téléphone/Mail, appareil sans
  /// client mail), la coordonnée est copiée pour rester utilisable.
  Future<void> _launchContact(
    Uri uri, {
    required String copyValue,
    required String fallbackMessage,
  }) async {
    var launched = false;
    try {
      final launcher = widget.launchContactUri;
      launched = launcher != null
          ? await launcher(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (launched || !mounted) return;
    try {
      await Clipboard.setData(ClipboardData(text: copyValue));
    } catch (_) {
      // Le presse-papiers peut être indisponible : le message reste utile.
    }
    if (!mounted) return;
    _showProfileMessage(fallbackMessage);
  }

  /// Les actions ouvrent maintenant le composeur système correspondant.
  void _showDirectContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Contact direct'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildContactItem(
                Icons.phone,
                'Téléphone',
                CompanyContact.phoneDisplay,
                () => _launchContact(
                  CompanyContact.phoneUri,
                  copyValue: CompanyContact.phoneDisplay,
                  fallbackMessage: CompanyContact.phoneFallbackMessage,
                ),
              ),
              _buildContactItem(
                Icons.email,
                'E-mail',
                CompanyContact.email,
                () => _launchContact(
                  CompanyContact.emailUri,
                  copyValue: CompanyContact.email,
                  fallbackMessage: CompanyContact.emailFallbackMessage,
                ),
              ),
              _buildContactItem(
                Icons.chat,
                'WhatsApp',
                CompanyContact.phoneDisplay,
                () => _launchContact(
                  CompanyContact.whatsAppUri(
                    text:
                        'Bonjour ${CompanyContact.name}, '
                        'j’ai besoin d’aide.',
                  ),
                  copyValue: CompanyContact.phoneDisplay,
                  fallbackMessage: CompanyContact.whatsAppFallbackMessage,
                ),
              ),
              _buildContactItem(
                Icons.schedule,
                'Horaires',
                CompanyContact.hours,
                null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Construit un élément du menu À propos
  Widget _buildAboutItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  /// Affiche le dialog principal du menu À propos
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('À propos'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildAboutItem(
                  context,
                  Icons.business,
                  'Informations sur l\'entreprise',
                  'Histoire, mission, localisation et zone d\'intervention',
                  () {
                    Navigator.of(context).pop();
                    _showCompanyInfoDialog(context);
                  },
                ),
                _buildAboutItem(
                  context,
                  Icons.group,
                  'Notre équipe',
                  'Photos et profils des membres de l\'équipe',
                  () {
                    Navigator.of(context).pop();
                    _showTeamDialog(context);
                  },
                ),
                _buildAboutItem(
                  context,
                  Icons.handshake,
                  'Nos partenaires',
                  'Leica, e-survey',
                  () {
                    Navigator.of(context).pop();
                    _showPartnersDialog(context);
                  },
                ),
                _buildAboutItem(
                  context,
                  Icons.settings,
                  'Nos services',
                  'Vente, Location, Formation, Réparation, Mise à jour',
                  () {
                    Navigator.of(context).pop();
                    _showServicesDialog(context);
                  },
                ),
                _buildAboutItem(
                  context,
                  Icons.privacy_tip,
                  'Politique de confidentialité',
                  'RGPD et protection des données',
                  () {
                    Navigator.of(context).pop();
                    _showPrivacyPolicyDialog(context);
                  },
                ),
                _buildAboutItem(
                  context,
                  Icons.description,
                  'Conditions d\'utilisation',
                  'Mentions légales',
                  () {
                    Navigator.of(context).pop();
                    _showTermsOfUseDialog(context);
                  },
                ),
                _buildAboutItem(
                  context,
                  Icons.code,
                  'Crédits',
                  'Équipe de développement',
                  () {
                    Navigator.of(context).pop();
                    _showCreditsDialog(context);
                  },
                ),
                _buildAboutItem(
                  context,
                  Icons.download_for_offline_outlined,
                  'Inviter à installer',
                  AppLinks.isPublished
                      ? 'Lien Google Play et App Store'
                      : 'Bientôt sur Google Play et l’App Store',
                  () {
                    Navigator.of(context).pop();
                    _showInviteDialog(context);
                  },
                ),
                _buildAboutItem(
                  context,
                  Icons.share,
                  'Partager nos coordonnées',
                  'Envoyez notre fiche à vos collègues',
                  () {
                    Navigator.of(context).pop();
                    _showShareDialog(context);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  /// Ouvre la position exacte fournie par l’entreprise dans Google Maps.
  Future<void> _openGoogleMaps() async {
    final uri = Uri.parse('https://maps.app.goo.gl/BtGKf2gwjaLpKFQN7?g_st=iw');

    try {
      final didLaunch = widget.launchGoogleMaps != null
          ? await widget.launchGoogleMaps!(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!didLaunch && mounted) {
        _showProfileMessage(
          'Impossible d’ouvrir Google Maps. Vérifiez votre connexion.',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        _showProfileMessage(
          'Impossible d’ouvrir Google Maps. Vérifiez votre connexion.',
          isError: true,
        );
      }
    }
  }

  /// Dialog Informations sur l'entreprise
  void _showCompanyInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Informations sur l\'entreprise'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ÉCHELLE EG39',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Notre Histoire',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Créée en 2019, ÉCHELLE EG39 est spécialisée dans la vente et location d\'équipements de topographie de haute précision. Nous accompagnons les professionnels du secteur dans leurs projets d\'infrastructure et de construction.',
                ),
                SizedBox(height: 16),
                Text(
                  'Notre Mission',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Fournir des équipements de topographie de qualité supérieure et un service après-vente exceptionnel pour accompagner nos clients dans la réussite de leurs projets.',
                ),
                SizedBox(height: 16),
                Text(
                  'Localisation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(CompanyLocation.address),
                SizedBox(height: 4),
                Text(
                  CompanyLocation.plusCode,
                  style: TextStyle(fontSize: 12, color: Color(0xFF7A7A7A)),
                ),
                SizedBox(height: 16),
                Text(
                  'Zone d\'intervention',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Sous-région ouest-africaine (Togo, Ghana, Bénin, Burkina Faso, Mali, etc.)',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openGoogleMaps();
              },
              icon: const Icon(Icons.map),
              label: const Text('Voir sur Google Maps'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog Notre équipe.
  ///
  /// Les noms et fonctions viennent de `lib/team.dart` : ne les codez pas ici,
  /// ils seraient ignorés par les autres écrans et par les tests.
  void _showTeamDialog(BuildContext context) {
    // Trace de diagnostic : montre dans le terminal l’équipe réellement
    // compilée, pour distinguer un problème de données d’un problème de build.
    assert(() {
      debugPrint(
        'Équipe compilée (${kTeamMembers.length}) : '
        '${kTeamMembers.map((member) => member.firstName).join(', ')}',
      );
      return true;
    }());
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Notre équipe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final member in kTeamMembers)
                  ListTile(
                    key: ValueKey('team-member-${member.firstName}'),
                    leading: CircleAvatar(
                      backgroundColor: member.color,
                      child: Text(
                        member.initial,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(member.firstName),
                    subtitle: Text(member.subtitle),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog Nos partenaires
  void _showPartnersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nos partenaires'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.gps_fixed, color: Color(0xFF2563EB)),
                  title: Text('Leica'),
                  subtitle: Text('Équipements de précision suisses'),
                ),
                ListTile(
                  leading: Icon(Icons.satellite_alt, color: Color(0xFFDC2626)),
                  title: Text('e-survey'),
                  subtitle: Text('GPS de nouvelle génération'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog Nos services
  void _showServicesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Nos services'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.shopping_cart, color: Color(0xFF2563EB)),
                  title: Text('Vente'),
                  subtitle: Text('Équipements neufs avec garantie 2 ans'),
                ),
                ListTile(
                  leading: Icon(Icons.access_time, color: Color(0xFF059669)),
                  title: Text('Location'),
                  subtitle: Text(
                    'GPS, théodolites, niveaux et stations totales',
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.school, color: Color(0xFFDC2626)),
                  title: Text('Formation'),
                  subtitle: Text('Initiation et perfectionnement'),
                ),
                ListTile(
                  leading: Icon(Icons.build, color: Color(0xFF7C3AED)),
                  title: Text('Réparation'),
                  subtitle: Text('Service après-vente et maintenance'),
                ),
                ListTile(
                  leading: Icon(Icons.update, color: Color(0xFFEA580C)),
                  title: Text('Mise à jour des logiciels'),
                  subtitle: Text('Logiciels de calcul et de CAO'),
                ),
                ListTile(
                  leading: Icon(Icons.support, color: Color(0xFF1F2937)),
                  title: Text('Support technique'),
                  subtitle: Text('Assistance 24h/24 et 7j/7'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog Politique de confidentialité
  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Politique de confidentialité'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Protection des données personnelles',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  'En conformité avec le RGPD, nous nous engageons à protéger vos données personnelles.',
                ),
                SizedBox(height: 16),
                Text(
                  'Données collectées :',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Nom et coordonnées'),
                Text('• Historique des commandes'),
                Text('• Données de localisation'),
                SizedBox(height: 16),
                Text(
                  'Utilisation :',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Traitement des commandes'),
                Text('• Amélioration de nos services'),
                Text('• Communication commerciale (avec consentement)'),
                SizedBox(height: 16),
                Text(
                  'Vos droits :',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Accès et rectification'),
                Text('• Effacement et portabilité'),
                Text('• Opposition et limitation'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog Conditions d'utilisation
  void _showTermsOfUseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Conditions d\'utilisation'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mentions légales',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  'Éditeur de l\'application :',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('ÉCHELLE EG39\nLomé, Togo\nSIRET : 123456789'),
                SizedBox(height: 16),
                Text(
                  'Responsabilité :',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'L\'application est fournie "en l\'état" sans garantie. Nous nous efforçons d\'assurer l\'exactitude des informations mais ne pouvons être tenus responsables des erreurs.',
                ),
                SizedBox(height: 16),
                Text(
                  'Propriété intellectuelle :',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Tous les contenus de l\'application sont protégés par les droits d\'auteur.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog Crédits
  void _showCreditsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Crédits'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Équipe de développement',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  'Développement :',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Développeur Principal'),
                Text('• Designer UI/UX'),
                Text('• Développeur Mobile'),
                SizedBox(height: 16),
                Text(
                  'Technologies utilisées :',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Flutter'),
                Text('• Dart'),
                Text('• Firebase'),
                SizedBox(height: 16),
                Text(
                  'Version :',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('1.0.0 - Mars 2024'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  /// Invite un nouvel utilisateur à installer l’application.
  void _showInviteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => InviteAppDialog(openUri: widget.launchContactUri),
    );
  }

  /// Envoie la fiche de l’entreprise vers les réseaux sociaux.
  void _showShareDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => ShareCompanyDialog(openUri: widget.launchContactUri),
    );
  }
}
