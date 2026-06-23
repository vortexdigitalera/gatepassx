---
name: flutter-m3-widgets
description: Use when working with Flutter Material 3 widgets, themes, theming, M3 migration, or comparing Material 2 vs Material 3 design. Covers all M3 widget categories, color/tone/typography changes, widget replacements, and material component usage patterns.
---

# Flutter Material 3 Widgets

## Overview

Material 3 (M3) is the default design language in Flutter since v3.16 (Nov 2023).
`useMaterial3` defaults to `true`. The M2 implementation and flag will eventually be removed.

### How the layers interact

```
M3 Expressive ── evolution of M3 (emotional UX via color, shape, size, motion, containment)
      ↑
M3 (Material 3) ── design system spec (fromSeed colors, surfaceTint, NavigationBar, etc.)
      ↑
Flutter Material library ── implements M3 in Dart widgets (ThemeData, widget catalog)
      ↑
Android/iOS/Web ── platform layer (Kotlin/Gradle for Android builds, plugins like mobile_scanner)
```

- **M3 Expressive** is NOT a new version of M3 (not M4). It's a set of expressive tactics and updated components on top of M3. Research shows expressive designs are preferred across ages, score higher on playfulness/energy/creativity, and users spot key UI elements up to 4x faster.
- **M3** is the design system spec (colors, typography, components, motion).
- **Flutter** implements M3 through `ThemeData`, `useMaterial3`, and the widgets catalog.
- **Kotlin/Android** is the build platform — Flutter plugins apply Kotlin Gradle Plugin for Android compilation. The Android SDK compiles Flutter's Dart code into native APK/AAB.

---

## M3 Styles (m3.material.io/styles)

Styles are the visual aspects of a UI that give it a distinct look and feel. M3 defines 6 style categories: Color, Typography, Shape, Elevation, Motion, Icons.

### Color

M3 color system: 26+ color roles, built-in accessible pairings (3:1 min contrast), dark theme, dynamic color.

#### Color roles
Color roles are assigned to UI elements based on emphasis and container type. Key categories:
- **Primary / On Primary / Primary Container / On Primary Container** — brand color and its variations
- **Secondary / On Secondary / Secondary Container / On Secondary Container** — accent
- **Tertiary / On Tertiary / Tertiary Container / On Tertiary Container** — contrasting accent
- **Error / On Error / Error Container / On Error Container** — error states
- **Surface variants** — `surface`, `surfaceDim`, `surfaceBright`, `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest`, `surfaceTint`
- **On Surface / On Surface Variant** — content on surfaces
- **Outline / Outline Variant** — borders, dividers
- **Inverse Surface / Inverse On Surface / Inverse Primary** — for elements that need to flip contrast (e.g. snackbar on top of content)
- **Scrim** — modal overlay backdrop
- **Shadow** — drop shadow color

Total: 45+ color roles in the full system.

#### Dynamic color
Two types:
- **User-generated** — source color extracted from user's wallpaper (Android 12+). Flutter: `DynamicColorBuilder` or `ColorScheme.fromImageProvider`.
- **Content-based** — source from in-app content (album art, book cover).

Usage: `ColorScheme.fromSeed(seedColor: color)` generates a full accessible palette from a single seed.

#### Baseline color scheme
Default static scheme with fixed colors for light and dark themes. Used as fallback when dynamic color is unavailable.

#### In Flutter
```dart
// Dynamic (wallpaper-based)
DynamicColorBuilder(builder: (light, dark) { ... })
// Seed-based (recommended for most apps)
ColorScheme.fromSeed(seedColor: myColor, brightness: brightness).harmonized()
// Manual
ColorScheme.light(primary: ..., onPrimary: ..., ...)
```

### Typography

#### Type scale (15 baseline + 15 emphasized)
5 categories × 3 sizes (Small/Medium/Large):

| Category | Usage |
|---|---|
| **Display** | Large, short text — hero headers |
| **Headline** | Section headlines |
| **Title** | Medium-emphasis, relatively short text |
| **Label** | Small text for component labels, captions |
| **Body** | Long-form reading text |

M3 uses `Typography.material2021` (vs M2's `material2014`). Font sizes, weights, letter spacing, and line heights changed.

#### M3 Expressive typography update (May 2025)
- **15 new emphasized type styles** — `display-large-emphasized`, `headline-medium-emphasized`, etc.
- Emphasized tokens allow clearer hierarchies and prioritized components
- **Roboto Flex** variable font with 6 axes for emotional range
- **Google Sans Flex** — Google's iconic typeface with variable axes, now open-source

#### Variable fonts
Use `FontVariation` class to control design axes at runtime (weight, width, slant, etc).

#### Google Fonts package
```dart
Text('Hello', style: GoogleFonts.inter())
Text('Hello', style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w700))
GoogleFonts.interTextTheme() // apply to full TextTheme
```

#### Font features
- `FontFeature` — OpenType feature tags (boolean toggles)
- `FontWeight` — numeric weight
- `FontStyle` — italic/normal
- `FontVariation` — continuous axis values for variable fonts

### Shape

M3 shape scale defines container corner roundedness from square to fully circular.

#### Shape categories
- **None** (0dp) — square
- **Extra small** (4dp) — slight rounding
- **Small** (8dp)
- **Medium** (12dp)
- **Large** (16dp)
- **Extra large** (28dp) — very rounded

#### Shape families applied to components
- **Small shape** — buttons, chips, text fields, snackbars
- **Medium shape** — cards, dialogs, date pickers, bottom sheets
- **Large shape** — navigation drawer, side sheets

#### In Flutter
```dart
// Per-component
CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
// Or globally
ThemeData(shape: 4) // not directly — use per-component themes
```

### Elevation

M3 uses relative distance along the z-axis. All surfaces and components have elevation values.

#### M3 elevation model
- **Surface tint** (color overlay) instead of shadows — `surfaceTint` on components indicates elevation
- **5 surface tonal variations** — `Surface1` through `Surface5`, calculated on-the-fly from elevation overlay color
- Elevation overlay on Android: `elevationOverlayColor` (defaults to `colorPrimary`) applied at alpha based on elevation

#### Default elevation values
| Component | Default elevation |
|---|---|
| Card | 1dp |
| Bottom sheet | 1dp |
| FAB | 6dp |
| Dialog | 6dp |
| App bar (scrolled) | 4dp |
| Navigation bar | 3dp |
| Snackbar | 6dp |
| Dropdown menu | 8dp |

#### In Flutter
```dart
// M3 pattern — disable shadow, use surfaceTint
CardThemeData(elevation: 0, surfaceTintColor: Colors.transparent)
// Restore M2 shadow behavior
ThemeData(colorScheme: scheme.copyWith(surfaceTint: Colors.transparent))
```

### Motion

Use motion to make UI expressive and easy to use. M3 transitions guide users as they navigate.

#### M3 motion principles
- **Responsive** — feels alive, acknowledges interaction immediately
- **Expressive** — reinforces brand personality
- **Transitional** — helps users understand spatial relationships
- **Intentional** — every animation has purpose

#### Motion types
- **Container transform** — elements morph between states (FAB to details screen)
- **Shared axis** — navigation between sibling screens (forward/backward along axis)
- **Fade through** — for unrelated screens
- **Fade** — simple content fade

#### In Flutter
```dart
// Page transitions
PageRouteBuilder(
  pageBuilder: (_, __, ___) => NextScreen(),
  transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
  transitionDuration: const Duration(milliseconds: 250),
)

// Implicit animations
AnimatedContainer, AnimatedOpacity, AnimatedPadding, AnimatedPositioned
// Explicit animations
AnimationController, Tween, AnimationBuilder
```

### Icons

Material Symbols are a set of variable icon fonts created at seven weights across three styles.

#### Icon weight/style matrix
| Weight | Outlined | Rounded | Sharp |
|---|---|---|---|
| 100 (Thin) | ✓ | ✓ | ✓ |
| 200 (ExtraLight) | ✓ | ✓ | ✓ |
| 300 (Light) | ✓ | ✓ | ✓ |
| 400 (Regular) | ✓ | ✓ | ✓ |
| 500 (Medium) | ✓ | ✓ | ✓ |
| 600 (SemiBold) | ✓ | ✓ | ✓ |
| 700 (Bold) | ✓ | ✓ | ✓ |

#### In Flutter
```dart
// Material icons (default filled style)
Icon(Icons.favorite)
// Different weight via OpticalSize or use IconButton variants
// For variable weight icons, use the material_symbols package
```

---

## useMaterial3 Flag

`ThemeData.useMaterial3` — `true` by default. When `true`, these defaults change:

| Property | M3 default | M2 default |
|---|---|---|
| `colorScheme` | M3 baseline light/dark scheme | M2 baseline light/dark scheme |
| `typography` | `Typography.material2021` | `Typography.material2014` |
| `splashFactory` | `InkSparkle` (Android non-web) or `InkRipple` | `InkSplash` |

Setting `useMaterial3: true` on a *constructed* ThemeData updates these defaults.
`ThemeData.copyWith(useMaterial3: true)` does **not** re-apply them — set explicitly.

### All widgets affected by useMaterial3

Badge, BottomAppBar, BottomSheet, all buttons (ElevatedButton, FilledButton, FilledButton.tonal, OutlinedButton, TextButton, FAB, IconButton variants, SegmentedButton), Card, Checkbox, all Chips (ActionChip, FilterChip, ChoiceChip, InputChip), DatePicker, Dialogs (AlertDialog, Dialog.fullscreen), Divider/VerticalDivider, ListTile, Menus (MenuAnchor, DropdownMenu, MenuBar), NavigationBar, NavigationDrawer, NavigationRail, Progress indicators, Radio, SearchBar/SearchAnchor, SnackBar, Slider/RangeSlider, Switch, TabBar/TabBar.secondary, TextField/InputDecoration, TimePicker, AppBar/SliverAppBar (medium/large), MaterialScrollBehavior (stretch overscroll).

## M2 vs M3 Key Differences

| Area | Material 2 | Material 3 |
|---|---|---|
| **Color generation** | `ColorScheme.light(primary: Colors.blue)` — manual | `ColorScheme.fromSeed(seedColor: Colors.blue)` — auto-generates accessible palette |
| **Elevation** | Drop shadows (`elevation`, `shadowColor`) | `surfaceTint` overlay + optional shadow |
| **Navigation indicators** | Rectangular | Pill-shaped, rounded |
| **AppBar** | Standard only | Standard, Medium, Large variants |
| **Tabs** | Single variant | Primary + `TabBar.secondary`, `TabAlignment` |
| **Background** | `Colors.grey[50]!` / `Colors.grey[850]!` | New M3 colors; restore via `copyWith(background: ...)` |
| **Color roles** | 12 roles | 45+ roles (surface variants, containers, inverse, scrim, shadow) |
| **Shape** | Fixed per component | Shape scale: none/xs/sm/med/lg/xl, applied per component family |
| **Icons** | Single weight/style | 7 weights × 3 styles (Material Symbols variable fonts) |
| **Motion** | Basic transition | Container transform, shared axis, fade through, fade |

## Widget Replacements (Must Migrate)

| M2 (old) | M3 (new) |
|---|---|
| `BottomNavigationBar` + `BottomNavigationBarItem` | `NavigationBar` + `NavigationDestination` |
| `Drawer` + `ListTile` | `NavigationDrawer` + `NavigationDestination` |
| `ToggleButtons` + `isSelected: List<bool>` | `SegmentedButton<T>` + `selected: Set<T>` |
| `ElevatedButton` used `primary`/`onPrimary` colors | Uses new M3 color mapping (use `FilledButton` for old look) |
| Default `Card` shadow-based elevation | Card uses `surfaceTint` |


## Navigation & Routing

### Navigator (imperative, stack-based)
```dart
Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SecondScreen()));
Navigator.of(context).pop();
```
Best for simple apps without complex deep linking.

### Named routes (not recommended for most apps)
```dart
Navigator.pushNamed(context, '/second');
// Declared in MaterialApp.routes
```
**Limitations:** can't customize deep-link behavior, no browser forward button support.

### Router (declarative, recommended)
Use routing packages like `go_router` for advanced navigation, deep linking, and web support:
```dart
MaterialApp.router(routerConfig: myGoRouter);
context.go('/second');
```
Packages like `go_router` are declarative — same screen(s) always shown for a given deep link. Integrates with browser History API on web.

### Router + Navigator together
- **Page-backed routes** (from `Router`/`Navigator.pages`) — deep-linkable
- **Pageless routes** (`Navigator.push`, `showDialog`) — not deep-linkable
- Removing a page-backed route removes all subsequent pageless routes

## Complete M3 Component Catalog

M3 defines 30+ components organized into 6 categories by purpose. Each has a dedicated page on m3.material.io/components.

### Action — initiate or commit an action

| Component | M3 page | Flutter class | Notes |
|---|---|---|---|
| **Buttons** (Text, Elevated, Filled, Filled tonal, Outlined) | /components/buttons | `TextButton`, `ElevatedButton`, `FilledButton`, `FilledButton.tonal`, `OutlinedButton` | FilledButton ≈ old M2 ElevatedButton look |
| **Floating action button** | /components/floating-action-button | `FloatingActionButton` | Key action always in reach |
| **Extended FAB** | /components/floating-action-button | `FloatingActionButton.extended` | Wider with text label |
| **Icon button** | /components/icon-buttons | `IconButton`, `IconButton.filled`, `IconButton.filledTonal`, `IconButton.outlined` | 4 M3 variants |
| **Segmented button** | /components/segmented-buttons | `SegmentedButton<T>` | Replaces M2 `ToggleButtons` |
| **Button groups** ✦ | /components/button-groups | Not yet in Flutter | New M3 Expressive — standard + connected variants |
| **Split button** ✦ | (Expressive) | Not yet in Flutter | Primary action + related menu with shape morphing |

### Communication — show status, feedback, or messages

| Component | M3 page | Flutter class | Notes |
|---|---|---|---|
| **Badge** | /components/badges | `Badge` | Dynamic content (counts, status) on navigation icons |
| **Progress indicators** | /components/progress-indicators | `LinearProgressIndicator`, `CircularProgressIndicator` | Determinate + indeterminate |
| **Snackbar** | /components/snackbars | `SnackBar` | Use `SnackBarBehavior.floating` for M3 look |
| **Banner** | /components/banners | Not in Flutter core | Prominent message with optional actions |

### Containment — group and separate content

| Component | M3 page | Flutter class | Notes |
|---|---|---|---|
| **Card** | /components/cards | `Card` | `elevation: 0, surfaceTintColor: transparent` |
| **Dialog** (basic + full-screen) | /components/dialogs | `AlertDialog`, `Dialog.fullscreen` | Larger radius, no shadow, `surfaceTint` |
| **Divider** | /components/dividers | `Divider`, `VerticalDivider` | Thin line grouping content |
| **List** | /components/lists | `ListTile` | New segmented variant in M3 Expressive |
| **Bottom sheet** | /components/bottom-sheets | `BottomSheet`, `showBottomSheet` | Use `showDragHandle: true` |
| **Toolbar (docked)** ✦ | /components/toolbar | Not yet in Flutter | M3 Expressive — docked action bar at screen bottom |

### Navigation — move between screens and views

| Component | M3 page | Flutter class | Notes |
|---|---|---|---|
| **App bar** (small, medium flexible, large flexible) | /components/app-bars | `AppBar`, `SliverAppBar.medium`, `SliverAppBar.large` | Renamed from "top app bar"; flexible variants replace medium/large |
| **Search app bar** ✦ | /components/app-bars | `SearchBar`, `SearchAnchor` | M3 Expressive — opens search view on selection |
| **Bottom app bar** | /components/app-bars | `BottomAppBar` | Actions at bottom of screen |
| **Navigation bar** | /components/navigation-bar | `NavigationBar` + `NavigationDestination` | Replaces M2 `BottomNavigationBar`; flexible variant in M3 Expressive |
| **Navigation drawer** | /components/navigation-drawer | `NavigationDrawer` + `NavigationDestination` | Replaces M2 `Drawer` + `ListTile` |
| **Navigation rail** | /components/navigation-rail | `NavigationRail` | For tablet/desktop; collapsed/expanded |
| **Tab bar** | /components/tabs | `TabBar`, `TabBar.secondary` | Primary + secondary variants, `TabAlignment` |

### Selection — let users choose options

| Component | M3 page | Flutter class | Notes |
|---|---|---|---|
| **Checkbox** | /components/checkboxes | `Checkbox`, `CheckboxListTile` | Three-state support |
| **Chips** (assist, filter, input, suggestion, elevated) | /components/chips | `Chip`, `InputChip`, `FilterChip`, `ChoiceChip`, `ActionChip` | Elevation variants in M3 Expressive |
| **Date picker** (docked, modal, modal input) | /components/date-pickers | `DatePickerDialog`, `showDatePicker`, `InputDatePickerFormField` | Docked replaces "desktop", modal replaces "mobile" |
| **Menu** | /components/menus | `MenuAnchor`, `DropdownMenu`, `MenuBar`, `PopupMenuButton` | Cascading menus, combo-box style |
| **Radio button** | /components/radio-buttons | `Radio`, `RadioListTile` | Single selection from a set |
| **Slider** | /components/sliders | `Slider`, `RangeSlider` | Continuous or discrete values |
| **Switch** | /components/switches | `Switch`, `SwitchListTile` | Toggle single item on/off |
| **Time picker** | /components/time-pickers | `TimePickerDialog`, `showTimePicker` | Analog + digital input modes |

### Text input — let users enter text

| Component | M3 page | Flutter class | Notes |
|---|---|---|---|
| **Text field** | /components/text-fields | `TextField` + `InputDecoration` | Filled + outlined variants |
| **Dropdown menu** | (see Menus) | `DropdownMenu` | Combo-box: text field + menu |

✦ = New in M3 Expressive (May 2025)

## M3 Theme Pattern

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness).harmonized(),
  fontFamily: GoogleFonts.inter().fontFamily,
  scaffoldBackgroundColor: scheme.surface,
  appBarTheme: AppBarTheme(
    centerTitle: true,
    backgroundColor: scheme.surface,
    foregroundColor: scheme.onSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 1,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  ),
  navigationBarTheme: NavigationBarThemeData(
    elevation: 0,
    height: 80,
    backgroundColor: scheme.surfaceContainerLow,
    surfaceTintColor: Colors.transparent,
    indicatorColor: scheme.secondaryContainer,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  bottomSheetTheme: BottomSheetThemeData(
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    showDragHandle: true,
  ),
  dialogTheme: DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  ),
  floatingActionButtonTheme: FloatingActionButtonThemeData(
    shape: const CircleBorder(),
    backgroundColor: scheme.primaryContainer,
    foregroundColor: scheme.onPrimaryContainer,
    elevation: 4,
  ),
)
```

## Restoration Patterns

Restore M2 background: `ColorScheme.fromSeed(seedColor: c).copyWith(background: Colors.grey[50]!)`
Disable surface tint: `.copyWith(surfaceTint: Colors.transparent)`
Restore M2 button colors: `ElevatedButton.styleFrom(backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary)`
Restore M2 letter spacing: `Theme.of(context).textTheme.bodyMedium!.copyWith(letterSpacing: 0.0)`

## Kotlin for Android (Build Context)

Kotlin is the primary language for Android development (Kotlin-first since Google I/O 2019). Relevant for Flutter Android builds:

- **Kotlin Gradle Plugin (KGP)** is applied by Flutter plugins like `dynamic_color`, `file_picker`, `mobile_scanner`, `share_plus`
- Android build files (`build.gradle.kts` or `build.gradle`) use Kotlin or Java
- Jetpack Compose is Android's modern native UI toolkit (Kotlin-based)
- Kotlin Multiplatform allows sharing code across Android, iOS, backend, web
- Over 50% of professional Android devs use Kotlin as primary language; apps built with Kotlin crash 20% less
- Interoperable with Java — can mix both in a project

### Key links
- Kotlin for Android overview: https://kotlinlang.org/docs/android-overview.html
- Android Kotlin docs: https://developer.android.com/kotlin
- Jetpack Compose: https://developer.android.com/jetpack/compose
- Kotlin Multiplatform: https://kotlinlang.org/multiplatform/

## Material 3 Expressive

**Not a new version (not M4)** — an evolution of M3 that adds emotional impact through visual design and interaction. Announced May 2025.

### Core tactics
- **Color** — bolder, more varied palettes; expanded use of color to create hierarchy and mood
- **Shape** — more distinctive container shapes (squircle, pill, asymmetric) to draw attention
- **Size** — larger, more prominent primary actions; better visual weight distribution
- **Motion** — expressive physics-based animations (wiggle loaders, shape morphing, rotation)
- **Containment** — explicit containers around key actions instead of relying on whitespace alone

### Research-backed (46 studies, 18,000+ participants)
- Expressive designs preferred by all age groups
- Score higher on playfulness, energy, creativity, friendliness
- Users more likely to switch to products using expressive components
- Key UI elements spotted up to **4x faster** (e.g. send button in email app)

### New/updated components
- **Split Button** — primary action + related menu, shape morphing and rotation animations
- **Expressive progress indicators** — wiggle/spinner variants with more character
- **Updated cards, dialogs, bottom sheets** — more shape and color options
- Container tactics for buttons, lists, and navigation elements

### How it relates to Flutter
- Alpha code available for **Jetpack Compose** (Android native)
- Flutter Material library will adopt expressive components over time
- Expressive tactics can be applied today via custom `ThemeData` (shape, color, motion)
- See updated Figma Design Kit for exploration

### Links
- Blog post: https://m3.material.io/blog/building-with-m3-expressive
- Research deep-dive: https://design.google/library/expressive-material-design-google-research
- Design Notes podcast: https://design.google/library/design-notes-material-3-expressive-liam-spradlin
- Google IO session: https://io.google/2025/explore/technical-session-24

## Docs Reference

- Material 3 spec: https://m3.material.io/get-started
- M3 styles hub: https://m3.material.io/styles
- M3 color system: https://m3.material.io/styles/color/system/overview
- M3 color roles: https://m3.material.io/styles/color/roles
- M3 dynamic color: https://m3.material.io/styles/color/dynamic
- M3 typography: https://m3.material.io/styles/typography
- M3 shape: https://m3.material.io/styles/shape/overview-principles
- M3 elevation: https://m3.material.io/styles/elevation
- M3 motion: https://m3.material.io/styles/motion
- M3 icons: https://m3.material.io/styles/icons
- Material 3 components catalog: https://m3.material.io/components
- Flutter widget catalog: https://docs.flutter.dev/ui/widgets/material
- Flutter navigation: https://docs.flutter.dev/ui/navigation
- Flutter typography: https://docs.flutter.dev/ui/design/text/typography
- M3 migration guide: https://docs.flutter.dev/release/breaking-changes/material-3-migration
- useMaterial3 API: https://api.flutter.dev/flutter/material/ThemeData/useMaterial3.html
- Flutter API docs: https://api.flutter.dev
- Kotlin for Android: https://kotlinlang.org/docs/android-overview.html
