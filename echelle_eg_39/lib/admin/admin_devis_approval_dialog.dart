import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_tokens.dart';

Future<int?> showAdminDevisApprovalDialog(
  BuildContext context, {
  required int devisId,
}) {
  return showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AdminDevisApprovalDialog(devisId: devisId),
  );
}

class _AdminDevisApprovalDialog extends StatefulWidget {
  const _AdminDevisApprovalDialog({required this.devisId});

  final int devisId;

  @override
  State<_AdminDevisApprovalDialog> createState() =>
      _AdminDevisApprovalDialogState();
}

class _AdminDevisApprovalDialogState extends State<_AdminDevisApprovalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = int.parse(_amountController.text.trim());
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Approuver le devis #${widget.devisId}',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AdminPalette.primaryText,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saisissez le montant à communiquer au client.',
                style: TextStyle(
                  color: AdminPalette.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AdminSpacing.lg),
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 16,
                decoration: InputDecoration(
                  labelText: 'Montant (FCFA)',
                  labelStyle: const TextStyle(
                    color: AdminPalette.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                  prefixIcon: const Icon(Icons.payments_outlined),
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
                validator: (value) {
                  final amount = int.tryParse(value?.trim() ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Saisissez un montant entier supérieur à zéro.';
                  }
                  if (amount > 9007199254740991) {
                    return 'Le montant saisi est trop élevé.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Annuler',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check, size: 18),
          label: const Text(
            'Confirmer l’approbation',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminPalette.approvalGreen,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AdminRadii.field),
            ),
          ),
        ),
      ],
    );
  }
}
