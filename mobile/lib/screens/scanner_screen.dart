import 'dart:async';
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

class _ScannerScreenState extends State<ScannerScreen> with TickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  final _pasteCtrl = TextEditingController();
  bool _paused = false;
  bool _torchOn = false;

  late final AnimationController _scanAnimCtrl;
  late final Animation<double> _scanLine;

  Rect? _scanWindowRect;

  @override
  void initState() {
    super.initState();
    _scanAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _scanLine = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnimCtrl, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _scanAnimCtrl.dispose();
    _pasteCtrl.dispose();
    _controller.dispose();
    super.dispose();
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

    if (mounted) _showResultDialog(valid, reason, match, pid);
  }

  void _showResultDialog(bool valid, String reason, GatePass? match, String pid) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: valid
                            ? [const Color(0xFF1B7A1B), const Color(0xFF2E7D32)]
                            : [const Color(0xFFB71C1C), const Color(0xFFC62828)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 400),
                          builder: (ctx, val, _) => Transform.scale(
                            scale: val,
                            child: Icon(
                              valid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              color: Colors.white,
                              size: 72,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          valid ? 'ACCESS GRANTED' : 'ACCESS DENIED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (reason != 'OK')
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(reason, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                          ),
                      ],
                    ),
                  ),
                  if (match != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: valid ? const Color(0xFF2E7D32).withValues(alpha: 0.1) : const Color(0xFFC62828).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.person_rounded, color: valid ? const Color(0xFF2E7D32) : const Color(0xFFC62828), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(match.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                Text(match.passId, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          _buildCategoryChip(match.category.name),
                        ],
                      ),
                    ),
                    const Divider(height: 24, indent: 20, endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Column(
                        children: [
                          _infoRow(Icons.assignment_ind_outlined, 'ID', match.idNumber),
                          if (match.phone != null && match.phone!.isNotEmpty)
                            _infoRow(Icons.phone_outlined, 'Phone', match.phone!),
                          _infoRow(Icons.business_outlined, 'Operator', match.operator),
                          if (match.gate != null && match.gate!.isNotEmpty)
                            _infoRow(Icons.location_on_outlined, 'Gate', match.gate!),
                          _infoRow(Icons.date_range_outlined, 'Valid', '${_fmt(match.validFrom)} — ${_fmt(match.validTo)}'),
                          if (match.tripType != null)
                            _infoRow(Icons.map_outlined, 'Trip', match.tripType!.name),
                        ],
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Pass ID: $pid', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('CLOSE', style: TextStyle(letterSpacing: 0.5)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (mounted) setState(() => _paused = false);
                          },
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                          label: const Text('SCAN AGAIN'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006400),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) setState(() => _paused = false);
    });
  }

  Widget _buildCategoryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF006400).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF006400))),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          SizedBox(width: 60, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  String _fmt(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  void _manualSubmit(String val) {
    if (val.trim().isNotEmpty) {
      _handleScan(val.trim());
      _pasteCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final scanSize = w * 0.7;
        final left = (w - scanSize) / 2;
        final top = (constraints.maxHeight - scanSize) / 2 - 40;
        _scanWindowRect = Rect.fromLTWH(left, top, scanSize, scanSize);

        return Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              fit: BoxFit.cover,
              scanWindow: _scanWindowRect,
              overlayBuilder: (ctx, cons) {
                return Stack(
                  children: [
                    // Dark overlay with cutout
                    CustomPaint(
                      size: cons.biggest,
                      painter: _ScannerOverlayPainter(
                        scanRect: _scanWindowRect!,
                        cornerColor: const Color(0xFF006400),
                      ),
                    ),
                    // Corner decoration
                    Positioned(
                      left: left - 4,
                      top: top - 4,
                      child: _CornerDecoration(size: scanSize + 8),
                    ),
                    // Scan line
                    Positioned(
                      left: left + 4,
                      top: top + 4 + _scanLine.value * (scanSize - 8),
                      child: Container(
                        width: scanSize - 8,
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFF006400).withValues(alpha: 0.8),
                              const Color(0xFFFFB300),
                              const Color(0xFF006400).withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Torch button
                    Positioned(
                      bottom: 120,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _controller,
                          builder: (ctx, state, _) {
                            if (!state.isInitialized) return const SizedBox();
                            return GestureDetector(
                              onTap: () {
                                _torchOn = !_torchOn;
                                _controller.toggleTorch();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                      color: _torchOn ? const Color(0xFFFFB300) : Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _torchOn ? 'TORCH ON' : 'TORCH OFF',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
              placeholderBuilder: (ctx) => const ColoredBox(
                color: Colors.black,
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
            // Header
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const Text('Scan QR Code', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                  const SizedBox(height: 4),
                  Text('Point camera at AHUON gate pass QR', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                ],
              ),
            ),
            // Paste field
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).padding.bottom + 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Icon(Icons.paste_rounded, color: Colors.white.withValues(alpha: 0.5), size: 20),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _pasteCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Or paste QR payload / Pass ID',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                        ),
                        onSubmitted: _manualSubmit,
                      ),
                    ),
                    if (_pasteCtrl.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.send_rounded, color: const Color(0xFF006400), size: 20),
                        onPressed: () => _manualSubmit(_pasteCtrl.text),
                      ),
                  ],
                ),
              ),
            ),
            // Paused overlay
            if (_paused)
              Container(color: Colors.black.withValues(alpha: 0.6)),
          ],
        );
      },
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanRect;
  final Color cornerColor;

  _ScannerOverlayPainter({required this.scanRect, required this.cornerColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark background
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16))),
      ),
      bgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) => oldDelegate.scanRect != scanRect;
}

class _CornerDecoration extends StatelessWidget {
  final double size;
  const _CornerDecoration({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(),
        size: Size(size, size),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF006400)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final r = 12.0;
    final len = 24.0;

    // Top-left corner
    canvas.drawLine(Offset(r, 0), Offset(r + len, 0), paint);
    canvas.drawLine(Offset(0, r), Offset(0, r + len), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - r - len, 0), Offset(size.width - r, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, r + len), paint);

    // Bottom-left
    canvas.drawLine(Offset(r, size.height), Offset(r + len, size.height), paint);
    canvas.drawLine(Offset(0, size.height - r - len), Offset(0, size.height - r), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - r - len, size.height), Offset(size.width - r, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - r - len), Offset(size.width, size.height - r), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
