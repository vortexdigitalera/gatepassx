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

class _IssuePassScreenState extends State<IssuePassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _eventCtrl = TextEditingController(text: 'Annual Dinner');
  final _organizerCtrl = TextEditingController(text: 'Event Organizer');
  final _gateCtrl = TextEditingController(text: 'Main Gate');
  final _tableCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();

  PassCategory _category = PassCategory.GUEST;
  EventType _eventType = EventType.DINNER;
  DateTime _validFrom = DateTime.now();
  DateTime _validTo = DateTime.now().add(const Duration(days: 1));
  GatePass? _generatedPass;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _idCtrl, _phoneCtrl, _emailCtrl, _eventCtrl, _organizerCtrl, _gateCtrl, _tableCtrl, _groupCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generateAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    final pass = GatePass(
      passId: 'GPX-${_eventType.name}-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      eventName: _eventCtrl.text.trim().isEmpty ? 'General Event' : _eventCtrl.text.trim(),
      eventType: _eventType,
      category: _category,
      fullName: _nameCtrl.text.trim(),
      idNumber: _idCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      organizer: _organizerCtrl.text.trim(),
      validFrom: _validFrom,
      validTo: _validTo,
      gate: _gateCtrl.text.trim().isEmpty ? null : _gateCtrl.text.trim(),
      tableNumber: _tableCtrl.text.trim().isEmpty ? null : _tableCtrl.text.trim(),
      groupRef: _groupCtrl.text.trim().isEmpty ? null : _groupCtrl.text.trim(),
      issuedBy: 'DePass Mobile',
    );
    pass.computeQrPayload(secret: AppConfig.qrSecret);

    await widget.onSave(pass);
    setState(() => _generatedPass = pass);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pass saved successfully')));
    }
  }

  Future<void> _shareQr() async {
    if (_generatedPass?.qrPayload == null) return;
    await SharePlus.instance.share(ShareParams(
      text: 'DePass\nID: ${_generatedPass!.passId}\nName: ${_generatedPass!.fullName}\nEvent: ${_generatedPass!.eventName}\nQR: ${_generatedPass!.qrPayload}',
    ));
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _validFrom : _validTo,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _validFrom = picked;
          if (_validTo.isBefore(_validFrom)) _validTo = _validFrom.add(const Duration(days: 1));
        } else {
          _validTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Event details
            _SectionLabel(text: 'EVENT DETAILS', cs: cs),
            const SizedBox(height: 8),
            TextFormField(
              controller: _eventCtrl,
              decoration: InputDecoration(labelText: 'Event Name', hintText: 'e.g. Annual Gala Dinner', prefixIcon: const Icon(Icons.celebration_outlined)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<EventType>(
              initialValue: _eventType,
              decoration: const InputDecoration(labelText: 'Event Type', prefixIcon: Icon(Icons.event_outlined)),
              items: EventType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
              onChanged: (v) => setState(() => _eventType = v!),
            ),
            const SizedBox(height: 20),

            // Guest details
            _SectionLabel(text: 'GUEST DETAILS', cs: cs),
            const SizedBox(height: 8),
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null, textCapitalization: TextCapitalization.words),
            const SizedBox(height: 12),
            TextFormField(controller: _idCtrl, decoration: const InputDecoration(labelText: 'ID / Registration Number', prefixIcon: Icon(Icons.assignment_ind_outlined)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 20),

            // Category
            _SectionLabel(text: 'PASS TYPE', cs: cs),
            const SizedBox(height: 8),
            DropdownButtonFormField<PassCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
              items: PassCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 20),

            // Organization
            _SectionLabel(text: 'ORGANIZATION', cs: cs),
            const SizedBox(height: 8),
            TextFormField(controller: _organizerCtrl, decoration: const InputDecoration(labelText: 'Organizer', prefixIcon: Icon(Icons.business_outlined))),
            const SizedBox(height: 12),
            TextFormField(controller: _gateCtrl, decoration: const InputDecoration(labelText: 'Gate / Entrance', prefixIcon: Icon(Icons.location_on_outlined))),
            const SizedBox(height: 20),

            // Dates
            _SectionLabel(text: 'VALIDITY PERIOD', cs: cs),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _DateField(label: 'From', date: _validFrom, onTap: () => _pickDate(true))),
                const SizedBox(width: 12),
                Expanded(child: _DateField(label: 'To', date: _validTo, onTap: () => _pickDate(false))),
              ],
            ),
            const SizedBox(height: 20),

            // Seating
            _SectionLabel(text: 'SEATING & REFERENCES', cs: cs),
            const SizedBox(height: 8),
            TextFormField(controller: _tableCtrl, decoration: const InputDecoration(labelText: 'Table / Seat Number', prefixIcon: Icon(Icons.table_restaurant_outlined))),
            const SizedBox(height: 12),
            TextFormField(controller: _groupCtrl, decoration: const InputDecoration(labelText: 'Group / Invite Reference', prefixIcon: Icon(Icons.confirmation_number_outlined))),
            const SizedBox(height: 24),

            // Generate button
            FilledButton.icon(
              onPressed: _generateAndSave,
              icon: const Icon(Icons.qr_code_2_rounded, size: 22),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('Generate & Save Pass', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),

            // Generated pass card
            if (_generatedPass != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Chip(label: Text(_generatedPass!.category.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), visualDensity: VisualDensity.compact),
                          const Spacer(),
                          Text(_generatedPass!.passId, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_generatedPass!.eventName, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(_generatedPass!.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(_generatedPass!.idNumber, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                      if (_generatedPass!.tableNumber != null) ...[
                        const SizedBox(height: 4),
                        Text('Table: ${_generatedPass!.tableNumber}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.primary)),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                        child: QrImageView(
                          data: _generatedPass!.qrPayload ?? _generatedPass!.computeQrPayload(secret: AppConfig.qrSecret),
                          version: QrVersions.auto,
                          size: 170,
                          eyeStyle: QrEyeStyle(color: cs.primary),
                          dataModuleStyle: QrDataModuleStyle(color: cs.primary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Valid: ${_generatedPass!.formattedValidity}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _shareQr,
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share Pass'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _SectionLabel({required this.text, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
