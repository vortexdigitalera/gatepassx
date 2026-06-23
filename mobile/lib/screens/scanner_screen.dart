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
  final VoidCallback onBack;

  const ScannerScreen({
    super.key,
    required this.onAddLog,
    required this.knownPasses,
    required this.onBack,
  });

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
      if (p.passId == pid) {
        match = p;
        break;
      }
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
        duration: const Duration(milliseconds: 400),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        widget.onBack();
      },
      child: LayoutBuilder(
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

                // Top header with back button
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          // Back button
                          _buildGlassButton(
                            onTap: widget.onBack,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 6),
                                Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                const Text('SCANNER', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
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
                                  color: _torchOn ? Colors.amber : Colors.white70,
                                  size: 24,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black.withValues(alpha: 0.45),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.all(10),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Instruction text
                Positioned(
                  left: 0,
                  right: 0,
                  top: top + scanSize + 24,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Point camera at QR code',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),

                // Paste field at bottom
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  child: _buildPasteField(cs),
                ),

                // Processing overlay
                if (_processing)
                  Container(color: Colors.black.withValues(alpha: 0.5)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlassButton({required VoidCallback onTap, required Widget child}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildOverlay(BoxConstraints cons, ColorScheme cs) {
    final rect = _scanRect!;
    return Stack(
      children: [
        CustomPaint(
          size: cons.biggest,
          painter: _OverlayPainter(rect, cs),
        ),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Icon(Icons.paste_rounded, color: Colors.white38, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: _pasteCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Paste QR / Pass ID',
                hintStyle: TextStyle(color: Colors.white24),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              onSubmitted: _manualSubmit,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              icon: Icon(Icons.send_rounded, color: cs.tertiary, size: 22),
              onPressed: () => _manualSubmit(_pasteCtrl.text),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result Bottom Sheet ──────────────────────────────────────────────────────

class _ResultSheet extends StatefulWidget {
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
  State<_ResultSheet> createState() => _ResultSheetState();
}

class _ResultSheetState extends State<_ResultSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = widget.valid ? Colors.green : Colors.red;

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
            const SizedBox(height: 8),

            // Animated status icon with pulse
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (ctx, _) => TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (ctx, scaleVal, child) {
                  return Transform.scale(
                    scale: scaleVal * _pulseAnim.value,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: statusColor.withValues(alpha: 0.15), width: 2),
                      ),
                      child: Icon(
                        widget.valid ? Icons.verified_rounded : Icons.cancel_rounded,
                        color: statusColor,
                        size: 56,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Status text
            Text(
              widget.valid ? 'ACCESS GRANTED' : 'ACCESS DENIED',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: statusColor,
                letterSpacing: 0.8,
              ),
            ),
            if (widget.reason != 'OK') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(widget.reason, style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.w500)),
              ),
            ],
            const SizedBox(height: 18),

            // Pass details
            if (widget.match != null)
              _buildMatchDetails(context, cs)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Flexible(child: Text('Pass ID: ${widget.pid}', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, fontFamily: 'monospace'))),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onClose,
                      child: const Text('CLOSE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: widget.onScanAgain,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                      label: const Text('SCAN AGAIN'),
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
    final m = widget.match!;
    final statusColor = widget.valid ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.person_rounded, color: statusColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(m.passId, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontFamily: 'monospace')),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(m.category.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 10),
          _infoRow(Icons.event_rounded, 'Event', m.eventName, cs),
          _infoRow(Icons.assignment_ind_rounded, 'ID', m.idNumber, cs),
          if (m.phone != null && m.phone!.isNotEmpty)
            _infoRow(Icons.phone_rounded, 'Phone', m.phone!, cs),
          _infoRow(Icons.business_rounded, 'Organizer', m.organizer, cs),
          if (m.gate != null && m.gate!.isNotEmpty)
            _infoRow(Icons.location_on_rounded, 'Gate', m.gate!, cs),
          if (m.tableNumber != null && m.tableNumber!.isNotEmpty)
            _infoRow(Icons.table_restaurant_rounded, 'Table', m.tableNumber!, cs),
          _infoRow(Icons.date_range_rounded, 'Valid',
              '${DateFormat('dd MMM yyyy').format(m.validFrom)} — ${DateFormat('dd MMM yyyy').format(m.validTo)}', cs),
          _infoRow(Icons.category_rounded, 'Type', m.eventType.name, cs),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
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
        Path()..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(24))),
      ),
      bg,
    );

    final paint = Paint()
      ..color = cs.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final r = 16.0;
    final len = 32.0;
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
