# lib/features/ai/widgets/ai_settings_tiles.dart

Shared implementation now lives in MyApps-AI v0.4.1; this page describes the app adapter.

`AiSettingsTiles`, added in 1.6.0 (ported from MyDay!!!!!, which took it from MyAnime!!!!!), builds the rows of the *On-device AI*
Settings section: the "Use on-device AI" switch, the model status row with its action, "Prefer the
faster model" (Android, only when both sizes are served), the notes on who owns the model, a
collapsed *Technical details* tile, and "Clear generated insights". On Windows, Linux and the web it
renders nothing; `settings_page.dart` does not build it there and shows the one-line
`aiNotSupportedHere` note instead. Unlike MyAnime, the switch has no feature gate: it can always be
turned on or off. See [`../services/on_device_ai_service.md`](../services/on_device_ai_service.md),
[`../services/insight_service.md`](../services/insight_service.md) and
[`../../../../on-device-ai.md`](../../../../on-device-ai.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AiSettingsTiles.new` | constructor (`AiSettingsTiles`) | B | Create the AI settings rows; takes no parameters besides `key`. |
| `AiSettingsTiles.createState` | method (`AiSettingsTiles`) | B | Create the state object. |
| [`_AiSettingsTilesState.initState`](#_aisettingstilesstate-initstate) | method (`_AiSettingsTilesState`) | A | Refresh the model status when Settings opens. |
| `_AiSettingsTilesState._localeTag` | method (`_AiSettingsTilesState`) | B | Return the app's current locale as a tag such as `zh_TW`. |
| `_AiSettingsTilesState._statusLabel` | method (`_AiSettingsTilesState`) | B | Word a model status with the `aiStatus*` strings. |
| [`_AiSettingsTilesState.build`](#_aisettingstilesstate-build) | method (`_AiSettingsTilesState`) | A | Build the rows. |

`grep -c 'Purpose:' lib/features/ai/widgets/ai_settings_tiles.dart` reports 6, matching the six
rows above. The class-level comment on `AiSettingsTiles` carries no `/// Purpose:` and is not a row.

## Documentation

### `void initState()` <a id="_aisettingstilesstate-initstate"></a>
- **Kind:** method of `_AiSettingsTilesState` (Flutter lifecycle override)
- **Source:** `lib/features/ai/widgets/ai_settings_tiles.dart` (line 45)
- **Purpose:** Refresh the model status when Settings opens.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** After the first frame, one forced status probe — only while the switch is on.
- **Algorithm:** In a post-frame callback, if still mounted, read `onDeviceAiServiceProvider`; if
  `enabled`, call `refreshStatus(localeTag: _localeTag())`.
- **Usage:** Flutter calls it when the tiles are first inserted.
- **Notes:** The post-frame callback is needed because `_localeTag` reads `Localizations`.

### `Widget build(BuildContext context)` <a id="_aisettingstilesstate-build"></a>
- **Kind:** method of `_AiSettingsTilesState`
- **Source:** `lib/features/ai/widgets/ai_settings_tiles.dart` (line 89)
- **Purpose:** Build the rows.
- **Inputs:** `context`.
- **Returns:** A `Column` of tiles, or `SizedBox.shrink()` when `platformMayHaveOnDeviceModel` is
  false.
- **Side effects:** None while building; the tiles call `OnDeviceAiService`, `AppSettingsNotifier`
  and `AiInsightStore` when tapped.
- **Algorithm:** Watches `appSettingsProvider` and `onDeviceAiServiceProvider`; inside a
  `ListenableBuilder` on the service:
  1. The switch, bound to `AppSettings.onDeviceAiEnabled` and `setOnDeviceAiEnabled`, always
     enabled, with the `aiUseOnDeviceDesc` subtitle.
  2. Only while on: the status row. `notEnabled` adds the "turn on Apple Intelligence" line; a
     running download shows the MB so far. Its action is Download for `downloadable` on Android
     (disabled while downloading), and Check again for `unavailable`, `unreachable`, `notEnabled`,
     `unknown` and `downloading`.
  3. "Prefer the faster model" (`setOnDeviceAiPreferFast`), on Android only when
     `report.hasSizeChoice`.
  4. The notes: on Android, who downloads the model and why it cannot be removed here; on Apple,
     that the system manages it.
  5. Since 1.11.0, a collapsed *Technical details* tile (`MyAppsAiDiagnosticsView` over `router.diagnostics()`) that lists every included backend, copyable: app and platform, selection, system AI, llama.cpp library and devices, each local model. It replaces the earlier tile with selectable text: status name and code, detail,
     variant, served and refused variants, model name, token limit, AICore version (or "not
     installed" on Android), SDK, device, compatibility, OS version and locale support, each only
     when known.
  6. "Clear generated insights": on tap, awaits `ref.read(aiInsightStoreProvider).clearAll()`
     (deletes `ai_insights.json` and resets every insight card), then shows the
     `aiClearInsightsDone` snack bar through a `ScaffoldMessenger` captured before the await.
- **Usage:** `lib/features/settings/views/settings_page.dart`, the *On-device AI* section
  (`if (platformMayHaveOnDeviceModel) const AiSettingsTiles() else ListTile(...aiNotSupportedHere)`;
  see [`../../settings/views/settings_page.md`](../../settings/views/settings_page.md));
  `test/ai_settings_tiles_ui_test.dart` (per platform with `debugDefaultTargetPlatformOverride`,
  including "Clear generated insights empties the insight cache").
- **Notes:** Every row after the switch, including "Clear generated insights", is shown only while
  the switch is on. `unsupported` is worded as needing iOS 26 or macOS 26 with Apple Intelligence;
  it is what the Apple plugin reports on iOS and macOS older than 26.


Current integration uses MyApps-AI v0.6.0, explicit platform injection, the shared source router and the unified settings skeleton. WebDAV entry points require device-local notice acknowledgement before any network request; see [sync.md](../../../sync.md).
