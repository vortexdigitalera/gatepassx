import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gate_pass.dart';

class PassStorage {
  static const _passesKey = 'ahuon_passes';
  static const _logsKey = 'ahuon_logs';

  Future<List<GatePass>> loadPasses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_passesKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map((e) => GatePass.fromJson(e)).toList();
  }

  Future<void> savePasses(List<GatePass> passes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = passes.map((p) => p.toJson()).toList();
    await prefs.setString(_passesKey, jsonEncode(jsonList));
  }

  Future<void> addOrUpdatePass(GatePass pass) async {
    final passes = await loadPasses();
    final idx = passes.indexWhere((p) => p.passId == pass.passId);
    if (idx >= 0) {
      passes[idx] = pass;
    } else {
      passes.add(pass);
    }
    await savePasses(passes);
  }

  Future<List<PassLog>> loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_logsKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map((e) => PassLog.fromJson(e)).toList();
  }

  Future<void> saveLogs(List<PassLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logsKey, jsonEncode(logs.map((l) => l.toJson()).toList()));
  }

  Future<void> addLog(PassLog log) async {
    final logs = await loadLogs();
    logs.insert(0, log); // newest first
    // keep last 200
    if (logs.length > 200) logs.removeRange(200, logs.length);
    await saveLogs(logs);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_passesKey);
    await prefs.remove(_logsKey);
  }
}
