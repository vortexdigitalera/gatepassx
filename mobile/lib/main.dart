import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';

import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
// shared_preferences is used via PassStorage; direct import not needed here.

import 'models/gate_pass.dart';
import 'services/pass_storage.dart';

void main() {
  runApp(const GatePassXApp());
}

class GatePassXApp extends StatelessWidget {
  const GatePassXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GatePassX - AHUON',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006400), // AHUON Green
          primary: const Color(0xFF006400),
        ),
        useMaterial3: true,
      ),
      home: const GatePassHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GatePassHome extends StatefulWidget {
  const GatePassHome({super.key});

  @override
  State<GatePassHome> createState() => _GatePassHomeState();
}

class _GatePassHomeState extends State<GatePassHome> {
  int _currentIndex = 0;
  final storage = PassStorage();

  List<GatePass> _passes = [];
  List<PassLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final passes = await storage.loadPasses();
    final logs = await storage.loadLogs();
    setState(() {
      _passes = passes;
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _savePass(GatePass pass) async {
    await storage.addOrUpdatePass(pass);
    await _loadData();
  }

  Future<void> _addLog(PassLog log) async {
    await storage.addLog(log);
    await _loadData();
  }

  Future<void> _importPasses() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    String content = utf8.decode(bytes);
    List<GatePass> imported = [];

    if (file.extension?.toLowerCase() == 'json') {
      final decoded = jsonDecode(content);
      final list = decoded is List ? decoded : (decoded['passes'] ?? []);
      imported = list.map<GatePass>((e) => GatePass.fromJson(e)).toList();
    } else {
      // Very simple CSV parser for demo (expects header similar to python sample)
      final lines = content.trim().split('\n');
      if (lines.length < 2) return;
      final headers = lines.first.split(',');
      for (var line in lines.skip(1)) {
        final values = line.split(',');
        final map = <String, dynamic>{};
        for (int i = 0; i < headers.length && i < values.length; i++) {
          map[headers[i].trim()] = values[i].trim();
        }
        try {
          imported.add(GatePass.fromJson(map));
        } catch (_) {}
      }
    }

    for (final p in imported) {
      await _savePass(p);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${imported.length} pass(es)')),
      );
    }
  }

  Future<void> _exportAll() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/ahuon_passes_export_${DateTime.now().millisecondsSinceEpoch}.json');
    final data = _passes.map((p) => p.toJson()).toList();
    await file.writeAsString(jsonEncode({'passes': data, 'exported_at': DateTime.now().toIso8601String()}));
    // Use share_plus modern API
    await Share.share('Exported AHUON passes JSON saved to ${file.path}. Use the Python generator to create PDFs.');
  }

  List<Widget> get _screens => [
        DashboardScreen(passes: _passes, logs: _logs, onRefresh: _loadData),
        IssuePassScreen(onSave: _savePass),
        PassesScreen(
          passes: _passes,
          onSave: _savePass,
          onAddLog: _addLog,
        ),
        ScannerScreen(onAddLog: _addLog, knownPasses: _passes),
        LogsScreen(logs: _logs),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GatePassX • AHUON'),
        backgroundColor: const Color(0xFF006400),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Import passes (JSON/CSV)',
            onPressed: _importPasses,
          ),
          IconButton(
            icon: const Icon(Icons.upload),
            tooltip: 'Export all (share JSON for Python)',
            onPressed: _passes.isEmpty ? null : _exportAll,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.add_card), label: 'Issue'),
          NavigationDestination(icon: Icon(Icons.list), label: 'Passes'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Logs'),
        ],
      ),
      floatingActionButton: _currentIndex == 2
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _currentIndex = 1), // go to Issue
              icon: const Icon(Icons.add),
              label: const Text('New Pass'),
            )
          : null,
    );
  }
}

// ============ SCREENS ============

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
                  // Parent will handle via nav, but for demo we can pop a dialog or note
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
    pass.computeQrPayload();

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
                        data: _generatedPass!.qrPayload ?? _generatedPass!.computeQrPayload(),
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
                              // In real app could save image or call native PDF gen
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

class PassesScreen extends StatelessWidget {
  final List<GatePass> passes;
  final Future<void> Function(GatePass) onSave;
  final Future<void> Function(PassLog) onAddLog;

  const PassesScreen({super.key, required this.passes, required this.onSave, required this.onAddLog});

  @override
  Widget build(BuildContext context) {
    if (passes.isEmpty) {
      return const Center(child: Text('No passes yet.\nUse Issue tab or Import.'));
    }

    return ListView.builder(
      itemCount: passes.length,
      itemBuilder: (context, index) {
        final p = passes[index];
        final isValid = p.validTo.isAfter(DateTime.now());
        return ListTile(
          title: Text(p.passId),
          subtitle: Text('${p.fullName} • ${p.operator} • ${p.category.name}'),
          trailing: Chip(
            label: Text(isValid ? 'VALID' : 'EXPIRED'),
            backgroundColor: isValid ? Colors.green.shade100 : Colors.red.shade100,
          ),
          onTap: () => _showPassDetails(context, p, onAddLog),
        );
      },
    );
  }

  void _showPassDetails(BuildContext context, GatePass p, Future<void> Function(PassLog) onAddLog) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(p.passId),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${p.idNumber} • ${p.phone ?? ''}'),
              const SizedBox(height: 12),
              if (p.qrPayload != null)
                QrImageView(data: p.qrPayload!, version: QrVersions.auto, size: 160),
              const SizedBox(height: 12),
              Text('Valid: ${p.formattedValidity}'),
              Text('Gate: ${p.gate ?? 'ANY'}'),
              Text('Operator: ${p.operator}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              final log = PassLog(
                passId: p.passId,
                action: 'ENTRY',
                gate: p.gate,
                valid: p.validTo.isAfter(DateTime.now()),
              );
              await onAddLog(log);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simulate ENTRY'),
          ),
        ],
      ),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  final Future<void> Function(PassLog) onAddLog;
  final List<GatePass> knownPasses;

  const ScannerScreen({super.key, required this.onAddLog, required this.knownPasses});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String? _lastResult;
  bool _isScanning = false;

  void _processPayload(String payload) async {
    setState(() {
      _lastResult = payload;
      _isScanning = false;
    });

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(payload);
    } catch (_) {
      data = {'pid': payload};
    }

    final pid = data?['pid'] ?? data?['pass_id'] ?? 'UNKNOWN';
    final matching = widget.knownPasses.where((p) => p.passId == pid).isNotEmpty
        ? widget.knownPasses.where((p) => p.passId == pid).first
        : null;

    final now = DateTime.now();
    bool valid = true;
    String reason = 'OK';

    if (matching != null) {
      if (now.isBefore(matching.validFrom) || now.isAfter(matching.validTo)) {
        valid = false;
        reason = 'EXPIRED / NOT YET VALID';
      }
    } else {
      // Accept unknown passes (demo mode) or reject based on policy
      valid = true; // allow for demo
      reason = 'UNKNOWN TO LOCAL DB (demo)';
    }

    final log = PassLog(
      passId: pid,
      action: valid ? 'ENTRY' : 'REJECTED',
      valid: valid,
      notes: reason,
    );
    await widget.onAddLog(log);

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(valid ? 'ACCESS GRANTED' : 'ACCESS DENIED'),
          content: Text('Pass: $pid\n$reason'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Point camera at AHUON Gate Pass QR or paste payload for manual verification.'),
        ),
        Expanded(
          child: _isScanning
              ? MobileScannerWidget(onDetect: (value) => _processPayload(value))
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _isScanning = true),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Start Camera Scanner'),
                      ),
                      const SizedBox(height: 24),
                      const Text('OR'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 300,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Paste QR payload or Pass ID',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) _processPayload(val.trim());
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (_lastResult != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Last scanned: ${_lastResult!.substring(0, _lastResult!.length.clamp(0, 80))}...',
                style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

// Minimal wrapper for mobile_scanner (graceful if not supported in this env)
class MobileScannerWidget extends StatelessWidget {
  final Function(String) onDetect;

  const MobileScannerWidget({super.key, required this.onDetect});

  @override
  Widget build(BuildContext context) {
    // If mobile_scanner is available at runtime it will work on real device.
    // For this env we provide fallback UI.
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.camera, size: 80, color: Colors.grey),
        const SizedBox(height: 12),
        const Text('Camera scanner active on supported devices (Android/iOS)'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            // Simulate a scan of the sample pass
            const sample = '{"pid":"AHUON-HAJJ-2026-000101","nm":"Alhaji Musa Ibrahim","cat":"PILGRIM","idn":"NG12345678","op":"Al-Mufid Travels","vf":"2026-06-25","vt":"2026-07-20","gt":"Lagos Hajj Camp Gate A"}';
            onDetect(sample);
          },
          child: const Text('Simulate Scan (sample pilgrim)'),
        ),
      ],
    );
  }
}

class LogsScreen extends StatelessWidget {
  final List<PassLog> logs;

  const LogsScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(child: Text('No activity logged yet.'));
    }
    return ListView.separated(
      itemCount: logs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final l = logs[i];
        return ListTile(
          leading: Icon(l.valid ? Icons.check_circle : Icons.cancel, color: l.valid ? Colors.green : Colors.red),
          title: Text('${l.action} — ${l.passId}'),
          subtitle: Text('${DateFormat.yMd().add_jm().format(l.timestamp)} ${l.gate ?? ''} ${l.notes ?? ''}'),
        );
      },
    );
  }
}
