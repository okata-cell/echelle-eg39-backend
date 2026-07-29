// Stub classes for backward compatibility - prolongation feature removed
// Users should contact the DG directly for extensions

import 'package:flutter/material.dart';

class ExtensionsManager {
  ExtensionsManager();

  Stream get events => const Stream.empty();

  void addExtension(LocationExtension extension) {
    // No-op - prolongation removed
  }

  LocationExtension? getExtension(String id) => null;

  int computeUnpaidForTransaction(int transactionId) => 0;
}

class LocationExtension {
  final String extensionId;
  final int transactionId;
  final String clientName;
  final String equipmentName;
  final String oldReturnDate;
  final String newReturnDate;
  final int additionalDays;
  final int additionalCost;
  final DateTime createdAt;
  final bool isPaid;
  final String? invoiceNumber;

  LocationExtension({
    required this.extensionId,
    required this.transactionId,
    required this.clientName,
    required this.equipmentName,
    required this.oldReturnDate,
    required this.newReturnDate,
    required this.additionalDays,
    required this.additionalCost,
    required this.createdAt,
    required this.isPaid,
    this.invoiceNumber,
  });
}

class AdminProlongationsPage extends StatelessWidget {
  const AdminProlongationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Fonctionnalité supprimée - Contacter le DG'),
      ),
    );
  }
}