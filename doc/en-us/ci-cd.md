# CI/CD and build commands

## Workflow

`.github/workflows/build.yml` runs on `v*` tag pushes and `workflow_dispatch`.

Every checkout step passes `submodules: recursive`. Without it `flutter pub get` fails on the missing
`packages/myapps_data` path dependency. The relative submodule URL resolves to the public GitHub copy
in CI, so the default `GITHUB_TOKEN` is sufficient.

## Jobs

| Job | Runner | Output | Notes |
| --- | --- | --- | --- |
| `android` | `ubuntu-latest` | APK (full) + AAB (store) | Java 17, optional signing secrets |
| `windows-x64` | `windows-latest` | Inno x64 installer | Stable Flutter `3.44.2`, `iscc installer.iss` |
| `windows-arm64` | `windows-11-arm` | Inno ARM64 installer | Flutter master for the ARM64 engine, `iscc /DARM64 installer.iss` |
| `ios` | `macos-latest` | Sideload IPA | Release, no codesign |
| `macos` | `macos-latest` | DMG | Uses `create-dmg` |

GitHub Release artifacts are uploaded on tag push.

## Workflow caveats

- Keep the workflow Flutter version aligned with the Dart SDK constraint.
- GitHub `secrets` cannot be used directly in step `if` expressions; route them through job-level
  `env`.
- Windows ARM64 Inno output is controlled by `iscc /DARM64 installer.iss`.
- Action versions: `actions/checkout@v7`, `actions/setup-java@v5`, `actions/upload-artifact@v7`,
  `actions/download-artifact@v8`, `softprops/action-gh-release@v3` (bumped from the Node 20-based
  majors GitHub deprecated). Validate workflow changes with a `workflow_dispatch` run before the next
  tag release.
- Known remaining warning: the Android job still prints Flutter's "plugins that apply KGP" warning
  for `package_info_plus`, `share_plus`, `shared_preferences_android`, `wakelock_plus`, and
  `file_picker`. The app side is already migrated (AGP 9.1.1, no app-level `kotlin-android`); the
  remaining warning is plugin-side only and, as of 2026-07, even the latest releases of those plugins
  still apply KGP. Full elimination requires flipping `android.builtInKotlin=true` once every plugin
  ships Built-in Kotlin support; verify with real APK/AAB builds when attempting it.

## Commands

```powershell
flutter pub get
flutter analyze
flutter test
flutter gen-l10n
dart run tool/generate_ios_icons.dart
dart run flutter_launcher_icons
dart run tool/validate_ios_icons.dart --clean
flutter build apk --release --no-tree-shake-icons --dart-define=FLAVOR=full
flutter build appbundle --release --no-tree-shake-icons --dart-define=FLAVOR=store
flutter build windows --release --dart-define=FLAVOR=full
iscc installer.iss
iscc /DARM64 installer.iss
```

Use the narrowest relevant command set for verification. For model or sync changes, include targeted
tests such as `flutter test test/sync_unknown_fields_test.dart` or
`flutter test test/device_finance_test.dart`.

## Fresh clone

The shared engine package is a git submodule, so a plain `git clone` leaves `packages/myapps_data`
empty and `flutter pub get` fails:

```bash
git clone --recurse-submodules <app-url>
# or, after a plain clone:
git submodule update --init
```
