# lib/shared/services/tray_service.dart

`TrayService` is the desktop system-tray singleton described in
[../../../platform-notes.md](../../../platform-notes.md): Show/Quit menu, minimize-to-tray,
close-to-tray, and macOS dock-icon visibility via a method channel.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`TrayService._`](#trayservice-new) | private constructor | A | Back the `TrayService.instance` singleton. |
| `minimizeToTray` | getter | B | Current minimize-to-tray preference. |
| `closeToTray` | getter | B | Current close-to-tray preference. |
| [`init`](#init) | method | A | Initialize the window/tray managers from persisted settings. |
| [`_setupTray`](#setuptray) | method | A | Set the tray icon/tooltip and build the context menu. |
| [`_rebuildMenu`](#rebuildmenu) | method | A | Rebuild the localized tray context menu. |
| [`setMinimizeToTray`](#setminimizetotray) | method | A | Update and persist the minimize-to-tray preference. |
| [`setCloseToTray`](#setclosetotray) | method | A | Update and persist the close-to-tray preference. |
| [`updateLocale`](#updatelocale) | method | A | Update the locale used for menu labels and rebuild the menu. |
| `onTrayIconMouseDown` | method (`TrayListener`) | B | Show the window on tray-icon left click. |
| `onTrayIconRightMouseDown` | method (`TrayListener`) | B | Pop up the tray context menu. |
| [`onTrayMenuItemClick`](#ontraymenuitemclick) | method (`TrayListener`) | A | Handle Show/Quit menu selections. |
| [`onWindowClose`](#onwindowclose) | method (`WindowListener`) | A | Hide-to-tray or destroy the window on close. |
| [`onWindowMinimize`](#onwindowminimize) | method (`WindowListener`) | A | Hide-to-tray on minimize, if enabled. |
| [`_showWindow`](#showwindow) | method | A | Restore dock visibility and show/focus the window. |
| [`_setDockIconVisible`](#setdockiconvisible) | static method | A | Toggle macOS Dock icon visibility via a method channel. |

## Documentation

### `TrayService._()` <a id="trayservice-new"></a>
- **Kind:** private unnamed constructor of `TrayService` (with `TrayListener, WindowListener`).
- **Source:** `lib/shared/services/tray_service.dart` (line 17).
- **Purpose:** Back the module-level singleton `TrayService.instance`.
- **Inputs:** None.
- **Returns:** A new `TrayService`.
- **Side effects:** None (state is set up later in `init`, not the constructor).
- **Algorithm:** Empty body; `static final TrayService instance = TrayService._()` eagerly
  constructs the singleton at class-load time.
- **Usage:** Never called directly; access via `TrayService.instance`.
- **Notes:** Unlike `AppFlavor._`/`AppTheme._` (pure static-only holders), `TrayService` mixes in
  `TrayListener`/`WindowListener`, so the private constructor here also exists to make the
  singleton the sole instance that can register as those listeners.

### `Future<void> init()` <a id="init"></a>
- **Kind:** method of `TrayService`.
- **Source:** `lib/shared/services/tray_service.dart` (line 45).
- **Purpose:** One-time initialization of the window manager, tray icon, and persisted
  minimize/close-to-tray preferences.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads `storage_config.json` via `DeviceStorage.readConfig()`; initializes
  `window_manager`/`tray_manager`; registers `this` as both a `WindowListener` and
  `TrayListener`.
- **Algorithm:** No-op if already initialized or not on Windows/macOS/Linux. Read
  `minimizeToTray`/`closeToTray` from config (default `false`); `windowManager.ensureInitialized()`,
  add self as a window listener, `setPreventClose(_closeToTray)`; `_setupTray()`; add self as a
  tray listener; mark initialized.
- **Usage:** Called once from `main()` (see [../../main.md](../../main.md)) on desktop platforms.
- **Notes:** Guarded by `_initialized` so a second call is a no-op.

### `Future<void> _setupTray()` <a id="setuptray"></a>
- **Kind:** method of `TrayService`.
- **Source:** `lib/shared/services/tray_service.dart` (line 68).
- **Purpose:** Set the tray icon and tooltip, then build the initial context menu.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** `trayManager.setIcon`/`setToolTip`; calls `_rebuildMenu`.
- **Algorithm:** Pick `.ico` on Windows, `.png` otherwise; set tooltip to `'MyDevice!!!!!'`;
  `_rebuildMenu()`.
- **Usage:** Called once from `init`.
- **Notes:** None.

### `Future<void> _rebuildMenu()` <a id="rebuildmenu"></a>
- **Kind:** method of `TrayService`.
- **Source:** `lib/shared/services/tray_service.dart` (line 82).
- **Purpose:** (Re)build the tray's context menu with localized "Show"/"Quit" labels for the
  current `_locale`.
- **Inputs:** None (reads `_locale`).
- **Returns:** `Future<void>`.
- **Side effects:** `trayManager.setContextMenu`.
- **Algorithm:** `lookupAppLocalizations(_locale)`, build a two-item menu (`show`, a separator,
  `quit`) with localized labels, and install it via `trayManager.setContextMenu`.
- **Usage:** Called from `_setupTray` and from `updateLocale` when the locale changes while
  already initialized.
- **Notes:** Uses `lookupAppLocalizations` directly (not `AppLocalizations.of(context)`) since the
  tray has no `BuildContext`.

### `Future<void> setMinimizeToTray(bool value)` <a id="setminimizetotray"></a>
- **Kind:** method of `TrayService`.
- **Source:** `lib/shared/services/tray_service.dart` (line 99).
- **Purpose:** Update and persist the minimize-to-tray preference.
- **Inputs:** `value`.
- **Returns:** `Future<void>`.
- **Side effects:** Updates `_minimizeToTray`; reads/writes `storage_config.json`.
- **Algorithm:** Set the field; read config, set `config['minimizeToTray'] = value`, write it back.
- **Usage:** Called from the settings page's tray-behavior toggles.
- **Notes:** Read-modify-write on the whole config map, same pattern as `setCloseToTray`.

### `Future<void> setCloseToTray(bool value)` <a id="setclosetotray"></a>
- **Kind:** method of `TrayService`.
- **Source:** `lib/shared/services/tray_service.dart` (line 111).
- **Purpose:** Update and persist the close-to-tray preference, and apply it to the window
  manager immediately.
- **Inputs:** `value`.
- **Returns:** `Future<void>`.
- **Side effects:** Updates `_closeToTray`; reads/writes `storage_config.json`;
  `windowManager.setPreventClose(value)`.
- **Algorithm:** Set the field; persist via read-modify-write; immediately call
  `windowManager.setPreventClose(value)` so the new behavior takes effect without a restart.
- **Usage:** Called from the settings page's tray-behavior toggles.
- **Notes:** Unlike `setMinimizeToTray`, this one also has an immediate runtime effect
  (`setPreventClose`) beyond persisting the preference.

### `Future<void> updateLocale(Locale locale)` <a id="updatelocale"></a>
- **Kind:** method of `TrayService`.
- **Source:** `lib/shared/services/tray_service.dart` (line 124).
- **Purpose:** Update the locale used for tray menu labels and rebuild the menu if already
  initialized.
- **Inputs:** `locale`.
- **Returns:** `Future<void>`.
- **Side effects:** Updates `_locale`; conditionally calls `_rebuildMenu`.
- **Algorithm:** Set `_locale`; `if (_initialized) await _rebuildMenu()`.
- **Usage:** Called when the app's locale changes (e.g. from `AppSettingsNotifier.setLocale`) so
  the tray menu's language stays in sync with the rest of the UI.
- **Notes:** No-ops (safely) if the tray hasn't been initialized yet.

### `void onTrayMenuItemClick(MenuItem menuItem)` <a id="ontraymenuitemclick"></a>
- **Kind:** method of `TrayService` (`TrayListener` override).
- **Source:** `lib/shared/services/tray_service.dart` (line 157).
- **Purpose:** Handle a click on the tray context menu.
- **Inputs:** `menuItem`.
- **Returns:** None.
- **Side effects:** `'show'` calls `_showWindow()`; `'quit'` disables prevent-close and calls
  `windowManager.close()`.
- **Algorithm:** `switch (menuItem.key)`: `'show'` → `_showWindow()`; `'quit'` →
  `windowManager.setPreventClose(false)` then `windowManager.close()`.
- **Usage:** Invoked by `tray_manager` when the user clicks a menu item.
- **Notes:** Quit explicitly disables prevent-close first so a `closeToTray`-configured window
  actually closes instead of hiding again.

### `void onWindowClose()` <a id="onwindowclose"></a>
- **Kind:** method of `TrayService` (`WindowListener` override).
- **Source:** `lib/shared/services/tray_service.dart` (line 177).
- **Purpose:** Implement the close-to-tray behavior: hide instead of quitting when enabled.
- **Inputs:** None (reads `_closeToTray`).
- **Returns:** None.
- **Side effects:** `windowManager.hide()` + `_setDockIconVisible(false)`, or
  `windowManager.destroy()`.
- **Algorithm:** If `_closeToTray`, hide the window and hide the macOS dock icon; otherwise
  destroy the window (a real quit).
- **Usage:** Invoked by `window_manager` when the window's close button is pressed (only
  reachable when `setPreventClose(true)` is in effect, i.e. `closeToTray` is on).
- **Notes:** None.

### `void onWindowMinimize()` <a id="onwindowminimize"></a>
- **Kind:** method of `TrayService` (`WindowListener` override).
- **Source:** `lib/shared/services/tray_service.dart` (line 192).
- **Purpose:** Implement minimize-to-tray: hide the window (instead of the normal OS minimize)
  when enabled.
- **Inputs:** None (reads `_minimizeToTray`).
- **Returns:** None.
- **Side effects:** `windowManager.hide()` + `_setDockIconVisible(false)` when enabled.
- **Algorithm:** `if (_minimizeToTray) { hide(); _setDockIconVisible(false); }` — otherwise the
  normal OS minimize proceeds untouched.
- **Usage:** Invoked by `window_manager` on a minimize event.
- **Notes:** None.

### `void _showWindow()` <a id="showwindow"></a>
- **Kind:** method of `TrayService`.
- **Source:** `lib/shared/services/tray_service.dart` (line 206).
- **Purpose:** Restore the window from a tray-hidden state: show the dock icon (macOS), show the
  window, and focus it.
- **Inputs:** None.
- **Returns:** `void`.
- **Side effects:** `_setDockIconVisible(true)`; `windowManager.show()`/`.focus()`.
- **Algorithm:** Three sequential calls, no branching of its own (the platform check lives inside
  `_setDockIconVisible`).
- **Usage:** Called from `onTrayIconMouseDown` (left-click) and `onTrayMenuItemClick`'s `'show'`
  case.
- **Notes:** None.

### `static void _setDockIconVisible(bool visible)` <a id="setdockiconvisible"></a>
- **Kind:** static method of `TrayService`.
- **Source:** `lib/shared/services/tray_service.dart` (line 217).
- **Purpose:** Toggle the macOS Dock icon's visibility via a native method channel; a no-op on
  other platforms.
- **Inputs:** `visible`.
- **Returns:** `void`.
- **Side effects:** Invokes the `com.yuanzhe.my_device/dock` method channel's
  `setDockIconVisible` method (macOS only).
- **Algorithm:** Early-return if `!Platform.isMacOS`; otherwise
  `_dockChannel.invokeMethod('setDockIconVisible', {'visible': visible})`.
- **Usage:** Called from `onWindowClose`, `onWindowMinimize`, and `_showWindow`.
- **Notes:** The Dart side does not await the method channel call's result — it's fire-and-forget.
