import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../models/gate_pass.dart';

class DashboardScreen extends StatefulWidget {
  final List<GatePass> passes;
  final List<PassLog> logs;
  final VoidCallback onRefresh;
  final ValueChanged<int> onNavigate;
  final VoidCallback onImport;
  final VoidCallback onExport;

  const DashboardScreen({
    super.key,
    required this.passes,
    required this.logs,
    required this.onRefresh,
    required this.onNavigate,
    required this.onImport,
    required this.onExport,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _animated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _animated = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = widget.passes.where((p) => p.validTo.isAfter(DateTime.now())).length;
    final todayEntries = widget.logs.where((l) =>
        l.action == 'ENTRY' &&
        l.timestamp.year == DateTime.now().year &&
        l.timestamp.month == DateTime.now().month &&
        l.timestamp.day == DateTime.now().day).length;

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: cs.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            children: [
              _buildHeroCard(context, cs, active, todayEntries, isWide),
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Quick Actions', Icons.bolt_rounded),
              const SizedBox(height: 12),
              _buildActionGrid(context, cs, isWide),
              const SizedBox(height: 24),
              if (widget.logs.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle(context, 'Recent Activity', Icons.timeline_rounded),
                    TextButton.icon(
                      onPressed: () => widget.onNavigate(4),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  math.min(5, widget.logs.length),
                  (i) => _buildActivityCard(context, cs, widget.logs[i], i),
                ),
              ] else
                _buildEmptyActivity(context, cs),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, ColorScheme cs, int active, int todayEntries, bool isWide) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, _animated ? 0 : -20, 0),
      child: Card(
        color: cs.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/logo.svg',
                        width: 28,
                        height: 28,
                        colorFilter: ColorFilter.mode(cs.onPrimaryContainer, BlendMode.srcIn),
                        placeholderBuilder: (_) => Icon(
                          Icons.confirmation_number_rounded,
                          color: cs.onPrimaryContainer,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DePass', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onPrimaryContainer, letterSpacing: 0.3)),
                        Text('Dinner & Event Gate Pass', style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer.withValues(alpha: 0.65), fontWeight: FontWeight.w400)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              isWide
                  ? Row(children: [
                      _buildStatCard(cs, 'Active', active.toString(), Icons.check_circle_rounded, cs.tertiary),
                      const SizedBox(width: 12),
                      _buildStatCard(cs, "Today's Entry", todayEntries.toString(), Icons.login_rounded, cs.secondary),
                      const SizedBox(width: 12),
                      _buildStatCard(cs, 'Total Passes', widget.passes.length.toString(), Icons.people_rounded, cs.primary),
                    ])
                  : Column(
                      children: [
                        Row(children: [
                          _buildStatCard(cs, 'Active', active.toString(), Icons.check_circle_rounded, cs.tertiary),
                          const SizedBox(width: 8),
                          _buildStatCard(cs, "Today's Entry", todayEntries.toString(), Icons.login_rounded, cs.secondary),
                        ]),
                        const SizedBox(height: 8),
                        _buildStatCard(cs, 'Total Passes', widget.passes.length.toString(), Icons.people_rounded, cs.primary),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(ColorScheme cs, String label, String value, IconData icon, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.onPrimaryContainer.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.onPrimaryContainer.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: cs.onPrimaryContainer.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context, ColorScheme cs, bool isWide) {
    final actions = [
      _ActionItem(Icons.add_card_rounded, 'Issue Pass', 'Create new gate pass', cs.primary, () => widget.onNavigate(1)),
      _ActionItem(Icons.qr_code_scanner_rounded, 'Scan QR', 'Verify at gate', cs.tertiary, () => widget.onNavigate(3)),
      _ActionItem(Icons.file_download_rounded, 'Import', 'JSON / CSV files', cs.secondary, widget.onImport),
      _ActionItem(Icons.upload_rounded, 'Export', 'Share pass data', cs.error, widget.onExport),
    ];

    if (isWide) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: actions.asMap().entries.map((e) => SizedBox(
          width: (MediaQuery.of(context).size.width - 44) / 2,
          child: _buildActionCard(context, cs, e.value, e.key),
        )).toList(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildActionCard(context, cs, actions[0], 0)),
            const SizedBox(width: 10),
            Expanded(child: _buildActionCard(context, cs, actions[1], 1)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildActionCard(context, cs, actions[2], 2)),
            const SizedBox(width: 10),
            Expanded(child: _buildActionCard(context, cs, actions[3], 3)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, ColorScheme cs, _ActionItem item, int index) {
    final delay = index * 80;
    return AnimatedContainer(
      duration: Duration(milliseconds: 400 + delay),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, _animated ? 0 : 30, 0)..scaleByDouble(1.0, _animated ? 1.0 : 0.95, 1.0, 1.0),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: item.color, size: 28),
                ),
                const SizedBox(height: 12),
                Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(item.subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, ColorScheme cs, PassLog log, int index) {
    final isEntry = log.action == 'ENTRY';
    final isReject = log.action == 'REJECTED';
    final color = isReject ? cs.error : (isEntry ? Colors.green : cs.tertiary);
    final icon = isReject ? Icons.block_rounded : (isEntry ? Icons.login_rounded : Icons.logout_rounded);

    final delay = index * 60;
    return AnimatedContainer(
      duration: Duration(milliseconds: 350 + delay),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(_animated ? 0 : 20, 0, 0),
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            '${log.action} — ${log.passId}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            DateFormat.yMd().add_jm().format(log.timestamp),
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: log.valid ? Colors.green.withValues(alpha: 0.08) : cs.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              log.valid ? 'VALID' : 'INVALID',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: log.valid ? Colors.green : cs.error),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyActivity(BuildContext context, ColorScheme cs) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inbox_rounded, size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
              ),
              const SizedBox(height: 12),
              Text('No activity yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('Scan passes to see activity here', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionItem(this.icon, this.label, this.subtitle, this.color, this.onTap);
}
