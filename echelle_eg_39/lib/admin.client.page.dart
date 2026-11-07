// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin/admin_components.dart';
import 'admin/admin_tokens.dart';
import 'admin_clients_service.dart';
import 'api_service.dart';
import 'login.page.dart';
import 'models_admin_client.dart';
import 'offline_registration_store.dart';

typedef AdminClientsLoader = Future<List<AdminClient>> Function();
typedef AdminClientUpdater =
    Future<AdminClient> Function({
      required String id,
      required String firstName,
      required String lastName,
      required String email,
      required String phone,
    });
typedef AdminClientStatusUpdater =
    Future<AdminClient> Function({required String id, required bool isActive});

Future<List<AdminClient>> loadOfflineAdminClients() async {
  final accounts = await OfflineRegistrationStore.instance.localAccounts();
  return accounts
      .where((entry) => entry.role != 'admin')
      .map(
        (entry) => AdminClient(
          id: entry.id,
          firstName: entry.firstName,
          lastName: entry.lastName,
          email: entry.email,
          phone: entry.phone,
          role: entry.role,
          createdAt: entry.createdAt,
          isLocalRegistration: true,
          syncStatus: entry.status,
        ),
      )
      .toList(growable: false);
}

class AdminClientsPage extends StatefulWidget {
  const AdminClientsPage({
    super.key,
    this.loadClients = AdminClientsService.loadClients,
    this.loadLocalClients = loadOfflineAdminClients,
    this.updateClient = AdminClientsService.updateClient,
    this.updateClientStatus = AdminClientsService.setClientActive,
  });

  final AdminClientsLoader loadClients;
  final AdminClientsLoader loadLocalClients;
  final AdminClientUpdater updateClient;
  final AdminClientStatusUpdater updateClientStatus;

  @override
  State<AdminClientsPage> createState() => _AdminClientsPageState();
}

class _AdminClientsPageState extends State<AdminClientsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<AdminClient> _clients = const [];
  String _searchQuery = '';
  String? _errorMessage;
  String? _offlineMessage;
  final Set<String> _mutatingClientIds = <String>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _offlineMessage = null;
      });
    }

    List<AdminClient> localClients = const [];
    try {
      localClients = await widget.loadLocalClients();
    } catch (_) {
      // A local storage issue should not prevent loading the server directory.
    }

    try {
      final serverClients = await widget.loadClients();
      if (!mounted) return;
      setState(() {
        _clients = mergeAdminClients(
          serverClients: serverClients,
          localClients: localClients,
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (_isSessionError(error)) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
        return;
      }
      setState(() {
        _clients = mergeAdminClients(
          serverClients: const [],
          localClients: localClients,
        );
        _isLoading = false;
        if (_clients.isEmpty) {
          _errorMessage = error is AdminClientsException
              ? error.message
              : 'Le répertoire clients est indisponible. Vérifie ta connexion puis réessaie.';
        } else {
          _offlineMessage =
              'Connexion au serveur indisponible : les comptes locaux non synchronisés sont affichés.';
        }
      });
    }
  }

  bool _isSessionError(Object error) {
    if (error is! AdminClientsException) return false;
    return error.statusCode == 401 ||
        error.message.contains('Session') ||
        error.message.contains('reconnect');
  }

  Future<void> _editClient(AdminClient client) async {
    final values = await showDialog<_ClientFormValues>(
      context: context,
      builder: (_) => _EditAdminClientDialog(client: client),
    );
    if (values == null || !mounted) return;

    await _runClientMutation(
      client.id,
      () => widget.updateClient(
        id: client.id,
        firstName: values.firstName,
        lastName: values.lastName,
        email: values.email,
        phone: values.phone,
      ),
      successMessage: 'Les coordonnées du client ont été mises à jour.',
    );
  }

  Future<void> _changeClientStatus(AdminClient client) async {
    final activate = !client.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          activate ? 'Réactiver ce compte ?' : 'Désactiver ce compte ?',
        ),
        content: Text(
          activate
              ? 'Le client pourra de nouveau se connecter. Son historique est conservé.'
              : 'Le client ne pourra plus se connecter. Son compte et son historique seront conservés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: activate
                  ? AdminPalette.blueprintBlue
                  : AdminPalette.destructiveRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(activate ? 'Réactiver' : 'Désactiver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runClientMutation(
      client.id,
      () => widget.updateClientStatus(id: client.id, isActive: activate),
      successMessage: activate
          ? 'Le compte client a été réactivé.'
          : 'Le compte client a été désactivé. Son historique est conservé.',
    );
  }

  /// Génère un nouveau code de récupération pour un client qui a perdu le sien.
  ///
  /// L'identité doit être vérifiée par téléphone avant de transmettre le code :
  /// c'est la seule preuve acceptée par l'application, qui n'envoie ni e-mail
  /// ni SMS.
  Future<void> _regenerateRecoveryCode(AdminClient client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Générer un nouveau code ?'),
        content: Text(
          'L’ancien code de ${client.fullName} ne fonctionnera plus. '
          'Vérifiez son identité par téléphone avant de lui communiquer le '
          'nouveau code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AdminPalette.blueprintBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Générer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _mutatingClientIds.add(client.id));
    try {
      final code = await ApiService.regenerateRecoveryCode(client.id);
      if (!mounted) return;
      await _showRecoveryCodeDialog(client, code);
    } catch (_) {
      if (!mounted) return;
      showAdminMessage(
        context,
        'Impossible de générer un code de récupération pour le moment.',
        backgroundColor: AdminPalette.destructiveRed,
      );
    } finally {
      if (mounted) setState(() => _mutatingClientIds.remove(client.id));
    }
  }

  Future<void> _showRecoveryCodeDialog(AdminClient client, String code) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Code de récupération'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('À communiquer à ${client.fullName} :'),
            const SizedBox(height: 12),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Il ne sera plus affiché. Il permet de retrouver l’accès si le '
              'mot de passe est oublié.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Copier et fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _runClientMutation(
    String clientId,
    Future<AdminClient> Function() update, {
    required String successMessage,
  }) async {
    setState(() => _mutatingClientIds.add(clientId));
    try {
      final updatedClient = await update();
      if (!mounted) return;
      setState(() {
        _clients = _clients
            .map(
              (client) =>
                  client.id == updatedClient.id ? updatedClient : client,
            )
            .toList(growable: false);
      });
      showAdminMessage(context, successMessage);
    } catch (error) {
      if (!mounted) return;
      if (_isSessionError(error)) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
        return;
      }
      showAdminMessage(
        context,
        error is AdminClientsException
            ? error.message
            : 'Impossible de mettre à jour ce compte. Réessaie.',
        backgroundColor: AdminPalette.destructiveRed,
      );
    } finally {
      if (mounted) setState(() => _mutatingClientIds.remove(clientId));
    }
  }

  List<AdminClient> get _visibleClients {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return _clients;

    return _clients
        .where((client) {
          return client.fullName.toLowerCase().contains(query) ||
              client.email.toLowerCase().contains(query) ||
              client.phone.toLowerCase().contains(query) ||
              client.id.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleClients = _visibleClients;

    return RefreshIndicator(
      onRefresh: _loadClients,
      color: AdminPalette.blueprintBlue,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: AdminPageHeader(
              title: 'Gestion des clients',
              subtitle: 'Retrouvez les comptes inscrits et leurs coordonnées.',
              icon: Icons.people_alt_outlined,
            ),
          ),
          if (_offlineMessage != null)
            SliverToBoxAdapter(child: _buildOfflineNotice(_offlineMessage!)),
          SliverToBoxAdapter(child: _buildSearchField()),
          SliverToBoxAdapter(child: _buildResultCount(visibleClients.length)),
          _buildContent(visibleClients),
        ],
      ),
    );
  }

  Widget _buildOfflineNotice(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.lg,
        0,
        AdminSpacing.lg,
        AdminSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(AdminSpacing.md),
        decoration: BoxDecoration(
          color: AdminPalette.safetyAmber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AdminRadii.field),
          border: Border.all(
            color: AdminPalette.safetyAmber.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AdminPalette.safetyAmber,
              size: 18,
            ),
            const SizedBox(width: AdminSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AdminPalette.primaryText,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.lg),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: 'Rechercher un client',
          hintText: 'Nom, e-mail ou téléphone',
          prefixIcon: const Icon(
            Icons.search,
            color: AdminPalette.secondaryText,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  tooltip: 'Effacer la recherche',
                  icon: const Icon(Icons.clear),
                  color: AdminPalette.secondaryText,
                ),
          filled: true,
          fillColor: AdminPalette.mutedSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminRadii.field),
            borderSide: const BorderSide(color: AdminPalette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminRadii.field),
            borderSide: const BorderSide(color: AdminPalette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AdminRadii.field),
            borderSide: const BorderSide(
              color: AdminPalette.blueprintBlue,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCount(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.lg,
        AdminSpacing.lg,
        AdminSpacing.lg,
        AdminSpacing.md,
      ),
      child: Semantics(
        liveRegion: true,
        label:
            '$count ${count == 1 ? 'client' : 'clients'} affiché${count == 1 ? '' : 's'}',
        child: ExcludeSemantics(
          child: Text(
            '$count ${count == 1 ? 'client' : 'clients'}',
            style: adminMonoStyle(
              context,
              color: AdminPalette.blueprintBlue,
              size: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<AdminClient> clients) {
    if (_isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AdminLoadingState(label: 'Chargement des clients…'),
      );
    }

    if (_errorMessage != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AdminErrorState(message: _errorMessage!, onRetry: _loadClients),
      );
    }

    if (clients.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AdminEmptyState(
          icon: _searchQuery.isEmpty
              ? Icons.people_outline
              : Icons.search_off_outlined,
          title: _searchQuery.isEmpty
              ? 'Aucun client pour le moment'
              : 'Aucun résultat',
          message: _searchQuery.isEmpty
              ? 'Les comptes clients enregistrés apparaîtront automatiquement ici.'
              : 'Essayez un autre nom, e-mail ou numéro de téléphone.',
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.lg,
        0,
        AdminSpacing.lg,
        AdminSpacing.section,
      ),
      sliver: SliverList.separated(
        itemCount: clients.length,
        separatorBuilder: (_, _) => const SizedBox(height: AdminSpacing.sm),
        itemBuilder: (context, index) {
          final client = clients[index];
          final contacts = <String>[
            if (!client.isLocalRegistration && !client.isActive)
              'Compte désactivé',
            if (client.email.isNotEmpty) client.email,
            if (client.phone.isNotEmpty) 'Tél. ${client.phone}',
            if (client.createdAt != null && client.createdAt!.isNotEmpty)
              'Inscrit le ${formatAdminDate(client.createdAt)}',
          ];

          final isMutating = _mutatingClientIds.contains(client.id);

          return AdminDirectoryRow(
            id: client.isLocalRegistration ? 'HORS LIGNE' : 'ID ${client.id}',
            title: client.fullName,
            contacts: contacts,
            actions: client.isLocalRegistration
                ? [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdminSpacing.sm,
                        vertical: AdminSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AdminPalette.safetyAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        client.syncStatus == 'needs_review'
                            ? 'À vérifier'
                            : 'À synchroniser',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AdminPalette.safetyAmber,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ]
                : [
                    PopupMenuButton<_AdminClientAction>(
                      tooltip: 'Actions pour ${client.fullName}',
                      enabled: !isMutating,
                      onSelected: (action) {
                        if (action == _AdminClientAction.edit) {
                          _editClient(client);
                        } else if (action ==
                            _AdminClientAction.recoveryCode) {
                          _regenerateRecoveryCode(client);
                        } else {
                          _changeClientStatus(client);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _AdminClientAction.edit,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Modifier'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: _AdminClientAction.recoveryCode,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.vpn_key_outlined),
                            title: Text('Code de récupération'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _AdminClientAction.toggleStatus,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              client.isActive
                                  ? Icons.block_outlined
                                  : Icons.check_circle_outline,
                              color: client.isActive
                                  ? AdminPalette.destructiveRed
                                  : AdminPalette.approvalGreen,
                            ),
                            title: Text(
                              client.isActive ? 'Désactiver' : 'Réactiver',
                              style: TextStyle(
                                color: client.isActive
                                    ? AdminPalette.destructiveRed
                                    : AdminPalette.approvalGreen,
                              ),
                            ),
                          ),
                        ),
                      ],
                      icon: isMutating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.more_vert),
                    ),
                  ],
          );
        },
      ),
    );
  }

  Widget _buildInactiveBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.sm,
        vertical: AdminSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AdminPalette.destructiveRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AdminPalette.destructiveRed.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        'Compte désactivé',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AdminPalette.destructiveRed,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum _AdminClientAction { edit, toggleStatus, recoveryCode }

class _ClientFormValues {
  const _ClientFormValues({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
}

class _EditAdminClientDialog extends StatefulWidget {
  const _EditAdminClientDialog({required this.client});

  final AdminClient client;

  @override
  State<_EditAdminClientDialog> createState() => _EditAdminClientDialogState();
}

class _EditAdminClientDialogState extends State<_EditAdminClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.client.firstName);
    _lastNameController = TextEditingController(text: widget.client.lastName);
    _emailController = TextEditingController(text: widget.client.email);
    _phoneController = TextEditingController(text: widget.client.phone);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ClientFormValues(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
      ),
    );
  }

  String? _requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label requis.';
    return null;
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AdminPalette.mutedSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadii.field),
        borderSide: const BorderSide(color: AdminPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadii.field),
        borderSide: const BorderSide(color: AdminPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadii.field),
        borderSide: const BorderSide(
          color: AdminPalette.blueprintBlue,
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Modifier le client'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                decoration: _fieldDecoration('Prénom', Icons.person_outline),
                validator: (value) => _requiredField(value, 'Prénom'),
              ),
              const SizedBox(height: AdminSpacing.sm),
              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                decoration: _fieldDecoration('Nom', Icons.person_outline),
                validator: (value) => _requiredField(value, 'Nom'),
              ),
              const SizedBox(height: AdminSpacing.sm),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                maxLength: 255,
                decoration: _fieldDecoration('E-mail', Icons.email_outlined),
                validator: (value) {
                  final requiredError = _requiredField(value, 'E-mail');
                  if (requiredError != null) return requiredError;
                  if (!RegExp(
                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                  ).hasMatch(value!.trim())) {
                    return 'Adresse e-mail invalide.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AdminSpacing.sm),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                maxLength: 20,
                decoration: _fieldDecoration('Téléphone', Icons.phone_outlined),
                validator: (value) {
                  final requiredError = _requiredField(value, 'Téléphone');
                  if (requiredError != null) return requiredError;
                  final phone = value!.trim();
                  if (phone.length < 8 || phone.length > 20) {
                    return 'Le téléphone doit contenir entre 8 et 20 caractères.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Enregistrer'),
          style: FilledButton.styleFrom(
            backgroundColor: AdminPalette.blueprintBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
          ),
        ),
      ],
    );
  }
}
