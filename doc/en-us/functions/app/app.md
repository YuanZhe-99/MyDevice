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
