import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/gate_pass.dart';

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
      valid = true;
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

class MobileScannerWidget extends StatelessWidget {
  final Function(String) onDetect;

  const MobileScannerWidget({super.key, required this.onDetect});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.camera, size: 80, color: Colors.grey),
        const SizedBox(height: 12),
        const Text('Camera scanner active on supported devices (Android/iOS)'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            const sample = '{"pid":"AHUON-HAJJ-2026-000101","nm":"Alhaji Musa Ibrahim","cat":"PILGRIM","idn":"NG12345678","op":"Al-Mufid Travels","vf":"2026-06-25","vt":"2026-07-20","gt":"Lagos Hajj Camp Gate A"}';
            onDetect(sample);
          },
          child: const Text('Simulate Scan (sample pilgrim)'),
        ),
      ],
    );
  }
}
