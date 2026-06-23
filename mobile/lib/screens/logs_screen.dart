import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gate_pass.dart';

class LogsScreen extends StatelessWidget {
  final List<PassLog> logs;

  const LogsScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(child: Text('No activity logged yet.'));
    }
    return ListView.separated(
      itemCount: logs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final l = logs[i];
        return ListTile(
          leading: Icon(l.valid ? Icons.check_circle : Icons.cancel, color: l.valid ? Colors.green : Colors.red),
          title: Text('${l.action} — ${l.passId}'),
          subtitle: Text('${DateFormat.yMd().add_jm().format(l.timestamp)} ${l.gate ?? ''} ${l.notes ?? ''}'),
        );
      },
    );
  }
}
