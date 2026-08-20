import 'dart:math';

import 'package:flutter/material.dart';

import 'admin/admin_components.dart';
import 'admin/admin_tokens.dart';
import 'data_manager.dart' as dm;

class ClientsMenuPage extends StatefulWidget {
  const ClientsMenuPage({super.key});

  @override
  State<ClientsMenuPage> createState() => _ClientsMenuPageState();
}

class _ClientsMenuPageState extends State<ClientsMenuPage> {
  final dm.DataManager _dataManager = dm.DataManager();
  late final VoidCallback _dataManagerListener;

  @override
  void initState() {
    super.initState();
    _dataManagerListener = () {
      if (mounted) setState(() {});
    };
    _dataManager.addListener(_dataManagerListener);
    _dataManager.initialize();
  }

  @override
  void dispose() {
    _dataManager.removeListener(_dataManagerListener);
    super.dispose();
  }

  String _generateClientId() {
    final random = Random();
    return 'C-${random.nextInt(9999).toString().padLeft(4, '0')}';
  }

  Future<void> _showClientFormSheet({dm.Client? existing, int? index}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final formKey = GlobalKey<FormState>();
    final isEditing = existing != null && index != null;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AdminSpacing.xxl,
                AdminSpacing.md,
                AdminSpacing.xxl,
                AdminSpacing.xxl,
              ),
              decoration: const BoxDecoration(
                color: AdminPalette.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AdminRadii.sheet),
                ),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AdminPalette.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: AdminSpacing.xl),
                      Text(
                        isEditing ? 'Modifier le client' : 'Ajouter un client',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AdminPalette.primaryText,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: AdminSpacing.xs),
                      Text(
                        isEditing
                            ? 'Mettez à jour les coordonnées du dossier.'
                            : 'Créez une fiche client avec au moins un contact.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AdminPalette.secondaryText,
                            ),
                      ),
                      const SizedBox(height: AdminSpacing.lg),
                      _buildClientField(
                        controller: nameController,
                        label: 'Nom complet',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le nom est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminSpacing.md),
                      _buildClientField(
                        controller: emailController,
                        label: 'Email (optionnel)',
                        icon: Icons.alternate_email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isNotEmpty &&
                              !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$')
                                  .hasMatch(email)) {
                            return 'Format d’email invalide';
                          }
                          if (email.isEmpty && phoneController.text.trim().isEmpty) {
                            return 'Ajoutez un email ou un téléphone';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminSpacing.md),
                      _buildClientField(
                        controller: phoneController,
                        label: 'Téléphone (optionnel)',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          final phone = value?.trim() ?? '';
                          if (phone.isNotEmpty && phone.length < 8) {
                            return 'Numéro de téléphone invalide';
                          }
                          if (phone.isEmpty && emailController.text.trim().isEmpty) {
                            return 'Ajoutez un téléphone ou un email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminSpacing.xl),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(sheetContext, false),
                              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: AdminSpacing.sm),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (!formKey.currentState!.validate()) return;

                                final client = dm.Client(
                                  id: existing?.id ?? _generateClientId(),
                                  name: nameController.text.trim(),
                                  email: emailController.text.trim().isEmpty
                                      ? null
                                      : emailController.text.trim(),
                                  phone: phoneController.text.trim().isEmpty
                                      ? null
                                      : phoneController.text.trim(),
                                );

                                if (isEditing) {
                                  _dataManager.updateClient(index, client);
                                } else {
                                  _dataManager.addClient(client);
                                }
                                Navigator.pop(sheetContext, true);
                              },
                              icon: Icon(isEditing ? Icons.save_outlined : Icons.person_add_alt_1),
                              label: Text(isEditing ? 'Enregistrer' : 'Ajouter'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminPalette.blueprintBlue,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AdminRadii.field),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

      if (saved == true && mounted) {
        showAdminMessage(
          context,
          isEditing ? 'Fiche client mise à jour.' : 'Client ajouté au répertoire.',
          backgroundColor: AdminPalette.approvalGreen,
        );
      }
    } finally {
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
    }
  }

  Widget _buildClientField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
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
      ),
    );
  }

  Future<void> _deleteClient(int index) async {
    final client = _dataManager.clients[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la fiche ?'),
        content: Text('La fiche de ${client.name} sera retirée du répertoire local.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminPalette.destructiveRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _dataManager.removeClient(index);
      showAdminMessage(
        context,
        'Fiche client supprimée.',
        backgroundColor: AdminPalette.destructiveRed,
      );
    }
  }

  void _showClientHistory(dm.Client client) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(
          AdminSpacing.xxl,
          AdminSpacing.md,
          AdminSpacing.xxl,
          AdminSpacing.xxl,
        ),
        decoration: const BoxDecoration(
          color: AdminPalette.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AdminRadii.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AdminPalette.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: AdminSpacing.xl),
            Text(
              'Historique client',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AdminPalette.primaryText,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AdminSpacing.xs),
            Text(
              client.name,
              style: const TextStyle(
                color: AdminPalette.blueprintBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AdminSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AdminSpacing.lg),
              decoration: BoxDecoration(
                color: AdminPalette.mutedSurface,
                borderRadius: BorderRadius.circular(AdminRadii.card),
              ),
              child: const Text(
                'L’historique des locations et demandes liées à ce client sera affiché ici.',
                style: TextStyle(color: AdminPalette.secondaryText, height: 1.4),
              ),
            ),
            const SizedBox(height: AdminSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = _dataManager.clients;
    final withContact = clients
        .where((client) =>
            (client.email?.isNotEmpty ?? false) || (client.phone?.isNotEmpty ?? false))
        .length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: AdminPageHeader(
            title: 'Répertoire clients',
            subtitle: 'Coordonnées, dossiers et contacts suivis par l’administration.',
            icon: Icons.people_alt_outlined,
            actions: [
              IconButton(
                onPressed: () => _showClientFormSheet(),
                tooltip: 'Ajouter un client',
                icon: const Icon(Icons.person_add_alt_1),
                color: AdminPalette.blueprintBlue,
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: AdminMetricCluster(
            primary: AdminMetric(
              label: 'Clients enregistrés',
              value: clients.length,
              icon: Icons.groups_outlined,
            ),
            secondary: [
              AdminMetric(
                label: 'Avec un contact',
                value: withContact,
                icon: Icons.contact_phone_outlined,
              ),
              AdminMetric(
                label: 'À compléter',
                value: clients.length - withContact,
                icon: Icons.assignment_late_outlined,
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.lg,
              AdminSpacing.xxl,
              AdminSpacing.lg,
              AdminSpacing.md,
            ),
            child: Row(
              children: [
                const Text(
                  'Répertoire',
                  style: TextStyle(
                    color: AdminPalette.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: AdminSpacing.sm),
                Text(
                  '${clients.length}',
                  style: adminMonoStyle(context, color: AdminPalette.blueprintBlue),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showClientFormSheet(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter'),
                  style: TextButton.styleFrom(
                    foregroundColor: AdminPalette.blueprintBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (clients.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: AdminEmptyState(
              icon: Icons.people_outline,
              title: 'Aucun client enregistré',
              message: 'Ajoutez une première fiche pour commencer le suivi.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AdminSpacing.lg,
              0,
              AdminSpacing.lg,
              AdminSpacing.section,
            ),
            sliver: SliverList.builder(
              itemCount: clients.length,
              itemBuilder: (context, index) {
                final client = clients[index];
                final contacts = <String>[
                  if (client.email?.isNotEmpty ?? false) '✉ ${client.email}',
                  if (client.phone?.isNotEmpty ?? false) '☎ ${client.phone}',
                ];
                return AdminDirectoryRow(
                  id: client.id,
                  title: client.name,
                  contacts: contacts,
                  onTap: () => _showClientHistory(client),
                  actions: [
                    IconButton(
                      onPressed: () => _showClientFormSheet(
                        existing: client,
                        index: index,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: AdminPalette.blueprintBlue,
                      tooltip: 'Modifier',
                    ),
                    IconButton(
                      onPressed: () => _deleteClient(index),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: AdminPalette.destructiveRed,
                      tooltip: 'Supprimer',
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
