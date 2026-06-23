import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gate_pass.dart';

class LogsScreen extends StatelessWidget {
  final List<PassLog> logs;

  const LogsScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No activity yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text('Scan passes to see logs here', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
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
        final color = isReject ? Colors.red : (isEntry ? Colors.green : Colors.orange);
        final icon = isReject ? Icons.block : (isEntry ? Icons.login_rounded : Icons.logout_rounded);

        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(l.action, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.passId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${DateFormat.yMd().add_jm().format(l.timestamp)}${l.gate != null ? ' • ${l.gate}' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            trailing: l.notes != null && l.notes != 'OK'
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l.notes!, style: TextStyle(fontSize: 9, color: Colors.red.shade400)),
                  )
                : Icon(Icons.check_circle, size: 18, color: Colors.green.shade300),
          ),
        );
      },
    );
  }
}
