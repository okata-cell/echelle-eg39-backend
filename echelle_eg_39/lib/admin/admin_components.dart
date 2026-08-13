import 'package:flutter/material.dart';

import 'admin_tokens.dart';

class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actions = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminSpacing.lg,
        AdminSpacing.lg,
        AdminSpacing.lg,
        AdminSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AdminPalette.deepSlate,
              borderRadius: BorderRadius.circular(AdminRadii.card),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AdminSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AdminPalette.primaryText,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                ),
                const SizedBox(height: AdminSpacing.xs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AdminPalette.secondaryText,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: AdminSpacing.sm),
            Wrap(
              spacing: AdminSpacing.xs,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class AdminMetric {
  const AdminMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;
}

class AdminMetricCluster extends StatelessWidget {
  const AdminMetricCluster({
    super.key,
    required this.primary,
    required this.secondary,
  });

  final AdminMetric primary;
  final List<AdminMetric> secondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AdminSpacing.lg),
      padding: const EdgeInsets.all(AdminSpacing.xl),
      decoration: BoxDecoration(
        color: AdminPalette.deepSlate,
        borderRadius: BorderRadius.circular(AdminRadii.sheet),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          final secondaryColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < secondary.length; index++) ...[
                if (index > 0) const Divider(color: Color(0x33475569), height: 20),
                _MiniMetric(metric: secondary[index]),
              ],
            ],
          );

          final primaryBlock = Expanded(
            flex: compact ? 5 : 6,
            child: _PrimaryMetric(metric: primary),
          );

          if (compact) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                primaryBlock,
                const SizedBox(width: AdminSpacing.xl),
                Expanded(flex: 4, child: secondaryColumn),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              primaryBlock,
              const SizedBox(width: AdminSpacing.xxl),
              Container(width: 1, height: 72, color: const Color(0x33475569)),
              const SizedBox(width: AdminSpacing.xxl),
              Expanded(flex: 5, child: secondaryColumn),
            ],
          );
        },
      ),
    );
  }
}

class _PrimaryMetric extends StatelessWidget {
  const _PrimaryMetric({required this.metric});

  final AdminMetric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(metric.icon, color: AdminPalette.safetyAmber, size: 18),
            const SizedBox(width: AdminSpacing.sm),
            Text(
              'PRIORITÉ',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFFFD38A),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AdminSpacing.sm),
        Text(
          '${metric.value}',
          style: adminMonoStyle(
            context,
            color: Colors.white,
            size: 42,
            weight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AdminSpacing.xs),
        Text(
          metric.label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFCBD5E1),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.metric});

  final AdminMetric metric;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(metric.icon, color: AdminPalette.blueprintBlue, size: 16),
        const SizedBox(width: AdminSpacing.sm),
        Expanded(
          child: Text(
            metric.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFCBD5E1),
                ),
          ),
        ),
        Text(
          '${metric.value}',
          style: adminMonoStyle(context, color: Colors.white, size: 18),
        ),
      ],
    );
  }
}

class AdminFilterOption {
  const AdminFilterOption({
    required this.value,
    required this.label,
    required this.count,
  });

  final String value;
  final String label;
  final int count;
}

class AdminSegmentedFilter extends StatelessWidget {
  const AdminSegmentedFilter({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  final List<AdminFilterOption> options;
  final String selectedValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AdminSpacing.lg,
        AdminSpacing.lg,
        AdminSpacing.lg,
        AdminSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminPalette.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: options.map((option) {
            final selected = selectedValue == option.value;
            return InkWell(
              onTap: selected ? null : () => onChanged(option.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? AdminPalette.blueprintBlue
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      option.label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: selected
                                ? AdminPalette.deepSlate
                                : AdminPalette.secondaryText,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: AdminSpacing.sm),
                    Text(
                      '${option.count}',
                      style: adminMonoStyle(
                        context,
                        color: selected
                            ? AdminPalette.blueprintBlue
                            : AdminPalette.tertiaryText,
                        size: 11,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.status});

  final Object? status;

  @override
  Widget build(BuildContext context) {
    final color = adminStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        adminStatusLabel(status).toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({super.key, this.label = 'Chargement des données…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AdminPalette.blueprintBlue,
              ),
            ),
            const SizedBox(height: AdminSpacing.md),
            Text(label, style: const TextStyle(color: AdminPalette.secondaryText)),
          ],
        ),
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AdminPalette.tertiaryText),
            const SizedBox(height: AdminSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AdminPalette.primaryText,
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AdminSpacing.xs),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AdminPalette.secondaryText,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class AdminErrorState extends StatelessWidget {
  const AdminErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.section),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: AdminPalette.destructiveRed),
            const SizedBox(height: AdminSpacing.md),
            Text(
              'Impossible de charger les données',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AdminPalette.primaryText,
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AdminSpacing.xs),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AdminPalette.secondaryText,
                  ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AdminSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminPalette.blueprintBlue,
                side: const BorderSide(color: AdminPalette.blueprintBlue),
                minimumSize: const Size(0, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDirectoryRow extends StatelessWidget {
  const AdminDirectoryRow({
    super.key,
    required this.id,
    required this.title,
    required this.contacts,
    this.onTap,
    this.actions = const <Widget>[],
  });

  final String id;
  final String title;
  final List<String> contacts;
  final VoidCallback? onTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final initial = title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: AdminSpacing.sm),
      decoration: BoxDecoration(
        color: AdminPalette.surface,
        borderRadius: BorderRadius.circular(AdminRadii.card),
        border: Border.all(color: AdminPalette.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(AdminSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AdminPalette.blueprintBlue.withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AdminPalette.blueprintBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AdminSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AdminPalette.primaryText,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AdminSpacing.xs),
                    Text(id, style: adminMonoStyle(context, size: 11)),
                    if (contacts.isNotEmpty) ...[
                      const SizedBox(height: AdminSpacing.sm),
                      Wrap(
                        spacing: AdminSpacing.md,
                        runSpacing: AdminSpacing.xs,
                        children: contacts
                            .where((contact) => contact.trim().isNotEmpty)
                            .map(
                              (contact) => Text(
                                contact,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AdminPalette.secondaryText,
                                    ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: AdminSpacing.sm),
                Row(mainAxisSize: MainAxisSize.min, children: actions),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AdminWorkItemCard extends StatelessWidget {
  const AdminWorkItemCard({
    super.key,
    required this.status,
    required this.reference,
    required this.title,
    required this.requester,
    this.meta,
    this.amount,
    this.leading,
    this.details,
    this.footer,
    this.onTap,
  });

  final Object? status;
  final String reference;
  final String title;
  final String requester;
  final String? meta;
  final String? amount;
  final Widget? leading;
  final Widget? details;
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = adminStatusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: AdminSpacing.md),
      decoration: BoxDecoration(
        color: AdminPalette.surface,
        borderRadius: BorderRadius.circular(AdminRadii.card),
        border: Border.all(color: AdminPalette.border),
        boxShadow: const [AdminElevation.card],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: AdminStroke.pendingAccent, color: accent),
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(AdminSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (leading != null) ...[
                            leading!,
                            const SizedBox(width: AdminSpacing.md),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(reference.toUpperCase(), style: adminMonoStyle(context, color: accent, size: 11)),
                                const SizedBox(height: AdminSpacing.xs),
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: AdminPalette.primaryText,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: AdminSpacing.xs),
                                Text(
                                  requester,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AdminPalette.secondaryText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AdminSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AdminStatusChip(status: status),
                              if (amount != null && amount!.isNotEmpty) ...[
                                const SizedBox(height: AdminSpacing.md),
                                Text(
                                  amount!,
                                  textAlign: TextAlign.end,
                                  style: adminMonoStyle(
                                    context,
                                    color: AdminPalette.primaryText,
                                    size: 13,
                                    weight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      if (meta != null && meta!.trim().isNotEmpty) ...[
                        const SizedBox(height: AdminSpacing.md),
                        Text(
                          meta!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AdminPalette.secondaryText,
                              ),
                        ),
                      ],
                      if (details != null) ...[
                        const SizedBox(height: AdminSpacing.md),
                        details!,
                      ],
                      if (footer != null) ...[
                        const SizedBox(height: AdminSpacing.lg),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDecisionBar extends StatelessWidget {
  const AdminDecisionBar({
    super.key,
    required this.onApprove,
    required this.onReject,
    this.isBusy = false,
  });

  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return const LinearProgressIndicator(
        minHeight: 2,
        color: AdminPalette.blueprintBlue,
        backgroundColor: AdminPalette.border,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final approve = Expanded(
          child: ElevatedButton.icon(
            onPressed: onApprove,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Approuver'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminPalette.approvalGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AdminRadii.field),
              ),
            ),
          ),
        );
        final reject = Expanded(
          child: OutlinedButton.icon(
            onPressed: onReject,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Rejeter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminPalette.destructiveRed,
              side: const BorderSide(color: AdminPalette.destructiveRed),
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AdminRadii.field),
              ),
            ),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [approve, const SizedBox(height: AdminSpacing.sm), reject],
          );
        }

        return Row(
          children: [
            reject,
            const SizedBox(width: AdminSpacing.sm),
            approve,
          ],
        );
      },
    );
  }
}

Future<String?> showAdminRejectionSheet(
  BuildContext context, {
  required String entityLabel,
  String helperText = 'Le motif sera visible par le client.',
}) async {
  final controller = TextEditingController();
  var isValid = false;

  try {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
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
                      'Rejeter $entityLabel',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AdminPalette.primaryText,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AdminSpacing.xs),
                    Text(
                      helperText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AdminPalette.secondaryText,
                          ),
                    ),
                    const SizedBox(height: AdminSpacing.lg),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 1000,
                      onChanged: (value) => setState(
                        () => isValid = value.trim().isNotEmpty,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Motif du rejet',
                        hintText: 'Expliquez la décision à conserver dans le dossier…',
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 46),
                          child: Icon(Icons.message_outlined),
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
                    const SizedBox(height: AdminSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                            child: const Text('Annuler'),
                          ),
                        ),
                        const SizedBox(width: AdminSpacing.sm),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: isValid
                                ? () => Navigator.pop(
                                      sheetContext,
                                      controller.text.trim(),
                                    )
                                : null,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Confirmer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminPalette.destructiveRed,
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
            );
          },
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

void showAdminMessage(
  BuildContext context,
  String message, {
  Color backgroundColor = AdminPalette.deepSlate,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AdminSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadii.field),
        ),
      ),
    );
}
