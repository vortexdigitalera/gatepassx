---
name: flutter-m3-dynamic-scanner
description: Fullscreen QR scanner with instant beep/auto-popup and Material 3 dynamic color theming for Flutter apps
source: auto-skill
extracted_at: '2026-06-23T06:07:41.384Z'
---

# Flutter M3 Dynamic Color + Fullscreen QR Scanner

## Part 1: Material 3 Dynamic Color Theming

### Dependencies
```yaml
dependencies:
  dynamic_color: ^1.7.0
```

### Theme Setup Pattern
Use `DynamicColorBuilder` at the root to get system wallpaper colors on Android 12+, with a seed-based fallback:

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightScheme = (lightDynamic ?? ColorScheme.fromSeed(seedColor: _fallbackSeed, brightness: Brightness.light)).harmonized();
        final darkScheme = (darkDynamic ?? ColorScheme.fromSeed(seedColor: _fallbackSeed, brightness: Brightness.dark)).harmonized();

        return MaterialApp(
          theme: _buildTheme(lightScheme),
          darkTheme: _buildTheme(darkScheme),
          themeMode: ThemeMode.system,
        );
      },
    );
  }
}
```

**Key:** Always call `.harmonized()` on the scheme to blend dynamic colors with the seed baseline.

### Build Theme from Scheme
Don't hardcode colors anywhere — derive everything from the `ColorScheme`:

```dart
ThemeData _buildTheme(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.secondaryContainer,
      surfaceTintColor: Colors.transparent,
    ),
    // ... etc
  );
}
```

### M3 Component Replacements

| Old (custom) | M3 Equivalent |
|---|---|
| `ElevatedButton` with custom colors | `FilledButton` / `FilledButton.icon` |
| Custom search `TextField` | `SearchBar` widget |
| Manual status badges with `Container` | `Chip` with `visualDensity: VisualDensity.compact` |
| Hardcoded category colors | `colorScheme.primary`, `.secondary`, `.tertiary`, `.error` |
| Custom bottom nav styling | `NavigationBar` with `indicatorColor: scheme.secondaryContainer` |
| `AlertDialog` for scanner results | `showModalBottomSheet` with animated content |

### Eliminating Hardcoded Colors
Replace ALL `Color(0xFFXXXXXX)` references in screens with `Theme.of(context).colorScheme.*` tokens:

| Use case | Token |
|---|---|
| Primary actions / accents | `cs.primary` |
| Card/section backgrounds | `cs.primaryContainer`, `cs.surfaceContainerLow` |
| Text on containers | `cs.onPrimaryContainer`, `cs.onSurfaceVariant` |
| Subtle dividers/borders | `cs.outlineVariant` |
| Success states | `Colors.green` (keep — no M3 equivalent) |
| Error/denied states | `cs.error`, `cs.errorContainer` |
| Secondary accents | `cs.secondary`, `cs.tertiary` |

## Part 2: Fullscreen QR Scanner with Auto-Detect + Beep

### Dependencies
```yaml
dependencies:
  mobile_scanner: ^7.2.0
  audioplayers: ^6.1.0

flutter:
  assets:
    - assets/sounds/beep.wav
```

### Generate Beep WAV Asset (no recording needed)
```python
import wave, struct, math
sr=44100; freq=1200; dur=0.12; amp=0.8
n=int(sr*dur); ns=int(sr*0.005)  # 5ms fade in/out
with wave.open('beep.wav','w') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
    for i in range(n):
        env=min(1.0, min(i/ns, (n-1-i)/ns))
        v=amp*env*math.sin(2*math.pi*freq*i/sr)
        w.writeframes(struct.pack('<h',int(v*32767)))
```

### Fullscreen Layout
Hide the app bar and bottom nav when the scanner tab is active:

```dart
// In parent Scaffold:
appBar: _currentIndex == scanIndex ? null : AppBar(...),
bottomNavigationBar: _currentIndex == scanIndex ? null : NavigationBar(...),
```

The scanner screen fills the entire body area with `Scaffold(backgroundColor: Colors.black)`.

### Auto-Detect with Instant Feedback
Use a `_processing` flag to prevent double-fires:

```dart
void _onDetect(BarcodeCapture capture) {
  if (_processing) return;  // debounce
  for (final barcode in capture.barcodes) {
    if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
      _handleScan(barcode.rawValue!);
      return;
    }
  }
}

Future<void> _handleScan(String payload) async {
  _processing = true;
  
  // 1. Play beep + haptic immediately
  HapticFeedback.heavyImpact();
  await _beepPlayer.play(AssetSource('sounds/beep.wav'), volume: 1.0);
  
  // 2. Validate the payload
  // 3. Log the entry
  // 4. Show result popup
}
```

### Animated Bottom Sheet Result Popup
Use `showModalBottomSheet` with a custom animation controller for the slide-up:

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  transitionAnimationController: AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  ),
  builder: (ctx) => _ResultSheet(valid: valid, match: match, ...),
).then((_) => setState(() => _processing = false));  // auto-resume scanning
```

The result sheet structure:
```
┌──────────────────────────────┐
│          ═══ (drag handle)    │
│                              │
│       ✅ / ❌ (72px, elastic │
│          animation)          │
│   ACCESS GRANTED / DENIED    │
│   (optional reason text)     │
│                              │
│  ┌─ Pass Details Card ─────┐ │
│  │ Avatar  Name    [CHIP]  │ │
│  │         Pass ID         │ │
│  │ ────────────────────── │ │
│  │ Event:  Annual Gala    │ │
│  │ ID:     REG-001        │ │
│  │ Table:  T-05           │ │
│  └─────────────────────────┘ │
│                              │
│  [CLOSE]  [SCAN AGAIN ⏵]    │
└──────────────────────────────┘
```

**Key:** The `onScanAgain` callback pops the sheet and resets `_processing = false`, which immediately re-enables the camera scanner.

### Status Icon Animation
Use `TweenAnimationBuilder` with elastic curve for the pop-in effect:

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0.0, end: 1.0),
  duration: const Duration(milliseconds: 450),
  curve: Curves.elasticOut,
  builder: (ctx, val, _) => Transform.scale(
    scale: val,
    child: Icon(
      valid ? Icons.check_circle_rounded : Icons.cancel_rounded,
      color: valid ? Colors.green : Colors.red,
      size: 72,
    ),
  ),
),
```

### Scanner Overlay
Use a `CustomPainter` for the darkened overlay with rounded cutout + corner brackets:

```dart
// Draw dark overlay with rounded cutout
canvas.drawPath(
  Path.combine(
    PathOperation.difference,
    Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
    Path()..addRRect(RRect.fromRectAndRadius(scanRect, Radius.circular(20))),
  ),
  Paint()..color = Colors.black.withValues(alpha: 0.55),
);

// Draw corner brackets using scheme.primary color
// 4 corners × 2 lines each = 8 drawLine calls
```

Add an animated scan line using `AnimatedBuilder` with a repeating controller.

## Gotchas
- `AudioPlayer` must be disposed in `dispose()` — leaked players cause memory warnings
- The `_processing` flag MUST be reset both in `onScanAgain` AND in `.then((_) => ...)` to handle user swiping the sheet away
- `mobile_scanner` v7+ uses `MobileScannerController` with `detectionSpeed` — set `DetectionSpeed.normal` for balance
- `showModalBottomSheet` with `isScrollControlled: true` needs `SafeArea(top: false)` in the content to avoid double-padding
- On iOS, `audioplayers` may need `AVAudioSession` configuration for mixing — test on device
- When hiding AppBar conditionally, ensure the scanner's `Scaffold` has its own `backgroundColor: Colors.black` so there's no white flash
- `DynamicColorBuilder` rebuilds the entire widget tree on color change — avoid expensive computations in its builder
- The `SearchBar` widget (M3) uses `WidgetStatePropertyAll` for styling, not the old `MaterialStateProperty`
