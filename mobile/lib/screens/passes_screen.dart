import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/gate_pass.dart';

class PassesScreen extends StatefulWidget {
  final List<GatePass> passes;
  final Future<void> Function(PassLog) onAddLog;
  final Future<void> Function(GatePass) onUpdatePass;
  const PassesScreen({super.key, required this.passes, required this.onAddLog, required this.onUpdatePass});

  @override
  State<PassesScreen> createState() => _PassesScreenState();
}

class _PassesScreenState extends State<PassesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'all';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<GatePass> get _filtered {
    var list = widget.passes;
    switch (_filter) {
      case 'active': list = list.where((p) => p.isActive).toList();
      case 'notStarted': list = list.where((p) => p.isNotStarted).toList();
      case 'expired': list = list.where((p) => p.isExpired).toList();
      case 'scanned': list = list.where((p) => p.scannedToday).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((p) => p.passId.toLowerCase().contains(q) || p.fullName.toLowerCase().contains(q) || p.idNumber.toLowerCase().contains(q) || p.eventName.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (widget.passes.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.app_registration, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text('No passes yet', style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text('Issue your first pass', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
      ]));
    }

    final filtered = _filtered;

    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: SearchBar(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        hintText: 'Search passes...',
        leading: const Padding(padding: EdgeInsets.only(left: 12), child: Icon(Icons.manage_search, size: 22)),
        trailing: _query.isNotEmpty ? [IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); })] : null,
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
      )),
      SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
        FilterChip(label: const Text('All'), selected: _filter == 'all', onSelected: (_) => setState(() => _filter = 'all')),
        const SizedBox(width: 8),
        FilterChip(label: const Text('Active'), selected: _filter == 'active', onSelected: (_) => setState(() => _filter = 'active')),
        const SizedBox(width: 8),
        FilterChip(label: const Text('Not Started'), selected: _filter == 'notStarted', onSelected: (_) => setState(() => _filter = 'notStarted')),
        const SizedBox(width: 8),
        FilterChip(label: const Text('Expired'), selected: _filter == 'expired', onSelected: (_) => setState(() => _filter = 'expired')),
        const SizedBox(width: 8),
        FilterChip(label: const Text('Scanned'), selected: _filter == 'scanned', onSelected: (_) => setState(() => _filter = 'scanned')),
      ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6), child: Align(alignment: Alignment.centerLeft, child: Text('${filtered.length} pass${filtered.length == 1 ? '' : 'es'}', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)))),
      Expanded(child: filtered.isEmpty
          ? Center(child: Text('No matches', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)))
          : ListView.builder(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), itemCount: filtered.length, itemBuilder: (ctx, i) => _buildCard(cs, tt, filtered[i]))),
    ]);
  }

  Widget _buildCard(ColorScheme cs, TextTheme tt, GatePass pass) {
    final statusColor = pass.isNotStarted ? Colors.orange : pass.isExpired ? cs.error : pass.scannedToday ? cs.tertiary : Colors.green;
    final statusLabel = pass.statusLabel;
    final statusIcon = pass.isNotStarted ? Icons.schedule : pass.isExpired ? Icons.timer_off : pass.scannedToday ? Icons.replay : Icons.check_circle;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetails(pass, cs, tt),
        child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(pass.category.name[0], style: GoogleFonts.inter(color: cs.onPrimaryContainer, fontWeight: FontWeight.w800, fontSize: 20)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pass.fullName, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text(pass.eventName, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            Text(pass.passId, style: tt.labelSmall?.copyWith(fontFamily: 'monospace', color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Badge(label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(statusIcon, size: 12, color: statusColor), const SizedBox(width: 3), Text(statusLabel, style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: statusColor))]), backgroundColor: statusColor.withValues(alpha: 0.08)),
            if (pass.scanCount > 0) ...[const SizedBox(height: 4), Text('${pass.scanCount} scan${pass.scanCount == 1 ? '' : 's'}', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.5)))],
          ]),
        ])),
      ),
    );
  }

  void _showDetails(GatePass pass, ColorScheme cs, TextTheme tt) {
    final isValid = pass.isActive;
    showDialog(context: context, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.of(ctx).size.height * 0.85), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(24), color: isValid ? cs.primaryContainer : cs.errorContainer, child: Column(children: [
          Icon(isValid ? Icons.verified : Icons.cancel, color: isValid ? cs.onPrimaryContainer : cs.onErrorContainer, size: 56),
          const SizedBox(height: 8),
          Text(pass.statusLabel, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: isValid ? cs.onPrimaryContainer : cs.onErrorContainer, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(pass.eventName, style: tt.bodySmall?.copyWith(color: (isValid ? cs.onPrimaryContainer : cs.onErrorContainer).withValues(alpha: 0.7))),
        ])),
        if (pass.qrPayload != null) Padding(padding: const EdgeInsets.fromLTRB(24, 16, 24, 8), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)), child: QrImageView(data: pass.qrPayload!, version: QrVersions.auto, size: 150, eyeStyle: QrEyeStyle(color: cs.primary, eyeShape: QrEyeShape.circle), dataModuleStyle: QrDataModuleStyle(color: cs.primary, dataModuleShape: QrDataModuleShape.circle)))),
        Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 16), child: Column(children: [
          _row(Icons.celebration, 'Event', pass.eventName, cs, tt),
          _row(Icons.person, 'Name', pass.fullName, cs, tt),
          _row(Icons.fingerprint, 'ID', pass.idNumber, cs, tt),
          _row(Icons.label, 'Category', pass.category.name, cs, tt),
          if (pass.phone != null && pass.phone!.isNotEmpty) _row(Icons.call, 'Phone', pass.phone!, cs, tt),
          _row(Icons.apartment, 'Organizer', pass.organizer, cs, tt),
          if (pass.gate != null && pass.gate!.isNotEmpty) _row(Icons.meeting_room, 'Gate', pass.gate!, cs, tt),
          if (pass.tableNumber != null && pass.tableNumber!.isNotEmpty) _row(Icons.grid_view, 'Table', pass.tableNumber!, cs, tt),
          _row(Icons.calendar_month, 'Valid', pass.formattedValidity, cs, tt),
          _row(Icons.sell, 'Type', pass.eventType.name, cs, tt),
          _row(Icons.pin, 'Scans', '${pass.scanCount}', cs, tt),
          if (pass.lastScannedAt != null) _row(Icons.history_toggle_off, 'Last Scan', DateFormat.yMd().add_jm().format(pass.lastScannedAt!), cs, tt),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton.icon(onPressed: () async {
            await widget.onAddLog(PassLog(passId: pass.passId, action: 'ENTRY', gate: pass.gate, valid: isValid, scanStatus: pass.isActive ? 'valid' : pass.statusLabel.toLowerCase()));
            if (isValid) {
              final updated = GatePass(passId: pass.passId, eventName: pass.eventName, eventType: pass.eventType, category: pass.category, fullName: pass.fullName, idNumber: pass.idNumber, phone: pass.phone, email: pass.email, organizer: pass.organizer, validFrom: pass.validFrom, validTo: pass.validTo, gate: pass.gate, tableNumber: pass.tableNumber, groupRef: pass.groupRef, issuedAt: pass.issuedAt, issuedBy: pass.issuedBy, lastScannedAt: DateTime.now(), scanCount: pass.scanCount + 1)..qrPayload = pass.qrPayload;
              await widget.onUpdatePass(updated);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          }, icon: const Icon(Icons.door_front_door, size: 18), label: const Text('Log ENTRY'))),
        ])),
      ]))),
    ));
  }

  Widget _row(IconData icon, String label, String value, ColorScheme cs, TextTheme tt) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
      Icon(icon, size: 16, color: cs.onSurfaceVariant),
      const SizedBox(width: 10),
      SizedBox(width: 68, child: Text(label, style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant))),
      Expanded(child: Text(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
    ]));
  }
}
