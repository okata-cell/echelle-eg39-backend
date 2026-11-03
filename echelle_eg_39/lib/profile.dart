import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_avatar_image.dart';

import 'company_contact.dart';
import 'company_location.dart';
import 'login.page.dart';
import 'profile_api.dart';
import 'profile_theme.dart';
import 'support_assistant.dart';
import 'widgets/about_hub_screen.dart';
import 'widgets/help_center_screen.dart';
import 'widgets/personal_info_screen.dart';

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

// Jetons et échelle typographique partagés avec les feuilles de détail du
// Profil : ils vivent dans `profile_theme.dart` pour rester une seule source.
typedef _ProfileTokens = ProfileTokens;
typedef _ProfileText = ProfileText;

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
    String? address,
    String? city,
    String? country,
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
        address: address ?? profile.address,
        city: city ?? profile.city,
        country: country ?? profile.country,
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
      onPressed: () => _openPersonalInfo(context),
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
        () => _openPersonalInfo(context),
        subtitle: 'Identité, e-mail et coordonnées',
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
        () => _openSheet(
          context,
          HelpCenterScreen(launchUri: widget.launchContactUri),
        ),
        subtitle: 'FAQ, glossaire et contact',
      ),

      _buildMenuItem(
        context,
        Icons.info_outline,
        'À propos',
        () => _openSheet(
          context,
          AboutHubScreen(
            openUri: widget.launchContactUri,
            launchMaps: widget.launchGoogleMaps,
          ),
        ),
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

  /// Ouvre la feuille « Informations personnelles ».
  ///
  /// Un seul formulaire et un seul bouton : le sélecteur ne fait que montrer un
  /// groupe de champs à la fois, sans perdre les valeurs saisies.
  Future<void> _openPersonalInfo(BuildContext context) async {
    final profile = _profile;
    if (profile == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PersonalInfoScreen(
          profile: profile,
          onSubmit: (draft) => _saveProfile(
            firstName: draft.firstName,
            lastName: draft.lastName,
            email: draft.email,
            company: draft.company,
            address: draft.address,
            city: draft.city,
            country: draft.country,
            currentPassword: draft.currentPassword,
            successMessage: 'Informations personnelles enregistrées.',
          ),
        ),
      ),
    );
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

  /// Ouvre une feuille de détail par-dessus l’écran Profil.
  void _openSheet(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }













}
