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
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

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
            Icon(Icons.folder_open_outlined, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No passes yet', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Use Issue tab or Import button', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
          ],
        ),
      );
    }

    final filtered = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SearchBar(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            hintText: 'Search passes...',
            leading: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.search_rounded)),
            trailing: _query.isNotEmpty
                ? [IconButton(icon: const Icon(Icons.clear_rounded, size: 20), onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); })]
                : null,
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
            elevation: const WidgetStatePropertyAll(0),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          child: Align(alignment: Alignment.centerLeft, child: Text('${filtered.length} pass(es)', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('No matches', style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _PassCard(pass: filtered[i], onAddLog: widget.onAddLog),
                ),
        ),
      ],
    );
  }
}

class _PassCard extends StatelessWidget {
  final GatePass pass;
  final Future<void> Function(PassLog) onAddLog;
  const _PassCard({required this.pass, required this.onAddLog});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isValid = pass.validTo.isAfter(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Text(pass.category.name[0], style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pass.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(pass.passId, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    Text('${pass.eventName} • ${pass.category.name}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              Chip(
                label: Text(isValid ? 'VALID' : 'EXPIRED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isValid ? Colors.green : cs.error)),
                backgroundColor: isValid ? Colors.green.withValues(alpha: 0.08) : cs.error.withValues(alpha: 0.08),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isValid = pass.validTo.isAfter(DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                color: isValid ? cs.primaryContainer : cs.errorContainer,
                child: Column(
                  children: [
                    Icon(isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: isValid ? cs.onPrimaryContainer : cs.onErrorContainer, size: 48),
                    const SizedBox(height: 8),
                    Text(isValid ? 'ACTIVE PASS' : 'EXPIRED PASS',
                        style: TextStyle(color: isValid ? cs.onPrimaryContainer : cs.onErrorContainer, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(pass.eventName, style: TextStyle(color: (isValid ? cs.onPrimaryContainer : cs.onErrorContainer).withValues(alpha: 0.7), fontSize: 12)),
                    Text(pass.passId, style: TextStyle(color: (isValid ? cs.onPrimaryContainer : cs.onErrorContainer).withValues(alpha: 0.8), fontSize: 11)),
                  ],
                ),
              ),
              if (pass.qrPayload != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                    child: QrImageView(
                      data: pass.qrPayload!, version: QrVersions.auto, size: 140,
                      eyeStyle: QrEyeStyle(color: cs.primary),
                      dataModuleStyle: QrDataModuleStyle(color: cs.primary),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  children: [
                    _detailRow(Icons.event_outlined, 'Event', pass.eventName, cs),
                    _detailRow(Icons.person_outline, 'Name', pass.fullName, cs),
                    _detailRow(Icons.assignment_ind_outlined, 'ID', pass.idNumber, cs),
                    _detailRow(Icons.category_outlined, 'Category', pass.category.name, cs),
                    if (pass.phone != null && pass.phone!.isNotEmpty) _detailRow(Icons.phone_outlined, 'Phone', pass.phone!, cs),
                    if (pass.email != null && pass.email!.isNotEmpty) _detailRow(Icons.email_outlined, 'Email', pass.email!, cs),
                    _detailRow(Icons.business_outlined, 'Organizer', pass.organizer, cs),
                    if (pass.gate != null && pass.gate!.isNotEmpty) _detailRow(Icons.location_on_outlined, 'Gate', pass.gate!, cs),
                    if (pass.tableNumber != null && pass.tableNumber!.isNotEmpty) _detailRow(Icons.table_restaurant_outlined, 'Table', pass.tableNumber!, cs),
                    _detailRow(Icons.date_range_outlined, 'Valid', pass.formattedValidity, cs),
                    _detailRow(Icons.event_outlined, 'Type', pass.eventType.name, cs),
                    if (pass.groupRef != null && pass.groupRef!.isNotEmpty) _detailRow(Icons.confirmation_number_outlined, 'Ref', pass.groupRef!, cs),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE'))),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await onAddLog(PassLog(passId: pass.passId, action: 'ENTRY', gate: pass.gate, valid: isValid));
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Log ENTRY'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(width: 68, child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
