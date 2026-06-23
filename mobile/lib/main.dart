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
      scrolledUnderElevation: 2,
      centerTitle: true,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      iconTheme: const IconThemeData(size: 26),
      titleTextStyle: TextStyle(
        color: scheme.onPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: scheme.onSurfaceVariant,
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 72,
      indicatorColor: scheme.secondaryContainer,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: scheme.onSecondaryContainer, size: 28);
        }
        return IconThemeData(color: scheme.onSurfaceVariant, size: 28);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface);
        }
        return TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: scheme.onSurfaceVariant);
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      showCloseIcon: true,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        minimumSize: const Size(0, 52),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        minimumSize: const Size(0, 52),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 15)),
    ),
    iconTheme: IconThemeData(size: 26, color: scheme.onSurfaceVariant),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 4,
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
        SnackBar(
          content: Text('Imported ${imported.length} pass(es)'),
          behavior: SnackBarBehavior.floating,
        ),
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

    return PopScope(
      canPop: _currentIndex == 0 && !_isScanner,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isScanner || _currentIndex != 0) {
          _onTabChange(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        appBar: _isScanner
            ? null
            : AppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.onPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.confirmation_number_rounded, size: 22, color: cs.onPrimary),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DePass', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onPrimary, letterSpacing: 0.3)),
                        Text('EVENT GATE PASS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w400, letterSpacing: 1.8, color: cs.onPrimary.withValues(alpha: 0.65))),
                      ],
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.file_download_rounded, size: 24),
                    tooltip: 'Import',
                    onPressed: _importPasses,
                  ),
                  IconButton(
                    icon: const Icon(Icons.upload_rounded, size: 24),
                    tooltip: 'Export',
                    onPressed: _passes.isEmpty ? null : _exportAll,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 24),
                    tooltip: 'Refresh',
                    onPressed: _loadData,
                  ),
                ],
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: IndexedStack(
                  key: ValueKey(_currentIndex),
                  index: _currentIndex,
                  children: [
                    DashboardScreen(
                      passes: _passes,
                      logs: _logs,
                      onRefresh: _loadData,
                      onNavigate: _onTabChange,
                      onImport: _importPasses,
                      onExport: _exportAll,
                    ),
                    IssuePassScreen(onSave: _savePass),
                    PassesScreen(passes: _passes, onAddLog: _addLog),
                    ScannerScreen(
                      onAddLog: _addLog,
                      knownPasses: _passes,
                      onBack: () => _onTabChange(0),
                    ),
                    LogsScreen(logs: _logs),
                  ],
                ),
              ),
        bottomNavigationBar: _isScanner
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: NavigationBar(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: _onTabChange,
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard_rounded),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.add_card_outlined),
                          selectedIcon: Icon(Icons.add_card_rounded),
                          label: 'Issue',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.badge_outlined),
                          selectedIcon: Icon(Icons.badge_rounded),
                          label: 'Passes',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.qr_code_scanner_rounded),
                          selectedIcon: Icon(Icons.qr_code_scanner_rounded),
                          label: 'Scan',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.history_rounded),
                          selectedIcon: Icon(Icons.history_rounded),
                          label: 'Logs',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        floatingActionButton: _currentIndex == 2
            ? FloatingActionButton.extended(
                onPressed: () => _onTabChange(1),
                icon: const Icon(Icons.add_rounded, size: 24),
                label: const Text('New Pass', style: TextStyle(fontWeight: FontWeight.w600)),
              )
            : null,
      ),
    );
  }
}
