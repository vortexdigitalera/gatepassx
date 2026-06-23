import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/gate_pass.dart';
import '../services/config.dart';

class IssuePassScreen extends StatefulWidget {
  final Future<void> Function(GatePass) onSave;
  const IssuePassScreen({super.key, required this.onSave});

  @override
  State<IssuePassScreen> createState() => _IssuePassScreenState();
}

class _IssuePassScreenState extends State<IssuePassScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _eventCtrl = TextEditingController(text: 'Annual Dinner');
  final _orgCtrl = TextEditingController(text: 'Event Organizer');
  final _gateCtrl = TextEditingController(text: 'Main Gate');
  final _tableCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();

  PassCategory _category = PassCategory.GUEST;
  EventType _eventType = EventType.DINNER;
  DateTime _validFrom = DateTime.now();
  DateTime _validTo = DateTime.now().add(const Duration(days: 1));
  GatePass? _generatedPass;
  bool _saving = false;

  late final AnimationController _cardCtrl;
  late final Animation<double> _cardAnim;

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _cardAnim = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    for (final c in [_nameCtrl, _idCtrl, _phoneCtrl, _emailCtrl, _eventCtrl, _orgCtrl, _gateCtrl, _tableCtrl, _groupCtrl]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _generateAndSave() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    final pass = GatePass(
      passId: 'GPX-${_eventType.name}-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      eventName: _eventCtrl.text.trim().isEmpty ? 'General Event' : _eventCtrl.text.trim(),
      eventType: _eventType, category: _category,
      fullName: _nameCtrl.text.trim(), idNumber: _idCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      organizer: _orgCtrl.text.trim(), validFrom: _validFrom, validTo: _validTo,
      gate: _gateCtrl.text.trim().isEmpty ? null : _gateCtrl.text.trim(),
      tableNumber: _tableCtrl.text.trim().isEmpty ? null : _tableCtrl.text.trim(),
      groupRef: _groupCtrl.text.trim().isEmpty ? null : _groupCtrl.text.trim(),
      issuedBy: 'DePass Mobile',
    );
    pass.computeQrPayload(secret: AppConfig.qrSecret);
    await widget.onSave(pass);
    if (!mounted) return;
    setState(() { _generatedPass = pass; _saving = false; });
    _cardCtrl.forward(from: 0);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pass saved'), behavior: SnackBarBehavior.floating));
  }

  Future<void> _shareQr() async {
    if (_generatedPass?.qrPayload == null) return;
    await SharePlus.instance.share(ShareParams(text: 'DePass\nID: ${_generatedPass!.passId}\nName: ${_generatedPass!.fullName}\nEvent: ${_generatedPass!.eventName}'));
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(context: context, initialDate: isFrom ? _validFrom : _validTo, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) {
      setState(() {
        if (isFrom) { _validFrom = picked; if (_validTo.isBefore(_validFrom)) _validTo = _validFrom.add(const Duration(days: 1)); }
        else { _validTo = picked; }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _section(tt, 'EVENT DETAILS', [
            TextFormField(controller: _eventCtrl, decoration: const InputDecoration(labelText: 'Event Name', prefixIcon: Icon(Icons.celebration_outlined)), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<EventType>(initialValue: _eventType, decoration: const InputDecoration(labelText: 'Event Type', prefixIcon: Icon(Icons.celebration_outlined)), items: EventType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(), onChanged: (v) => setState(() => _eventType = v!)),
          ]),
          const SizedBox(height: 20),
          _section(tt, 'GUEST DETAILS', [
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null, textCapitalization: TextCapitalization.words),
            const SizedBox(height: 12),
            TextFormField(controller: _idCtrl, decoration: const InputDecoration(labelText: 'ID Number', prefixIcon: Icon(Icons.fingerprint_outlined)), validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.call_outlined)), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_outlined)), keyboardType: TextInputType.emailAddress),
          ]),
          const SizedBox(height: 20),
          _section(tt, 'PASS TYPE', [
            DropdownButtonFormField<PassCategory>(initialValue: _category, decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.label_outlined)), items: PassCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(), onChanged: (v) => setState(() => _category = v!)),
          ]),
          const SizedBox(height: 20),
          _section(tt, 'ORGANIZATION', [
            TextFormField(controller: _orgCtrl, decoration: const InputDecoration(labelText: 'Organizer', prefixIcon: Icon(Icons.apartment_outlined))),
            const SizedBox(height: 12),
            TextFormField(controller: _gateCtrl, decoration: const InputDecoration(labelText: 'Gate', prefixIcon: Icon(Icons.meeting_room_outlined))),
          ]),
          const SizedBox(height: 20),
          _section(tt, 'VALIDITY', [
            Row(children: [
              Expanded(child: _dateField(cs, tt, 'From', _validFrom, () => _pickDate(true))),
              const SizedBox(width: 12),
              Expanded(child: _dateField(cs, tt, 'To', _validTo, () => _pickDate(false))),
            ]),
          ]),
          const SizedBox(height: 20),
          _section(tt, 'SEATING & REFERENCES', [
            TextFormField(controller: _tableCtrl, decoration: const InputDecoration(labelText: 'Table / Seat', prefixIcon: Icon(Icons.grid_view_outlined))),
            const SizedBox(height: 12),
            TextFormField(controller: _groupCtrl, decoration: const InputDecoration(labelText: 'Group Reference', prefixIcon: Icon(Icons.confirmation_number_outlined))),
          ]),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _generateAndSave,
            icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.qr_code_2, size: 22),
            label: Text(_saving ? 'Saving...' : 'Generate & Save Pass'),
          ),
          if (_generatedPass != null) ...[
            const SizedBox(height: 24),
            _buildPassCard(cs, tt),
          ],
        ]),
      ),
    );
  }

  Widget _section(TextTheme tt, String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      const SizedBox(height: 10),
      ...children,
    ]);
  }

  Widget _dateField(ColorScheme cs, TextTheme tt, String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(prefixIcon: const Icon(Icons.calendar_today, size: 20), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: tt.labelSmall),
          Text(DateFormat('dd MMM yyyy').format(date), style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildPassCard(ColorScheme cs, TextTheme tt) {
    return ScaleTransition(
      scale: _cardAnim,
      child: FadeTransition(opacity: _cardAnim, child: Card.filled(
        color: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Row(children: [
            Chip(label: Text(_generatedPass!.category.name, style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700))),
            const Spacer(),
            Text(_generatedPass!.passId, style: tt.labelSmall?.copyWith(fontFamily: 'monospace')),
          ]),
          const SizedBox(height: 8),
          Text(_generatedPass!.fullName, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          Text(_generatedPass!.eventName, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)), child: QrImageView(
            data: _generatedPass!.qrPayload ?? '', version: QrVersions.auto, size: 180,
            eyeStyle: QrEyeStyle(color: cs.primary, eyeShape: QrEyeShape.circle),
            dataModuleStyle: QrDataModuleStyle(color: cs.primary, dataModuleShape: QrDataModuleShape.circle),
          )),
          const SizedBox(height: 12),
          Text('Valid: ${_generatedPass!.formattedValidity}', style: tt.bodySmall),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: _shareQr, icon: const Icon(Icons.share, size: 18), label: const Text('Share Pass')),
        ])),
      )),
    );
  }
}
