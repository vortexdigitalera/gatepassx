import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/gate_pass.dart';

final _catColors = {
  PassCategory.ATTENDEE: const Color(0xFF1B7A1B),
  PassCategory.VIP: const Color(0xFFFFB300),
  PassCategory.STAFF: const Color(0xFF1565C0),
  PassCategory.SPEAKER: const Color(0xFF7B1FA2),
  PassCategory.MEDIA: const Color(0xFFE65100),
  PassCategory.VENDOR: const Color(0xFF00ACC1),
};

class PassesScreen extends StatefulWidget {
  final List<GatePass> passes;
  final Future<void> Function(PassLog) onAddLog;

  const PassesScreen({super.key, required this.passes, required this.onAddLog});

  @override
  State<PassesScreen> createState() => _PassesScreenState();
}

class _PassesScreenState extends State<PassesScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GatePass> get _filtered {
    if (_searchQuery.isEmpty) return widget.passes;
    final q = _searchQuery.toLowerCase();
    return widget.passes.where((p) =>
      p.passId.toLowerCase().contains(q) ||
      p.fullName.toLowerCase().contains(q) ||
      p.idNumber.toLowerCase().contains(q) ||
      p.operator.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.passes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No passes yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text('Use Issue tab or Import button', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    final filtered = _filtered;

    return Column(
      children: [
        // Search bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search passes...',
              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: Colors.grey.shade400),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Text('${filtered.length} pass(es)', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),

        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('No matches', style: TextStyle(color: Colors.grey.shade500)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return _PassCard(pass: p, onAddLog: widget.onAddLog);
                  },
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
    final isValid = pass.validTo.isAfter(DateTime.now());
    final catColor = _catColors[pass.category] ?? const Color(0xFF006400);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [catColor.withValues(alpha: 0.2), catColor.withValues(alpha: 0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    pass.category.name[0],
                    style: TextStyle(color: catColor, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pass.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(pass.passId, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 2),
                    Text('${pass.operator} • ${pass.category.name}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isValid ? const Color(0xFF2E7D32).withValues(alpha: 0.1) : const Color(0xFFC62828).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                child: Text(
                  isValid ? 'VALID' : 'EXPIRED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isValid ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final catColor = _catColors[pass.category] ?? const Color(0xFF006400);
    final isValid = pass.validTo.isAfter(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isValid
                        ? [const Color(0xFF004D00), const Color(0xFF1B7A1B)]
                        : [const Color(0xFF8B0000), const Color(0xFFC62828)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      isValid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isValid ? 'ACTIVE PASS' : 'EXPIRED PASS',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(pass.passId, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                  ],
                ),
              ),
              // QR
              if (pass.qrPayload != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: pass.qrPayload!,
                      version: QrVersions.auto,
                      size: 140,
                      eyeStyle: const QrEyeStyle(color: Color(0xFF004D00)),
                      dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF004D00)),
                    ),
                  ),
                ),
              ],
              // Info
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Column(
                  children: [
                    _detailRow(Icons.person_outline, 'Name', pass.fullName, catColor),
                    _detailRow(Icons.assignment_ind_outlined, 'ID', pass.idNumber, null),
                    _detailRow(Icons.category_outlined, 'Category', pass.category.name, catColor),
                    if (pass.phone != null && pass.phone!.isNotEmpty)
                      _detailRow(Icons.phone_outlined, 'Phone', pass.phone!, null),
                    _detailRow(Icons.business_outlined, 'Operator', pass.operator, null),
                    if (pass.gate != null && pass.gate!.isNotEmpty)
                      _detailRow(Icons.location_on_outlined, 'Gate', pass.gate!, null),
                    if (pass.groupRef != null && pass.groupRef!.isNotEmpty)
                      _detailRow(Icons.flight_outlined, 'Group', pass.groupRef!, null),
                    _detailRow(Icons.date_range_outlined, 'Valid', pass.formattedValidity, null),
                    if (pass.tripType != null)
                      _detailRow(Icons.map_outlined, 'Trip', pass.tripType!.name, null),
                    if (pass.vehiclePlate != null && pass.vehiclePlate!.isNotEmpty)
                      _detailRow(Icons.directions_car_outlined, 'Vehicle', pass.vehiclePlate!, null),
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
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('CLOSE'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final log = PassLog(
                        passId: pass.passId,
                        action: 'ENTRY',
                        gate: pass.gate,
                        valid: isValid,
                      );
                      await onAddLog(log);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Log ENTRY'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006400),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color? color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey.shade500),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
