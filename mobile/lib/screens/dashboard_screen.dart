import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../models/gate_pass.dart';

class DashboardScreen extends StatelessWidget {
  final List<GatePass> passes;
  final List<PassLog> logs;
  final VoidCallback onRefresh;
  final ValueChanged<int> onNavigate;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onScan;

  const DashboardScreen({super.key, required this.passes, required this.logs, required this.onRefresh, required this.onNavigate, required this.onImport, required this.onExport, required this.onScan});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    int active = 0, notStarted = 0, expired = 0, totalScans = 0;
    for (final p in passes) {
      if (p.isNotStarted) { notStarted++; } else if (p.isExpired) { expired++; } else { active++; }
      totalScans += p.scanCount;
    }

    final upcoming = passes.where((p) => p.isNotStarted).toList()..sort((a, b) => a.validFrom.compareTo(b.validFrom));
    final nextEvent = upcoming.isNotEmpty ? upcoming.first : null;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        slivers: [
          // ── Hero Card ──
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), sliver: SliverToBoxAdapter(
            child: Card.filled(
              color: cs.primaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: cs.onPrimaryContainer.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Center(child: SvgPicture.asset('assets/icons/logo.svg', width: 24, height: 24, colorFilter: ColorFilter.mode(cs.onPrimaryContainer, BlendMode.srcIn), placeholderBuilder: (_) => Icon(Icons.confirmation_number_rounded, color: cs.onPrimaryContainer, size: 24)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('DePass', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: cs.onPrimaryContainer)),
                    Text('Dinner & Event Gate Pass', style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.6))),
                  ])),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  _statCard(cs, tt, 'Active', active, Icons.check_circle, cs.tertiary),
                  const SizedBox(width: 8),
                  _statCard(cs, tt, 'Scans', totalScans, Icons.sensors, cs.secondary),
                  const SizedBox(width: 8),
                  _statCard(cs, tt, 'Total', passes.length, Icons.group, cs.primary),
                ]),
              ])),
            ),
          )),

          // ── Status Chips ──
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), sliver: SliverToBoxAdapter(
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              _statusChip('Not Started', notStarted, Icons.schedule, Colors.orange),
              _statusChip('Active', active, Icons.check_circle, Colors.green),
              _statusChip('Expired', expired, Icons.timer_off, cs.error),
            ]),
          )),

          // ── Next Event ──
          if (nextEvent != null) SliverPadding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), sliver: SliverToBoxAdapter(
            child: Card.outlined(
              color: Colors.orange.withValues(alpha: 0.04),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: CircleAvatar(backgroundColor: Colors.orange.withValues(alpha: 0.1), child: const Icon(Icons.schedule, color: Colors.orange)),
                title: Text('Next: ${nextEvent.eventName}', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text(DateFormat('dd MMM yyyy').format(nextEvent.validFrom), style: tt.bodySmall),
                trailing: Text(_countdown(nextEvent.validFrom), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.orange)),
              ),
            ),
          )),

          // ── Quick Actions ──
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), sliver: SliverToBoxAdapter(
            child: Text('Quick Actions', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          )),
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), sliver: SliverToBoxAdapter(
            child: Row(children: [
              Expanded(child: _actionCard(cs, tt, Icons.note_add, 'Issue Pass', 'Create new pass', cs.primary, () => onNavigate(1))),
              const SizedBox(width: 10),
              Expanded(child: _actionCard(cs, tt, Icons.qr_code_2, 'Scan QR', 'Verify at gate', cs.tertiary, onScan)),
            ]),
          )),
          SliverPadding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), sliver: SliverToBoxAdapter(
            child: Row(children: [
              Expanded(child: _actionCard(cs, tt, Icons.download, 'Import', 'JSON / CSV', cs.secondary, onImport)),
              const SizedBox(width: 10),
              Expanded(child: _actionCard(cs, tt, Icons.cloud_upload, 'Export', 'Share data', cs.error, onExport)),
            ]),
          )),

          // ── Recent Activity ──
          if (logs.isNotEmpty) ...[
            SliverPadding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), sliver: SliverToBoxAdapter(
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Recent Activity', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                TextButton.icon(onPressed: () => onNavigate(3), icon: const Icon(Icons.arrow_forward, size: 16), label: const Text('View All')),
              ]),
            )),
            SliverPadding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), sliver: SliverList(
              delegate: SliverChildBuilderDelegate((ctx, i) => _logTile(cs, tt, logs[i]), childCount: logs.take(5).length),
            )),
          ] else SliverPadding(padding: const EdgeInsets.fromLTRB(16, 40, 16, 100), sliver: SliverToBoxAdapter(
            child: Center(child: Column(children: [
              Icon(Icons.inbox_rounded, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              Text('No activity yet', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('Scan passes to see activity here', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
            ])),
          )),
        ],
      ),
    );
  }

  Widget _statCard(ColorScheme cs, TextTheme tt, String label, int value, IconData icon, Color accent) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.onPrimaryContainer.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, color: accent, size: 24),
        const SizedBox(height: 4),
        Text('$value', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.onPrimaryContainer)),
        Text(label, style: tt.labelSmall?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.55))),
      ]),
    ));
  }

  Widget _statusChip(String label, int count, IconData icon, Color color) {
    return FilterChip(
      label: Text('$label: $count'),
      selected: count > 0,
      onSelected: (_) {},
      avatar: Icon(icon, size: 18, color: color),
    );
  }

  Widget _actionCard(ColorScheme cs, TextTheme tt, IconData icon, String label, String subtitle, Color color, VoidCallback onTap) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(height: 10),
          Text(label, style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          Text(subtitle, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ])),
      ),
    );
  }

  Widget _logTile(ColorScheme cs, TextTheme tt, PassLog log) {
    final isReject = log.action == 'REJECTED';
    final color = isReject ? cs.error : (log.action == 'ENTRY' ? Colors.green : cs.tertiary);
    final icon = isReject ? Icons.do_not_disturb_on : (log.action == 'ENTRY' ? Icons.door_front_door : Icons.exit_to_app);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color, size: 20)),
        title: Text('${log.action} — ${log.passId}', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(DateFormat.yMd().add_jm().format(log.timestamp), style: tt.bodySmall),
        trailing: Badge(
          label: Text(log.valid ? 'OK' : 'FAIL', style: tt.labelSmall?.copyWith(color: log.valid ? Colors.green : cs.error, fontWeight: FontWeight.w700)),
          backgroundColor: log.valid ? Colors.green.withValues(alpha: 0.08) : cs.error.withValues(alpha: 0.08),
        ),
      ),
    );
  }

  String _countdown(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    return '${diff.inMinutes}m';
  }
}
