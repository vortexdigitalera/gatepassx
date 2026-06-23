---
name: project-rebrand
description: Use when rebranding or pivoting a multi-component project (Python + Flutter) across all layers — data models, QR payloads, app icons, CI workflows, and platform identity — while preserving backward compatibility.
---

# Project Rebrand / Domain Pivot

When pivoting a project from one domain to another (e.g., Hajj/Umrah → Dinner & Events), follow this layered approach to ensure consistency and catch all references.

## Procedure

### 1. Plan the Data Model Migration First
- List all field renames (`operator` → `organizer`, `trip_type` → `event_type`)
- List all enum changes (old values → new values, added/removed values)
- List all new fields being added
- Decide on backward-compat strategy (e.g., legacy field mapping in `fromJson`/CSV import)
- Rename environment variables (`AHUON_QR_SECRET` → `GATEPASSX_QR_SECRET`)
- Rename storage keys (`ahuon_passes` → `gpx_passes`)

### 2. Work Bottom-Up Through the Stack
Execute changes in this order so each layer builds on the one below:

1. **Python models** — enums, field names, validators, `get_qr_secret()` helper
2. **Python generator** — PDF layout, brand colors, text strings
3. **Python CLI** — commands, help text, legacy field coercion in CSV/JSON import
4. **Python utils / __init__** — env var references, exports
5. **Flutter model** — match Python model exactly, add `fromJson` legacy mapping
6. **Flutter services** — config (env var), storage (key names)
7. **Flutter screens** — UI text, category color maps, field references
8. **Flutter main.dart** — app title, theme colors, branding
9. **Sample data** — replace domain-specific CSV/JSON with new domain data
10. **Docs / README / .env.example** — full rewrite for new domain
11. **Scripts** — CI, build, signing (search for old org name)
12. **Tests** — update to use new model fields

### 3. Legacy Compatibility Mapping
In import/deserialization code, map old field names to new ones silently:
```python
# Python CLI
if "operator" in item and "organizer" not in item:
    item["organizer"] = item.pop("operator")
if "trip_type" in item and "event_type" not in item:
    item["event_type"] = EventType(mapping.get(item["trip_type"].upper(), ...))
```
```dart
// Flutter fromJson
final organizer = json['organizer'] ?? json['operator'] ?? json['org'] ?? 'Unknown';
final etStr = norm(json['event_type'] ?? json['eventType'] ?? json['trip_type'] ?? 'DINNER');
```

### 4. Brand Color Palette Swap
Replace the old palette with the new one consistently across:
- PDF generator color constants
- Flutter `ThemeData` / `ColorScheme`
- Flutter screen category color maps
- Scanner overlay corner/line colors
- QR code eye/module colors

### 5. Grep Sweep for Residual References
After all changes, grep for old domain terms across all source files:
```
grep -r "OLD_NAME|old_field|OLD_ENUM" --include="*.{py,dart,json,csv,sh,md,yml}"
```
Fix any hits. Intentional backward-compat references in import logic are acceptable.

### 6. Verify at Each Layer
- **Python**: Run `--help`, then test `generate`, `validate`, `scan`, `info` commands
- **Flutter**: Run `flutter analyze` (0 errors), then `flutter test`
- **Integration**: Export JSON from Flutter → import in Python CLI → generate PDF (round-trip test)

### 7. Update Tests
Tests will reference old model fields and enum values. Rewrite them to use the new model, and add a specific test for legacy field deserialization to ensure backward compat works.

## Compact QR Payload with HMAC Integrity

When the QR payload must stay small (for fast scanning) but tamper-evident, use compact keys in the JSON:

```python
# Python side
base = {
    "pid": self.pass_id,
    "ev": self.event_name,
    "nm": self.full_name,
    "cat": self.category,
    "idn": self.id_number,
    "org": self.organizer,
    "vf": self.valid_from.isoformat(),
    "vt": self.valid_to.isoformat(),
    "gt": self.gate or "",
}
if self.table_number:
    base["tbl"] = self.table_number
if self.group_ref:
    base["grp"] = self.group_ref

# HMAC signature
sig = hmac.new(secret.encode(), json.dumps(base, sort_keys=True).encode(), hashlib.sha256).hexdigest()[:16]
base["sig"] = sig
payload = json.dumps(base, separators=(",", ":"))
```

```dart
// Flutter side — must produce identical output
final hmac = Hmac(sha256, utf8.encode(secret));
final sig = hmac.convert(utf8.encode(jsonEncode(data))).toString().substring(0, 16);
```

**Critical:** Both sides must use `sort_keys=True` (Python) / default key order (Dart `jsonEncode`), same secret, same sha256 truncation length. Any divergence breaks verification.

## CLI Command Structure for Artifact Generators

For tools that generate physical artifacts (PDFs, QR codes, badges) from structured data, this command set covers the common workflows:

| Command | Purpose |
|---------|---------|
| `generate` | Batch produce artifacts from a data file (CSV/JSON/YAML) |
| `new` | Interactively create a single record (outputs JSON) |
| `validate` | Check a record file's signature/integrity |
| `scan` | Verify a raw QR payload string from terminal |
| `qr` | Generate standalone QR image from a record |
| `template` | Output a blank template file for bulk import |
| `info` | Show statistics of a data file |

### 8. Mobile Platform Identity Rename (Android + iOS)

When changing the app name and package/bundle ID, touch these files:

**Android:**
| File | What to change |
|------|---------------|
| `android/app/build.gradle` | `namespace = "com.new.package"` and `applicationId = "com.new.package"` |
| `android/app/src/main/AndroidManifest.xml` | `android:label="NewAppName"` |
| `android/app/src/main/kotlin/com/old/package/MainActivity.kt` | Move to new package directory, update `package` declaration |

Steps:
```bash
mkdir -p android/app/src/main/kotlin/com/new/package
# Write new MainActivity.kt with updated package declaration
rm -rf android/app/src/main/kotlin/com/old/package
```

**iOS:**
| File | What to change |
|------|---------------|
| `ios/Runner.xcodeproj/project.pbxproj` | All `PRODUCT_BUNDLE_IDENTIFIER` values (appears in Debug/Release/Profile configs + RunnerTests) |
| `ios/Runner/Info.plist` | `CFBundleDisplayName`, `CFBundleName`, and any description strings mentioning old brand |

Use `replace_all` when editing `project.pbxproj` — the old bundle ID appears in multiple build configurations.

### 9. Programmatic App Icon Generation (Python/PIL)

When no icon asset is provided, generate all platform icons from a single Python script:

```python
from PIL import Image, ImageDraw

SIZE = 1024
img = Image.new('RGB', (SIZE, SIZE), (26, 26, 46))  # base color
draw = ImageDraw.Draw(img)

# Gradient background
for y in range(SIZE):
    t = y / SIZE
    r = int(15 + (26 - 15) * t)
    draw.line([(0, y), (SIZE-1, y)], fill=(r, r, int(35 + (46-35)*t)))

# Rounded rect mask
mask = Image.new('L', (SIZE, SIZE), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE-1, SIZE-1], radius=int(SIZE*0.18), fill=255)
img.putalpha(mask)

# Draw brand element (letter, logo, etc.) on a separate RGBA layer, then composite
d_layer = Image.new('RGBA', (SIZE, SIZE), (0,0,0,0))
# ... draw on d_layer ...
img = Image.alpha_composite(img.convert('RGBA'), d_layer)
```

**Android sizes** (mipmap directories under `res/`):
| Density | Size |
|---------|------|
| mdpi | 48×48 |
| hdpi | 72×72 |
| xhdpi | 96×96 |
| xxhdpi | 144×144 |
| xxxhdpi | 192×192 |

**iOS sizes** (all in `Assets.xcassets/AppIcon.appiconset/`):
20@1x/2x/3x, 29@1x/2x/3x, 40@1x/2x/3x, 60@2x/3x, 76@1x/2x, 83.5@2x, 1024@1x

**Critical iOS note:** iOS icons must NOT have alpha — flatten onto a solid background before saving:
```python
ios_img = Image.new('RGBA', (size, size), (255, 255, 255, 255))
ios_img = Image.alpha_composite(ios_img, resized)
ios_img = ios_img.convert('RGB')  # strip alpha
ios_img.save(path, 'PNG')
```

### 10. SVG Logo → Multi-Platform App Icons

When a user provides an SVG logo, convert it to all required PNG sizes using `cairosvg` + PIL:

```bash
pip install cairosvg
```

```python
import cairosvg
from PIL import Image, ImageDraw
import io

svg_data = open('logo.svg', 'rb').read()
master_png = cairosvg.svg2png(bytestring=svg_data, output_width=1024, output_height=1024)
master = Image.open(io.BytesIO(master_png)).convert('RGBA')

def make_app_icon(master_img, size, bg_color=(10, 61, 61)):
    bg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(bg)
    r = int(size * 0.18)
    draw.rounded_rectangle([0, 0, size-1, size-1], radius=r, fill=bg_color + (255,))
    pad = int(size * 0.12)
    logo_size = size - 2 * pad
    logo = master_img.resize((logo_size, logo_size), Image.LANCZOS)
    bg.paste(logo, (pad, pad), logo)
    return bg
```

**Critical:** Always render the SVG at 1024×1024 first (master), then scale down. The SVG viewBox and any `transform` attributes are handled by cairosvg automatically.

Also register the SVG as a Flutter asset in `pubspec.yaml` for in-app use:
```yaml
flutter:
  assets:
    - assets/icons/logo.svg
```

### 11. GitHub Actions Workflow Audit After Rebrand

After renaming a project, CI/CD workflows will contain stale artifact names, release titles, and package filenames. Audit checklist:

1. **Grep all workflow files** for old brand names: `grep -rn "OldName\|old-name\|old_name" .github/workflows/`
2. **Update artifact naming patterns** — e.g., `oldname-android-*.apk` → `newname-android-*.apk`
3. **Update release titles** — e.g., `--title "OldName $VERSION"` → `--title "NewName $VERSION"`
4. **Update upload-artifact `name:` and `path:` fields** to match new naming
5. **Validate YAML syntax** with Python: `yaml.safe_load()` on each workflow file
6. **Test locally:**
   - CI workflow: run `flutter pub get && flutter analyze --no-fatal-infos && flutter test`
   - Release packaging: simulate the packaging step (cp + zip) and verify the artifact works
   - Verify packaged artifacts are functional (unzip + run CLI + check output)

### 12. CI SDK Version Sync After Package Upgrades

When upgrading Flutter/Dart packages (especially major bumps like `flutter_lints` 4→6, `google_fonts` 7→8), the local environment may have a newer Flutter SDK than what's pinned in CI workflows. This causes `flutter pub get` to fail in CI with errors like:

```
Because flutter_lints 6.0.0 requires SDK version ^3.8.0 and no versions of flutter_lints match >6.0.0 <7.0.0, flutter_lints ^6.0.0 is forbidden.
```

**Fix:** Check the local Flutter version (`flutter --version`) and update `FLUTTER_VERSION` in all workflow files to match:

```yaml
# .github/workflows/ci.yml (and release.yml, ios-build.yml, etc.)
env:
  FLUTTER_VERSION: '3.44.3'  # must match local environment
```

**Procedure:**
1. Run `flutter pub outdated` to see available upgrades
2. Update `pubspec.yaml` constraints (avoid beta versions — pin back to stable if `--major-versions` picks a beta)
3. Run `flutter pub upgrade` to update transitive deps in the lock file
4. Verify locally: `flutter analyze` + `flutter test`
5. Check local SDK version: `flutter --version`
6. Update `FLUTTER_VERSION` env var in ALL workflow files to match
7. Commit and push — monitor CI with `gh run watch`

**Dependency conflict gotcha:** Some packages have cross-dependencies that prevent upgrading. E.g., `share_plus ^13` requires `cross_file ^0.3.5` which conflicts with `file_picker ^11`. When this happens, keep the older version of the conflicting package rather than forcing a beta.

### 13. Monitoring CI with `gh` CLI

After pushing, use the GitHub CLI to monitor workflow runs without leaving the terminal:

```bash
# List recent runs
gh run list --limit 5

# Watch a specific run until it completes (blocks until done)
gh run watch <RUN_ID> --exit-status

# Get failure logs for a specific run
gh run view <RUN_ID> --log-failed

# Re-run a failed workflow
gh run rerun <RUN_ID>
```

**Typical flow after a push:**
1. `gh run list` → find the run ID for your commit
2. `gh run watch <ID> --exit-status` → wait for completion
3. If failed: `gh run view <ID> --log-failed | tail -40` → diagnose
4. Fix locally, commit, push → repeat

### 14. Triggering Workflows with `gh` — Branch Selection Gotcha

When using `gh workflow run` to manually trigger a workflow, it **defaults to the repo's default branch** (usually `main`). If your changes are on a feature branch, you MUST pass `--ref`:

```bash
# ❌ WRONG — runs from main, builds old code
gh workflow run "Build and Release" --field version="v22.0.0-beta"

# ✅ CORRECT — runs from dev branch with your changes
gh workflow run "Build and Release" --ref dev --field version="v22.0.0-beta"
```

The release will appear successful, but the artifacts will contain the OLD code from `main`. Always verify the run's branch in `gh run view <ID>` output.

### 15. Cleaning Up Stale Release Assets After Re-runs

When you re-trigger a release workflow (e.g., to fix a build from wrong branch), the `--clobber` flag in `gh release upload` replaces same-named assets, but OLD assets from the previous run remain. Clean them up:

```bash
# List current assets
gh release view <TAG> --json assets --jq '.assets[].name'

# Delete stale assets by name
gh release delete-asset <TAG> old-asset-name.apk --yes
```

### 16. `gh` Authentication — `GITHUB_TOKEN` Env Var Override

In Codespaces and CI environments, a `GITHUB_TOKEN` environment variable may be set that overrides `gh` auth. To use a different PAT:

```bash
# Unset the env var first, then authenticate
unset GITHUB_TOKEN
echo "github_pat_..." | gh auth login --with-token

# For git push operations, configure gh as the credential helper
gh auth setup-git
git push origin dev
```

Without `gh auth setup-git`, git push will try the stale socket-based credential helper and fail with "Missing or invalid credentials".

## Key Gotchas
- Category color maps in Flutter screens must be updated for new enum values (missing entries = default color)
- `pubspec.yaml` description field often contains the old brand name
- Test files are easily missed — they'll fail with `undefined_enum_constant` or `undefined_named_parameter`
- Storage key renames cause data loss for existing users (consider migration logic if needed)
- Environment variable renames require updating both Python AND Flutter config classes
- QR payload format changes break cross-platform verification — if you change keys, update BOTH sides simultaneously and test the round-trip
- Android `MainActivity.kt` directory path MUST match the `namespace` in build.gradle — mismatched paths cause `ClassNotFoundException` at runtime
- iOS `project.pbxproj` has the bundle ID in 3 build configs (Debug, Release, Profile) + RunnerTests — use global replace
- When generating icons, always start from a 1024×1024 master and scale down with `Image.LANCZOS` for sharp results
- The `Info.plist` camera/microphone permission descriptions (`NSCameraUsageDescription`) often contain the old brand name — easy to miss
- After a rename, search ALL user-visible strings: share text, `issued_by` fields, snackbar messages, export filenames
- GitHub Actions workflow files are easy to forget — they live in `.github/workflows/` and contain artifact names, release titles, and packaging dir names
- When updating `project.pbxproj`, use `replace_all: true` — the old bundle ID appears in multiple `XCBuildConfiguration` blocks
- `cairosvg` needs `libcairo2` system library — install with `apt-get install libcairo2-dev` if not present
- SVG files with `transform="matrix(-1, 0, 0, 1, 0, 0)"` (horizontal flip) render correctly through cairosvg — no manual handling needed
- After updating workflows, always validate YAML with `yaml.safe_load()` before pushing — a syntax error in CI YAML silently disables the workflow
- Simulate release packaging locally (`cp + zip`) and verify the zip contents are functional (unzip + run) before relying on the CI pipeline
- `flutter pub upgrade --major-versions` can pick beta/pre-release versions — always check and pin back to stable
- After upgrading packages, the CI `FLUTTER_VERSION` env var MUST match the local SDK version or `pub get` will fail in CI with "SDK version forbidden" errors
- The `flutter_lints` package version is tightly coupled to the Dart SDK — `^6.0.0` needs Dart `^3.8.0`, `^5.0.0` needs Dart `^3.4.0`
- When CI fails with "version solving failed", the fix is usually to bump `FLUTTER_VERSION` in the workflow, not downgrade packages
- `gh run watch` blocks the terminal — useful for scripting but remember it exits with non-zero on failure (`--exit-status`)
- `gh workflow run` defaults to the repo's default branch — always pass `--ref <branch>` when triggering from a feature/dev branch
- After re-running a release workflow, old assets from the previous run persist — use `gh release delete-asset` to clean up
- In Codespaces, `GITHUB_TOKEN` env var overrides `gh` auth — use `unset GITHUB_TOKEN` before `gh auth login --with-token`, then `gh auth setup-git` for git push
