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
  final _operatorCtrl = TextEditingController(text: 'Al-Mufid Travels');
  final _gateCtrl = TextEditingController(text: 'Lagos Hajj Camp Gate A');
  final _groupCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();

  PassCategory _category = PassCategory.PILGRIM;
  TripType? _tripType = TripType.HAJJ;
  DateTime _validFrom = DateTime.now();
  DateTime _validTo = DateTime.now().add(const Duration(days: 25));

  GatePass? _generatedPass;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _phoneCtrl.dispose();
    _operatorCtrl.dispose();
    _gateCtrl.dispose();
    _groupCtrl.dispose();
    _vehicleCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    final pass = GatePass(
      passId: 'AHUON-${_tripType?.name ?? "GEN"}-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      category: _category,
      fullName: _nameCtrl.text.trim(),
      idNumber: _idCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      operator: _operatorCtrl.text.trim(),
      tripType: _tripType,
      validFrom: _validFrom,
      validTo: _validTo,
      gate: _gateCtrl.text.trim().isEmpty ? null : _gateCtrl.text.trim(),
      groupRef: _groupCtrl.text.trim().isEmpty ? null : _groupCtrl.text.trim(),
      vehiclePlate: _vehicleCtrl.text.trim().isEmpty ? null : _vehicleCtrl.text.trim(),
      issuedBy: 'Mobile - GatePassX',
    );
    pass.computeQrPayload(secret: AppConfig.qrSecret);

    await widget.onSave(pass);

    setState(() {
      _generatedPass = pass;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pass saved locally')));
    }
  }

  Future<void> _shareQr() async {
    if (_generatedPass?.qrPayload == null) return;
    await Share.share(
      'AHUON Gate Pass\nID: ${_generatedPass!.passId}\nName: ${_generatedPass!.fullName}\nQR: ${_generatedPass!.qrPayload}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Issue New Gate Pass', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _idCtrl,
              decoration: const InputDecoration(labelText: 'Passport / NIN / Plate *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<PassCategory>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: PassCategory.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<TripType?>(
                  value: _tripType,
                  decoration: const InputDecoration(labelText: 'Trip Type', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('-')),
                    ...TripType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  ],
                  onChanged: (v) => setState(() => _tripType = v),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _operatorCtrl,
              decoration: const InputDecoration(labelText: 'Operator (AHUON member)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  initialValue: DateFormat('yyyy-MM-dd').format(_validFrom),
                  decoration: const InputDecoration(labelText: 'Valid From (YYYY-MM-DD)', border: OutlineInputBorder()),
                  onChanged: (v) {
                    try { _validFrom = DateTime.parse(v); } catch (_) {}
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: DateFormat('yyyy-MM-dd').format(_validTo),
                  decoration: const InputDecoration(labelText: 'Valid To (YYYY-MM-DD)', border: OutlineInputBorder()),
                  onChanged: (v) {
                    try { _validTo = DateTime.parse(v); } catch (_) {}
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextFormField(controller: _gateCtrl, decoration: const InputDecoration(labelText: 'Gate / Checkpoint', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextFormField(controller: _groupCtrl, decoration: const InputDecoration(labelText: 'Group / Flight / Bus Ref', border: OutlineInputBorder())),
            if (_category == PassCategory.VEHICLE) ...[
              const SizedBox(height: 12),
              TextFormField(controller: _vehicleCtrl, decoration: const InputDecoration(labelText: 'Vehicle Plate', border: OutlineInputBorder())),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _generateAndSave,
              icon: const Icon(Icons.qr_code),
              label: const Text('Generate & Save Pass'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006400),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (_generatedPass != null) ...[
              const SizedBox(height: 24),
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(_generatedPass!.passId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(_generatedPass!.fullName),
                      const SizedBox(height: 12),
                      QrImageView(
                        data: _generatedPass!.qrPayload ?? _generatedPass!.computeQrPayload(secret: AppConfig.qrSecret),
                        version: QrVersions.auto,
                        size: 180,
                      ),
                      const SizedBox(height: 8),
                      Text('Valid: ${_generatedPass!.formattedValidity}'),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _shareQr,
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('JSON can be exported from Passes tab and fed to Python generator for PDF'))
                              );
                            },
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('High-Quality PDF via Python'),
                          ),
                        ],
                      )
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
