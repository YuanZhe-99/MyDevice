# AGENTS.md

This file is the operating guide for agents working on **MyDevice!!!!!**. Read it before editing anything, then read the relevant code and the user's request carefully. The user's message is the change request: plan the work, execute it in this workspace, verify it, and keep this document current when the project changes.

## Project Snapshot

- **Name:** MyDevice!!!!!, with five exclamation marks in user-facing app names, installer metadata, macOS bundle names, and window titles.
- **Description:** A privacy-first personal device inventory app for detailed hardware specs, network management, dataset organization, map locations, WebDAV sync, local backup, ZIP/Markdown export, desktop tray behavior, local API access, and lifecycle/finance tracking.
- **Author / package id:** `yuanzhe`, `com.yuanzhe.mydevice`.
- **License:** GPL-3.0.
- **Current version:** `0.4.0+11` in `pubspec.yaml`, `0.4.0.0` for MSIX, and `0.4.0` in `installer.iss`.
- **Framework:** Flutter with Dart SDK `^3.11.3`; CI uses Flutter `3.41.6`.
- **Platforms:** Windows, Android, iOS, macOS, with Linux/web project files present but not primary release targets.
- **Repository:** `C:\Users\yuanzhe\src\MyDevice`.
- **Remotes:**
  - `origin` -> `<local_gitea_address>`
  - `github` -> `git@github.com:YuanZhe-99/MyDevice.git`

Do not include secrets, credentials, personal device data, WebDAV credentials, signing keys, or generated private configuration in commits or in this file. Remote URLs and public project metadata are OK.

## Required Agent Workflow

1. Treat the user's message as the modification request.
2. Read this `AGENTS.md`, inspect the relevant source files, and understand the current behavior before editing.
3. Make a concise plan when the work is non-trivial, then implement the requested changes directly in the workspace.
4. Keep changes scoped. Do not revert unrelated user work in the tree.
5. Update `AGENTS.md` in the same change set whenever architecture, behavior, data formats, commands, release process, version locations, remotes, caveats, or project descriptions change. This document replaces the older role of an external summary and must stay current and complete.
6. Verify with the narrowest meaningful checks for the change, usually `flutter analyze` and relevant `flutter test` targets for Dart changes.
7. When the work is complete, report briefly in both English and Chinese:
   - what changed,
   - what was verified,
   - the current/pre-change version,
   - the configured remotes,
   - whether anything could not be done.
8. For normal code changes, ask whether the user wants to push to all remotes. The user must provide/confirm the release version before a release push.

## Release, Version, Commit, Tag, and Push Flow

For ordinary feature/fix work, do not bump versions or tag until the user confirms the release version and confirms pushing.

When the user confirms the version and wants to push:

1. Update every version location:
   - `pubspec.yaml`: `version: X.Y.Z+N` where `N` is the Flutter build number and increments for releases.
   - `pubspec.yaml`: `msix_config.msix_version: X.Y.Z.0`.
   - `installer.iss`: `AppVersion=X.Y.Z`.
   - `installer.iss`: both `OutputBaseFilename=MyDevice_X.Y.Z_Setup` and `OutputBaseFilename=MyDevice_X.Y.Z_arm64_Setup`.
   - Do not manually edit in-app version display; `settings_page.dart` reads `PackageInfo.fromPlatform()`.
2. Re-run appropriate verification.
3. Commit all intended changes.
4. Create an annotated tag named `vX.Y.Z`.
5. Push the commit to both `origin` and `github`.
6. Push the tag to both `origin` and `github`.

GitHub Actions release builds are triggered by tag pushes to `github`. Tags must be pushed explicitly, either with `git push <remote> <tag>` or an intentional `--tags`.

For documentation-only maintenance that the user explicitly says does not require a release, commit and push the documentation change to the requested remotes without changing versions or creating a tag.

## Build Flavors

Flavor logic lives in `lib/app/flavor.dart`.

| Flavor | Dart define | Online search | Distribution |
| --- | --- | --- | --- |
| `full` | `--dart-define=FLAVOR=full` | Enabled | GitHub Releases, sideload, APK, desktop installers |
| `store` | `--dart-define=FLAVOR=store` | Disabled | Google Play and App Store builds |

Online device/chip search must be fully gated for store builds. Check both service and UI paths:

- `lib/features/devices/services/device_search_service.dart`: `search()` and `fetchDetail()` return early for store.
- `lib/features/devices/services/chip_search_service.dart`: online CPU/GPU search is gated behind `AppFlavor.isFull`.
- `lib/features/devices/views/device_edit_page.dart`: three online search buttons are hidden for store.
- `lib/features/devices/views/device_list_page.dart`: online search FAB is hidden for store.

Any ungated online search path is an App Store rejection risk.

## Repository Structure

```text
lib/
  main.dart
  app/
    app.dart
    flavor.dart
    router.dart
    theme.dart
  features/
    devices/
      models/device.dart
      services/chip_search_service.dart
      services/device_search_service.dart
      services/device_storage.dart
      services/exchange_rate_service.dart
      services/preset_service.dart
      views/
      widgets/device_category_icon.dart
    network/
      models/network.dart
      services/network_storage.dart
      views/
    datasets/
      models/dataset.dart
      services/dataset_storage.dart
      views/
    settings/views/
  shared/
    providers/app_settings.dart
    services/
      auto_sync_service.dart
      backup_service.dart
      image_service.dart
      import_export_service.dart
      local_api_server.dart
      sync_merge.dart
      tray_service.dart
      webdav_service.dart
    utils/json_preservation.dart
    views/device_map_page.dart
    views/webdav_config_page.dart
    widgets/
  l10n/
```

Primary tests currently include:

- `test/device_finance_test.dart`
- `test/sync_unknown_fields_test.dart`
- `test/widget_test.dart`

The `tool/` directory contains ad hoc validation and source-testing scripts, especially around CPU/GPU scraping and preset data. Prefer focused tests for production behavior and keep tool scripts out of release-critical paths unless the user asks for them.

## Core Architecture

- State management uses `flutter_riverpod`; do not introduce Provider or Bloc for normal changes.
- Navigation uses `go_router` with a `ShellRoute` for four bottom tabs: Devices, Network, Datasets, Settings.
- The visual system uses Material 3 via `flex_color_scheme`.
- L10n supports English, Japanese, Simplified Chinese, and Traditional Chinese. The ARB template is `lib/l10n/app_en.arb`; generated localization files live under `lib/l10n/`.
- File I/O should go through `DeviceStorage.getAppDir()` so custom storage paths work.
- JSON output is pretty-printed with `JsonEncoder.withIndent('  ')`.
- Optional null/empty fields are usually omitted from JSON using conditional map entries.
- Model timestamps use `DateTime.now()` local time.
- Preserve unknown JSON fields with the existing `extraJson` pattern so older versions do not delete newer fields during normal saves or sync merges.

## Feature Areas

### Devices

The main device model is in `lib/features/devices/models/device.dart`. It tracks identity, category, emoji/image, brand/model/serial number, CPU, GPU, RAM, storage, display, battery, OS, location, purchase/release dates, lifecycle status, retirement/sale state, purchase price, sold price, recurring costs, notes, `modifiedAt`, and unknown JSON fields.

Important nested models and enums include `CpuInfo`, `GpuInfo`, `StorageInfo`, `StorageType`, `StorageInterface`, `RamType`, and `DeviceCategory`. Device categories include desktop, laptop, phone, tablet, headphone, watch, router, game console, VPS, dev board, and other.

Device lifecycle and finance were added in v0.4.0. Retired or sold devices must be removed from network assignments and dataset storage links, and excluded from network/storage pickers. Device detail and Markdown export should include lifecycle and finance information when relevant.

### Networks

Network data is in `lib/features/network/models/network.dart`.

- `Network`: `id`, `name`, `type`, `subnet`, `gateway`, `dnsServers`, `notes`, `modifiedAt`, plus unknown JSON fields.
- `NetworkType`: LAN, Tailscale, ZeroTier, EasyTier, WireGuard, other.
- `NetworkDevice`: assignment between a network and a device, with `networkId`, `deviceId`, address mode, IP address, hostname, `isExitNode`, and unknown JSON fields.

`NetworkDevice` intentionally has no `id` or `modifiedAt`. Its identity is the composite key `(networkId, deviceId)`, and sync compares serialized content against the base snapshot.

### Datasets

Dataset data is in `lib/features/datasets/models/dataset.dart`.

- `DataSet`: `id`, `name`, default emoji, storage links, `modifiedAt`, and unknown JSON fields.
- `DataSetStorageLink`: `deviceId` plus storage slot indices on that device.

Datasets link to device storage slots by index, so be careful when changing storage list behavior.

### Online Search and Presets

Full flavor can fetch device specs from GSMArena and Notebookcheck through `device_search_service.dart`, and chip specs from TechPowerUp, AMD, and Intel through `chip_search_service.dart`. Store flavor must not expose or execute online search.

Bundled presets are loaded by `preset_service.dart` from `assets/presets/`:

- `cpus.json`
- `gpus.json`
- `brands.json`
- `device_templates.json`

These are lazy-loaded and cached.

### Map

`device_map_page.dart` provides a read-only OpenStreetMap view of devices with coordinates. `map_picker_page.dart` provides the full-screen location picker and Nominatim search. The default center is Tokyo.

### Backup, Export, Import, and Images

- `backup_service.dart`: local auto-backup once per day, manual backups, retention, selective restore by module.
- `import_export_service.dart`: ZIP export/import for the three data JSON files plus `images/`; Markdown export for LLM-friendly text summaries.
- ZIP import must keep path traversal protection.
- `image_service.dart`: file picking, URL download, UUID filenames in `images/`, relative path resolution, deletion.

### Desktop API, Tray, and Startup

- `local_api_server.dart`: desktop-only Shelf server, default port `7789`.
- Endpoints include `GET /ping`, `GET /device/list(?category=)`, `GET /device/search?q=`, `POST /device/add`, and `GET /device/stats`.
- CORS is permissive. Basic auth is required when listening on non-localhost and optional on loopback. The server refuses unsafe non-localhost startup without credentials.
- `tray_service.dart`: system tray, Show/Hide, Quit, minimize-to-tray, close-to-tray, and macOS dock icon visibility through `com.yuanzhe.my_device/dock`.
- `launch_at_startup` handles desktop auto-start. macOS uses LaunchAtLogin-Modern via Swift Package Manager.

## WebDAV Sync Rules

WebDAV sync is per-record three-way merge, not whole-file replacement.

Flow:

1. Download remote JSON.
2. Load local JSON and `.sync_base/` base snapshots.
3. Merge per record using `modifiedAt` where available.
4. Auto-resolve when only one side changed.
5. Detect conflict when the same record changed on both sides after the last sync.
6. Upload merged data.
7. Save the new base snapshot.

Manual sync uses `autoResolve: false` and shows conflict dialogs. Auto-sync uses `autoResolve: true` and last-writer-wins per record without blocking the UI.

Important sync constraints:

- `device_data.json`: merge `Device` records by `id` and `modifiedAt`.
- `network_data.json`: merge `Network` records by `id` and `modifiedAt`; merge `NetworkDevice` assignments by composite key and content comparison.
- `dataset_data.json`: merge `DataSet` records by `id` and `modifiedAt`.
- Images sync additively, referenced-only, based on the union of `imagePath` basenames from local and remote device records. Orphan images should not be repeatedly uploaded/downloaded.
- `_syncing` prevents concurrent syncs.
- `_atomicWrite()` uses tmp-then-rename to avoid corrupting local files.
- Each data file merge has per-file error handling so one malformed file does not block other files.
- Local files are re-read after network I/O to detect concurrent user edits during sync.
- Sync errors and image warnings should be visible in dialogs, not only snackbars.

Auto-sync triggers include app launch, app resume, a 30-second debounce after storage saves, and a 15-minute timer while the app process is alive. Mobile OS suspension may delay timers until resume. Storage-layer `save()` methods should notify auto-sync so non-UI writes are covered.

## Persisted Data Inventory

Default app data directory is `Documents/MyDevice` on desktop or the platform app documents directory on mobile. Custom storage paths are stored in `storage_config.json`; path changes migrate data files, backups, and images.

| Data | File | Synced | Merge strategy |
| --- | --- | --- | --- |
| Devices | `device_data.json` | Yes | Per-record by `id` and `modifiedAt` |
| Networks | `network_data.json` | Yes | Per-record by `id` and `modifiedAt` |
| Network assignments | `network_data.json` | Yes | Composite key plus content comparison |
| Datasets | `dataset_data.json` | Yes | Per-record by `id` and `modifiedAt` |
| Images | `images/` | Yes | Referenced-only filename comparison |
| Theme, locale, backup settings, sort preferences, default currency, exchange-rate settings | `storage_config.json` | No | Local preference |
| WebDAV credentials | `webdav_config.json` | No | Local secret/config only |
| Sync base snapshots | `.sync_base/*.json` | No | Local merge tracking |
| Backups | `backups/*.json` | No | Local recovery |
| Exchange-rate cache | `exchange_rates.json` | No | Local cache/fallback data |

Cross-reference rules:

- Deleting a device must remove related network assignments and dataset storage links.
- Retiring or selling a device should also remove it from assignments/links and pickers.
- Deleting a network filters assignments in `NetworkStorage.deleteNetwork()`.
- Deleting a dataset deletes its contained storage links.
- Sync merge does not currently run full cross-reference validation after merging; this is a known limitation.

## Platform Caveats

### Windows

- Inno Setup installer is defined in `installer.iss`; output goes to `build/installer/`.
- The installer creates Start Menu shortcuts. Do not create shortcuts programmatically.
- App icon: `windows/runner/resources/app_icon.ico`.
- MSIX configuration is in `pubspec.yaml` under `msix_config` with `internetClient`.

### macOS

- App name is `MyDevice!!!!!` in `macos/Runner/Configs/AppInfo.xcconfig`.
- Deployment target is `13.0`, required for LaunchAtLogin-Modern.
- LaunchAtLogin-Modern is added via Swift Package Manager in `project.pbxproj`.
- `MainFlutterWindow.swift` has a `launch_at_startup` method channel for startup enablement.
- `AppDelegate.swift` keeps the app alive when the last window closes and exposes the dock visibility method channel.
- Both `DebugProfile.entitlements` and `Release.entitlements` must include `com.apple.security.network.client` and `com.apple.security.network.server`; without them, sandboxed network requests and the local API server break.
- App icons are generated with `flutter_launcher_icons`; keep the macOS section in `flutter_launcher_icons.yaml`.

### iOS

- `CFBundleDisplayName` is `MyDevice!!!!!` in `Info.plist`.
- HTTPS network access needs no special entitlement.
- App Store IPA requires signing/provisioning and is not built by CI.

### Android

- `android/app/build.gradle.kts` should use `import java.util.Properties`.
- Use `kotlin { jvmToolchain(17) }`, not deprecated `kotlinOptions`.
- Keystore properties should use nullable casts such as `as String?`.
- Core library desugaring is enabled.
- Signing is optional locally via `key.properties`; CI uses GitHub Secrets.

## CI/CD

`.github/workflows/build.yml` runs on `v*` tag pushes and `workflow_dispatch`.

Jobs:

- Android APK full flavor and AAB store flavor.
- Windows x64 full installer on `windows-latest`.
- Windows ARM64 full installer on `windows-11-arm`; this uses Flutter master because stable did not have an ARM64 engine for the noted workflow.
- iOS full sideload IPA without codesign.
- macOS full DMG via `create-dmg`.
- GitHub Release artifact upload on tag push.

Important workflow caveats:

- Keep workflow Flutter version aligned with the Dart SDK constraint.
- GitHub `secrets` cannot be used directly in step `if` expressions; route through job-level `env`.
- Windows ARM64 Inno output is controlled by `iscc /DARM64 installer.iss`.

## Useful Commands

```powershell
flutter pub get
flutter analyze
flutter test
flutter gen-l10n
flutter build apk --release --no-tree-shake-icons --dart-define=FLAVOR=full
flutter build appbundle --release --no-tree-shake-icons --dart-define=FLAVOR=store
flutter build windows --release --dart-define=FLAVOR=full
iscc installer.iss
iscc /DARM64 installer.iss
```

Use the narrowest relevant command set for verification. For model/sync changes, include targeted tests such as `flutter test test/sync_unknown_fields_test.dart` or `flutter test test/device_finance_test.dart`.

## Version History Reference

- `v0.1.0`: Initial device inventory, networks, datasets, map, online search, presets, original WebDAV sync, backup, ZIP import/export, four-language localization, custom storage path.
- `v0.1.1`: Store/full flavors, CI/CD, platform naming/icons, macOS network client entitlement, privacy/README updates.
- `v0.1.2`: Per-record three-way WebDAV merge with base snapshots and conflict dialogs.
- `v0.1.3`: Sync audit, cascade delete for device references, network notes l10n/UI improvements, version-location documentation.
- `v0.1.4`: Atomic sync writes, per-file errors, concurrent save detection, auto-sync UI callbacks, safer base saves.
- `v0.2.0`: Broad i18n cleanup for hardcoded UI strings and locale-aware date formatting.
- `v0.2.1`: Markdown export for LLM personalization.
- `v0.3.0`: Local API server, system tray, launch at startup, desktop settings, macOS platform changes.
- `v0.3.1`: Windows ARM64 CI fix, no app version bump.
- `v0.3.2`: Referenced-only image sync and improved sync error/warning reporting.
- `v0.3.3`: Periodic auto-sync, storage-layer save notifications, auto-sync UI refresh, unknown-field preservation.
- `v0.4.0`: Device lifecycle and finance tracking, exchange-rate support, financial overview, retired/sold cleanup, Markdown/detail finance output.
