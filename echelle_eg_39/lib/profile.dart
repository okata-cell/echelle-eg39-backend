
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'login.page.dart';

/// Dialog de support chat pour l'assistance rapide
class ChatSupportDialog extends StatefulWidget {
  const ChatSupportDialog({Key? key}) : super(key: key);

  @override
  State<ChatSupportDialog> createState() => _ChatSupportDialogState();
}

class _ChatSupportDialogState extends State<ChatSupportDialog> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Bonjour ! Comment puis-je vous aider aujourd\'hui ?',
      isBot: true,
      timestamp: DateTime.now(),
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    final userMessage = ChatMessage(
      text: messageText,
      isBot: false,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
    });

    _messageController.clear();

    // Simulation de réponse du bot après un délai
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      
      final botResponse = _generateBotResponse(messageText);
      setState(() {
        _messages.add(botResponse);
      });
    });
  }

  ChatMessage _generateBotResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();
    
    // Salutations
    if (lowerMessage.contains('bonjour') || lowerMessage.contains('salut') || lowerMessage.contains('hello')) {
      return ChatMessage(
        text: 'Bonjour ! Bienvenue chez ÉCHELLE EG39, votre partenaire en équipements de topographie. Comment puis-je vous aider aujourd\'hui ?',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('merci') || lowerMessage.contains('remercie')) {
      return ChatMessage(
        text: 'Je vous en prie ! C\'est un plaisir de vous aider. N\'hésitez pas si vous avez d\'autres questions !',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('au revoir') || lowerMessage.contains('bye') || (lowerMessage.contains('salut') && lowerMessage.contains('plus'))) {
      return ChatMessage(
        text: 'Au revoir ! À bientôt chez ÉCHELLE EG39. N\'oubliez pas de consulter nos équipements disponibles !',
        isBot: true,
        timestamp: DateTime.now(),
      );
    }
    
    // Informations sur l'entreprise
    else if (lowerMessage.contains('entreprise') || lowerMessage.contains('société') || lowerMessage.contains('qui êtes-vous')) {
      return ChatMessage(
        text: 'ÉCHELLE EG39 est une entreprise spécialisée dans la vente et location d\'équipements de topographie. Nous proposons GPS, Théodolites, Niveaux et station totales pour les professionnels du secteur.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('où') || lowerMessage.contains('localisation') || lowerMessage.contains('adresse') || lowerMessage.contains('situe')) {
      return ChatMessage(
        text: 'Nous sommes situés au Togo plus precisement a Lomé, quartier aflao gagli et intervenons dans toute la sous-région ouest-africaine. Contactez-nous pour connaître notre adresse exacte et nos points de service.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('contact') || lowerMessage.contains('téléphone') || lowerMessage.contains('mail') || lowerMessage.contains('email')) {
      return ChatMessage(
        text: 'Vous pouvez nous joindre via l\'application ou consulter la section "Contact" dans le menu principal. Nous sommes disponibles du lundi au vendredi de 8h à 18h.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('horaire') || lowerMessage.contains('ouverture') || lowerMessage.contains('fermeture')) {
      return ChatMessage(
        text: 'Nos horaires : Lundi à Vendredi de 8h à 18h, Samedi de 9h à 15h. Nous sommes fermés le dimanche et les jours fériés.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    }
    
    // Services et équipements
    else if (lowerMessage.contains('service') || lowerMessage.contains('prestation')) {
      return ChatMessage(
        text: 'Nous proposons : Location d\'équipements, Vente de matériel neuf, Maintenance et SAV, Formation sur les équipements, Conseil technique personnalisé.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('équipement') || lowerMessage.contains('matériel') || lowerMessage.contains('produit')) {
      return ChatMessage(
        text: 'Nos équipements : GPS de précision, Théodolites électroniques, Niveaux automatiques, Stations totales, Accessoires de topographie. Consultez notre catalogue !',
        isBot: true,
        timestamp: DateTime.now(),
      );
    }
    
    // Questions spécifiques sur les produits
    else if (lowerMessage.contains('gps')) {
      return ChatMessage(
        text: 'Nous proposons des GPS e-survey E300, E600, E800 et autres modèles haute précision. Ils sont disponibles à la location ou à l\'achat avec garantie.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('théodolite') || lowerMessage.contains('theodolite')) {
      return ChatMessage(
        text: 'Nos théodolites Leica et Stonex offrent une précision maximale pour vos relevés. Disponibles en location avec opérateur si nécessaire.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('niveau') || lowerMessage.contains('nivellement')) {
      return ChatMessage(
        text: 'Les niveaux automatiques Leica et Stonex sont parfaits pour le nivellement de précision. Disponibles à la location ou à l\'achat.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('station totale') || lowerMessage.contains('total station')) {
      return ChatMessage(
        text: 'Nos stations totales combinent théodolite et distancemètre pour des mesures ultra-précises. Idéales pour l\'implantation et le bornage.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    }
    
    // Prix et tarifs
    else if (lowerMessage.contains('prix') || lowerMessage.contains('tarif') || lowerMessage.contains('coût')) {
      return ChatMessage(
        text: 'Nos tarifs varient selon l\'équipement et la durée. Contactez-nous pour un devis personnalisé. Location à partir de 15 000 FCFA/jour selon l\'équipement.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('location') || lowerMessage.contains('louer')) {
      return ChatMessage(
        text: 'Pour la location d\'équipements, consultez la section "Location" de notre application. Nous avons GPS, Théodolites, Niveaux et Stations totales disponibles.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('achat') || lowerMessage.contains('acheter')) {
      return ChatMessage(
        text: 'Pour acheter des équipements, rendez-vous dans la section "Vente". Tous nos produits neufs bénéficient d\'une garantie de 2 ans.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    }
    
    // Disponibilité et livraison
    else if (lowerMessage.contains('disponibilité') || lowerMessage.contains('stock') || lowerMessage.contains('disponible')) {
      return ChatMessage(
        text: 'Pour vérifier la disponibilité d\'un équipement, utilisez la fonction de recherche dans les sections Location ou Vente. Stock mis à jour en temps réel.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('livraison') || lowerMessage.contains('livrer') || lowerMessage.contains('transport')) {
      return ChatMessage(
        text: 'Nous livrons dans tout le Sénégal et en Afrique de l\'Ouest. Frais de livraison calculés selon la destination. Livraison gratuite dans Dakar pour les achats > 500 000 FCFA.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    }
    
    // Support et assistance
    else if (lowerMessage.contains('garantie') || lowerMessage.contains('sav') || lowerMessage.contains('réparation')) {
      return ChatMessage(
        text: 'Tous nos équipements neufs sont garantis 2 ans. Notre SAV assure la maintenance et les réparations. Pièces d\'origine disponibles.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('formation') || lowerMessage.contains('apprentissage')) {
      return ChatMessage(
        text: 'Nous proposons la formation sur nos équipements : initiation GPS, perfectionnement théodolite, utilisation stations totales. Formation sur site possible.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    } else if (lowerMessage.contains('aide') || lowerMessage.contains('help') || lowerMessage.contains('problème')) {
      return ChatMessage(
        text: 'Je suis là pour vous aider ! Vous pouvez aussi consulter notre FAQ dans l\'application ou contacter notre support technique au +221 XX XXX XX XX.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    }
    
    // Questions sur l'application
    else if (lowerMessage.contains('application') || lowerMessage.contains('app')) {
      return ChatMessage(
        text: 'Notre de consulter nos équipements EG39 vous permet application ÉCHELLE, faire des réservations, suivre vos commandes et accéder à notre support 24h/24.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    }
    
    // Questions métier
    else if (lowerMessage.contains('topographie') || lowerMessage.contains('géomètre') || lowerMessage.contains('implantation')) {
      return ChatMessage(
        text: 'Spécialistes de la topographie, nous accompagnons les géomètres, BTP et projets d\'infrastructure. Équipements de haute précision pour tous vos besoins.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    }
    
    // Réponse par défaut améliorée
    else {
      return ChatMessage(
        text: 'Je n\'ai pas bien compris votre question, mais je suis là pour vous aider ! Vous pouvez me demander nos services, équipements, tarifs, ou me poser toute question sur ÉCHELLE EG39. Vous pouvez aussi consulter notre FAQ ou appeler notre support au +228 90 01 43 29.',
        isBot: true,
        timestamp: DateTime.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        height: 500,
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildMessagesList(),
            ),
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
                  'En ligne',
                  style: TextStyle(
                    color: Color(0xFFBFDBFE),
                    fontSize: 12,
                  ),
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
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Tapez votre message...',
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
              onPressed: _sendMessage,
              icon: const Icon(
                Icons.send,
                color: Colors.white,
                size: 18,
              ),
            ),
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

/// Écran de profil utilisateur
/// Affiche les informations de l'utilisateur et les options de gestion du compte
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({Key? key}) : super(key: key);

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}


class _ProfilScreenState extends State<ProfilScreen> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  String _userName = 'Utilisateur';
  String _userEmail = 'user@exemple.com';
  String _userPhone = '+228 90 01 43 29';
  String _userAddress = 'Lomé, Aflao Gagli';
  String _userCompany = 'ÉCHELLE EG39';
  String _userJobTitle = 'Géomètre-Topographe';
  String _userIndustry = 'Topographie';
  String _userBirthDate = '01/01/1990';
  String _contactPreference = 'Email';
  bool _notificationsEnabled = true;
  bool _smsEnabled = true;
  bool _callsEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildContent(context),
            ],
          ),
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
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            _selectedImage != null
                ? ClipOval(
                    child: Image.file(
                      _selectedImage!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    Icons.person,
                    size: 40,
                    color: Color(0xFF2563EB),
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
            child: Icon(
              icon,
              size: 30,
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Sélectionne une image depuis la source spécifiée
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo de profil mise à jour !'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Construit les informations utilisateur
  Widget _buildUserInfo() {
    return Column(
      children: [
        Text(
          _userName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _userEmail,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFBFDBFE),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showEditProfileDialog,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Affiche le dialog d'édition du profil
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Modifier le profil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom d\'utilisateur',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _userName = nameController.text.isEmpty ? _userName : nameController.text;
                  _userEmail = emailController.text.isEmpty ? _userEmail : emailController.text;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profil mis à jour !'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        );
      },
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
    return _buildSection(
      'Mon compte',
      [
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
          'Adresse de l\'entreprise ',
          () => _showAddressDialog(context),
          trailing: _userAddress,
        ),
        _buildMenuItem(
          context,
          Icons.business,
          'Informations professionnelles',
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
          Icons.cake,
          'Date de naissance',
          () => _showBirthDateDialog(context),
          trailing: _userBirthDate,
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
      ],
    );
  }


  /// Section "Support"
  Widget _buildSupportSection(BuildContext context) {
    return _buildSection(
      'Support',
      [
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
      ],
    );
  }

  /// Informations de l'application
  Widget _buildAppInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        children: [
          Text(
            'ÉCHELLE EG39',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
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
        label: const Text('Se déconnecter'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFEE2E2),
          foregroundColor: const Color(0xFFDC2626),
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
        ),
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
              // Navigation vers la page de login et suppression de l'historique
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Déconnexion réussie !')),
              );
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  /// Affiche le dialog de support chat
  void _showChatSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ChatSupportDialog(),
    );
  }

  /// Construit une section avec titre et éléments
  Widget _buildSection(String title, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const Divider(height: 1),
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
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6B7280)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  // Dialogs pour les nouvelles fonctionnalités

  void _showPersonalInfoDialog(BuildContext context) {
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Informations personnelles'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom d\'utilisateur',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _userName = nameController.text.isEmpty ? _userName : nameController.text;
                  _userEmail = emailController.text.isEmpty ? _userEmail : emailController.text;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Informations mises à jour !'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        );
      },
    );
  }

  void _showPhoneDialog(BuildContext context) {
    final phoneController = TextEditingController(text: _userPhone);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Numéro de téléphone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ce numéro sera utilisé pour les notifications SMS',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _userPhone = phoneController.text.isEmpty ? _userPhone : phoneController.text;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Numéro mis à jour !'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        );
      },
    );
  }

  void _showAddressDialog(BuildContext context) {
    final addressController = TextEditingController(text: _userAddress);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Adresse de l\'entreprise'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Adresse complète',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              const Text(
                'Cette adresse utilisée pour localiser l\'entreprise ',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _userAddress = addressController.text.isEmpty ? _userAddress : addressController.text;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Adresse mise à jour !'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        );
      },
    );
  }

  void _showProfessionalInfoDialog(BuildContext context) {
    final companyController = TextEditingController(text: _userCompany);
    final jobTitleController = TextEditingController(text: _userJobTitle);
    final industryController = TextEditingController(text: _userIndustry);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Informations professionnelles'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: 'Entreprise',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: jobTitleController,
                decoration: const InputDecoration(
                  labelText: 'Poste',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: industryController,
                decoration: const InputDecoration(
                  labelText: 'Secteur d\'activité',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _userCompany = companyController.text.isEmpty ? _userCompany : companyController.text;
                  _userJobTitle = jobTitleController.text.isEmpty ? _userJobTitle : jobTitleController.text;
                  _userIndustry = industryController.text.isEmpty ? _userIndustry : industryController.text;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Informations professionnelles mises à jour !'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        );
      },
    );
  }

  void _showPasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Changer le mot de passe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe actuel',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              const Text(
                'Le mot de passe doit contenir au moins 8 caractères',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Les mots de passe ne correspondent pas'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (newPasswordController.text.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Le mot de passe doit contenir au moins 8 caractères'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mot de passe changé avec succès !'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Changer'),
            ),
          ],
        );
      },
    );
  }

  void _showBirthDateDialog(BuildContext context) {
    final birthDateController = TextEditingController(text: _userBirthDate);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Date de naissance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: birthDateController,
                decoration: const InputDecoration(
                  labelText: 'Date de naissance (JJ/MM/AAAA)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 8),
              const Text(
                'Utilisé pour vous offrir des offres spéciales à votre anniversaire',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _userBirthDate = birthDateController.text.isEmpty ? _userBirthDate : birthDateController.text;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Date de naissance mise à jour !'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        );
      },
    );
  }

  void _showContactPreferencesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Préférences de contact'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Comment préférez-vous être contacté ?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<String>(
                    title: const Text('Email'),
                    value: 'Email',
                    groupValue: _contactPreference,
                    onChanged: (value) {
                      setState(() {
                        _contactPreference = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('SMS'),
                    value: 'SMS',
                    groupValue: _contactPreference,
                    onChanged: (value) {
                      setState(() {
                        _contactPreference = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Appels téléphoniques'),
                    value: 'Appels',
                    groupValue: _contactPreference,
                    onChanged: (value) {
                      setState(() {
                        _contactPreference = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Notifications :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Notifications push'),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value!;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('SMS'),
                    value: _smsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _smsEnabled = value!;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Appels'),
                    value: _callsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _callsEnabled = value!;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Préférences de contact mises à jour !'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        );
      },
    );
  }



  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Paramètres'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Notifications'),
                subtitle: const Text('Gérer les notifications de l\'application'),
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Mode sombre'),
                subtitle: const Text('Utiliser le thème sombre'),
                trailing: Switch(
                  value: false,
                  onChanged: (value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fonctionnalité bientôt disponible'),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Langue'),
                subtitle: const Text('Français'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fonctionnalité bientôt disponible'),
                    ),
                  );
                },
              ),
            ],
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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  /// Construit un élément FAQ
  Widget _buildFAQItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(answer),
        onTap: () {},
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
      String youtubeSearchUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent(searchQuery)}';
      Uri searchUri = Uri.parse(youtubeSearchUrl);
      
      if (await canLaunchUrl(searchUri)) {
        await launchUrl(searchUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: recherche générique sur la topographie
        String fallbackUrl = 'https://www.youtube.com/results?search_query=topographie+gps+formation';
        Uri fallbackUri = Uri.parse(fallbackUrl);
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      // En cas d'erreur, ouvrir une recherche YouTube générique
      String fallbackUrl = 'https://www.youtube.com/results?search_query=tutoriel+topographie+gps';
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
      'Implantation d\'ouvrages': 'construction staking surveying tutorial'
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

  /// Construit un élément de base de connaissances
  Widget _buildKnowledgeItem(String title, String description) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.article, color: Color(0xFF2563EB)),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }

  /// Construit un élément du glossaire
  Widget _buildGlossaryItem(String term, String definition) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.book, color: Color(0xFF059669)),
        title: Text(term, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(definition),
        onTap: () {},
      ),
    );
  }

  /// Construit un élément de contact
  Widget _buildContactItem(IconData icon, String label, String value, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2563EB)),
        title: Text(label),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  /// Construit un élément de formation
  Widget _buildTrainingItem(String title, String date, String description) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.school, color: Color(0xFF7C3AED)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: const TextStyle(color: Color(0xFF2563EB))),
            const SizedBox(height: 4),
            Text(description),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
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
          content: Container(
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
          content: Container(
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
          content: Container(
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

  /// Dialog Signaler un problème
  void _showReportProblemDialog(BuildContext context) {
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Signaler un problème'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Décrivez le problème',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.photo_camera),
                label: Text('Ajouter des photos'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Problème signalé avec succès !'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: Text('Envoyer'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog Base de connaissances
  void _showKnowledgeBaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Base de connaissances'),
          content: Container(
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
                _buildKnowledgeItem(
                  'Calcul de surfaces',
                  'Méthodes et outils',
                ),
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
          content: Container(
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
                Container(
                  height: 200,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _buildGlossaryItem('Altimétrie', 'Mesure des altitudes et des hauteurs'),
                      _buildGlossaryItem('Azimut', 'Angle horizontal mesuré dans le sens horaire'),
                      _buildGlossaryItem('Bornage', 'Délimitation d\'une propriété'),
                      _buildGlossaryItem('Cadastre', 'Enregistrement public des propriétés foncières'),
                      _buildGlossaryItem('Gisement', 'Angle horizontal mesuré à partir du nord'),
                      _buildGlossaryItem('Nivellement', 'Détermination des différences d\'altitude'),
                      _buildGlossaryItem('Station totale', 'Instrument combinant théodolite et distancemètre'),
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

  /// Dialog Contact direct
  void _showDirectContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Contact direct'),
          content: Container(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildContactItem(
                  Icons.phone,
                  'Téléphone',
                  '+228 90 01 43 29',
                  () {},
                ),
                _buildContactItem(
                  Icons.email,
                  'Email',
                  'contact@echelle-eg39.com',
                  () {},
                ),
                _buildContactItem(
                  Icons.chat,
                  'WhatsApp',
                  '+228 90 01 43 29',
                  () {},
                ),
                _buildContactItem(
                  Icons.schedule,
                  'Horaires',
                  'Lun-Ven: 8h-18h\nSam: Si urgence',
                  () {},
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


  /// Dialog Centre de formation
  void _showTrainingCenterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Centre de formation'),
          content: Container(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                _buildTrainingItem(
                  'Initiation GPS',
                  '15-16 Mars 2024',
                  'Formation de base sur l\'utilisation des GPS de précision',
                ),
                _buildTrainingItem(
                  'Perfectionnement Théodolite',
                  '22-23 Mars 2024',
                  'Techniques avancées de mesure angulaire',
                ),
                _buildTrainingItem(
                  'Stations totales',
                  '29-30 Mars 2024',
                  'Utilisation complète des stations totales',
                ),
                _buildTrainingItem(
                  'Calcul topographique',
                  '05-06 Avril 2024',
                  'Méthodes de calcul et compensation',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Fermer'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Inscription envoyée !'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: Text('S\'inscrire'),
            ),
          ],
        );
      },
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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
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
          content: Container(
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
    const String googleMapsUrl = 'https://www.google.com/maps/search/Aflao+Gagli+Lomé+Togo';
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Créée en 2019, ÉCHELLE EG39 est spécialisée dans la vente et location d\'équipements de topographie de haute précision. Nous accompagnons les professionnels du secteur dans leurs projets d\'infrastructure et de construction.',
                ),
                SizedBox(height: 16),
                Text(
                  'Notre Mission',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Fournir des équipements de topographie de qualité supérieure et un service après-vente exceptionnel pour accompagner nos clients dans la réussite de leurs projets.',
                ),
                SizedBox(height: 16),
                Text(
                  'Localisation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Lomé, quartier Aflao Gagli, Togo',
                ),
                SizedBox(height: 16),
                Text(
                  'Zone d\'intervention',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                  leading: Icon(Icons.precision_manufacturing, color: Color(0xFFEA580C)),
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
                  subtitle: Text('GPS, théodolites, niveaux et stations totales'),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'En conformité avec le RGPD, nous nous engageons à protéger vos données personnelles.',
                ),
                SizedBox(height: 16),
                Text(
                  'Données collectées :',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text('• Nom et coordonnées'),
                Text('• Historique des commandes'),
                Text('• Données de localisation'),
                SizedBox(height: 16),
                Text(
                  'Utilisation :',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text('• Traitement des commandes'),
                Text('• Amélioration de nos services'),
                Text('• Communication commerciale (avec consentement)'),
                SizedBox(height: 16),
                Text(
                  'Vos droits :',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Éditeur de l\'application :',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text('ÉCHELLE EG39\nLomé, Togo\nSIRET : 123456789'),
                SizedBox(height: 16),
                Text(
                  'Responsabilité :',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text('L\'application est fournie "en l\'état" sans garantie. Nous nous efforçons d\'assurer l\'exactitude des informations mais ne pouvons être tenus responsables des erreurs.'),
                SizedBox(height: 16),
                Text(
                  'Propriété intellectuelle :',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text('Tous les contenus de l\'application sont protégés par les droits d\'auteur.'),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Développement :',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text('• Développeur Principal'),
                Text('• Designer UI/UX'),
                Text('• Développeur Mobile'),
                SizedBox(height: 16),
                Text(
                  'Technologies utilisées :',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text('• Flutter'),
                Text('• Dart'),
                Text('• Firebase'),
                SizedBox(height: 16),
                Text(
                  'Version :',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
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

  /// Dialog Évaluation
  void _showRatingDialog(BuildContext context) {
    int selectedRating = 5;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Évaluer l\'application'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Comment évaluez-vous notre application ?'),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setState) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            selectedRating = index + 1;
                          });
                        },
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 16),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Commentaires (optionnel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Merci pour votre évaluation de $selectedRating étoiles !'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog Partage
  void _showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Partager l\'application'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Invitez vos collègues à découvrir notre application :'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Partage WhatsApp...')),
                          );
                        },
                        icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                        iconSize: 40,
                      ),
                      const Text('WhatsApp'),
                    ],
                  ),
                  Column(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Partage Email...')),
                          );
                        },
                        icon: const Icon(Icons.email, color: Color(0xFF2563EB)),
                        iconSize: 40,
                      ),
                      const Text('Email'),
                    ],
                  ),
                  Column(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lien copié !')),
                          );
                        },
                        icon: const Icon(Icons.link, color: Color(0xFF059669)),
                        iconSize: 40,
                      ),
                      const Text('Copier lien'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Découvrez ÉCHELLE EG39 - Votre partenaire en équipements de topographie !\n\nTéléchargez notre application pour accéder à notre catalogue et nos services.\n\nDisponible sur Google Play et App Store',
                  ),
                ),
              ),
            ],
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
                  leading: Icon(Icons.health_and_safety, color: Color(0xFFDC2626)),
                  title: Text('ISO 45001:2018'),
                  subtitle: Text('Santé et sécurité au travail'),
                ),
                ListTile(
                  leading: Icon(Icons.gavel, color: Color(0xFF7C3AED)),
                  title: Text('Agréments techniques'),
                  subtitle: Text('Reconnaissance officielle'),
                ),
                ListTile(
                  leading: Icon(Icons.precision_manufacturing, color: Color(0xFFEA580C)),
                  title: Text('Certifications partenaires'),
                  subtitle: Text('Leica, Stonex, e-survey'),
                ),
                ListTile(
                  leading: Icon(Icons.account_balance_wallet, color: Color(0xFF1F2937)),
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
