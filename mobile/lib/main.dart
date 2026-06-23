import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/gate_pass.dart';
import 'services/pass_storage.dart';
import 'screens/dashboard_screen.dart';
import 'screens/issue_pass_screen.dart';
import 'screens/passes_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/logs_screen.dart';

const _seed = Color(0xFF006B5E);

ThemeData _buildTheme(Brightness brightness, ColorScheme? dynamic) {
  final scheme = (dynamic ?? ColorScheme.fromSeed(seedColor: _seed, brightness: brightness)).harmonized();

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: GoogleFonts.inter().fontFamily,
    textTheme: GoogleFonts.interTextTheme(brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme),
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 80,
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: const CircleBorder(),
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 4,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final themeIndex = prefs.getInt('theme_mode') ?? 0;
  runApp(GatePassXApp(initialTheme: ThemeMode.values[themeIndex]));
}

class GatePassXApp extends StatefulWidget {
  final ThemeMode initialTheme;
  const GatePassXApp({super.key, required this.initialTheme});

  @override
  State<GatePassXApp> createState() => _GatePassXAppState();
}

class _GatePassXAppState extends State<GatePassXApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialTheme;
  }

  void _setTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? light, ColorScheme? dark) {
        return MaterialApp(
          title: 'DePass',
          theme: _buildTheme(Brightness.light, light),
          darkTheme: _buildTheme(Brightness.dark, dark),
          themeMode: _themeMode,
          home: GatePassHome(onThemeChanged: _setTheme, themeMode: _themeMode),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// ── Lazy IndexedStack ──

class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const LazyIndexedStack({super.key, required this.index, required this.children});

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late List<bool> _activated;

  @override
  void initState() {
    super.initState();
    _activated = List.generate(widget.children.length, (i) => i == widget.index);
  }

  @override
  void didUpdateWidget(LazyIndexedStack old) {
    super.didUpdateWidget(old);
    if (_activated.length != widget.children.length) {
      _activated = List.generate(widget.children.length, (i) => i == widget.index);
    }
    _activated[widget.index] = true;
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: List.generate(widget.children.length, (i) => _activated[i] ? widget.children[i] : const SizedBox.shrink()),
    );
  }
}

// ── App Shell ──

class GatePassHome extends StatefulWidget {
  final ValueChanged<ThemeMode> onThemeChanged;
  final ThemeMode themeMode;
  const GatePassHome({super.key, required this.onThemeChanged, required this.themeMode});

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
    try {
      final passes = await storage.loadPasses();
      final logs = await storage.loadLogs();
      setState(() { _passes = passes; _logs = logs; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) _snack('Failed to load: $e');
    }
  }

  Future<void> _savePass(GatePass pass) async {
    await storage.addOrUpdatePass(pass);
    await _loadData();
  }

  Future<void> _addLog(PassLog log) async {
    await storage.addLog(log);
    await _loadData();
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => ScannerScreen(
        onAddLog: _addLog,
        knownPasses: _passes,
        onUpdatePass: _savePass,
      ),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 250),
    ));
  }

  Future<void> _importPasses() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json', 'csv'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    String content = utf8.decode(bytes);
    List<GatePass> imported = [];

    if (file.extension?.toLowerCase() == 'json') {
      try {
        final decoded = jsonDecode(content);
        final list = decoded is List ? decoded : (decoded['passes'] ?? []);
        imported = list.map<GatePass>((e) => GatePass.fromJson(e)).toList();
      } catch (e) {
        if (mounted) _snack('Import failed: invalid JSON');
        return;
      }
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
        try { imported.add(GatePass.fromJson(map)); } catch (_) {}
      }
    }

    for (final p in imported) { await storage.addOrUpdatePass(p); }
    await _loadData();
    if (mounted) _snack('Imported ${imported.length} pass(es)');
  }

  Future<void> _exportAll() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/depass_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonEncode({'passes': _passes.map((p) => p.toJson()).toList(), 'exported_at': DateTime.now().toIso8601String()}));
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'DePass export'));
      if (mounted) _snack('Export ready');
    } catch (e) {
      if (mounted) _snack('Export failed: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  IconData _themeIcon() {
    switch (widget.themeMode) {
      case ThemeMode.light: return Icons.light_mode;
      case ThemeMode.dark: return Icons.dark_mode;
      case ThemeMode.system: return Icons.brightness_auto;
    }
  }

  void _cycleTheme() {
    final next = ThemeMode.values[(widget.themeMode.index + 1) % 3];
    widget.onThemeChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentIndex != 0) setState(() => _currentIndex = 0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('DePass', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
          actions: [
            IconButton(icon: Icon(_themeIcon()), tooltip: 'Theme', onPressed: _cycleTheme),
            IconButton(icon: const Icon(Icons.download_rounded), tooltip: 'Import', onPressed: _importPasses),
            IconButton(icon: const Icon(Icons.publish_rounded), tooltip: 'Export', onPressed: _passes.isEmpty ? null : _exportAll),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : LazyIndexedStack(
                index: _currentIndex,
                children: [
                  DashboardScreen(passes: _passes, logs: _logs, onRefresh: _loadData, onNavigate: (i) => setState(() => _currentIndex = i), onImport: _importPasses, onExport: _exportAll, onScan: _openScanner),
                  IssuePassScreen(onSave: _savePass),
                  PassesScreen(passes: _passes, onAddLog: _addLog, onUpdatePass: _savePass),
                  LogsScreen(logs: _logs),
                ],
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.note_add_outlined), selectedIcon: Icon(Icons.note_add), label: 'Issue'),
            NavigationDestination(icon: Icon(Icons.app_registration_outlined), selectedIcon: Icon(Icons.app_registration), label: 'Passes'),
            NavigationDestination(icon: Icon(Icons.history_toggle_off_outlined), selectedIcon: Icon(Icons.history_toggle_off), label: 'Logs'),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: SizedBox(
          width: 64,
          height: 64,
          child: FloatingActionButton(
            onPressed: _openScanner,
            tooltip: 'Scan QR',
            child: const Icon(Icons.qr_code_2, size: 30),
          ),
        ),
      ),
    );
  }
}
