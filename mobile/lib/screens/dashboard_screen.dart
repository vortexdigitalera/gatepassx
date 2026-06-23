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

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('AHUON GatePassX', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Association for Hajj and Umrah Operators of Nigeria', style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StatCard(label: 'Active Passes', value: active.toString()),
                      const SizedBox(width: 12),
                      _StatCard(label: "Today's Entries", value: todayEntries.toString()),
                      const SizedBox(width: 12),
                      _StatCard(label: 'Total Passes', value: passes.length.toString()),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.add),
                label: const Text('Issue New Pass'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Use the Issue tab in bottom navigation')));
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.qr_code_scanner),
                label: const Text('Open Scanner'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Switch to the Scan tab')));
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (logs.isNotEmpty) ...[
            const Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...logs.take(5).map((log) => ListTile(
                  dense: true,
                  leading: Icon(
                    log.action == 'ENTRY' ? Icons.login : (log.action == 'EXIT' ? Icons.logout : Icons.block),
                    color: log.valid ? Colors.green : Colors.red,
                  ),
                  title: Text('${log.action} • ${log.passId}'),
                  subtitle: Text(DateFormat.yMd().add_jm().format(log.timestamp)),
                )),
          ],
          const SizedBox(height: 40),
          const Center(
            child: Text('Use Export to feed data to the Python PDF generator', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
