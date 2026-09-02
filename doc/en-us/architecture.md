# Architecture

This page covers the app shell, navigation, state management, theming, localization, and
overall repository layout of MyDevice!!!!!. For data-level details see
[Data Formats](data-formats.md); for the sync engine see [WebDAV Sync](sync.md).

## Entry point: `lib/main.dart`

`main()` performs startup work before `runApp()`:

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. On desktop (`Platform.isWindows || Platform.isMacOS || Platform.isLinux`, never on
   web): sets up `launch_at_startup` with the resolved package name/executable path.
3. On the same desktop platforms: starts the local API server (`LocalApiServer.start()`).
4. On the same desktop platforms: initializes the system tray (`TrayService.instance.init()`).
5. Fires `BackupService.runAutoBackupIfNeeded()` (fire-and-forget, once-per-day auto-backup).
6. Fires `DeviceExchangeRateService.refreshIfNeeded()` for automatic exchange-rate updates.
7. Starts `AutoSyncService.instance.start()`, the lifecycle observer that drives
   auto-sync triggers (see [WebDAV Sync](sync.md)).
8. Calls `runApp()`, wrapping `MyDeviceApp` in `DevicePreview` (enabled only in debug
   builds) and a Riverpod `ProviderScope`.

## App shell: `lib/app/`

- **`app.dart`** — `MyDeviceApp`, a `ConsumerWidget` that watches `appSettingsProvider`
  and builds a `MaterialApp.router`. It wires theme mode, locale, supported locales, and
  `routerConfig: appRouter` together. The app title is literally `'MyDevice!!!!!'`.
- **`router.dart`** — `appRouter` is a `GoRouter` with `initialLocation: '/devices'` and a
  single `ShellRoute` wrapping a `ShellScaffold`. Five tab routes live inside that shell,
  reached from a bottom `NavigationBar` on windows narrower than 600 logical pixels and from a
  side `NavigationRail` on wider ones — a width-only decision made by `useNavigationRail` in
  `lib/shared/utils/adaptive_layout.dart` (see [Adaptive Layout](adaptive-layout.md)). Every
  other page is pushed on the root navigator above the shell:

  | Path | Page |
  | --- | --- |
  | `/devices` | `DeviceListPage` |
  | `/services` | `ServiceListPage` |
  | `/network` | `NetworkListPage` |
  | `/datasets` | `DataSetListPage` |
  | `/settings` | `SettingsPage` |

- **`theme.dart`** — `AppTheme.light` / `AppTheme.dark` are built with
  `flex_color_scheme`'s `FlexThemeData`, both using `FlexScheme.blue`,
  `FlexSurfaceMode.levelSurfacesLowScaffold`, Material 3, and
  `NavigationDestinationLabelBehavior.onlyShowSelected` for the bottom nav bar. Light uses
  `blendLevel: 7` / `blendOnLevel: 10`; dark uses `blendLevel: 13` / `blendOnLevel: 20`.
- **`flavor.dart`** — `AppFlavor` reads a compile-time `FLAVOR` dart-define
  (`String.fromEnvironment('FLAVOR', defaultValue: 'full')`). `AppFlavor.isStore` is true
  only when the define is exactly `'store'`; `AppFlavor.isFull` is its negation. See
  [Online Search and Presets](features/online-search-and-presets.md) for how this gates
  online search.

## State management

State management uses `flutter_riverpod` throughout (`ProviderScope` at the root,
`ConsumerWidget`/`ConsumerStatefulWidget` in pages, providers such as
`appSettingsProvider` in `lib/shared/providers/app_settings.dart`). New code should not
introduce `Provider` or `Bloc`.

## Localization (l10n)

The app supports four languages: English, Japanese, Simplified Chinese, and Traditional
Chinese, confirmed by the ARB files under `lib/l10n/`:

- `app_en.arb` (template)
- `app_ja.arb`
- `app_zh.arb` (Simplified)
- `app_zh_TW.arb` (Traditional)

Generated localization classes (`AppLocalizations` and per-locale subclasses) live
alongside them under `lib/l10n/`. Regenerate with `flutter gen-l10n` after editing the
template ARB.

## Repository structure

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
    services/
      models/service.dart
      services/service_storage.dart
      services/service_template_service.dart
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
      sync_progress.dart
      sync_wake_lock.dart
      tray_service.dart
      webdav_service.dart
    utils/json_preservation.dart
    views/device_map_page.dart
    views/webdav_config_page.dart
    widgets/
  l10n/
```

(Adapted from `AGENTS.md`; `lib/shared/widgets/map_picker_page.dart` and
`lib/features/devices/widgets/device_avatar.dart` also live under those directories —
see [Map](features/map.md) and [Devices](features/devices.md).)

## Shared package (`myapps_data`)

The WebDAV sync engine, backup engine, ZIP transfer engine, and auto-sync scheduler are **not in this
repo**. They live in the shared `myapps_data` package, embedded at `packages/myapps_data` as a git
submodule and consumed as a pub path dependency. MyAnime, MyDay, and MyDevice all use it, which is
what keeps their wire format, backup format, and lock semantics interoperable.

- **What stays here:** all models, the per-feature storage hubs, the per-module merge wrappers,
  `mergeAssignments`, the Markdown export, and every page.
- **What moved:** the transport, lock lifecycle, merge pipeline, `.sync_base` snapshots, image sync,
  backup bundle and blob store, ZIP allowlist, and sync scheduling.
- **The seam:** [`functions/app/data_modules.md`](functions/app/data_modules.md) declares the
  `StorageAdapter` over `DeviceStorage` plus one `DataModule` per data file. It is the single source
  of truth for data-file names and backup module keys.
- **The facades:** `WebDAVService`, `BackupService`, `ImportExportService`, and `AutoSyncService`
  keep their previous public APIs and delegate to the package. Their shapes are deliberately frozen
  so call sites and tests keep working; behavior changes belong in the package.
- **MyDevice-specific knob:** the backup engine is built with `syntheticImagesModule: true`, which is
  what makes `images` a selectable restore module here and not in the other two apps.

`.gitmodules` uses the relative URL `../MyApps-DATA.git`, so it resolves against whichever remote a
clone tracks — Gitea clones fetch from Gitea, GitHub clones from GitHub, and no host name is ever
committed. Fresh clones need `git clone --recurse-submodules` or `git submodule update --init`.

## Core architecture rules

- Navigation uses `go_router` with a `ShellRoute` for the five tabs listed above.
- The visual system uses Material 3 via `flex_color_scheme`.
- Every width or height decision — whether a layout may split, where navigation lives, how many
  columns fit, how tall a dialog may be — goes through `lib/shared/utils/adaptive_layout.dart`. A
  widget file that compares a size against a number is a bug. See
  [Adaptive Layout](adaptive-layout.md).
- File I/O goes through `DeviceStorage.getAppDir()` so a user-configured custom storage
  path (`storage_config.json`) is always honored.
- JSON output is pretty-printed with `JsonEncoder.withIndent('  ')`.
- Optional null/empty fields are omitted from JSON via conditional map entries (e.g.
  `if (notes != null) 'notes': notes`), not written as explicit `null`.
- Every model's `modifiedAt` is written as `DateTime.now().toUtc()`. Local-time
  `modifiedAt` values break cross-timezone sync conflict detection; old data written in
  local time still parses, but new writes must be UTC. See [Data Formats](data-formats.md).
- Unknown/forward-compatible JSON fields are preserved via the `extraJson` pattern
  (`lib/shared/utils/json_preservation.dart`) so an older app build never silently drops
  fields a newer build wrote. See [Data Formats](data-formats.md#extrajson-unknown-field-preservation).

## Where to go next

- [Data Formats](data-formats.md) for every model's exact fields and the persisted-data
  inventory.
- [WebDAV Sync](sync.md) for how records merge across devices.
- [Backup and Restore](backup-restore.md) for local backup/restore and ZIP/Markdown
  export.
- [Platform Notes](platform-notes.md) for Windows/macOS/iOS/Android-specific behavior and
  the desktop API/tray/startup integration.
