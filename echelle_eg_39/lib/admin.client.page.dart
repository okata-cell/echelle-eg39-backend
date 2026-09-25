import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'admin/admin_components.dart';
import 'admin/admin_tokens.dart';
import 'admin_clients_service.dart';
import 'login.page.dart';
import 'models_admin_client.dart';

typedef AdminClientsLoader = Future<List<AdminClient>> Function();

Future<List<AdminClient>> loadOfflineAdminClients() async {
  final prefs = await SharedPreferences.getInstance();
  final registrations = <String>[
    ...?prefs.getStringList('registered_users'),
    ...?prefs.getStringList('pending_sync_users'),
  ];

  return registrations
      .map(AdminClient.tryParseLocalRegistration)
      .whereType<AdminClient>()
      .toList(growable: false);
}

class AdminClientsPage extends StatefulWidget {
  const AdminClientsPage({
    super.key,
    this.loadClients = AdminClientsService.loadClients,
    this.loadLocalClients = loadOfflineAdminClients,
  });

  final AdminClientsLoader loadClients;
  final AdminClientsLoader loadLocalClients;

  @override
  State<AdminClientsPage> createState() => _AdminClientsPageState();
}

class _AdminClientsPageState extends State<AdminClientsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<AdminClient> _clients = const [];
  String _searchQuery = '';
  String? _errorMessage;
  String? _offlineMessage;
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

  List<AdminClient> get _visibleClients {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return _clients;

    return _clients.where((client) {
      return client.fullName.toLowerCase().contains(query) ||
          client.email.toLowerCase().contains(query) ||
          client.phone.toLowerCase().contains(query) ||
          client.id.toLowerCase().contains(query);
    }).toList(growable: false);
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
              subtitle:
                  'Retrouvez les comptes inscrits et leurs coordonnées.',
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
            if (client.email.isNotEmpty) client.email,
            if (client.phone.isNotEmpty) 'Tél. ${client.phone}',
            if (client.createdAt != null && client.createdAt!.isNotEmpty)
              'Inscrit le ${formatAdminDate(client.createdAt)}',
          ];

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
                        'À synchroniser',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AdminPalette.safetyAmber,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ]
                : const [],
          );
        },
      ),
    );
  }
}
