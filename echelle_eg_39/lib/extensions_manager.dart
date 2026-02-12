import 'dart:async';

// Basic in-memory simulation of extensions (prolongations) store + events
// This abstracts a future backend. Switch internals later without changing UI code.

class LocationExtension {
  final String extensionId;
  final int transactionId;
  final String clientName;
  final String equipmentName;
  final String oldReturnDate; // ISO yyyy-MM-dd
  final String newReturnDate; // ISO yyyy-MM-dd
  final int additionalDays;
  final int additionalCost;
  final DateTime createdAt;
  bool isPaid;
  DateTime? paidAt;
  final String invoiceNumber;

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
    this.paidAt,
    required this.invoiceNumber,
  });
}

class ExtensionEvent {
  final String type; // extensionAdded, extensionPaid, transactionUpdated
  final int transactionId;
  final String? extensionId;
  ExtensionEvent(this.type, this.transactionId, [this.extensionId]);
}

class ExtensionsManager {
  static final ExtensionsManager _instance = ExtensionsManager._internal();
  factory ExtensionsManager() => _instance;
  ExtensionsManager._internal();

  final Map<String, LocationExtension> _extensions = {};
  final Map<int, List<String>> _byTransaction = {};

  final StreamController<ExtensionEvent> _controller =
      StreamController<ExtensionEvent>.broadcast();
  Stream<ExtensionEvent> get events => _controller.stream;

  void addExtension(LocationExtension ext) {
    _extensions[ext.extensionId] = ext;
    final list = _byTransaction.putIfAbsent(ext.transactionId, () => <String>[]);
    if (!list.contains(ext.extensionId)) {
      list.add(ext.extensionId);
    }
    _controller.add(ExtensionEvent('extensionAdded', ext.transactionId, ext.extensionId));
    _controller.add(ExtensionEvent('transactionUpdated', ext.transactionId));
  }

  LocationExtension? getExtension(String id) => _extensions[id];

  List<LocationExtension> getExtensionsByTransaction(int transactionId) {
    final ids = _byTransaction[transactionId] ?? const <String>[];
    return ids.map((id) => _extensions[id]).whereType<LocationExtension>().toList();
  }

  List<LocationExtension> listPendingExtensions() {
    return _extensions.values.where((e) => !e.isPaid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int computeUnpaidForTransaction(int transactionId) {
    final exts = getExtensionsByTransaction(transactionId);
    return exts.where((e) => !e.isPaid).fold<int>(0, (sum, e) => sum + e.additionalCost);
  }

  void markExtensionPaid(String extensionId) {
    final ext = _extensions[extensionId];
    if (ext == null) return;
    if (ext.isPaid) return; // idempotent
    ext.isPaid = true;
    ext.paidAt = DateTime.now();
    _controller.add(ExtensionEvent('extensionPaid', ext.transactionId, extensionId));
    _controller.add(ExtensionEvent('transactionUpdated', ext.transactionId));
  }
}
