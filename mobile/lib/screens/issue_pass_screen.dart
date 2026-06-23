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

  final _catColors = {
    PassCategory.PILGRIM: const Color(0xFF1B7A1B),
    PassCategory.STAFF: const Color(0xFF1565C0),
    PassCategory.VEHICLE: const Color(0xFFE65100),
    PassCategory.VISITOR: const Color(0xFF7B1FA2),
    PassCategory.VIP: const Color(0xFFFFB300),
  };

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

    setState(() => _generatedPass = pass);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pass saved successfully'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ));
    }
  }

  Future<void> _shareQr() async {
    if (_generatedPass?.qrPayload == null) return;
    await SharePlus.instance.share(ShareParams(
      text: 'AHUON Gate Pass\nID: ${_generatedPass!.passId}\nName: ${_generatedPass!.fullName}\nQR: ${_generatedPass!.qrPayload}',
    ));
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? _validFrom : _validTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: const Color(0xFF006400)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _validFrom = picked;
          if (_validTo.isBefore(_validFrom)) _validTo = _validFrom.add(const Duration(days: 25));
        } else {
          _validTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _catColors[_category] ?? const Color(0xFF006400);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [catColor.withOpacity(0.1), catColor.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: catColor.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.assignment_outlined, color: catColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Issue New Pass', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('${_category.name} • ${_tripType?.name ?? 'GENERAL'}', style: TextStyle(fontSize: 12, color: catColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Name
            _SectionLabel(text: 'PERSONAL DETAILS'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter full name',
                prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade400),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _idCtrl,
              decoration: InputDecoration(
                labelText: 'Passport / NIN / Plate',
                hintText: 'Enter ID number',
                prefixIcon: Icon(Icons.assignment_ind_outlined, color: Colors.grey.shade400),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g. +234801234567',
                prefixIcon: Icon(Icons.phone_outlined, color: Colors.grey.shade400),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),

            // Category & Trip
            _SectionLabel(text: 'PASS TYPE'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<PassCategory>(
                    value: _category,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Icon(Icons.category_outlined, color: Colors.grey.shade400, size: 20),
                      ),
                    ),
                    items: PassCategory.values.map((c) => DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(color: _catColors[c], shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(c.name),
                        ],
                      ),
                    )).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<TripType?>(
                    value: _tripType,
                    decoration: InputDecoration(
                      labelText: 'Trip',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Icon(Icons.map_outlined, color: Colors.grey.shade400, size: 20),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('-', style: TextStyle(color: Colors.grey))),
                      ...TripType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))),
                    ],
                    onChanged: (v) => setState(() => _tripType = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Operator
            _SectionLabel(text: 'ORGANIZATION'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _operatorCtrl,
              decoration: InputDecoration(
                labelText: 'Operator (AHUON member)',
                prefixIcon: Icon(Icons.business_outlined, color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _gateCtrl,
              decoration: InputDecoration(
                labelText: 'Gate / Checkpoint',
                prefixIcon: Icon(Icons.location_on_outlined, color: Colors.grey.shade400),
              ),
            ),
            const SizedBox(height: 20),

            // Dates
            _SectionLabel(text: 'VALIDITY PERIOD'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'From',
                    date: _validFrom,
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'To',
                    date: _validTo,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Optional fields
            _SectionLabel(text: 'ADDITIONAL INFO'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _groupCtrl,
              decoration: InputDecoration(
                labelText: 'Group / Flight / Bus Ref',
                prefixIcon: Icon(Icons.flight_outlined, color: Colors.grey.shade400),
              ),
            ),
            if (_category == PassCategory.VEHICLE) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _vehicleCtrl,
                decoration: InputDecoration(
                  labelText: 'Vehicle Plate',
                  prefixIcon: Icon(Icons.directions_car_outlined, color: Colors.grey.shade400),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Generate button
            Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: catColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: ElevatedButton.icon(
                onPressed: _generateAndSave,
                icon: const Icon(Icons.qr_code_2_rounded, size: 22),
                label: const Text('Generate & Save Pass', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: catColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

            // Generated pass card
            if (_generatedPass != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF006400).withOpacity(0.15)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_generatedPass!.category.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: catColor)),
                        ),
                        const Spacer(),
                        Text(_generatedPass!.passId, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(_generatedPass!.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(_generatedPass!.idNumber, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: _generatedPass!.qrPayload ?? _generatedPass!.computeQrPayload(secret: AppConfig.qrSecret),
                        version: QrVersions.auto,
                        size: 170,
                        eyeStyle: QrEyeStyle(color: const Color(0xFF004D00)),
                        dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF004D00)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Valid: ${_generatedPass!.formattedValidity}',
                        style: TextStyle(fontSize: 12, color: catColor.withOpacity(0.8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _shareQr,
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF006400),
                            side: const BorderSide(color: Color(0xFF006400)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Use Export in App Bar to get JSON for Python PDF generator'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            ));
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                          label: const Text('PDF Generator'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006400),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
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
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(
          color: const Color(0xFF006400),
          borderRadius: BorderRadius.circular(2),
        )),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600, letterSpacing: 0.5)),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey.shade500),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
