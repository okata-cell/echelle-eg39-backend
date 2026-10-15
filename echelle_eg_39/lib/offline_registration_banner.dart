import 'package:flutter/material.dart';

import 'offline_registration_store.dart';
import 'sync_service.dart';

typedef OfflineRegistrationSync = Future<SyncResult> Function();
typedef OfflineRegistrationStatusLoader =
    Future<List<OfflineRegistrationEntry>> Function();

const _bannerBlue = Color(0xFF0066CC);
const _bannerSurface = Color(0xFFEFF6FF);
const _bannerBorder = Color(0xFFBFDBFE);
const _bannerText = Color(0xFF1E3A5F);

/// Shows unsynchronized registrations on the client home screen.
class OfflineRegistrationBanner extends StatefulWidget {
  const OfflineRegistrationBanner({
    super.key,
    this.loadRegistrations = _loadRegistrations,
    this.syncRegistrations = SyncService.syncPendingUsers,
  });

  final OfflineRegistrationStatusLoader loadRegistrations;
  final OfflineRegistrationSync syncRegistrations;

  static Future<List<OfflineRegistrationEntry>> _loadRegistrations() =>
      OfflineRegistrationStore.instance.localAccounts();

  @override
  State<OfflineRegistrationBanner> createState() =>
      _OfflineRegistrationBannerState();
}

class _OfflineRegistrationBannerState extends State<OfflineRegistrationBanner>
    with WidgetsBindingObserver {
  late Future<List<OfflineRegistrationEntry>> _registrationsFuture;
  bool _isSyncing = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registrationsFuture = widget.loadRegistrations();
  }

  @override
  void didUpdateWidget(covariant OfflineRegistrationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadRegistrations != widget.loadRegistrations) {
      _refreshRegistrations();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshRegistrations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _refreshRegistrations() {
    if (!mounted) return;
    setState(() {
      _syncError = null;
      _registrationsFuture = widget.loadRegistrations();
    });
  }

  Future<void> _retrySync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncError = null;
    });

    try {
      final result = await widget.syncRegistrations();
      if (!mounted) return;
      setState(() {
        _registrationsFuture = widget.loadRegistrations();
        if (!result.success) {
          _syncError = 'Vérifiez votre connexion et réessayez.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncError = 'Synchronisation impossible. Réessayez plus tard.';
      });
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OfflineRegistrationEntry>>(
      future: _registrationsFuture,
      builder: (context, snapshot) {
        final registrations = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting ||
            registrations == null ||
            registrations.isEmpty) {
          return const SizedBox.shrink();
        }

        final waitingCount = registrations
            .where((entry) => entry.status == 'pending')
            .length;
        final needsReviewCount = registrations
            .where((entry) => entry.status != 'pending')
            .length;
        final hasWaitingRegistrations = waitingCount > 0;
        final title = hasWaitingRegistrations
            ? 'Inscription en attente de synchronisation'
            : 'Inscription à vérifier';
        final details = <String>[
          if (hasWaitingRegistrations)
            waitingCount == 1
                ? 'Votre inscription sera envoyée dès que la connexion sera rétablie.'
                : '$waitingCount inscriptions seront envoyées dès que la connexion sera rétablie.',
          if (needsReviewCount > 0)
            '$needsReviewCount inscription(s) nécessitent une vérification.',
        ];
        final subtitle = details.join(' ');

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Semantics(
            container: true,
            liveRegion: true,
            label: '$title. $subtitle',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
              decoration: BoxDecoration(
                color: _bannerSurface,
                border: Border.all(color: _bannerBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.cloud_upload_outlined,
                          color: _bannerBlue,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: _bannerText,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: _bannerText, height: 1.4),
                            ),
                            if (_syncError != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _syncError!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFF9A3412),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (hasWaitingRegistrations)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isSyncing ? null : _retrySync,
                        style: TextButton.styleFrom(
                          foregroundColor: _bannerBlue,
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: _isSyncing
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _bannerBlue,
                                ),
                              )
                            : const Icon(Icons.sync_rounded, size: 18),
                        label: Text(
                          _isSyncing ? 'Synchronisation…' : 'Réessayer',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
