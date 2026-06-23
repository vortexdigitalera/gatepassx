import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
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

const _fallbackSeed = Color(0xFF1A1A2E);

ThemeData _buildTheme(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      indicatorColor: scheme.secondaryContainer,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

void main() {
  runApp(const GatePassXApp());
}

class GatePassXApp extends StatelessWidget {
  const GatePassXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightScheme = (lightDynamic ?? ColorScheme.fromSeed(seedColor: _fallbackSeed, brightness: Brightness.light)).harmonized();
        final darkScheme = (darkDynamic ?? ColorScheme.fromSeed(seedColor: _fallbackSeed, brightness: Brightness.dark)).harmonized();

        return MaterialApp(
          title: 'DePass',
          theme: _buildTheme(lightScheme),
          darkTheme: _buildTheme(darkScheme),
          themeMode: ThemeMode.system,
          home: const GatePassHome(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class GatePassHome extends StatefulWidget {
  const GatePassHome({super.key});

  @override
  State<GatePassHome> createState() => _GatePassHomeState();
}

class _GatePassHomeState extends State<GatePassHome> {
  static const _scanIndex = 3;

  int _currentIndex = 0;
  final storage = PassStorage();

  List<GatePass> _passes = [];
  List<PassLog> _logs = [];
  bool _loading = true;

  bool get _isScanner => _currentIndex == _scanIndex;

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
    final result = await FilePicker.pickFiles(
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
    final file = File('${dir.path}/gatepassx_export_${DateTime.now().millisecondsSinceEpoch}.json');
    final data = _passes.map((p) => p.toJson()).toList();
    await file.writeAsString(jsonEncode({'passes': data, 'exported_at': DateTime.now().toIso8601String()}));
    await SharePlus.instance.share(ShareParams(text: 'Exported DePass JSON to ${file.path}'));
  }

  void _onTabChange(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      appBar: _isScanner
          ? null
          : AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.confirmation_number_outlined, size: 20, color: cs.onPrimary),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      Text('DePass', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: cs.onPrimary)),
                      Text('EVENT GATE PASS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w300, letterSpacing: 1.5, color: cs.onPrimary.withValues(alpha: 0.7))),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(icon: const Icon(Icons.file_download_outlined), tooltip: 'Import', onPressed: _importPasses),
                IconButton(icon: const Icon(Icons.upload_outlined), tooltip: 'Export', onPressed: _passes.isEmpty ? null : _exportAll),
                IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh', onPressed: _loadData),
              ],
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentIndex,
              children: [
                DashboardScreen(passes: _passes, logs: _logs, onRefresh: _loadData),
                IssuePassScreen(onSave: _savePass),
                PassesScreen(passes: _passes, onAddLog: _addLog),
                ScannerScreen(onAddLog: _addLog, knownPasses: _passes),
                LogsScreen(logs: _logs),
              ],
            ),
      bottomNavigationBar: _isScanner
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _onTabChange,
                  height: 64,
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
                    NavigationDestination(icon: Icon(Icons.add_card_outlined), selectedIcon: Icon(Icons.add_card), label: 'Issue'),
                    NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Passes'),
                    NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded), selectedIcon: Icon(Icons.qr_code_scanner), label: 'Scan'),
                    NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Logs'),
                  ],
                ),
              ),
            ),
      floatingActionButton: _currentIndex == 2
          ? FloatingActionButton.extended(
              onPressed: () => _onTabChange(1),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Pass'),
            )
          : null,
    );
  }
}
