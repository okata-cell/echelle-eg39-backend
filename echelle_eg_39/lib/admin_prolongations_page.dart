import 'package:flutter/material.dart';
import 'extensions_manager.dart';
import 'demo_flags.dart';
import 'dart:async';

class AdminProlongationsPage extends StatefulWidget {
  const AdminProlongationsPage({Key? key}) : super(key: key);

  @override
  State<AdminProlongationsPage> createState() => _AdminProlongationsPageState();
}

class _AdminProlongationsPageState extends State<AdminProlongationsPage> {
  final ExtensionsManager _manager = ExtensionsManager();
  late final StreamSubscription _sub;

  List<LocationExtension> _pending = const [];

  @override
  void initState() {
    super.initState();
    _pending = _manager.listPendingExtensions();
    if (kDemoPaymentsEnabled) {
      _sub = _manager.events.listen((event) {
        if (!mounted) return;
        setState(() {
          _pending = _manager.listPendingExtensions();
        });
      });
    }
  }

  @override
  void dispose() {
    if (kDemoPaymentsEnabled) {
      _sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiements en attente (DEMO)'),
      ),
      body: _pending.isEmpty
          ? const Center(
              child: Text(
                'Aucun paiement en attente',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.separated(
              itemCount: _pending.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final ext = _pending[index];
                return ListTile(
                  leading: const Icon(Icons.hourglass_top, color: Colors.orange),
                  title: Text(ext.equipmentName),
                  subtitle: Text(
                    'Tx #${ext.transactionId} • +${ext.additionalDays}j • ${ext.additionalCost} FCFA\nEmise: ${ext.createdAt.toLocal()}'.split('.').first,
                  ),
                  isThreeLine: true,
                  trailing: ElevatedButton.icon(
                    onPressed: () {
                      _manager.markExtensionPaid(ext.extensionId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Paiement validé')),
                      );
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Valider'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                );
              },
            ),
    );
  }
}
