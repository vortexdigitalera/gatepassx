import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gate_pass.dart';

class DashboardScreen extends StatelessWidget {
  final List<GatePass> passes;
  final List<PassLog> logs;
  final VoidCallback onRefresh;

  const DashboardScreen({super.key, required this.passes, required this.logs, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = passes.where((p) => p.validTo.isAfter(DateTime.now())).length;
    final todayEntries = logs.where((l) =>
        l.action == 'ENTRY' &&
        l.timestamp.year == DateTime.now().year &&
        l.timestamp.month == DateTime.now().month &&
        l.timestamp.day == DateTime.now().day).length;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: cs.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Hero card
          Card(
            color: cs.primaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.15),
                        child: Icon(Icons.confirmation_number_outlined, color: cs.onPrimaryContainer, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DePass', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
                            Text('Dinner & Event Gate Pass', style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _StatCard(label: 'Active', value: active.toString(), icon: Icons.check_circle_outline, color: cs.tertiary, cs: cs),
                      const SizedBox(width: 8),
                      _StatCard(label: "Today's Entry", value: todayEntries.toString(), icon: Icons.login_rounded, color: cs.secondary, cs: cs),
                      const SizedBox(width: 8),
                      _StatCard(label: 'Total', value: passes.length.toString(), icon: Icons.people_outline, color: cs.primary, cs: cs),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('Quick Actions', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ActionCard(icon: Icons.add_card_rounded, label: 'Issue Pass', subtitle: 'Create new pass', color: cs.primary, onTap: () => _snack(context, 'Go to Issue tab to create a new pass.'))),
              const SizedBox(width: 8),
              Expanded(child: _ActionCard(icon: Icons.qr_code_scanner_rounded, label: 'Scan QR', subtitle: 'Verify at gate', color: cs.tertiary, onTap: () => _snack(context, 'Switch to the Scan tab.'))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _ActionCard(icon: Icons.file_download_outlined, label: 'Import', subtitle: 'JSON / CSV files', color: cs.secondary, onTap: () => _snack(context, 'Use Import in the App Bar.'))),
              const SizedBox(width: 8),
              Expanded(child: _ActionCard(icon: Icons.upload_outlined, label: 'Export', subtitle: 'For CLI PDF gen', color: cs.error, onTap: () => _snack(context, 'Use Export in the App Bar.'))),
            ],
          ),
          const SizedBox(height: 20),

          if (logs.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Activity', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                TextButton(onPressed: () {}, child: const Text('View All')),
              ],
            ),
            const SizedBox(height: 8),
            ...logs.take(5).map((log) => _ActivityCard(log: log)),
          ] else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text('No activity yet', style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text('Scan passes to see activity here', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final ColorScheme cs;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.onPrimaryContainer.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: cs.onPrimaryContainer.withValues(alpha: 0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final PassLog log;

  const _ActivityCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEntry = log.action == 'ENTRY';
    final isReject = log.action == 'REJECTED';
    final color = isReject ? cs.error : (isEntry ? Colors.green : cs.tertiary);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            isReject ? Icons.block : (isEntry ? Icons.login_rounded : Icons.logout_rounded),
            color: color, size: 20,
          ),
        ),
        title: Text('${log.action} — ${log.passId}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(DateFormat.yMd().add_jm().format(log.timestamp), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        trailing: Chip(
          label: Text(log.valid ? 'VALID' : 'INVALID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: log.valid ? Colors.green : cs.error)),
          backgroundColor: log.valid ? Colors.green.withValues(alpha: 0.08) : cs.error.withValues(alpha: 0.08),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
