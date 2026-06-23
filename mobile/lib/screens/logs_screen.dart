import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gate_pass.dart';

class LogsScreen extends StatefulWidget {
  final List<PassLog> logs;
  const LogsScreen({super.key, required this.logs});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _filter = 'all';

  List<PassLog> get _filtered {
    if (_filter == 'all') return widget.logs;
    if (_filter == 'entry') return widget.logs.where((l) => l.action == 'ENTRY').toList();
    if (_filter == 'rejected') return widget.logs.where((l) => l.action == 'REJECTED').toList();
    return widget.logs;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (widget.logs.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history_toggle_off, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text('No activity yet', style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text('Scan passes to see logs here', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
      ]));
    }

    final filtered = _filtered;

    return Column(children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Row(children: [
        FilterChip(label: const Text('All'), selected: _filter == 'all', onSelected: (_) => setState(() => _filter = 'all')),
        const SizedBox(width: 8),
        FilterChip(label: const Text('Entries'), selected: _filter == 'entry', onSelected: (_) => setState(() => _filter = 'entry')),
        const SizedBox(width: 8),
        FilterChip(label: const Text('Rejected'), selected: _filter == 'rejected', onSelected: (_) => setState(() => _filter = 'rejected')),
      ])),
      Expanded(child: filtered.isEmpty
          ? Center(child: Text('No matching logs', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)))
          : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), itemCount: filtered.length, itemBuilder: (ctx, i) => _buildTile(cs, tt, filtered[i]))),
    ]);
  }

  Widget _buildTile(ColorScheme cs, TextTheme tt, PassLog log) {
    final isReject = log.action == 'REJECTED';
    final color = isReject ? cs.error : (log.action == 'ENTRY' ? Colors.green : cs.tertiary);
    final icon = isReject ? Icons.do_not_disturb_on : (log.action == 'ENTRY' ? Icons.door_front_door : Icons.exit_to_app);

    final statusLabel = log.scanStatus ?? (log.valid ? 'valid' : 'invalid');
    final statusCfg = _statusDisplay(statusLabel, color, cs);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
        title: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)), child: Text(log.action, style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: color))),
          const SizedBox(width: 8),
          Expanded(child: Text(log.passId, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.access_time, size: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.5)), const SizedBox(width: 4), Expanded(child: Text(DateFormat.yMd().add_jm().format(log.timestamp), style: tt.bodySmall))]),
          if (log.gate != null && log.gate!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Row(children: [Icon(Icons.place, size: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.4)), const SizedBox(width: 4), Text(log.gate!, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.7)))])),
        ])),
        trailing: Tooltip(message: log.notes ?? statusLabel, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: statusCfg.color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: statusCfg.color.withValues(alpha: 0.1))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(statusCfg.icon, size: 13, color: statusCfg.color), const SizedBox(width: 4), Text(statusCfg.label, style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: statusCfg.color))]))),
      ),
    );
  }

  _StatusDisplay _statusDisplay(String scanStatus, Color fallback, ColorScheme cs) {
    switch (scanStatus) {
      case 'valid': return _StatusDisplay(Icons.check_circle, Colors.green, 'VALID');
      case 'notStarted': return _StatusDisplay(Icons.schedule, Colors.orange, 'NOT STARTED');
      case 'expired': return _StatusDisplay(Icons.timer_off, cs.error, 'EXPIRED');
      case 'duplicate': return _StatusDisplay(Icons.replay, cs.tertiary, 'DUPLICATE');
      case 'unknown': return _StatusDisplay(Icons.help_outline, Colors.grey, 'UNKNOWN');
      default: return _StatusDisplay(Icons.check_circle, fallback, scanStatus.toUpperCase());
    }
  }
}

class _StatusDisplay { final IconData icon; final Color color; final String label; const _StatusDisplay(this.icon, this.color, this.label); }
