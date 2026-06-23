---
name: flutter-multi-agent-audit
description: Parallel multi-agent Flutter app audit methodology — three specialized agents for code quality, Android config, and UX/responsiveness, with systematic auto-fix workflow
source: auto-skill
extracted_at: '2026-06-23T17:31:23.323Z'
---

# Flutter Multi-Agent App Audit

Systematic methodology for comprehensive Flutter app auditing using three parallel specialized agents, followed by prioritized auto-fix.

## Architecture

Launch **three agents simultaneously** using the `agent` tool, each with a distinct focus:

```
Agent 1: Dart Code Quality   → All files under lib/
Agent 2: Android Config      → build.gradle, manifest, signing, pubspec
Agent 3: UX & Responsiveness → All screen files + main.dart
```

Each agent reads all relevant files completely and returns issues with severity ratings.

## Agent 1: Dart Code Quality

**Files:** Every `.dart` file under `lib/` (models, services, screens, widgets, main).

**Prompt template:**
```
You are analyzing a Flutter app. Do a THOROUGH code review of ALL Dart files under lib/.
Read every file completely.

Look for:
1. Bugs: Logic errors, null safety issues, unhandled edge cases, race conditions
2. Performance: Unnecessary rebuilds, missing const, expensive ops in build()
3. Memory leaks: Undisposed controllers, listeners, streams
4. Data issues: Serialization bugs, missing error handling in JSON parse
5. Navigation issues: Back button handling, tab state preservation
6. Accessibility: Missing semantics, contrast issues, touch targets
7. Best practices: Dart/Flutter conventions, state management

For each issue provide: File path + line, Severity (CRITICAL/HIGH/MEDIUM/LOW),
Category, Description, Suggested fix (concrete code).
```

**Common findings to watch for:**
- `AnimationController` passed to `showModalBottomSheet(transitionAnimationController:)` is never disposed → memory leak per sheet open
- Storage load-modify-save without mutex → race condition on rapid operations
- `_savePass` called in a loop during import, each triggering full reload → O(N²)
- `jsonDecode()` without try/catch → crash on malformed input
- `ShareParams(text: filePath)` shares a string, not the file → use `files: [XFile(path)]`
- `DateTime.tryParse(...) ?? DateTime.now()` for validTo → date-only strings parse to midnight, making passes expire a day early. Fix: set to end-of-day `DateTime(y, m, d, 23, 59, 59)`
- `_scanRect!` force-unwrap before layout completes → null crash on first frame
- `setReleaseMode()` called every scan instead of once in `initState`
- In-place mutation of model objects passed by reference → state corruption if save fails
- Duplicate scans incrementing counters → only increment for `PassScanStatus.valid`, not `duplicate`

## Agent 2: Android Config & Build

**Files:** `build.gradle` (app + root), `AndroidManifest.xml`, `settings.gradle`, `gradle.properties`, `pubspec.yaml`, signing configs.

**Prompt template:**
```
Analyze the Android configuration and build setup. Look for:
1. Build issues: SDK mismatches, deprecated APIs
2. Security: Hardcoded secrets, insecure permissions, exported components
3. Performance: Missing ProGuard/R8, oversized APK
4. Compatibility: minSdk/targetSdk, permission declarations
5. Icon/branding: Launcher icon config, adaptive icons
6. Signing: Config completeness, debug vs release
```

**Common findings:**
- Missing `INTERNET` permission in main manifest (only in debug)
- Release signing silently falls back to debug key → should fail explicitly
- No `minifyEnabled`/`shrinkResources` in release build type
- `compileSdk` set to unreleased API level
- `targetSdk` using Flutter variable instead of explicit value

## Agent 3: UX & Responsiveness

**Files:** All screen files + main.dart.

**Prompt template:**
```
Do a thorough UX and responsiveness review. Analyze:
1. Responsiveness: phones (320-420dp), tablets (600dp+), foldables
2. Touch targets: all interactive elements ≥48x48dp?
3. Empty/error/loading states
4. Scroll behavior, keyboard handling
5. Dark mode: hardcoded colors that break contrast
6. Typography: font sizes <11sp are unreadable
7. Animation performance: forever-repeating nested animations
```

**Common findings:**
- Status chip rows overflow on 320dp screens → use `Wrap` or `FittedBox`
- Nested `AnimatedBuilder` (forever pulse) inside `TweenAnimationBuilder` → rebuilds every frame forever
- `TweenAnimationBuilder` on every list item replays on search → jarring
- Hardcoded `Colors.green`/`Colors.orange` break contrast in dark mode
- Scanner back button under 48dp touch target
- No `errorBuilder` on `MobileScanner` → black screen on permission denied
- No loading indicator during async save/import → user double-taps creating duplicates

## Auto-Fix Workflow

1. **Aggregate** all findings from three agents
2. **Deduplicate** — multiple agents may report the same issue
3. **Prioritize** by severity: CRITICAL → HIGH → MEDIUM → LOW
4. **Fix in order** using `edit` tool (targeted edits, not full rewrites)
5. **Run `flutter analyze`** after each batch of fixes
6. **Fix any new analysis issues** introduced by the fixes
7. **Commit** with descriptive message listing all fixes
8. **Push and rebuild** if CI/CD is configured

## Fix Priority Rules

| Severity | Action |
|---|---|
| CRITICAL | Fix immediately — crashes, data loss, memory leaks |
| HIGH | Fix in same session — broken features, security gaps |
| MEDIUM | Fix if straightforward — UX issues, perf improvements |
| LOW | Document as suggestions — style preferences, minor optimizations |

## Pitfalls

- Don't rewrite entire files for icon changes — use targeted `edit` calls
- `cross_file` package import is unnecessary if `share_plus` is already imported (XFile is re-exported)
- When fixing `AnimatedSwitcher` + `IndexedStack`, just remove the `AnimatedSwitcher` entirely — it never triggers because `IndexedStack` doesn't change widget identity
- After fixing `validTo` end-of-day, verify that `isExpired` / `isActive` boundary logic still works correctly
- Always add `mounted` check after any `await` before calling `setState` or animation controllers
- When fixing in-place mutation, create a new object copy with `..qrPayload = original.qrPayload` to preserve computed fields
