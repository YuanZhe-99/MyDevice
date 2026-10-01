# lib/shared/providers/app_settings.dart

Riverpod state for device-local UI preferences (theme mode, locale) and, since 1.6.0, the two
on-device AI switches (use on-device AI, prefer the faster model). Backed by `DeviceStorage`'s
theme/locale and `onDeviceAi*` keys in `storage_config.json` (see
[../../../data-formats.md](../../../data-formats.md)). The AI switches are also pushed into
[`OnDeviceAiService`](../../features/ai/services/on_device_ai_service.md), which owns the policy.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`AppSettingsNotifier` constructor](#appsettingsnotifier-new) | constructor | A | Create the notifier and kick off loading persisted settings. |
| [`AppSettingsNotifier.fixed`](#appsettingsnotifier-fixed) | named constructor | A | Create a notifier that starts from fixed settings (tests). |
| [`_loadPersisted`](#loadpersisted) | method (`AppSettingsNotifier`) | A | Load theme mode, locale and the AI switches from `DeviceStorage`, then push the AI switches to the service. |
| [`setThemeMode`](#setthememode) | method (`AppSettingsNotifier`) | A | Update state and persist the new theme mode. |
| [`setLocale`](#setlocale) | method (`AppSettingsNotifier`) | A | Update state and persist the new locale. |
| [`setOnDeviceAiEnabled`](#setondeviceaienabled) | method (`AppSettingsNotifier`) | A | Turn on-device AI on or off. |
| [`setOnDeviceAiPreferFast`](#setondeviceaipreferfast) | method (`AppSettingsNotifier`) | A | Prefer the faster on-device model where both sizes are served. |
| [`AppSettings` constructor](#appsettings-new) | constructor | A | Create an immutable settings value. |
| [`copyWith`](#copywith) | method (`AppSettings`) | A | Create a modified copy of the settings value. |

`appSettingsProvider` (the `StateNotifierProvider<AppSettingsNotifier, AppSettings>` top-level
value) has no `/// Purpose:` comment of its own and is a plain provider declaration, not a
function/method/constructor — it is not counted as a separate row. The fields `onDeviceAiEnabled`
and `onDeviceAiPreferFast` carry plain `///` descriptions and are not rows either. Row count (9)
matches `grep -c '/// Purpose:' lib/shared/providers/app_settings.dart` (9).

## Documentation

### `AppSettingsNotifier() : super(const AppSettings())` <a id="appsettingsnotifier-new"></a>
- **Kind:** constructor of `AppSettingsNotifier` (extends `StateNotifier<AppSettings>`).
- **Source:** `lib/shared/providers/app_settings.dart` (line 13).
- **Purpose:** Initialize the notifier with default settings, then asynchronously load the real
  persisted values.
- **Inputs:** None.
- **Returns:** A new `AppSettingsNotifier`.
- **Side effects:** Calls `_loadPersisted()` (fire-and-forget; not awaited by the constructor).
- **Algorithm:** Seed `state` with `const AppSettings()` (system theme, no locale override, both AI
  switches off), then call `_loadPersisted()` without awaiting it.
- **Usage:** Constructed once by `appSettingsProvider`'s Riverpod factory.
- **Notes:** Because loading is not awaited, the very first frame briefly renders with default
  settings until `_loadPersisted` resolves and updates `state`.

### `AppSettingsNotifier.fixed(super.settings)` <a id="appsettingsnotifier-fixed"></a>
- **Kind:** named constructor of `AppSettingsNotifier` (v1.6.0).
- **Source:** `lib/shared/providers/app_settings.dart` (line 23).
- **Purpose:** Create a notifier that starts from the given settings.
- **Inputs:** `settings` — the initial `AppSettings`, forwarded to `StateNotifier`.
- **Returns:** A new `AppSettingsNotifier`.
- **Side effects:** None; nothing is read from disk and nothing is pushed to `OnDeviceAiService`.
- **Algorithm:** Super-parameter forwarding only; `_loadPersisted` is not called.
- **Usage:** `AppSettingsNotifier.fixed(AppSettings(onDeviceAiEnabled: enabled))` in
  `test/ai_insight_card_ui_test.dart` and `test/ai_settings_tiles_ui_test.dart`, overriding
  `appSettingsProvider`.
- **Notes:** For tests. The setters still persist through `DeviceStorage`.

### `Future<void> _loadPersisted()` <a id="loadpersisted"></a>
- **Kind:** method of `AppSettingsNotifier`.
- **Source:** `lib/shared/providers/app_settings.dart` (line 31).
- **Purpose:** Read the persisted theme mode, locale tag and AI switches from `DeviceStorage`,
  update `state` accordingly, and hand the AI switches to `OnDeviceAiService`.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads `DeviceStorage.getThemeMode()`/`getLocaleTag()`/
  `getOnDeviceAiEnabled()`/`getOnDeviceAiPreferFast()` (all from `storage_config.json`); overwrites
  `state`; awaits `OnDeviceAiService.instance.setPreferFast(...)` and then `setEnabled(...)`.
- **Algorithm:** Map the stored string (`'light'`/`'dark'`/anything else) to `ThemeMode.light`/
  `.dark`/`.system`; parse a stored locale tag of the form `languageCode` or
  `languageCode_countryCode` into a `Locale`; assign the new `AppSettings(themeMode, locale,
  onDeviceAiEnabled, onDeviceAiPreferFast)`; then push the size preference first and the switch
  second.
- **Usage:** Called once from the unnamed constructor.
- **Notes:** A `null` locale tag leaves `locale` as `null`, which `MyDeviceApp` interprets as
  "follow system locale" (see [../../app/app.md](../../app/app.md)). The preference is pushed
  before the switch so the startup status probe that `setEnabled(true)` triggers already uses the
  persisted size preference. While the switch is off, `setEnabled(false)` makes no backend call
  ([`on_device_ai_service.md`](../../features/ai/services/on_device_ai_service.md)).

### `void setThemeMode(ThemeMode mode)` <a id="setthememode"></a>
- **Kind:** method of `AppSettingsNotifier`.
- **Source:** `lib/shared/providers/app_settings.dart` (line 65).
- **Purpose:** Update the in-memory theme mode and persist it.
- **Inputs:** `mode` — the new `ThemeMode`.
- **Returns:** None.
- **Side effects:** Updates `state`; calls `DeviceStorage.setThemeMode(str)`.
- **Algorithm:** `state = state.copyWith(themeMode: mode)`; map `light`/`dark` to their string
  form and `system` to `null` before persisting.
- **Usage:** Called from the settings page's theme selector.
- **Notes:** Storing `null` for `system` means "no override recorded," matching
  `_loadPersisted`'s default-to-system fallback for an unrecognized/absent value.

### `void setLocale(Locale? locale)` <a id="setlocale"></a>
- **Kind:** method of `AppSettingsNotifier`.
- **Source:** `lib/shared/providers/app_settings.dart` (line 80).
- **Purpose:** Update the in-memory locale override and persist it.
- **Inputs:** `locale` — the new locale, or `null` to follow the system locale.
- **Returns:** None.
- **Side effects:** Updates `state`; calls `DeviceStorage.setLocaleTag(...)`.
- **Algorithm:** `state = state.copyWith(locale: locale, clearLocale: locale == null)`; persist
  `null` when clearing, otherwise a `languageCode` or `languageCode_countryCode` tag string.
- **Usage:** Called from the settings page's language selector.
- **Notes:** `copyWith`'s `clearLocale` flag exists specifically because a nullable field can't be
  distinguished from "leave unchanged" via `??` alone — see `copyWith` below.

### `void setOnDeviceAiEnabled(bool enabled)` <a id="setondeviceaienabled"></a>
- **Kind:** method of `AppSettingsNotifier` (v1.6.0).
- **Source:** `lib/shared/providers/app_settings.dart` (line 98).
- **Purpose:** Turn on-device AI on or off.
- **Inputs:** `enabled`.
- **Returns:** None.
- **Side effects:** Updates `state`; calls `DeviceStorage.setOnDeviceAiEnabled(enabled)` and
  `OnDeviceAiService.instance.setEnabled(enabled)`, neither awaited.
- **Algorithm:** `state = state.copyWith(onDeviceAiEnabled: enabled)`, persist, switch the service.
- **Usage:** `onChanged: notifier.setOnDeviceAiEnabled` on the "Use on-device AI" switch in
  [`AiSettingsTiles`](../../features/ai/widgets/ai_settings_tiles.md).
- **Notes:** Off by default. Switching off cancels anything running, and the insight cards then
  render nothing. The value is device-local (`storage_config.json` is never synced).

### `void setOnDeviceAiPreferFast(bool enabled)` <a id="setondeviceaipreferfast"></a>
- **Kind:** method of `AppSettingsNotifier` (v1.6.0).
- **Source:** `lib/shared/providers/app_settings.dart` (line 109).
- **Purpose:** Prefer the faster on-device model where both sizes are served.
- **Inputs:** `enabled`.
- **Returns:** None.
- **Side effects:** Updates `state`; calls `DeviceStorage.setOnDeviceAiPreferFast(enabled)` and
  `OnDeviceAiService.instance.setPreferFast(enabled)` (which re-probes the status while on),
  neither awaited.
- **Algorithm:** `state = state.copyWith(onDeviceAiPreferFast: enabled)`, persist, tell the
  service.
- **Usage:** `onChanged: notifier.setOnDeviceAiPreferFast` on the "Prefer the faster model" row in
  [`AiSettingsTiles`](../../features/ai/widgets/ai_settings_tiles.md), shown on Android only when
  both model sizes are served.
- **Notes:** Android only; Apple platforms have one system model.

### `const AppSettings({this.themeMode = ThemeMode.system, this.locale, this.onDeviceAiEnabled = false, this.onDeviceAiPreferFast = false})` <a id="appsettings-new"></a>
- **Kind:** constructor of `AppSettings`.
- **Source:** `lib/shared/providers/app_settings.dart` (line 132).
- **Purpose:** Create an immutable settings snapshot.
- **Inputs:** `themeMode` (default `ThemeMode.system`), `locale` (default `null`),
  `onDeviceAiEnabled` (default `false`), `onDeviceAiPreferFast` (default `false`).
- **Returns:** A new `AppSettings`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:** Used as the notifier's default state and rebuilt via `copyWith` on every update.
- **Notes:** None.

### `AppSettings copyWith({ThemeMode? themeMode, Locale? locale, bool? onDeviceAiEnabled, bool? onDeviceAiPreferFast, bool clearLocale = false})` <a id="copywith"></a>
- **Kind:** method of `AppSettings`.
- **Source:** `lib/shared/providers/app_settings.dart` (line 144).
- **Purpose:** Create a modified copy of an `AppSettings` value.
- **Inputs:** `themeMode`, `locale`, `onDeviceAiEnabled`, `onDeviceAiPreferFast` (each an optional
  replacement), `clearLocale` (force `locale` to `null` regardless of the `locale` argument).
- **Returns:** A new `AppSettings`.
- **Side effects:** None.
- **Algorithm:** Each field is `argument ?? this.field`, except `locale: clearLocale ? null :
  (locale ?? this.locale)` — `clearLocale` takes precedence over any passed `locale` value.
- **Usage:** Called from `setThemeMode`, `setLocale`, `setOnDeviceAiEnabled` and
  `setOnDeviceAiPreferFast`.
- **Notes:** The `clearLocale` flag is what makes "explicitly set locale to null" distinguishable
  from "don't touch locale" in a `copyWith` pattern, since passing `locale: null` would otherwise
  be indistinguishable from omitting the parameter.

## Interface style (since 1.7.0)

`AppSettings` gains `uiStyle` (`AppUiStyle`, default `AppUiStyle.expressive`), present in the
constructor, `copyWith` and `_loadPersisted` (which maps `DeviceStorage.getUiStyle()` — `'material3'`
or null — to the enum). New method `AppSettingsNotifier.setUiStyle(AppUiStyle style)` (Tier B) updates
`state` and persists through `DeviceStorage.setUiStyle('material3' or null)`, so only the non-default
Material 3 style is stored, as `uiStyle: "material3"` in `storage_config.json`. `MyDeviceApp.build`
passes `settings.uiStyle` to `AppTheme.light`/`dark`, so the theme rebuilds at once; `ShellScaffold`
watches `appSettingsProvider.select((s) => s.uiStyle == AppUiStyle.expressive)` and builds
`_ExpressiveNavBar` for Expressive (a compact floating pill since 1.7.1). The setting is local and never synced.

## Navigation position (since 1.7.1)

`AppSettings` gains `navPlacement` (`NavPlacement`, defined in `lib/app/theme.dart`: `bottom`, `sideOnWide`, `side`; default `bottom`) and `navRailOnRight` (default false), present in the constructor, `copyWith` and `_loadPersisted` (which reads `DeviceStorage.getNavPlacement()` -- `'sideOnWide'`, `'side'` or null, unknown values reading as the default -- and `getNavRailRight()`). Two Tier B methods follow the `setUiStyle` pattern: `AppSettingsNotifier.setNavPlacement(NavPlacement placement)` chooses bottom everywhere (the default, for both styles), the side rail on wide windows only, or the side rail everywhere (not recommended on phones), and `AppSettingsNotifier.setNavRailOnRight(bool right)` puts the rail on the right. Each updates `state` and persists through `DeviceStorage`; both keys live only in `storage_config.json` and are never synced. `ShellScaffold` watches both. Row count: 12 (`grep -c '/// Purpose:'`).
