import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../models/gate_pass.dart';

class ScannerScreen extends StatefulWidget {
  final Future<void> Function(PassLog) onAddLog;
  final List<GatePass> knownPasses;

  const ScannerScreen({super.key, required this.onAddLog, required this.knownPasses});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController();
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed && !_paused) {
      _controller.start();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_paused) return;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null) {
        _handleScan(barcode.rawValue!);
        return;
      }
    }
  }

  void _handleScan(String payload) {
    _paused = true;

    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(payload);
    } catch (_) {
      data = {'pid': payload};
    }

    final pid = data?['pid'] ?? data?['pass_id'] ?? payload;
    final match = widget.knownPasses.where((p) => p.passId == pid).isNotEmpty
        ? widget.knownPasses.firstWhere((p) => p.passId == pid)
        : null;

    final now = DateTime.now();
    bool valid = true;
    String reason = 'OK';

    if (match != null) {
      if (now.isBefore(match.validFrom) || now.isAfter(match.validTo)) {
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
    widget.onAddLog(log);

    if (mounted) {
      _showResultDialog(valid, reason, match, pid);
    }
  }

  void _showResultDialog(bool valid, String reason, GatePass? match, String pid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              color: valid ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              child: Column(
                children: [
                  Icon(
                    valid ? Icons.check_circle : Icons.cancel,
                    color: Colors.white,
                    size: 64,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    valid ? 'ACCESS GRANTED' : 'ACCESS DENIED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (reason != 'OK')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        reason,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (match != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        match.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildCategoryChip(match.category.name),
                  ],
                ),
              ),
              _infoRow(Icons.badge_outlined, 'Pass ID', match.passId),
              if (match.idNumber.isNotEmpty)
                _infoRow(Icons.assignment_ind_outlined, 'ID No', match.idNumber),
              if (match.phone != null && match.phone!.isNotEmpty)
                _infoRow(Icons.phone_outlined, 'Phone', match.phone!),
              if (match.operator.isNotEmpty)
                _infoRow(Icons.business_outlined, 'Operator', match.operator),
              if (match.gate != null && match.gate!.isNotEmpty)
                _infoRow(Icons.location_on_outlined, 'Gate', match.gate!),
              if (match.groupRef != null && match.groupRef!.isNotEmpty)
                _infoRow(Icons.flight_outlined, 'Group', match.groupRef!),
              _infoRow(
                Icons.date_range_outlined,
                'Valid',
                '${_fmt(match.validFrom)} — ${_fmt(match.validTo)}',
              ),
              if (match.tripType != null)
                _infoRow(Icons.map_outlined, 'Trip', match.tripType!.name),
              if (match.vehiclePlate != null && match.vehiclePlate!.isNotEmpty)
                _infoRow(Icons.directions_car_outlined, 'Vehicle', match.vehiclePlate!),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Pass ID: $pid\n$reason',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _paused = false);
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('SCAN AGAIN'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF006400),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) setState(() => _paused = false);
            },
            child: const Text('CLOSE'),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) setState(() => _paused = false);
    });
  }

  Widget _buildCategoryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF006400).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF006400),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  void _manualSubmit(String val) {
    if (val.trim().isNotEmpty) _handleScan(val.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          fit: BoxFit.cover,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.black87,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Paste QR payload or Pass ID',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.paste, color: Colors.white.withOpacity(0.7)),
              ),
              onSubmitted: _manualSubmit,
            ),
          ),
        ),
        if (_paused)
          Container(color: Colors.black54),
      ],
    );
  }
}
