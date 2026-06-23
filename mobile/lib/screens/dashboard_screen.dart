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
    final active = passes.where((p) => p.validTo.isAfter(DateTime.now())).length;
    final todayEntries = logs.where((l) =>
        l.action == 'ENTRY' &&
        l.timestamp.year == DateTime.now().year &&
        l.timestamp.month == DateTime.now().month &&
        l.timestamp.day == DateTime.now().day).length;
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: cs.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Welcome header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF004D00), Color(0xFF1B7A1B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.door_sliding_outlined, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome to GatePassX', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('AHUON Gate Pass Management', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _StatCard(label: 'Active', value: active.toString(), icon: Icons.check_circle_outline, color: Colors.greenAccent),
                    const SizedBox(width: 10),
                    _StatCard(label: "Today's Entry", value: todayEntries.toString(), icon: Icons.login_rounded, color: Colors.amberAccent),
                    const SizedBox(width: 10),
                    _StatCard(label: 'Total', value: passes.length.toString(), icon: Icons.people_outline, color: Colors.lightBlueAccent),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quick actions
          Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.add_card_rounded,
                  label: 'Issue Pass',
                  subtitle: 'Create new pass',
                  color: cs.primary,
                  onTap: () => _showInfo(context, 'Go to Issue tab to create a new gate pass.'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionCard(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan QR',
                  subtitle: 'Verify at gate',
                  color: cs.secondary,
                  onTap: () => _showInfo(context, 'Switch to the Scan tab to verify passes.'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.file_download_outlined,
                  label: 'Import',
                  subtitle: 'JSON / CSV files',
                  color: Colors.blueGrey,
                  onTap: () => _showInfo(context, 'Use the Import button in the App Bar.'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionCard(
                  icon: Icons.upload_outlined,
                  label: 'Export',
                  subtitle: 'For Python PDF gen',
                  color: Colors.deepPurple,
                  onTap: () => _showInfo(context, 'Use the Export button in the App Bar.'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recent activity
          if (logs.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All', style: TextStyle(fontSize: 12)),
                ),
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
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text('No activity yet', style: TextStyle(color: Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text('Scan passes to see activity here', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
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
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
    final isEntry = log.action == 'ENTRY';
    final isReject = log.action == 'REJECTED';
    final color = isReject ? Colors.red : (isEntry ? Colors.green : Colors.orange);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isReject ? Icons.block : (isEntry ? Icons.login_rounded : Icons.logout_rounded),
            color: color,
            size: 20,
          ),
        ),
        title: Text('${log.action} — ${log.passId}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(DateFormat.yMd().add_jm().format(log.timestamp), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: log.valid ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            log.valid ? 'VALID' : 'INVALID',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: log.valid ? Colors.green : Colors.red,
            ),
          ),
        ),
      ),
    );
  }
}
