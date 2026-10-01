# lib/app/app.dart

Defines `MyDeviceApp`, the root widget: wires theme, locale, and routing into a
`MaterialApp.router`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `MyDeviceApp` constructor | constructor | B | Create the root app widget. |
| `build` | method (`MyDeviceApp`) | B | Build the `MaterialApp.router` with theme/locale/routing wired in. |

## Documentation

Both declarations are Tier B: the constructor is a trivial `const` widget constructor, and `build`
is pure widget composition (reads `appSettingsProvider` for theme mode and locale, wires
`AppTheme.light`/`AppTheme.dark`, `AppLocalizations.supportedLocales`/`localizationsDelegates`, and
`appRouter` from [../router.md](router.md) into `MaterialApp.router`) with no branching or I/O
of its own. See [../../architecture.md](../../architecture.md) for the app shell overview.

## Dynamic color (since 1.7.0)

`MyDeviceApp.build` wraps `MaterialApp.router` in `DynamicColorBuilder` (package `dynamic_color`). The
builder's wallpaper-derived (Material You) schemes are passed to `AppTheme.light(...)` /
`AppTheme.dark(...)` **only** when `!kIsWeb && defaultTargetPlatform == TargetPlatform.android`.
The gate exists because on Windows and macOS the plugin returns the system accent color, which would
replace the app's own blue seed; those platforms (and iOS, and Android 11 or older, where the plugin
returns no scheme) therefore use `ColorScheme.fromSeed(AppTheme.seedColor)`. `build` also reads
`settings.uiStyle` (`AppSettings.uiStyle`) and passes it as the second argument of both
`AppTheme.light(...)` and `AppTheme.dark(...)`, so changing the interface style rebuilds the theme at
once. All other `MaterialApp.router` arguments (locale, delegates, `DevicePreview.appBuilder`,
router) are unchanged. See [theme.md](theme.md) and [../../platform-notes.md](../../platform-notes.md).
