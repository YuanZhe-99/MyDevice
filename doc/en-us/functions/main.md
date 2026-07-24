# lib/main.dart

The app's entry point: initializes desktop-only startup services (launch-at-startup, the local
API server, the system tray) before running the widget tree, and kicks off fire-and-forget
background tasks (auto-backup, exchange-rate refresh, the auto-sync lifecycle observer).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`main`](#main) | top-level function | A | App entry point: desktop startup wiring, then `runApp`. |

## Documentation

### `void main() async` <a id="main"></a>
- **Kind:** top-level function.
- **Source:** `lib/main.dart` (line 22).
- **Purpose:** Perform desktop-only startup wiring and launch the Flutter app.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Calls `WidgetsFlutterBinding.ensureInitialized()`; on Windows/macOS/Linux,
  configures `launch_at_startup` and starts `LocalApiServer` and `TrayService`; calls
  `BackupService.runAutoBackupIfNeeded()`, `DeviceExchangeRateService.refreshIfNeeded()`, and
  `AutoSyncService.instance.start()`; runs the widget tree via `runApp`.
- **Algorithm:**
  1. Ensure the Flutter binding is initialized.
  2. On desktop platforms (`!kIsWeb` and Windows/macOS/Linux), read `PackageInfo` and configure
     `launch_at_startup` with the app name and resolved executable path.
  3. On the same desktop platforms, `await LocalApiServer.start()` (a no-op if the API server is
     disabled in settings — see [shared/services/local_api_server.md](shared/services/local_api_server.md)).
  4. On the same desktop platforms, initialize the system tray via `TrayService.instance.init()`.
  5. Fire-and-forget `BackupService.runAutoBackupIfNeeded()` and
     `DeviceExchangeRateService.refreshIfNeeded()` (neither is awaited before `runApp`).
  6. Start the auto-sync lifecycle observer, `AutoSyncService.instance.start()`.
  7. `runApp` wraps `MyDeviceApp` in a `ProviderScope` and `DevicePreview` (enabled only in debug
     mode).
- **Usage:** Called once by the Flutter engine at process start; not called from anywhere in app
  code.
- **Notes:** The three desktop-only steps intentionally gate on the same platform check
  (`!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)`) so mobile builds skip
  launch-at-startup, the local API server, and the tray entirely.
