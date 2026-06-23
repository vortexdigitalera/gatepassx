import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import 'models/gate_pass.dart';
import 'services/pass_storage.dart';
import 'screens/dashboard_screen.dart';
import 'screens/issue_pass_screen.dart';
import 'screens/passes_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/logs_screen.dart';

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
          seedColor: const Color(0xFF006400),
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
              onPressed: () => setState(() => _currentIndex = 1),
              icon: const Icon(Icons.add),
              label: const Text('New Pass'),
            )
          : null,
    );
  }
}
