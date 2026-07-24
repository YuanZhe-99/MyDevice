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
- **Usage:** Never called; `AppFlavor.isFull`/`AppFlavor.isStore` are read directly as static
  constants throughout the devices feature (search gating) and settings UI.
- **Notes:** `_flavor` resolves at compile time from `String.fromEnvironment('FLAVOR',
  defaultValue: 'full')`, so flavor selection is a `--dart-define` build-time constant, not a
  runtime setting.
