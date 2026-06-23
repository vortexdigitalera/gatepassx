import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
              decoration: BoxDecoration(color: cs.surfaceContainerHigh, shape: BoxShape.circle),
              child: Icon(Icons.history_rounded, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 16),
            Text('No activity yet', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text('Scan passes to see logs here', style: GoogleFonts.inter(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: logs.length,
      itemBuilder: (context, i) {
        final l = logs[i];
        final config = _getLogConfig(l, cs);

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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: config.color.withValues(alpha: 0.1),
                child: Icon(config.icon, color: config.color, size: 22),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: config.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l.action, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: config.color)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l.passId, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            DateFormat.yMd().add_jm().format(l.timestamp),
                            style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    if (l.gate != null && l.gate!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                            const SizedBox(width: 4),
                            Text(l.gate!, style: GoogleFonts.inter(fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              trailing: _buildTrailing(l, cs, config),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrailing(PassLog l, ColorScheme cs, _LogConfig config) {
    final label = l.scanStatus ?? (l.valid ? 'valid' : 'invalid');
    final statusCfg = _getStatusDisplay(label, config.color, cs);

    return Tooltip(
      message: l.notes ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: statusCfg.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: statusCfg.color.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusCfg.icon, size: 13, color: statusCfg.color),
            const SizedBox(width: 4),
            Text(statusCfg.label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusCfg.color)),
          ],
        ),
      ),
    );
  }

  _StatusDisplay _getStatusDisplay(String scanStatus, Color fallbackColor, ColorScheme cs) {
    switch (scanStatus) {
      case 'valid':
        return _StatusDisplay(icon: Icons.check_circle_rounded, color: Colors.green, label: 'VALID');
      case 'notStarted':
        return _StatusDisplay(icon: Icons.schedule_rounded, color: Colors.orange, label: 'NOT STARTED');
      case 'expired':
        return _StatusDisplay(icon: Icons.timer_off_rounded, color: cs.error, label: 'EXPIRED');
      case 'duplicate':
        return _StatusDisplay(icon: Icons.replay_rounded, color: cs.tertiary, label: 'DUPLICATE');
      case 'unknown':
        return _StatusDisplay(icon: Icons.help_outline_rounded, color: Colors.grey, label: 'UNKNOWN');
      default:
        return _StatusDisplay(icon: Icons.check_circle_rounded, color: fallbackColor, label: scanStatus.toUpperCase());
    }
  }

  _LogConfig _getLogConfig(PassLog l, ColorScheme cs) {
    final isEntry = l.action == 'ENTRY';
    final isReject = l.action == 'REJECTED';

    if (isReject) {
      if (l.scanStatus == 'notStarted') return _LogConfig(Icons.schedule_rounded, Colors.orange);
      if (l.scanStatus == 'expired') return _LogConfig(Icons.timer_off_rounded, cs.error);
      if (l.scanStatus == 'duplicate') return _LogConfig(Icons.replay_rounded, cs.tertiary);
      if (l.scanStatus == 'unknown') return _LogConfig(Icons.help_outline_rounded, Colors.grey);
      return _LogConfig(Icons.block_rounded, cs.error);
    }
    if (isEntry) return _LogConfig(Icons.login_rounded, Colors.green);
    return _LogConfig(Icons.logout_rounded, cs.tertiary);
  }
}

class _LogConfig {
  final IconData icon;
  final Color color;
  const _LogConfig(this.icon, this.color);
}

class _StatusDisplay {
  final IconData icon;
  final Color color;
  final String label;
  const _StatusDisplay({required this.icon, required this.color, required this.label});
}
