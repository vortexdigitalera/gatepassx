import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../models/gate_pass.dart';

class ScanResult {
  final PassScanStatus status;
  final GatePass? match;
  final String pid;
  final String reason;
  const ScanResult({required this.status, required this.match, required this.pid, required this.reason});
  bool get isGranted => status == PassScanStatus.valid || status == PassScanStatus.duplicate;
}

class ScannerScreen extends StatefulWidget {
  final Future<void> Function(PassLog) onAddLog;
  final List<GatePass> knownPasses;
  final Future<void> Function(GatePass) onUpdatePass;
  const ScannerScreen({super.key, required this.onAddLog, required this.knownPasses, required this.onUpdatePass});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with TickerProviderStateMixin {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.normal, facing: CameraFacing.back);
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
    _beepPlayer.setReleaseMode(ReleaseMode.release);
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

  Future<void> _playFeedback() async {
    HapticFeedback.heavyImpact();
    try {
      await _beepPlayer.play(AssetSource('sounds/beep.wav'), volume: 1.0);
    } catch (_) {}
  }

  ScanResult _evaluateScan(String payload) {
    Map<String, dynamic>? data;
    try { data = jsonDecode(payload); } catch (_) { data = {'pid': payload}; }
    final pid = data?['pid'] ?? data?['pass_id'] ?? payload;
    GatePass? match;
    for (final p in widget.knownPasses) {
      if (p.passId == pid) { match = p; break; }
    }
    if (match == null) {
      return ScanResult(status: PassScanStatus.unknown, match: null, pid: pid, reason: 'Pass not found');
    }
    final status = match.computeScanStatus();
    String reason;
    switch (status) {
      case PassScanStatus.valid:
        reason = 'OK';
      case PassScanStatus.notStarted:
        final d = match.validFrom.difference(DateTime.now());
        reason = d.inDays > 0 ? 'Starts in ${d.inDays}d' : d.inHours > 0 ? 'Starts in ${d.inHours}h' : 'Starts in ${d.inMinutes}m';
      case PassScanStatus.expired:
        final d = DateTime.now().difference(match.validTo);
        reason = d.inDays > 0 ? 'Expired ${d.inDays}d ago' : d.inHours > 0 ? 'Expired ${d.inHours}h ago' : 'Expired ${d.inMinutes}m ago';
      case PassScanStatus.duplicate:
        final d = DateTime.now().difference(match.lastScannedAt!);
        reason = 'Scanned ${d.inMinutes}m ago';
      case PassScanStatus.unknown:
        reason = 'Unknown';
    }
    return ScanResult(status: status, match: match, pid: pid, reason: reason);
  }

  void _handleScan(String payload) {
    _processing = true;
    final result = _evaluateScan(payload);
    _playFeedback();
    widget.onAddLog(PassLog(
      passId: result.pid,
      action: result.isGranted ? 'ENTRY' : 'REJECTED',
      valid: result.isGranted,
      notes: result.reason,
      scanStatus: result.status.name,
    ));
    if (result.match != null && result.status == PassScanStatus.valid) {
      result.match!.lastScannedAt = DateTime.now();
      result.match!.scanCount += 1;
      widget.onUpdatePass(result.match!);
    }
    if (mounted) _showResult(result);
  }

  void _showResult(ScanResult result) {
    final sheetCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: sheetCtrl,
      builder: (ctx) => _ResultSheet(
        result: result,
        onScanAgain: () { Navigator.pop(ctx); setState(() => _processing = false); },
        onClose: () { Navigator.pop(ctx); setState(() => _processing = false); },
      ),
    ).then((_) {
      sheetCtrl.dispose();
      if (mounted) setState(() => _processing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop();
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
                  errorBuilder: (ctx, err) => _buildError(),
                  placeholderBuilder: (_) => const ColoredBox(
                    color: Colors.black,
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                ),
                _buildTopBar(cs),
                _buildInstruction(top, scanSize),
                _buildPasteBar(cs),
                if (_processing) const ColoredBox(color: Color(0x80000000)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_rounded, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              Text('Camera unavailable', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Check camera permissions', style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text('SCANNER', style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
              const Spacer(),
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: _controller,
                builder: (ctx, state, _) {
                  if (!state.isInitialized) return const SizedBox();
                  return IconButton.filled(
                    onPressed: () {
                      setState(() => _torchOn = !_torchOn);
                      _controller.toggleTorch();
                    },
                    icon: Icon(_torchOn ? Icons.bolt : Icons.bolt_outlined, color: _torchOn ? Colors.amber : Colors.white70),
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstruction(double top, double scanSize) {
    return Positioned(
      left: 0, right: 0,
      top: top + scanSize + 24,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(12)),
          child: Text('Point camera at QR code', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildPasteBar(ColorScheme cs) {
    return Positioned(
      left: 16, right: 16,
      bottom: MediaQuery.of(context).padding.bottom + 16,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const Padding(padding: EdgeInsets.only(left: 14), child: Icon(Icons.content_paste, color: Colors.white38, size: 20)),
            Expanded(
              child: TextField(
                controller: _pasteCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Paste QR / Pass ID',
                  hintStyle: GoogleFonts.inter(color: Colors.white24),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    _handleScan(v.trim());
                    _pasteCtrl.clear();
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: IconButton(
                onPressed: () {
                  if (_pasteCtrl.text.trim().isNotEmpty) {
                    _handleScan(_pasteCtrl.text.trim());
                    _pasteCtrl.clear();
                  }
                },
                icon: Icon(Icons.arrow_circle_up, color: cs.tertiary, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(BoxConstraints cons, ColorScheme cs) {
    final rect = _scanRect;
    if (rect == null) return const SizedBox.shrink();
    return Stack(
      children: [
        CustomPaint(size: cons.biggest, painter: _OverlayPainter(rect, cs)),
        AnimatedBuilder(
          animation: _scanLineAnim,
          builder: (ctx, _) => Positioned(
            left: rect.left + 6,
            top: rect.top + 6 + _scanLineAnim.value * (rect.height - 12),
            child: Container(
              width: rect.width - 12,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  cs.primary.withValues(alpha: 0.9),
                  cs.tertiary.withValues(alpha: 0.9),
                  cs.primary.withValues(alpha: 0.9),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Result Sheet ──

class _ResultSheet extends StatefulWidget {
  final ScanResult result;
  final VoidCallback onScanAgain;
  final VoidCallback onClose;
  const _ResultSheet({required this.result, required this.onScanAgain, required this.onClose});

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
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = widget.result;
    final cfg = _statusConfig(r.status);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (ctx, _) => TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (ctx, scale, child) => Transform.scale(
                  scale: scale * _pulseAnim.value,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cfg.color.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: cfg.color.withValues(alpha: 0.2), width: 3),
                    ),
                    child: Icon(cfg.icon, color: cfg.color, size: 56),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(cfg.title, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: cfg.color, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: cfg.color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cfg.color.withValues(alpha: 0.1)),
              ),
              child: Text(r.reason, style: tt.bodyMedium?.copyWith(color: cfg.color, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 16),
            if (r.match != null)
              _buildDetails(cs, tt, cfg.color)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Flexible(child: Text('ID: ${r.pid}', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, fontFamily: 'monospace'))),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: widget.onClose, child: const Text('CLOSE'))),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: widget.onScanAgain,
                      icon: const Icon(Icons.qr_code_2, size: 20),
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

  Widget _buildDetails(ColorScheme cs, TextTheme tt, Color statusColor) {
    final m = widget.result.match!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.person, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.fullName, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(m.passId, style: tt.labelSmall?.copyWith(fontFamily: 'monospace')),
                  ],
                ),
              ),
              Chip(label: Text(m.category.name, style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 8),
          _row(Icons.celebration, 'Event', m.eventName, cs, tt),
          _row(Icons.fingerprint, 'ID', m.idNumber, cs, tt),
          if (m.phone != null && m.phone!.isNotEmpty) _row(Icons.call, 'Phone', m.phone!, cs, tt),
          _row(Icons.apartment, 'Organizer', m.organizer, cs, tt),
          if (m.gate != null && m.gate!.isNotEmpty) _row(Icons.meeting_room, 'Gate', m.gate!, cs, tt),
          if (m.tableNumber != null && m.tableNumber!.isNotEmpty) _row(Icons.grid_view, 'Table', m.tableNumber!, cs, tt),
          _row(Icons.calendar_month, 'Valid', '${DateFormat('dd MMM yyyy').format(m.validFrom)} — ${DateFormat('dd MMM yyyy').format(m.validTo)}', cs, tt),
          _row(Icons.sell, 'Type', m.eventType.name, cs, tt),
          _row(Icons.pin, 'Scans', '${m.scanCount}', cs, tt),
          if (m.lastScannedAt != null) _row(Icons.history_toggle_off, 'Last Scan', DateFormat.yMd().add_jm().format(m.lastScannedAt!), cs, tt),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(width: 72, child: Text(label, style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant))),
          Expanded(child: Text(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  _StatusConfig _statusConfig(PassScanStatus status) {
    switch (status) {
      case PassScanStatus.valid: return _StatusConfig(Icons.verified, Colors.green, 'ACCESS GRANTED');
      case PassScanStatus.notStarted: return _StatusConfig(Icons.schedule, Colors.orange, 'NOT STARTED YET');
      case PassScanStatus.expired: return _StatusConfig(Icons.timer_off, Colors.red, 'PASS EXPIRED');
      case PassScanStatus.duplicate: return _StatusConfig(Icons.replay_circle_filled, Colors.amber.shade700, 'ALREADY SCANNED');
      case PassScanStatus.unknown: return _StatusConfig(Icons.help_outline, Colors.grey, 'UNKNOWN PASS');
    }
  }
}

class _StatusConfig {
  final IconData icon;
  final Color color;
  final String title;
  const _StatusConfig(this.icon, this.color, this.title);
}

class _OverlayPainter extends CustomPainter {
  final Rect scanRect;
  final ColorScheme cs;
  _OverlayPainter(this.scanRect, this.cs);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(24))),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    final paint = Paint()
      ..color = cs.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const r = 16.0;
    const len = 32.0;
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
