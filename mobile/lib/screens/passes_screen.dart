import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/gate_pass.dart';

class PassesScreen extends StatelessWidget {
  final List<GatePass> passes;
  final Future<void> Function(GatePass) onSave;
  final Future<void> Function(PassLog) onAddLog;

  const PassesScreen({super.key, required this.passes, required this.onSave, required this.onAddLog});

  @override
  Widget build(BuildContext context) {
    if (passes.isEmpty) {
      return const Center(child: Text('No passes yet.\nUse Issue tab or Import.'));
    }

    return ListView.builder(
      itemCount: passes.length,
      itemBuilder: (context, index) {
        final p = passes[index];
        final isValid = p.validTo.isAfter(DateTime.now());
        return ListTile(
          title: Text(p.passId),
          subtitle: Text('${p.fullName} • ${p.operator} • ${p.category.name}'),
          trailing: Chip(
            label: Text(isValid ? 'VALID' : 'EXPIRED'),
            backgroundColor: isValid ? Colors.green.shade100 : Colors.red.shade100,
          ),
          onTap: () => _showPassDetails(context, p, onAddLog),
        );
      },
    );
  }

  void _showPassDetails(BuildContext context, GatePass p, Future<void> Function(PassLog) onAddLog) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p.passId),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${p.idNumber} • ${p.phone ?? ''}'),
              const SizedBox(height: 12),
              if (p.qrPayload != null)
                QrImageView(data: p.qrPayload!, version: QrVersions.auto, size: 160),
              const SizedBox(height: 12),
              Text('Valid: ${p.formattedValidity}'),
              Text('Gate: ${p.gate ?? 'ANY'}'),
              Text('Operator: ${p.operator}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              final log = PassLog(
                passId: p.passId,
                action: 'ENTRY',
                gate: p.gate,
                valid: p.validTo.isAfter(DateTime.now()),
              );
              await onAddLog(log);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simulate ENTRY'),
          ),
        ],
      ),
    );
  }
}
