import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
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
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  final _pasteCtrl = TextEditingController();
  final _beepPlayer = AudioPlayer();

  bool _processing = false;
  bool _torchOn = false;

  late final AnimationController _scanLineCtrl;
  late final Animation<double> _scanLineAnim;

  Rect? _scanRect;

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _pasteCtrl.dispose();
    _beepPlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        _handleScan(barcode.rawValue!);
        return;
      }
    }
  }

  Future<void> _playFeedback(bool valid) async {
    HapticFeedback.heavyImpact();
    try {
      await _beepPlayer.setReleaseMode(ReleaseMode.release);
      await _beepPlayer.play(AssetSource('sounds/beep.wav'), volume: 1.0);
    } catch (_) {}
  }

  void _handleScan(String payload) {
    _processing = true;

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(payload);
    } catch (_) {
      data = {'pid': payload};
    }

    final pid = data?['pid'] ?? data?['pass_id'] ?? payload;
    GatePass? match;
    for (final p in widget.knownPasses) {
      if (p.passId == pid) { match = p; break; }
    }

    final now = DateTime.now();
    bool valid = true;
    String reason = 'OK';

    if (match != null) {
      if (now.isBefore(match.validFrom) || now.isAfter(match.validTo)) {
        valid = false;
        reason = 'EXPIRED / NOT YET VALID';
      }
    } else {
      reason = 'UNKNOWN PASS';
    }

    final log = PassLog(
      passId: pid,
      action: valid ? 'ENTRY' : 'REJECTED',
      valid: valid,
      notes: reason,
    );
    widget.onAddLog(log);

    _playFeedback(valid);

    if (mounted) _showResult(valid, reason, match, pid);
  }

  void _showResult(bool valid, String reason, GatePass? match, String pid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      ),
      builder: (ctx) => _ResultSheet(
        valid: valid,
        reason: reason,
        match: match,
        pid: pid,
        onScanAgain: () {
          Navigator.pop(ctx);
          setState(() => _processing = false);
        },
        onClose: () {
          Navigator.pop(ctx);
          setState(() => _processing = false);
        },
      ),
    ).then((_) {
      if (mounted) setState(() => _processing = false);
    });
  }

  void _manualSubmit(String val) {
    if (val.trim().isNotEmpty) {
      _handleScan(val.trim());
      _pasteCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final scanSize = w * 0.68;
        final left = (w - scanSize) / 2;
        final top = h * 0.22;
        _scanRect = Rect.fromLTWH(left, top, scanSize, scanSize);

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Full camera feed
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                fit: BoxFit.cover,
                scanWindow: _scanRect,
                overlayBuilder: (ctx, cons) => _buildOverlay(cons, cs),
                placeholderBuilder: (_) => const ColoredBox(
                  color: Colors.black,
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              ),

              // Top safe area — header
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // Back hint
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              const Text('SCANNER', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Torch toggle
                        ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _controller,
                          builder: (ctx, state, _) {
                            if (!state.isInitialized) return const SizedBox();
                            return IconButton(
                              onPressed: () {
                                setState(() => _torchOn = !_torchOn);
                                _controller.toggleTorch();
                              },
                              icon: Icon(
                                _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                color: _torchOn ? cs.tertiary : Colors.white70,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withValues(alpha: 0.45),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Instruction text below scan frame
              Positioned(
                left: 0, right: 0,
                top: top + scanSize + 20,
                child: Center(
                  child: Text(
                    'Point camera at QR code',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                  ),
                ),
              ),

              // Paste field at bottom
              Positioned(
                left: 16, right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 12,
                child: _buildPasteField(cs),
              ),

              // Processing overlay
              if (_processing)
                Container(color: Colors.black.withValues(alpha: 0.5)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverlay(BoxConstraints cons, ColorScheme cs) {
    final rect = _scanRect!;
    return Stack(
      children: [
        // Darkened overlay with cutout
        CustomPaint(
          size: cons.biggest,
          painter: _OverlayPainter(rect, cs),
        ),
        // Animated scan line
        AnimatedBuilder(
          animation: _scanLineAnim,
          builder: (ctx, _) => Positioned(
            left: rect.left + 6,
            top: rect.top + 6 + _scanLineAnim.value * (rect.height - 12),
            child: Container(
              width: rect.width - 12,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    cs.primary.withValues(alpha: 0.9),
                    cs.tertiary.withValues(alpha: 0.9),
                    cs.primary.withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasteField(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(Icons.paste_rounded, color: Colors.white38, size: 18),
          ),
          Expanded(
            child: TextField(
              controller: _pasteCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Paste QR / Pass ID',
                hintStyle: const TextStyle(color: Colors.white24),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              ),
              onSubmitted: _manualSubmit,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(Icons.send_rounded, color: cs.tertiary, size: 20),
              onPressed: () => _manualSubmit(_pasteCtrl.text),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result Bottom Sheet ──────────────────────────────────────────────────────

class _ResultSheet extends StatelessWidget {
  final bool valid;
  final String reason;
  final GatePass? match;
  final String pid;
  final VoidCallback onScanAgain;
  final VoidCallback onClose;

  const _ResultSheet({
    required this.valid,
    required this.reason,
    required this.match,
    required this.pid,
    required this.onScanAgain,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = valid ? Colors.green : Colors.red;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Status icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              builder: (ctx, val, _) => Transform.scale(
                scale: val,
                child: Icon(
                  valid ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: statusColor,
                  size: 72,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Status text
            Text(
              valid ? 'ACCESS GRANTED' : 'ACCESS DENIED',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: statusColor,
                letterSpacing: 0.5,
              ),
            ),
            if (reason != 'OK') ...[
              const SizedBox(height: 4),
              Text(reason, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 16),

            // Pass details
            if (match != null)
              _buildMatchDetails(context, cs)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text('Pass ID: $pid', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onClose,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('CLOSE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: onScanAgain,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: const Text('SCAN AGAIN'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  }

  Widget _buildMatchDetails(BuildContext context, ColorScheme cs) {
    final m = match!;
    final statusColor = valid ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Name row
          Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.1),
                child: Icon(Icons.person_rounded, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(m.passId, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Chip(
                label: Text(m.category.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 8),
          _infoRow(Icons.event_outlined, 'Event', m.eventName, cs),
          _infoRow(Icons.assignment_ind_outlined, 'ID', m.idNumber, cs),
          if (m.phone != null && m.phone!.isNotEmpty)
            _infoRow(Icons.phone_outlined, 'Phone', m.phone!, cs),
          _infoRow(Icons.business_outlined, 'Organizer', m.organizer, cs),
          if (m.gate != null && m.gate!.isNotEmpty)
            _infoRow(Icons.location_on_outlined, 'Gate', m.gate!, cs),
          if (m.tableNumber != null && m.tableNumber!.isNotEmpty)
            _infoRow(Icons.table_restaurant_outlined, 'Table', m.tableNumber!, cs),
          _infoRow(Icons.date_range_outlined, 'Valid',
              '${DateFormat('dd MMM yyyy').format(m.validFrom)} — ${DateFormat('dd MMM yyyy').format(m.validTo)}', cs),
          _infoRow(Icons.category_outlined, 'Type', m.eventType.name, cs),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 68,
            child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

// ── Overlay Painter ──────────────────────────────────────────────────────────

class _OverlayPainter extends CustomPainter {
  final Rect scanRect;
  final ColorScheme cs;

  _OverlayPainter(this.scanRect, this.cs);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(20))),
      ),
      bg,
    );

    // Corner brackets
    final paint = Paint()
      ..color = cs.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final r = 14.0;
    final len = 28.0;
    final l = scanRect.left, t = scanRect.top, ri = scanRect.right, b = scanRect.bottom;

    canvas.drawLine(Offset(l + r, t), Offset(l + r + len, t), paint);
    canvas.drawLine(Offset(l, t + r), Offset(l, t + r + len), paint);
    canvas.drawLine(Offset(ri - r - len, t), Offset(ri - r, t), paint);
    canvas.drawLine(Offset(ri, t + r), Offset(ri, t + r + len), paint);
    canvas.drawLine(Offset(l + r, b), Offset(l + r + len, b), paint);
    canvas.drawLine(Offset(l, b - r - len), Offset(l, b - r), paint);
    canvas.drawLine(Offset(ri - r - len, b), Offset(ri - r, b), paint);
    canvas.drawLine(Offset(ri, b - r - len), Offset(ri, b - r), paint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) => old.scanRect != scanRect;
}
