import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'api_service.dart';
import 'login.page.dart';
import 'models_anonymized_user.dart';
import 'admin/admin_components.dart';
import 'admin/admin_tokens.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    this.loadUsers = ApiService.getAnonymizedUsers,
  });

  final Future<List<AnonymizedUser>> Function() loadUsers;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _searchDebounce;
  List<AnonymizedUser> _users = const [];
  String _searchQuery = '';
  String _selectedRole = allAnonymizedRolesFilter;
  String? _errorMessage;
  bool _isLoading = true;
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _isSessionError(Object error) {
    if (error is ApiException) {
      return error.message.contains('Session') ||
          error.message.contains('reconnect');
    }
    return false;
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final users = await widget.loadUsers();
      if (!mounted) return;

      final availableRoles = _rolesFrom(users);
      setState(() {
        _users = List<AnonymizedUser>.unmodifiable(users);
        _isLoading = false;
        if (_selectedRole != allAnonymizedRolesFilter &&
            !availableRoles.contains(_selectedRole)) {
          _selectedRole = allAnonymizedRolesFilter;
        }
      });
    } catch (error) {
      if (!mounted) return;
      if (_isSessionError(error)) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = _messageForError(error);
      });
    }
  }

  List<String> _rolesFrom(Iterable<AnonymizedUser> users) {
    final roles = users
        .map((user) => user.role.trim())
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList();
    roles.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return roles;
  }

  List<String> get _availableRoles => _rolesFrom(_users);

  List<AnonymizedUser> get _visibleUsers {
    final query = _searchQuery.toLowerCase();
    return _users
        .where((user) {
          final roleMatches =
              _selectedRole == allAnonymizedRolesFilter ||
              user.role == _selectedRole;
          if (!roleMatches) return false;
          if (query.isEmpty) return true;

          return user.id.toLowerCase().contains(query) ||
              user.role.toLowerCase().contains(query) ||
              user.maskedEmail.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  bool get _hasActiveFilter =>
      _hasSearchText || _selectedRole != allAnonymizedRolesFilter;

  String _messageForError(Object error) {
    if (error is ApiException) return error.message;
    return 'Le répertoire n’a pas pu être chargé. Vérifiez votre connexion puis réessayez.';
  }

  void _onSearchChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    if (_hasSearchText != hasText && mounted) {
      setState(() => _hasSearchText = hasText);
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (mounted) {
      setState(() {
        _searchQuery = '';
        _hasSearchText = false;
      });
    }
    _searchFocusNode.requestFocus();
    SemanticsService.announce('Recherche effacée', TextDirection.ltr);
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _hasSearchText = false;
      _selectedRole = allAnonymizedRolesFilter;
    });
    _searchFocusNode.requestFocus();
  }

  void _selectRole(String role) {
    if (_selectedRole == role) return;
    setState(() => _selectedRole = role);
  }

  int _countForRole(String role) {
    if (role == allAnonymizedRolesFilter) return _users.length;
    return _users.where((user) => user.role == role).length;
  }

  @override
  Widget build(BuildContext context) {
    final visibleUsers = _visibleUsers;

    return RefreshIndicator(
      onRefresh: _loadUsers,
      color: AdminPalette.blueprintBlue,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: AdminPageHeader(
              title: 'Répertoire anonymisé',
              subtitle:
                  'Identifiants, rôles et e-mails réduits au strict nécessaire.',
              icon: Icons.people_alt_outlined,
            ),
          ),
          SliverToBoxAdapter(child: _buildPrivacyStatement()),
          SliverToBoxAdapter(child: _buildSearchField()),
          SliverToBoxAdapter(child: _buildRoleFilter()),
          SliverToBoxAdapter(child: _buildResultLedger(visibleUsers.length)),
          _buildContent(visibleUsers),
        ],
      ),
    );
  }

  Widget _buildPrivacyStatement() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.lg,
        0,
        AdminSpacing.lg,
        AdminSpacing.lg,
      ),
      child: Semantics(
        label: 'Politique de confidentialité',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.visibility_off_outlined,
                size: 16,
                color: AdminPalette.secondaryText,
              ),
            ),
            const SizedBox(width: AdminSpacing.sm),
            Expanded(
              child: Text(
                'Les adresses e-mail sont volontairement masquées dans cet espace d’administration.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AdminPalette.secondaryText,
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
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText: 'Rechercher',
          hintText: 'Identifiant, rôle ou e-mail masqué',
          prefixIcon: const Icon(
            Icons.search,
            color: AdminPalette.secondaryText,
          ),
          suffixIcon: _hasSearchText
              ? IconButton(
                  onPressed: _clearSearch,
                  tooltip: 'Effacer la recherche',
                  icon: const Icon(Icons.clear),
                  color: AdminPalette.secondaryText,
                )
              : null,
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

  Widget _buildRoleFilter() {
    final options = <AdminFilterOption>[
      AdminFilterOption(
        value: allAnonymizedRolesFilter,
        label: 'Tous',
        count: _countForRole(allAnonymizedRolesFilter),
      ),
      for (final role in _availableRoles)
        AdminFilterOption(value: role, label: role, count: _countForRole(role)),
    ];

    return AdminSegmentedFilter(
      options: options,
      selectedValue: _selectedRole,
      onChanged: _selectRole,
    );
  }

  Widget _buildResultLedger(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.lg,
        AdminSpacing.md,
        AdminSpacing.lg,
        AdminSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            label: formatAnonymizedLiveRegion(count),
            child: ExcludeSemantics(
              child: Text(
                formatAnonymizedResultCount(count),
                style: adminMonoStyle(
                  context,
                  color: AdminPalette.blueprintBlue,
                  size: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          Expanded(
            child: Text(
              'Identifiant · rôle · e-mail masqué',
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AdminPalette.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<AnonymizedUser> visibleUsers) {
    if (_isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AdminLoadingState(label: 'Chargement du répertoire…'),
      );
    }

    if (_errorMessage != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AdminErrorState(
          message: _errorMessage!,
          onRetry: _loadUsers,
        ),
      );
    }

    if (_users.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AdminEmptyState(
          icon: Icons.people_outline,
          title: 'Aucun utilisateur à afficher',
          message:
              'Aucun enregistrement anonymisé n’est disponible pour le moment.',
        ),
      );
    }

    if (visibleUsers.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AdminEmptyState(
              icon: Icons.search_off_outlined,
              title: 'Aucun résultat',
              message: 'Modifiez la recherche ou sélectionnez un autre rôle.',
            ),
            if (_hasActiveFilter)
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Effacer les filtres'),
              ),
          ],
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
      sliver: SliverToBoxAdapter(
        child: AdminDirectoryManifest(users: visibleUsers),
      ),
    );
  }
}
