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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_rounded, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 16),
            Text('No activity yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text('Scan passes to see logs here', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
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
        final icon = isReject ? Icons.block_rounded : (isEntry ? Icons.login_rounded : Icons.logout_rounded);

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (i < 10 ? i * 30 : 0)),
          curve: Curves.easeOutCubic,
          builder: (ctx, val, child) => Transform.translate(
            offset: Offset((1 - val) * 16, 0),
            child: Opacity(opacity: val, child: child),
          ),
          child: Card(
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 22),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l.action, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l.passId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${DateFormat.yMd().add_jm().format(l.timestamp)}${l.gate != null ? ' • ${l.gate}' : ''}',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              trailing: l.notes != null && l.notes != 'OK'
                  ? Tooltip(
                      message: l.notes!,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.info_outline_rounded, size: 18, color: cs.error.withValues(alpha: 0.7)),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.check_circle_rounded, size: 18, color: Colors.green.withValues(alpha: 0.7)),
                    ),
            ),
          ),
        );
      },
    );
  }
}
