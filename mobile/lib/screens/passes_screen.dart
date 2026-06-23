import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/gate_pass.dart';

class PassesScreen extends StatefulWidget {
  final List<GatePass> passes;
  final Future<void> Function(PassLog) onAddLog;
  const PassesScreen({super.key, required this.passes, required this.onAddLog});

  @override
  State<PassesScreen> createState() => _PassesScreenState();
}

class _PassesScreenState extends State<PassesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GatePass> get _filtered {
    if (_query.isEmpty) return widget.passes;
    final q = _query.toLowerCase();
    return widget.passes.where((p) =>
      p.passId.toLowerCase().contains(q) ||
      p.fullName.toLowerCase().contains(q) ||
      p.idNumber.toLowerCase().contains(q) ||
      p.organizer.toLowerCase().contains(q) ||
      p.eventName.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (widget.passes.isEmpty) {
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
              child: Icon(Icons.badge_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 16),
            Text('No passes yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text('Use Issue tab or Import button', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
          ],
        ),
      );
    }

    final filtered = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: SearchBar(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            hintText: 'Search passes...',
            leading: const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Icon(Icons.search_rounded, size: 24),
            ),
            trailing: _query.isNotEmpty
                ? [IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 22),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  )]
                : null,
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${filtered.length} pass${filtered.length == 1 ? '' : 'es'}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('No matches found', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _buildPassCard(context, cs, filtered[i], i),
                ),
        ),
      ],
    );
  }

  Widget _buildPassCard(BuildContext context, ColorScheme cs, GatePass pass, int index) {
    final isValid = pass.validTo.isAfter(DateTime.now());
    final statusColor = isValid ? Colors.green : cs.error;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (ctx, val, child) => Transform.translate(
        offset: Offset(0, (1 - val) * 20),
        child: Opacity(opacity: val, child: child),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showDetails(context, pass, cs, isValid),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      pass.category.name[0],
                      style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w800, fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pass.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text(pass.passId, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontFamily: 'monospace')),
                      Text('${pass.eventName} • ${pass.category.name}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isValid ? 'VALID' : 'EXPIRED',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, GatePass pass, ColorScheme cs, bool isValid) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  color: isValid ? cs.primaryContainer : cs.errorContainer,
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.elasticOut,
                        builder: (_, val, child) => Transform.scale(scale: val, child: child),
                        child: Icon(
                          isValid ? Icons.verified_rounded : Icons.cancel_rounded,
                          color: isValid ? cs.onPrimaryContainer : cs.onErrorContainer,
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isValid ? 'ACTIVE PASS' : 'EXPIRED PASS',
                        style: TextStyle(
                          color: isValid ? cs.onPrimaryContainer : cs.onErrorContainer,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(pass.eventName, style: TextStyle(color: (isValid ? cs.onPrimaryContainer : cs.onErrorContainer).withValues(alpha: 0.7), fontSize: 13)),
                      Text(pass.passId, style: TextStyle(color: (isValid ? cs.onPrimaryContainer : cs.onErrorContainer).withValues(alpha: 0.6), fontSize: 11, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                if (pass.qrPayload != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: QrImageView(
                        data: pass.qrPayload!,
                        version: QrVersions.auto,
                        size: 150,
                        eyeStyle: QrEyeStyle(color: cs.primary, eyeShape: QrEyeShape.circle),
                        dataModuleStyle: QrDataModuleStyle(color: cs.primary, dataModuleShape: QrDataModuleShape.circle),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    children: [
                      _detailRow(Icons.event_rounded, 'Event', pass.eventName, cs),
                      _detailRow(Icons.person_rounded, 'Name', pass.fullName, cs),
                      _detailRow(Icons.assignment_ind_rounded, 'ID', pass.idNumber, cs),
                      _detailRow(Icons.category_rounded, 'Category', pass.category.name, cs),
                      if (pass.phone != null && pass.phone!.isNotEmpty) _detailRow(Icons.phone_rounded, 'Phone', pass.phone!, cs),
                      if (pass.email != null && pass.email!.isNotEmpty) _detailRow(Icons.email_rounded, 'Email', pass.email!, cs),
                      _detailRow(Icons.business_rounded, 'Organizer', pass.organizer, cs),
                      if (pass.gate != null && pass.gate!.isNotEmpty) _detailRow(Icons.location_on_rounded, 'Gate', pass.gate!, cs),
                      if (pass.tableNumber != null && pass.tableNumber!.isNotEmpty) _detailRow(Icons.table_restaurant_rounded, 'Table', pass.tableNumber!, cs),
                      _detailRow(Icons.date_range_rounded, 'Valid', pass.formattedValidity, cs),
                      _detailRow(Icons.event_rounded, 'Type', pass.eventType.name, cs),
                      if (pass.groupRef != null && pass.groupRef!.isNotEmpty) _detailRow(Icons.confirmation_number_rounded, 'Ref', pass.groupRef!, cs),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('CLOSE'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await widget.onAddLog(PassLog(passId: pass.passId, action: 'ENTRY', gate: pass.gate, valid: isValid));
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.login_rounded, size: 20),
                          label: const Text('Log ENTRY'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 68, child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
