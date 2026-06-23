import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gate_pass.dart';

class LogsScreen extends StatelessWidget {
  final List<PassLog> logs;
  const LogsScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_outlined, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No activity yet', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Scan passes to see logs here', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: logs.length,
      itemBuilder: (context, i) {
        final l = logs[i];
        final isEntry = l.action == 'ENTRY';
        final isReject = l.action == 'REJECTED';
        final color = isReject ? cs.error : (isEntry ? Colors.green : cs.tertiary);
        final icon = isReject ? Icons.block : (isEntry ? Icons.login_rounded : Icons.logout_rounded);

        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Row(
              children: [
                Chip(
                  label: Text(l.action, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                  backgroundColor: color.withValues(alpha: 0.08),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(l.passId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${DateFormat.yMd().add_jm().format(l.timestamp)}${l.gate != null ? ' • ${l.gate}' : ''}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ),
            trailing: l.notes != null && l.notes != 'OK'
                ? Tooltip(
                    message: l.notes!,
                    child: Icon(Icons.info_outline, size: 18, color: cs.error.withValues(alpha: 0.6)),
                  )
                : Icon(Icons.check_circle_outline, size: 18, color: Colors.green.withValues(alpha: 0.6)),
          ),
        );
      },
    );
  }
}
