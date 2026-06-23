import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

import 'package:google_fonts/google_fonts.dart';
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

final theme = ThemeData(
  textTheme: GoogleFonts.bricolageGrotesqueTextTheme(),
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF006400),
    primary: const Color(0xFF006400),
    secondary: const Color(0xFFFFB300),
    surface: Colors.white,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFF1F5F9),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    centerTitle: true,
    backgroundColor: Color(0xFF006400),
    foregroundColor: Colors.white,
  ),
  cardTheme: CardThemeData(
    elevation: 2,
    shadowColor: const Color(0xFF006400).withValues(alpha: 0.15),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF006400), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: const Color(0xFF006400),
      foregroundColor: Colors.white,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    elevation: 8,
    shadowColor: Colors.black26,
    indicatorColor: const Color(0xFF006400).withValues(alpha: 0.12),
    backgroundColor: Colors.white,
    labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
  ),
  chipTheme: ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  ),
);

void main() {
  runApp(const GatePassXApp());
}

class GatePassXApp extends StatelessWidget {
  const GatePassXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GatePassX - AHUON',
      theme: theme,
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

class _GatePassHomeState extends State<GatePassHome> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final storage = PassStorage();

  late final AnimationController _fabController;
  late final Animation<double> _fabScale;

  List<GatePass> _passes = [];
  List<PassLog> _logs = [];
  bool _loading = true;

  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabScale = CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack);
    _loadData();
    _fabController.forward();
  }

  @override
  void dispose() {
    _fabController.dispose();
    _pageController.dispose();
    super.dispose();
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
    _fabController.forward(from: 0);
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
        SnackBar(
          content: Text('Imported ${imported.length} pass(es)'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _exportAll() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/ahuon_passes_export_${DateTime.now().millisecondsSinceEpoch}.json');
    final data = _passes.map((p) => p.toJson()).toList();
    await file.writeAsString(jsonEncode({'passes': data, 'exported_at': DateTime.now().toIso8601String()}));
    await SharePlus.instance.share(ShareParams(text: 'Exported AHUON passes JSON saved to ${file.path}. Use the Python generator to create PDFs.'));
  }

  void _onTabChange(int index) {
    setState(() => _currentIndex = index);
    _fabController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.app_registration, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              children: [
                Text('GatePassX', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                Text('AHUON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w300, letterSpacing: 2)),
              ],
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF004D00), Color(0xFF006400), Color(0xFF1B7A1B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          _AppBarAction(
            icon: Icons.file_download_outlined,
            tooltip: 'Import passes',
            onPressed: _importPasses,
          ),
          _AppBarAction(
            icon: Icons.upload_outlined,
            tooltip: 'Export for Python PDF',
            onPressed: _passes.isEmpty ? null : _exportAll,
          ),
          _AppBarAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          const SizedBox(width: 4),
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
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
           boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabChange,
            backgroundColor: Colors.white,
            height: 64,
            destinations: [
              _navDest(icon: Icons.dashboard_rounded, selectedIcon: Icons.dashboard, label: 'Home'),
              _navDest(icon: Icons.add_card_rounded, selectedIcon: Icons.add_card, label: 'Issue'),
              _navDest(icon: Icons.folder_rounded, selectedIcon: Icons.folder, label: 'Passes'),
              _navDest(icon: Icons.qr_code_scanner_rounded, selectedIcon: Icons.qr_code_scanner, label: 'Scan'),
              _navDest(icon: Icons.history_rounded, selectedIcon: Icons.history, label: 'Logs'),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 2
          ? ScaleTransition(
              scale: _fabScale,
              child: FloatingActionButton.extended(
                onPressed: () => _onTabChange(1),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New Pass'),
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )
          : null,
    );
  }
}

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _AppBarAction({required this.icon, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(foregroundColor: Colors.white),
      ),
    );
  }
}

NavigationDestination _navDest({required IconData icon, required IconData selectedIcon, required String label}) {
  return NavigationDestination(
    icon: Icon(icon),
    selectedIcon: Icon(selectedIcon),
    label: label,
  );
}
