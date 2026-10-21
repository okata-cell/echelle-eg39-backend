import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'login.page.dart';
import 'profile_api.dart';

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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _sendError = null;
    });
    try {
      await widget.profileApi.submitSupportMessage(message: messageText);
      if (!mounted) return;
      final timestamp = DateTime.now();
      setState(() {
        _messages
          ..add(
            ChatMessage(text: messageText, isBot: false, timestamp: timestamp),
          )
          ..add(
            ChatMessage(
              text:
                  'Votre message a été transmis au support. L’équipe vous recontactera via les coordonnées de votre compte.',
              isBot: true,
              timestamp: DateTime.now(),
            ),
          );
        _sendError = null;
      });
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } on ProfileApiException catch (error) {
      if (mounted) setState(() => _sendError = error.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
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
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key, this.profileApi});

  final ProfileApi? profileApi;

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
  final TextEditingController _personalEmailController = TextEditingController();
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
  String _userAddress = '';
  String _userCity = '';
  String _userCountry = 'Togo';
  String _userCompany = '';
  String _contactPreference = 'Email';
  bool _notificationsEnabled = true;
  bool _smsEnabled = true;
  bool _callsEnabled = false;

  String get _addressSummary => [
    _userAddress,
    _userCity,
    _userCountry,
  ].where((part) => part.trim().isNotEmpty).join(', ');

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
    await _loadLocalPreferences();

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

  Future<void> _loadLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _contactPreference =
          prefs.getString('profile.contactPreference') ?? 'Email';
      _notificationsEnabled = prefs.getBool('profile.notifications') ?? true;
      _smsEnabled = prefs.getBool('profile.sms') ?? true;
      _callsEnabled = prefs.getBool('profile.calls') ?? false;
    });
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
      _userCompany = profile.company;
      _userAddress = profile.address;
      _userCity = profile.city;
      _userCountry = profile.country;
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
      backgroundColor: const Color(0xFFF9FAFB),
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

  /// Construit l'en-tête avec avatar et informations utilisateur
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          _buildAvatar(),
          const SizedBox(height: 12),
          _buildUserInfo(),
        ],
      ),
    );
  }

  /// Construit l'avatar utilisateur
  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _showImagePickerDialog,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (_selectedAvatarBytes != null)
              ClipOval(
                child: Image.memory(
                  _selectedAvatarBytes!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.person,
                    size: 40,
                    color: Color(0xFF2563EB),
                  ),
                ),
              )
            else
              Center(
                child: Text(
                  _userName.trim().isEmpty
                      ? '…'
                      : _userName
                            .trim()
                            .split(RegExp(r'\\s+'))
                            .take(2)
                            .map(
                              (part) =>
                                  part.isEmpty ? '' : part[0].toUpperCase(),
                            )
                            .join(),
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 70,
      );
      if (image == null || !mounted) return;

      final bytes = await image.readAsBytes();
      final mimeType = switch (image.mimeType?.toLowerCase() ??
          image.name.split('.').last.toLowerCase()) {
        'image/jpeg' || 'jpg' || 'jpeg' => 'image/jpeg',
        'image/png' || 'png' => 'image/png',
        'image/webp' || 'webp' => 'image/webp',
        _ => null,
      };
      if (mimeType == null) {
        _showProfileMessage(
          'Choisissez une image JPEG, PNG ou WebP.',
          isError: true,
        );
        return;
      }
      if (bytes.lengthInBytes > ProfileApi.maxAvatarBytes) {
        _showProfileMessage('La photo doit peser 1 Mo maximum.', isError: true);
        return;
      }

      setState(() => _isSavingProfile = true);
      try {
        final profile = await _profileApi.updateAvatar(
          bytes: bytes,
          mimeType: mimeType,
        );
        await _applyProfile(profile, cache: true);
        if (mounted) _showProfileMessage('Photo de profil enregistrée.');
      } on ProfileApiException catch (error) {
        if (mounted) _showProfileMessage(error.message, isError: true);
      } finally {
        if (mounted) setState(() => _isSavingProfile = false);
      }
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text(
            _userName,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _userEmail,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFFBFDBFE),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Modifier les informations personnelles',
                onPressed: () => _showPersonalInfoDialog(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(32, 32),
                  maximumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construit le contenu principal de l'écran
  Widget _buildContent(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            _buildAccountSection(context),
            const SizedBox(height: 16),
            _buildSupportSection(context),
            const SizedBox(height: 16),
            _buildAppInfo(),
            const SizedBox(height: 16),
            _buildLogoutButton(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Section "Mon compte"
  Widget _buildAccountSection(BuildContext context) {
    return _buildSection('Mon compte', [
      _buildMenuItem(
        context,
        Icons.person,
        'Informations personnelles',
        () => _showPersonalInfoDialog(context),
      ),
      _buildMenuItem(
        context,
        Icons.phone,
        'Numéro de téléphone',
        () => _showPhoneDialog(context),
        trailing: _userPhone,
      ),
      _buildMenuItem(
        context,
        Icons.location_on,
        'Adresse de l’entreprise',
        () => _showAddressDialog(context),
        trailing: _addressSummary,
      ),
      _buildMenuItem(
        context,
        Icons.business,
        'Entreprise',
        () => _showProfessionalInfoDialog(context),
        trailing: _userCompany,
      ),
      _buildMenuItem(
        context,
        Icons.lock,
        'Mot de passe',
        () => _showPasswordDialog(context),
        trailing: '••••••••',
      ),
      _buildMenuItem(
        context,
        Icons.contact_phone,
        'Préférences de contact',
        () => _showContactPreferencesDialog(context),
        trailing: _contactPreference,
      ),
      _buildMenuItem(
        context,
        Icons.settings,
        'Paramètres',
        () => _showSettingsDialog(context),
      ),
    ]);
  }

  /// Section "Support"
  Widget _buildSupportSection(BuildContext context) {
    return _buildSection('Support', [
      _buildMenuItem(
        context,
        Icons.chat,
        'Chat Support',
        () => _showChatSupportDialog(context),
      ),
      _buildMenuItem(
        context,
        Icons.help_center,
        'Centre d\'aide',
        () => _showHelpCenterDialog(context),
      ),

      _buildMenuItem(
        context,
        Icons.info_outline,
        'À propos',
        () => _showAboutDialog(context),
      ),
    ]);
  }

  /// Informations de l'application
  Widget _buildAppInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'ÉCHELLE EG39',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton de déconnexion
  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showLogoutDialog(context),
        icon: const Icon(Icons.logout),
        label: Text(
          'Se déconnecter',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFEE2E2),
          foregroundColor: const Color(0xFFDC2626),
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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

  /// Construit une section avec titre et éléments
  Widget _buildSection(String title, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          ...items,
        ],
      ),
    );
  }

  /// Construit un élément de menu
  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    String? trailing,
  }) {
    return InkWell(
      key: ValueKey('profile-menu-$title'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF6B7280),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
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

  Future<void> _showAddressDialog(BuildContext context) async {
    final profile = _profile;
    if (profile == null) return;
    final addressController = TextEditingController(text: profile.address);
    final cityController = TextEditingController(text: profile.city);
    final countryController = TextEditingController(text: profile.country);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Adresse de l’entreprise'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Adresse complète',
                    ),
                    maxLines: 2,
                  ),
                  TextField(
                    controller: cityController,
                    decoration: const InputDecoration(labelText: 'Ville'),
                  ),
                  TextField(
                    controller: countryController,
                    decoration: const InputDecoration(labelText: 'Pays'),
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
                        setDialogState(() => isSubmitting = true);
                        final saved = await _saveProfile(
                          address: addressController.text,
                          city: cityController.text,
                          country: countryController.text,
                          successMessage: 'Adresse enregistrée.',
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
    addressController.dispose();
    cityController.dispose();
    countryController.dispose();
  }

  Future<void> _showProfessionalInfoDialog(BuildContext context) async {
    final controller = TextEditingController(text: _userCompany);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Informations professionnelles'),
        content: TextField(
          controller: controller,
          maxLength: 255,
          decoration: const InputDecoration(labelText: 'Entreprise'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final saved = await _saveProfile(
                company: controller.text,
                successMessage: 'Entreprise enregistrée.',
              );
              if (dialogContext.mounted && saved) Navigator.pop(dialogContext);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
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

  Future<void> _showContactPreferencesDialog(BuildContext context) async {
    var preference = _contactPreference;
    var notifications = _notificationsEnabled;
    var sms = _smsEnabled;
    var calls = _callsEnabled;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Préférences de contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Moyen de contact préféré'),
                ),
                RadioGroup<String>(
                  groupValue: preference,
                  onChanged: (value) {
                    if (value != null) setDialogState(() => preference = value);
                  },
                  child: const Column(
                    children: [
                      RadioListTile<String>(
                        title: Text('E-mail'),
                        value: 'Email',
                      ),
                      RadioListTile<String>(title: Text('SMS'), value: 'SMS'),
                      RadioListTile<String>(
                        title: Text('Appel téléphonique'),
                        value: 'Appels',
                      ),
                    ],
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Notifications push'),
                  value: notifications,
                  onChanged: (value) =>
                      setDialogState(() => notifications = value),
                ),
                SwitchListTile(
                  title: const Text('Recevoir les SMS'),
                  value: sms,
                  onChanged: (value) => setDialogState(() => sms = value),
                ),
                SwitchListTile(
                  title: const Text('Recevoir les appels'),
                  value: calls,
                  onChanged: (value) => setDialogState(() => calls = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || saved != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile.contactPreference', preference);
    await prefs.setBool('profile.notifications', notifications);
    await prefs.setBool('profile.sms', sms);
    await prefs.setBool('profile.calls', calls);
    setState(() {
      _contactPreference = preference;
      _notificationsEnabled = notifications;
      _smsEnabled = sms;
      _callsEnabled = calls;
    });
    _showProfileMessage('Préférences enregistrées sur cet appareil.');
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    var notifications = _notificationsEnabled;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Paramètres'),
          content: SwitchListTile(
            title: const Text('Notifications push'),
            subtitle: const Text('Préférence enregistrée sur cet appareil.'),
            value: notifications,
            onChanged: (value) => setDialogState(() => notifications = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || saved != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('profile.notifications', notifications);
    setState(() => _notificationsEnabled = notifications);
    _showProfileMessage('Préférence enregistrée sur cet appareil.');
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

  /// Construit un élément vidéo
  Widget _buildVideoItem(String title, String url) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.play_circle, color: Color(0xFFDC2626)),
        title: Text(title),
        subtitle: const Text('Cliquer pour voir la vidéo'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _openYouTubeVideo(url),
      ),
    );
  }

  /// Ouvre une recherche YouTube basée sur le titre de la vidéo
  Future<void> _openYouTubeVideo(String videoTitle) async {
    try {
      // Nettoyer le titre pour en faire une requête de recherche efficace
      String searchQuery = _generateSearchQuery(videoTitle);

      // Créer l'URL de recherche YouTube
      String youtubeSearchUrl =
          'https://www.youtube.com/results?search_query=${Uri.encodeComponent(searchQuery)}';
      Uri searchUri = Uri.parse(youtubeSearchUrl);

      if (await canLaunchUrl(searchUri)) {
        await launchUrl(searchUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: recherche générique sur la topographie
        String fallbackUrl =
            'https://www.youtube.com/results?search_query=topographie+gps+formation';
        Uri fallbackUri = Uri.parse(fallbackUrl);
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      // En cas d'erreur, ouvrir une recherche YouTube générique
      String fallbackUrl =
          'https://www.youtube.com/results?search_query=tutoriel+topographie+gps';
      Uri fallbackUri = Uri.parse(fallbackUrl);
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Génère une requête de recherche optimisée à partir du titre
  String _generateSearchQuery(String title) {
    // Dictionnaire de mots-clés pour améliorer les recherches
    Map<String, String> keywords = {
      'GPS e-survey E300': 'GPS e-survey E300 configuration tutorial',
      'Théodolite Leica': 'Leica theodolite tutorial使用方法',
      'Station totale': 'total station surveying tutorial',
      'Niveau automatique': 'automatic level surveying tutorial',
      'Calibration GPS': 'GPS calibration RTK tutorial',
      'Formation topographie': 'surveying basics tutorial',
      'Calcul de surfaces': 'land area calculation surveying',
      'Implantation d\'ouvrages': 'construction staking surveying tutorial',
    };

    // Rechercher des correspondances dans le dictionnaire
    for (String key in keywords.keys) {
      if (title.contains(key)) {
        return keywords[key]!;
      }
    }

    // Si aucune correspondance trouvée, utiliser le titre original
    return title;
  }

  /// Article consultable : tap to expand the complete information.
  Widget _buildKnowledgeItem(String title, String description) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: const Icon(Icons.article_outlined, color: Color(0xFF2563EB)),
        title: Text(title),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [Text(description)],
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

  Widget _buildTrainingItem({
    required String title,
    required String description,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.school_outlined, color: Color(0xFF2563EB)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? const Color(0xFF2563EB) : Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }

  /// Affiche le dialog du centre d'aide avec les 7 nouvelles fonctionnalités
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
                  Icons.play_circle_outline,
                  'Tutoriels vidéo',
                  'Guides d\'utilisation des équipements',
                  () {
                    Navigator.of(context).pop();
                    _showVideoTutorialsDialog(context);
                  },
                ),
                _buildHelpCenterItem(
                  context,
                  Icons.bug_report,
                  'Signaler un problème',
                  'Formulaire avec photos et description',
                  () {
                    Navigator.of(context).pop();
                    _showReportProblemDialog(context);
                  },
                ),
                _buildHelpCenterItem(
                  context,
                  Icons.library_books,
                  'Base de connaissances',
                  'Articles techniques sur la topographie',
                  () {
                    Navigator.of(context).pop();
                    _showKnowledgeBaseDialog(context);
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
                _buildHelpCenterItem(
                  context,
                  Icons.school,
                  'Centre de formation',
                  'Calendrier des formations disponibles',
                  () {
                    Navigator.of(context).pop();
                    _showTrainingCenterDialog(context);
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

  /// Dialog Tutoriels vidéo
  void _showVideoTutorialsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Tutoriels Vidéo'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildVideoItem(
                  'GPS e-survey E300 - Configuration',
                  'GPS e-survey E300 configuration tutorial',
                ),

                _buildVideoItem(
                  'Théodolite Leica - Utilisation de base',
                  'Leica theodolite tutorial使用方法',
                ),

                _buildVideoItem(
                  'Station totale - Relevé topographique',
                  'total station surveying tutorial',
                ),

                _buildVideoItem(
                  'Niveau automatique - Nivellement',
                  'automatic level surveying tutorial',
                ),

                _buildVideoItem(
                  'Calibration GPS de précision',
                  'GPS calibration RTK tutorial',
                ),
                _buildVideoItem(
                  'Formation topographie de base',
                  'surveying basics tutorial',
                ),
                _buildVideoItem(
                  'Calcul de surfaces topographiques',
                  'land area calculation surveying',
                ),
                _buildVideoItem(
                  'Implantation d\'ouvrages',
                  'construction staking surveying tutorial',
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

  Future<void> _showReportProblemDialog(BuildContext context) async {
    final messageController = TextEditingController();
    final attachments = <ProfileImageAttachment>[];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isSubmitting = false;
        String? error;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Signaler un problème'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    maxLength: 5000,
                    decoration: const InputDecoration(
                      labelText: 'Décrivez le problème',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed:
                        isSubmitting ||
                            attachments.length >=
                                ProfileApi.maxSupportAttachmentCount
                        ? null
                        : () async {
                            final file = await _picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1000,
                              maxHeight: 1000,
                              imageQuality: 70,
                            );
                            if (file == null || !dialogContext.mounted) return;
                            final mimeType = switch (file.mimeType
                                    ?.toLowerCase() ??
                                file.name.split('.').last.toLowerCase()) {
                              'image/jpeg' || 'jpg' || 'jpeg' => 'image/jpeg',
                              'image/png' || 'png' => 'image/png',
                              'image/webp' || 'webp' => 'image/webp',
                              _ => null,
                            };
                            if (mimeType == null) {
                              setDialogState(
                                () => error =
                                    'Choisissez une image JPEG, PNG ou WebP.',
                              );
                              return;
                            }
                            final bytes = await file.readAsBytes();
                            final currentTotal = attachments.fold<int>(
                              0,
                              (total, image) =>
                                  total + image.bytes.lengthInBytes,
                            );
                            if (bytes.lengthInBytes + currentTotal >
                                ProfileApi.maxSupportAttachmentBytes) {
                              setDialogState(
                                () => error =
                                    'Le total des images ne peut pas dépasser 2 Mo.',
                              );
                              return;
                            }
                            setDialogState(() {
                              error = null;
                              attachments.add(
                                ProfileImageAttachment(
                                  bytes: bytes,
                                  mimeType: mimeType,
                                ),
                              );
                            });
                          },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text('Ajouter des photos (${attachments.length}/3)'),
                  ),
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var index = 0; index < attachments.length; index++)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  attachments[index].bytes,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: -8,
                                top: -8,
                                child: IconButton(
                                  tooltip: 'Retirer la photo',
                                  onPressed: () => setDialogState(
                                    () => attachments.removeAt(index),
                                  ),
                                  icon: const Icon(Icons.cancel, size: 20),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ],
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
                        if (messageController.text.trim().isEmpty) {
                          setDialogState(
                            () => error =
                                'Décrivez le problème avant de l’envoyer.',
                          );
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          error = null;
                        });
                        try {
                          await _profileApi.submitSupportMessage(
                            message: messageController.text,
                            attachments: attachments,
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          Navigator.pop(dialogContext);
                          if (mounted) {
                            _showProfileMessage(
                              'Votre message a été transmis au support.',
                            );
                          }
                        } on ProfileApiException catch (apiError) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isSubmitting = false;
                              error = apiError.message;
                            });
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Envoyer'),
              ),
            ],
          ),
        );
      },
    );
    messageController.dispose();
  }

  /// Dialog Base de connaissances
  void _showKnowledgeBaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Base de connaissances'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildKnowledgeItem(
                  'Principes de topographie',
                  'Les bases de la topographie moderne',
                ),
                _buildKnowledgeItem(
                  'GPS de précision',
                  'Fonctionnement et calibration',
                ),
                _buildKnowledgeItem('Calcul de surfaces', 'Méthodes et outils'),
                _buildKnowledgeItem(
                  'Implantation d\'ouvrages',
                  'Techniques et bonnes pratiques',
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

  Future<void> _launchContact(Uri uri) async {
    try {
      if (!await canLaunchUrl(uri)) {
        if (mounted) {
          _showProfileMessage(
            'Impossible d’ouvrir cette application.',
            isError: true,
          );
        }
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        _showProfileMessage(
          'Impossible d’ouvrir cette application.',
          isError: true,
        );
      }
    }
  }

  /// Les actions ouvrent maintenant le composeur système correspondant.
  void _showDirectContactDialog(BuildContext context) {
    const phone = '+22890014329';
    const email = 'contact@echelle-eg39.com';
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
                '+228 90 01 43 29',
                () => _launchContact(Uri(scheme: 'tel', path: phone)),
              ),
              _buildContactItem(
                Icons.email,
                'E-mail',
                email,
                () => _launchContact(Uri(scheme: 'mailto', path: email)),
              ),
              _buildContactItem(
                Icons.chat,
                'WhatsApp',
                '+228 90 01 43 29',
                () => _launchContact(
                  Uri.https('wa.me', '/22890014329', {
                    'text': 'Bonjour ÉCHELLE EG39, j’ai besoin d’aide.',
                  }),
                ),
              ),
              _buildContactItem(
                Icons.schedule,
                'Horaires',
                'Lundi–vendredi : 8h–18h\nSamedi : sur demande',
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

  /// L’inscription devient une demande d’intérêt, sans dates de session promises.
  Future<void> _showTrainingCenterDialog(BuildContext context) async {
    const trainings = <(String, String)>[
      (
        'Initiation GPS',
        'Formation de base à l’utilisation des GPS de précision.',
      ),
      (
        'Perfectionnement Théodolite',
        'Techniques avancées de mesure angulaire.',
      ),
      ('Stations totales', 'Utilisation des stations totales en topographie.'),
      ('Calcul topographique', 'Méthodes de calcul et de compensation.'),
    ];

    var selectedTraining = '';
    final requestedTraining = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Centre de formation'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choisissez un thème. L’équipe vous contactera au sujet des prochaines sessions.',
                  ),
                  const SizedBox(height: 12),
                  for (final training in trainings)
                    _buildTrainingItem(
                      title: training.$1,
                      description: training.$2,
                      selected: selectedTraining == training.$1,
                      onTap: () =>
                          setDialogState(() => selectedTraining = training.$1),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: selectedTraining.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, selectedTraining),
              child: const Text('Demander à être recontacté'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || requestedTraining == null) return;
    try {
      await _profileApi.registerTrainingInterest(
        trainingName: requestedTraining,
      );
      if (mounted) {
        _showProfileMessage(
          'Demande enregistrée. L’équipe vous contactera pour cette formation.',
        );
      }
    } on ProfileApiException catch (error) {
      if (mounted) _showProfileMessage(error.message, isError: true);
    }
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
                  'Leica, Stonex, e-survey',
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
                  Icons.star,
                  'Évaluation',
                  'Notez l\'application',
                  () {
                    Navigator.of(context).pop();
                    _showRatingDialog(context);
                  },
                ),
                _buildAboutItem(
                  context,
                  Icons.share,
                  'Partage',
                  'Invitez vos collègues',
                  () {
                    Navigator.of(context).pop();
                    _showShareDialog(context);
                  },
                ),
                _buildAboutItem(
                  context,
                  Icons.verified,
                  'Certifications',
                  'ISO et agréments techniques',
                  () {
                    Navigator.of(context).pop();
                    _showCertificationsDialog(context);
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

  /// Ouvre Google Maps avec la localisation de l'entreprise
  Future<void> _openGoogleMaps() async {
    const String googleMapsUrl =
        'https://www.google.com/maps/search/Aflao+Gagli+Lomé+Togo';
    final Uri uri = Uri.parse(googleMapsUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // En cas d'erreur, ouvrir Google Maps avec une recherche plus générale
      const String fallbackUrl = 'https://www.google.com/maps/search/Lomé+Togo';
      final Uri fallbackUri = Uri.parse(fallbackUrl);
      if (await canLaunchUrl(fallbackUri)) {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
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
                Text('Lomé, quartier Aflao Gagli, Togo'),
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

  /// Dialog Notre équipe
  void _showTeamDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Notre équipe'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFF2563EB),
                    child: Text('M', style: TextStyle(color: Colors.white)),
                  ),
                  title: Text('Maurice'),
                  subtitle: Text('Directeur Général\nExpert en topographie'),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFF059669),
                    child: Text('A', style: TextStyle(color: Colors.white)),
                  ),
                  title: Text('Akossiwa'),
                  subtitle: Text('Responsable Commerciale\nSpécialiste GPS'),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFDC2626),
                    child: Text('K', style: TextStyle(color: Colors.white)),
                  ),
                  title: Text('Koffi'),
                  subtitle: Text('Technicien SAV\nExpert en réparation'),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFF7C3AED),
                    child: Text('Y', style: TextStyle(color: Colors.white)),
                  ),
                  title: Text('Yao'),
                  subtitle: Text('Formateur\nExpert en théodolites'),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFEA580C),
                    child: Text('A', style: TextStyle(color: Colors.white)),
                  ),
                  title: Text('Abigail'),
                  subtitle: Text('Responsable Administrative\nSupport client'),
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
                  leading: Icon(Icons.science, color: Color(0xFF059669)),
                  title: Text('Stonex'),
                  subtitle: Text('Technologies de mesure italiennes'),
                ),
                ListTile(
                  leading: Icon(Icons.satellite_alt, color: Color(0xFFDC2626)),
                  title: Text('e-survey'),
                  subtitle: Text('GPS de nouvelle génération'),
                ),
                ListTile(
                  leading: Icon(Icons.construction, color: Color(0xFF7C3AED)),
                  title: Text('Trimble'),
                  subtitle: Text('Solutions de géolocalisation'),
                ),
                ListTile(
                  leading: Icon(
                    Icons.precision_manufacturing,
                    color: Color(0xFFEA580C),
                  ),
                  title: Text('Sokkia'),
                  subtitle: Text('Instruments topographiques japonais'),
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

  /// Enregistre réellement la note et son commentaire dans le compte connecté.
  Future<void> _showRatingDialog(BuildContext context) async {
    var selectedRating = 5;
    final commentController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isSubmitting = false;
        String? error;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Évaluer l’application'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Comment évaluez-vous notre application ?'),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Note : $selectedRating sur 5 étoiles',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => IconButton(
                        tooltip: '${index + 1} étoile${index == 0 ? '' : 's'}',
                        onPressed: isSubmitting
                            ? null
                            : () => setDialogState(
                                () => selectedRating = index + 1,
                              ),
                        icon: Icon(
                          index < selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: const Color(0xFF9A6700),
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire (facultatif)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                if (error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      error!,
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                  ),
              ],
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
                        setDialogState(() {
                          isSubmitting = true;
                          error = null;
                        });
                        try {
                          await _profileApi.submitRating(
                            rating: selectedRating,
                            comment: commentController.text,
                          );
                          if (!dialogContext.mounted) {
                            return;
                          }
                          Navigator.pop(dialogContext);
                          if (mounted) {
                            _showProfileMessage(
                              'Merci, votre évaluation a été enregistrée.',
                            );
                          }
                        } on ProfileApiException catch (apiError) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isSubmitting = false;
                              error = apiError.message;
                            });
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Envoyer'),
              ),
            ],
          ),
        );
      },
    );
    commentController.dispose();
  }

  /// Partage un texte réel via le composeur WhatsApp, e-mail ou le presse-papiers.
  void _showShareDialog(BuildContext context) {
    const invitation =
        'Découvrez ÉCHELLE EG39, votre partenaire en équipements de topographie. Contact : +228 90 01 43 29 — contact@echelle-eg39.com';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Partager ÉCHELLE EG39'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Partagez les coordonnées de l’entreprise.'),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _launchContact(
                      Uri.https('wa.me', '/', {'text': invitation}),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.email_outlined),
                  label: const Text('E-mail'),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _launchContact(
                      Uri(
                        scheme: 'mailto',
                        path: 'contact@echelle-eg39.com',
                        queryParameters: {
                          'subject': 'ÉCHELLE EG39',
                          'body': invitation,
                        },
                      ),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.copy_outlined),
                  label: const Text('Copier le texte'),
                  onPressed: () async {
                    await Clipboard.setData(
                      const ClipboardData(text: invitation),
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    if (mounted) _showProfileMessage('Texte copié.');
                  },
                ),
              ],
            ),
          ],
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

  /// Dialog Certifications
  void _showCertificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Certifications'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.verified, color: Color(0xFF2563EB)),
                  title: Text('ISO 9001:2015'),
                  subtitle: Text('Management de la qualité'),
                ),
                ListTile(
                  leading: Icon(Icons.security, color: Color(0xFF059669)),
                  title: Text('ISO 14001:2015'),
                  subtitle: Text('Management environnemental'),
                ),
                ListTile(
                  leading: Icon(
                    Icons.health_and_safety,
                    color: Color(0xFFDC2626),
                  ),
                  title: Text('ISO 45001:2018'),
                  subtitle: Text('Santé et sécurité au travail'),
                ),
                ListTile(
                  leading: Icon(Icons.gavel, color: Color(0xFF7C3AED)),
                  title: Text('Agréments techniques'),
                  subtitle: Text('Reconnaissance officielle'),
                ),
                ListTile(
                  leading: Icon(
                    Icons.precision_manufacturing,
                    color: Color(0xFFEA580C),
                  ),
                  title: Text('Certifications partenaires'),
                  subtitle: Text('Leica, Stonex, e-survey'),
                ),
                ListTile(
                  leading: Icon(
                    Icons.account_balance_wallet,
                    color: Color(0xFF1F2937),
                  ),
                  title: Text('Licences de distribution'),
                  subtitle: Text('Autorisations officielles'),
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
}
