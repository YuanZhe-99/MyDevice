# lib/shared/providers/app_settings.dart

Riverpod state for device-local UI preferences (theme mode, locale). Backed by
`DeviceStorage`'s theme/locale keys in `storage_config.json` (see
[../../../data-formats.md](../../../data-formats.md)).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`AppSettingsNotifier` constructor](#appsettingsnotifier-new) | constructor | A | Create the notifier and kick off loading persisted settings. |
| [`_loadPersisted`](#loadpersisted) | method (`AppSettingsNotifier`) | A | Load theme mode and locale from `DeviceStorage`. |
| [`setThemeMode`](#setthememode) | method (`AppSettingsNotifier`) | A | Update state and persist the new theme mode. |
| [`setLocale`](#setlocale) | method (`AppSettingsNotifier`) | A | Update state and persist the new locale. |
| [`AppSettings` constructor](#appsettings-new) | constructor | A | Create an immutable settings value. |
| [`copyWith`](#copywith) | method (`AppSettings`) | A | Create a modified copy of the settings value. |

`appSettingsProvider` (the `StateNotifierProvider<AppSettingsNotifier, AppSettings>` top-level
value) has no `/// Purpose:` comment of its own and is a plain provider declaration, not a
function/method/constructor — it is not counted as a separate row.

## Documentation

### `AppSettingsNotifier() : super(const AppSettings())` <a id="appsettingsnotifier-new"></a>
- **Kind:** constructor of `AppSettingsNotifier` (extends `StateNotifier<AppSettings>`).
- **Source:** `lib/shared/providers/app_settings.dart` (line 12).
- **Purpose:** Initialize the notifier with default settings, then asynchronously load the real
  persisted values.
- **Inputs:** None.
- **Returns:** A new `AppSettingsNotifier`.
- **Side effects:** Calls `_loadPersisted()` (fire-and-forget; not awaited by the constructor).
- **Algorithm:** Seed `state` with `const AppSettings()` (system theme, no locale override), then
  call `_loadPersisted()` without awaiting it.
- **Usage:** Constructed once by `appSettingsProvider`'s Riverpod factory.
- **Notes:** Because loading is not awaited, the very first frame briefly renders with default
  settings until `_loadPersisted` resolves and updates `state`.

### `Future<void> _loadPersisted()` <a id="loadpersisted"></a>
- **Kind:** method of `AppSettingsNotifier`.
- **Source:** `lib/shared/providers/app_settings.dart` (line 21).
- **Purpose:** Read the persisted theme mode and locale tag from `DeviceStorage` and update
  `state` accordingly.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads `DeviceStorage.getThemeMode()`/`getLocaleTag()`; overwrites `state`.
- **Algorithm:** Map the stored string (`'light'`/`'dark'`/anything else) to `ThemeMode.light`/
  `.dark`/`.system`; parse a stored locale tag of the form `languageCode` or
  `languageCode_countryCode` into a `Locale`; assign the new `AppSettings(themeMode, locale)`.
- **Usage:** Called once from the constructor.
- **Notes:** A `null` locale tag leaves `locale` as `null`, which `MyDeviceApp` interprets as
  "follow system locale" (see [../../app/app.md](../../app/app.md)).

### `void setThemeMode(ThemeMode mode)` <a id="setthememode"></a>
- **Kind:** method of `AppSettingsNotifier`.
- **Source:** `lib/shared/providers/app_settings.dart` (line 45).
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
- **Source:** `lib/shared/providers/app_settings.dart` (line 60).
- **Purpose:** Update the in-memory locale override and persist it.
- **Inputs:** `locale` — the new locale, or `null` to follow the system locale.
- **Returns:** None.
- **Side effects:** Updates `state`; calls `DeviceStorage.setLocaleTag(...)`.
- **Algorithm:** `state = state.copyWith(locale: locale, clearLocale: locale == null)`; persist
  `null` when clearing, otherwise a `languageCode` or `languageCode_countryCode` tag string.
- **Usage:** Called from the settings page's language selector.
- **Notes:** `copyWith`'s `clearLocale` flag exists specifically because a nullable field can't be
  distinguished from "leave unchanged" via `??` alone — see `copyWith` below.

### `const AppSettings({this.themeMode = ThemeMode.system, this.locale})` <a id="appsettings-new"></a>
- **Kind:** constructor of `AppSettings`.
- **Source:** `lib/shared/providers/app_settings.dart` (line 82).
- **Purpose:** Create an immutable settings snapshot.
- **Inputs:** `themeMode` (default `ThemeMode.system`), `locale` (default `null`).
- **Returns:** A new `AppSettings`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment.
- **Usage:** Used as the notifier's default state and rebuilt via `copyWith` on every update.
- **Notes:** None.

### `AppSettings copyWith({ThemeMode? themeMode, Locale? locale, bool clearLocale = false})` <a id="copywith"></a>
- **Kind:** method of `AppSettings`.
- **Source:** `lib/shared/providers/app_settings.dart` (line 89).
- **Purpose:** Create a modified copy of an `AppSettings` value.
- **Inputs:** `themeMode` (optional replacement), `locale` (optional replacement),
  `clearLocale` (force `locale` to `null` regardless of the `locale` argument).
- **Returns:** A new `AppSettings`.
- **Side effects:** None.
- **Algorithm:** `themeMode: themeMode ?? this.themeMode`; `locale: clearLocale ? null : (locale ??
  this.locale)` — `clearLocale` takes precedence over any passed `locale` value.
- **Usage:** Called from both `setThemeMode` and `setLocale`.
- **Notes:** The `clearLocale` flag is what makes "explicitly set locale to null" distinguishable
  from "don't touch locale" in a `copyWith` pattern, since passing `locale: null` would otherwise
  be indistinguishable from omitting the parameter.
