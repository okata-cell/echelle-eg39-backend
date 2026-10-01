import 'package:flutter/material.dart';

/// Shows a rejection dialog and returns the trimmed reason only on confirmation.
Future<String?> showAdminRejectionDialog(
  BuildContext context, {
  required String title,
  String hintText = 'Saisissez le motif du rejet.',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AdminRejectionDialog(title: title, hintText: hintText),
  );
}

class _AdminRejectionDialog extends StatefulWidget {
  const _AdminRejectionDialog({required this.title, required this.hintText});

  final String title;
  final String hintText;

  @override
  State<_AdminRejectionDialog> createState() => _AdminRejectionDialogState();
}

class _AdminRejectionDialogState extends State<_AdminRejectionDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = _controller.text.trim();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.cancel, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Motif du rejet',
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.message_outlined),
        ),
        maxLines: 3,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: reason.isEmpty
              ? null
              : () => Navigator.of(context).pop(reason),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}
