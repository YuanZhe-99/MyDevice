# lib/app/flavor.dart

Defines `AppFlavor`, the build-flavor gate described in [../../architecture.md](../../architecture.md)
and this repo's `AGENTS.md` Build Flavors table. `store`-flavor builds must hide online device/chip
search; `full`-flavor builds (GitHub Releases, sideload, desktop installers) show it.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`AppFlavor._`](#appflavor-new) | private constructor | A | Prevent instantiation; `AppFlavor` is static-only. |
| `isStore` | static const getter | B | Whether this build was compiled with `--dart-define=FLAVOR=store`. |
| `isFull` | static const getter | B | The logical negation of `isStore`. |
| `deviceSearchExposed` | static const getter | B | Whether the "Fetch Device Info" search is offered in the UI; currently equals `isFull`. |

`deviceSearchExposed` gates only the UI entry points — the editor's search button
(`device_edit_page.dart`) and the device list's search shortcut (`device_list_page.dart`). The
service, parsers, fixtures and tests stay in every build, so setting it to `false` is the switch for
the day every search source stops answering; `DeviceSearchService` and `ChipSearchService` keep
their own `isStore`/`isFull` guards.

## Documentation

### `AppFlavor._()` <a id="appflavor-new"></a>
- **Kind:** private unnamed constructor of `AppFlavor`.
- **Source:** `lib/app/flavor.dart` (line 11).
- **Purpose:** Make `AppFlavor` a non-instantiable, static-only holder class for the compile-time
  flavor flag.
- **Inputs:** None.
- **Returns:** N/A (the constructor is private and never called).
- **Side effects:** None.
- **Algorithm:** No body; its only role is to be private, which prevents `AppFlavor()` from
  compiling anywhere outside this file.
- **Usage:** Never called; `AppFlavor.isFull`/`AppFlavor.isStore`/`AppFlavor.deviceSearchExposed`
  are read directly as static constants throughout the devices feature (search gating) and
  settings UI.
- **Notes:** `_flavor` resolves at compile time from `String.fromEnvironment('FLAVOR',
  defaultValue: 'full')`, so flavor selection is a `--dart-define` build-time constant, not a
  runtime setting.
