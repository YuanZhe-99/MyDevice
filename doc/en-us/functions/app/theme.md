# lib/app/theme.dart

Defines `AppTheme`, the app's Material 3 light/dark theme via `flex_color_scheme`
(`FlexScheme.blue`), matching the visual system described in
[../../architecture.md](../../architecture.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`AppTheme._`](#apptheme-new) | private constructor | A | Prevent instantiation; `AppTheme` is static-only. |
| [`light`](#light) | static getter | A | Build the light `ThemeData`. |
| [`dark`](#dark) | static getter | A | Build the dark `ThemeData`. |

## Documentation

### `AppTheme._()` <a id="apptheme-new"></a>
- **Kind:** private unnamed constructor of `AppTheme`.
- **Source:** `lib/app/theme.dart` (line 10).
- **Purpose:** Make `AppTheme` a non-instantiable, static-only holder for the two theme getters.
- **Inputs:** None.
- **Returns:** N/A.
- **Side effects:** None.
- **Algorithm:** Empty private constructor body.
- **Usage:** Never called directly.
- **Notes:** Same pattern as `AppFlavor._()` in [flavor.md](flavor.md).

### `static ThemeData get light` <a id="light"></a>
- **Kind:** static getter of `AppTheme`.
- **Source:** `lib/app/theme.dart` (line 17).
- **Purpose:** Build the app's light-mode `ThemeData`.
- **Inputs:** None.
- **Returns:** `ThemeData` built by `FlexThemeData.light(...)`.
- **Side effects:** None (constructs a new `ThemeData` on every access; not cached).
- **Algorithm:** Calls `FlexThemeData.light` with `scheme: FlexScheme.blue`,
  `surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold`, `blendLevel: 7`, and
  `FlexSubThemesData(blendOnLevel: 10, useMaterial3Typography: true, useM2StyleDividerInM3: true,
  inputDecoratorBorderType: FlexInputBorderType.outline, navigationBarLabelBehavior:
  NavigationDestinationLabelBehavior.onlyShowSelected)`, with `useMaterial3: true`.
- **Usage:** Read in `MyDeviceApp.build()` as `theme: AppTheme.light` (see
  [../app.md](app.md)).
- **Notes:** None.

### `static ThemeData get dark` <a id="dark"></a>
- **Kind:** static getter of `AppTheme`.
- **Source:** `lib/app/theme.dart` (line 37).
- **Purpose:** Build the app's dark-mode `ThemeData`.
- **Inputs:** None.
- **Returns:** `ThemeData` built by `FlexThemeData.dark(...)`.
- **Side effects:** None.
- **Algorithm:** Same shape as `light`, but via `FlexThemeData.dark` with `blendLevel: 13` and
  `blendOnLevel: 20` (higher blend levels than light mode, per `flex_color_scheme` convention for
  dark surfaces).
- **Usage:** Read in `MyDeviceApp.build()` as `darkTheme: AppTheme.dark`.
- **Notes:** None.
