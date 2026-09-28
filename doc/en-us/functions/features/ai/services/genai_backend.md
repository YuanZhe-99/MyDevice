# lib/features/ai/services/genai_backend.dart

The Dart seam between `OnDeviceAiService` and the platform's on-device model, added in 1.6.0 and
ported from MyDay!!!!! (itself from MyAnime!!!!!) with only the channel name changed. It holds the `GenAiStatus` and
`GenAiFailure` enums, the `GenAiStatusReport` and `GenAiCoreInfo` value classes the platform answers
with, the abstract `GenAiBackend` interface that tests replace with a fake, and
`MethodChannelGenAiBackend`, which talks over `com.yuanzhe.my_device/genai` to `GenAiChannel.kt`
(`android/app/src/main/kotlin/com/yuanzhe/my_device/GenAiChannel.kt`) on Android and the
`on_device_ai_apple` plugin (`packages/on_device_ai_apple/`) on iOS and macOS. Policy — the switch,
the queue, the parsing — lives on the service's side of this seam (see
[`on_device_ai_service.md`](on_device_ai_service.md)), so everything worth testing runs without a
device. See [`../../../../on-device-ai.md`](../../../../on-device-ai.md) for the platform facts, the
channel's methods and the status table. **Not verified on a device** (2026-09-28).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`platformMayHaveOnDeviceModel`](#platformmayhaveondevicemodel) | top-level getter | A | Report whether this platform can have an on-device model at all. |
| `GenAiStatus` | enum | B | What the on-device model can do on this device, right now. |
| `GenAiFailure` | enum | B | Why a generation attempt did not produce an answer. |
| `GenAiException.new` | constructor (`GenAiException`) | B | Create a generation failure. |
| `GenAiException.toString` | method (`GenAiException`) | B | Describe the failure for logs. |
| `GenAiStatusReport.new` | constructor (`GenAiStatusReport`) | B | Describe the model's availability. |
| [`GenAiStatusReport.hasSizeChoice`](#genaistatusreport-hassizechoice) | getter (`GenAiStatusReport`) | A | Say whether the served variants include both model sizes. |
| [`GenAiStatusReport.fromJson`](#genaistatusreport-fromjson) | static method (`GenAiStatusReport`) | A | Read the map the platform channel sends. |
| `GenAiCoreInfo.new` | constructor (`GenAiCoreInfo`) | B | Describe the device's model system. |
| `GenAiCoreInfo.fromJson` | static method (`GenAiCoreInfo`) | B | Read the map the platform channel sends; null when nothing usable came back. |
| `GenAiBackend.statusReport` | abstract method (`GenAiBackend`) | B | Ask what the model can do, and what the device said about it. |
| `GenAiBackend.coreInfo` | abstract method (`GenAiBackend`) | B | Describe the device's model system. |
| `GenAiBackend.download` | abstract method (`GenAiBackend`) | B | Ask the system to fetch the model (Android only). |
| `GenAiBackend.generate` | abstract method (`GenAiBackend`) | B | Generate one answer. |
| `GenAiBackend.choose` | abstract method (`GenAiBackend`) | B | Pick up to `maxItems` of `options`. |
| `GenAiBackend.prewarm` | abstract method (`GenAiBackend`) | B | Load the model ahead of a batch. |
| `GenAiBackend.cancel` | abstract method (`GenAiBackend`) | B | Stop whatever is running. |
| `MethodChannelGenAiBackend.new` | constructor (`MethodChannelGenAiBackend`) | B | Create the channel backend; the channel is injectable for tests. |
| [`MethodChannelGenAiBackend.statusReport`](#methodchannelgenaibackend-statusreport) | method (`MethodChannelGenAiBackend`) | A | Ask the platform for the model's status. |
| `MethodChannelGenAiBackend.coreInfo` | method (`MethodChannelGenAiBackend`) | B | Read the device's model-system details (`info` call); null whenever the call fails. |
| [`MethodChannelGenAiBackend.download`](#methodchannelgenaibackend-download) | method (`MethodChannelGenAiBackend`) | A | Ask the system to fetch the model. |
| `MethodChannelGenAiBackend.generate` | method (`MethodChannelGenAiBackend`) | B | Generate one answer over the channel; a null reply becomes `''`. |
| [`MethodChannelGenAiBackend.choose`](#methodchannelgenaibackend-choose) | method (`MethodChannelGenAiBackend`) | A | Pick up to `maxItems` of `options`. |
| `MethodChannelGenAiBackend.prewarm` | method (`MethodChannelGenAiBackend`) | B | Load the model ahead of a batch; errors are swallowed. |
| `MethodChannelGenAiBackend.cancel` | method (`MethodChannelGenAiBackend`) | B | Stop whatever is running; errors are swallowed. |
| `MethodChannelGenAiBackend._handlePlatformCall` | method (`MethodChannelGenAiBackend`) | B | Receive download progress from the platform. |
| [`MethodChannelGenAiBackend.failureForCode`](#methodchannelgenaibackend-failureforcode) | static method (`MethodChannelGenAiBackend`) | A | Map a platform error code to a failure. |

`grep -c 'Purpose:' lib/features/ai/services/genai_backend.dart` reports 25, matching 25 of the 27
rows above.

**Reconciliation:** the two extra rows are the top-level enums `GenAiStatus` and `GenAiFailure`,
which carry a plain `///` summary (and one per value) but no `/// Purpose:` block. Their values are
listed in [`../../../../on-device-ai.md`](../../../../on-device-ai.md#statuses-and-failures). The
value fields of `GenAiException`, `GenAiStatusReport` and `GenAiCoreInfo`,
`GenAiStatusReport.unsupported`, `MethodChannelGenAiBackend.channelName` (`'com.yuanzhe.my_device/genai'`)
and the private fields `_channel`, `_onProgress` and `_listening` carry no `/// Purpose:` block and
are not rows.

## Documentation

### `bool get platformMayHaveOnDeviceModel` <a id="platformmayhaveondevicemodel"></a>
- **Kind:** top-level getter
- **Source:** `lib/features/ai/services/genai_backend.dart` (line 15)
- **Purpose:** Report whether this platform can have an on-device model at all.
- **Inputs:** None.
- **Returns:** `bool` — true on Android, iOS and macOS; false on Windows, Linux and the web.
- **Side effects:** None.
- **Algorithm:** `!kIsWeb` and `defaultTargetPlatform` is Android, iOS or macOS.
- **Usage:** Every `MethodChannelGenAiBackend` method checks it first;
  `OnDeviceAiService.refreshStatus` checks it too. In the UI it gates
  [`AiSettingsTiles.build`](../widgets/ai_settings_tiles.md), `AiInsightCard.build`, and the
  Settings page's AI section in `_buildSettingsList` (which shows a single "not available" line
  instead).
- **Notes:** A coarse gate: off these platforms the backend answers `unsupported` without touching
  the channel, and Settings shows no AI rows. Because it reads `defaultTargetPlatform`, tests switch
  it with `debugDefaultTargetPlatformOverride`. Whether a given device actually has a model is a
  run-time question answered by `OnDeviceAiService.refreshStatus()`.

### `bool get hasSizeChoice` <a id="genaistatusreport-hassizechoice"></a>
- **Kind:** getter of `GenAiStatusReport`
- **Source:** `lib/features/ai/services/genai_backend.dart` (line 164)
- **Purpose:** Say whether the served variants include both model sizes.
- **Inputs:** None.
- **Returns:** `bool` — true when `served` contains both `/full` and `/fast`.
- **Side effects:** None.
- **Algorithm:** A substring check on the comma-separated `served` list reported by Android's probe;
  false when `served` is null.
- **Usage:** [`AiSettingsTiles.build`](../widgets/ai_settings_tiles.md) shows "Prefer the faster
  model" only when the platform is Android and this is true.
- **Notes:** A control that cannot change anything is not shown. Apple never reports `served`.

### `static GenAiStatusReport fromJson(Map<Object?, Object?>? answer)` <a id="genaistatusreport-fromjson"></a>
- **Kind:** static method of `GenAiStatusReport`
- **Source:** `lib/features/ai/services/genai_backend.dart` (line 176)
- **Purpose:** Read the map the platform channel sends.
- **Inputs:** `answer` — the `status` reply, possibly null.
- **Returns:** `GenAiStatusReport`.
- **Side effects:** None.
- **Algorithm:**
  1. Map the `status` string to a `GenAiStatus` by name. Any other string becomes `unknown`; a
     missing or non-string value becomes `unavailable`.
  2. Take `code` and `tokenLimit` only when they are `int` (`code` defaults to -1, `tokenLimit` to
     null).
  3. Take `detail`, `variant`, `served`, `refused` and `baseModelName` with `toString()`.
- **Usage:** `MethodChannelGenAiBackend.statusReport`.
- **Notes:** An unknown status is reported as itself rather than folded into `unavailable`, so a
  newer platform value is visible in the technical details. Missing fields are absent, not wrong.
  `unsupported` is what the Apple plugin answers on iOS and macOS older than 26.

### `Future<GenAiStatusReport> statusReport({bool force = false, bool preferFast = false})` <a id="methodchannelgenaibackend-statusreport"></a>
- **Kind:** method of `MethodChannelGenAiBackend` (`@override`)
- **Source:** `lib/features/ai/services/genai_backend.dart` (line 376)
- **Purpose:** Ask the platform for the model's status.
- **Inputs:** `force` — re-probe rather than trust a model that is already serving; `preferFast` —
  ask for the smaller model where a device serves both.
- **Returns:** `Future<GenAiStatusReport>`; never throws.
- **Side effects:** One `status` channel call with `{feature: 'prompt', force, preferFast}`.
- **Algorithm:**
  1. Off the supported platforms, return `GenAiStatusReport.unsupported` without a call.
  2. Invoke `status` and parse the reply with `GenAiStatusReport.fromJson`.
  3. `MissingPluginException` → `unreachable` with detail `channel not registered`;
     `PlatformException` → `unreachable` with `code: message`; anything else → `unreachable` with
     the error's type name.
- **Usage:** `OnDeviceAiService.refreshStatus` (forced), `OnDeviceAiService.download` and
  `OnDeviceAiService._pump` (unforced) — see [`on_device_ai_service.md`](on_device_ai_service.md).
- **Notes:** A missing plugin is never reported as `unsupported`: that is how a plugin that failed
  to register on iOS or macOS gets noticed.

### `Future<bool> download({void Function(int bytes, int total)? onProgress})` <a id="methodchannelgenaibackend-download"></a>
- **Kind:** method of `MethodChannelGenAiBackend` (`@override`)
- **Source:** `lib/features/ai/services/genai_backend.dart` (line 432)
- **Purpose:** Ask the system to fetch the model.
- **Inputs:** `onProgress` — bytes so far and the total, -1 when unknown.
- **Returns:** `Future<bool>` — true when the download completed (a null reply is false).
- **Side effects:** AICore downloads the model; progress arrives as `downloadProgress` method calls
  from the platform. Registers the channel's call handler once.
- **Algorithm:**
  1. Off the supported platforms, throw `GenAiException(unavailable)`.
  2. Store `onProgress`; on first use, install `_handlePlatformCall` as the method-call handler.
  3. Invoke `download` with `{feature: 'prompt'}`; map a `PlatformException` through
     `failureForCode` and a `MissingPluginException` to `unavailable`.
  4. Clear the stored callback in `finally`.
- **Usage:** `OnDeviceAiService.download`, from the Download button in
  [`AiSettingsTiles`](../widgets/ai_settings_tiles.md).
- **Notes:** The app never downloads anything itself. The Apple plugin has no `download`; the
  button is shown only on Android.

### `Future<List<String>> choose({required String instructions, required String prompt, required List<String> options, int maxItems = 3})` <a id="methodchannelgenaibackend-choose"></a>
- **Kind:** method of `MethodChannelGenAiBackend` (`@override`)
- **Source:** `lib/features/ai/services/genai_backend.dart` (line 498)
- **Purpose:** Pick up to `maxItems` of `options`.
- **Inputs:** `instructions`, `prompt`, `options` — the allowed ids, `maxItems`.
- **Returns:** `Future<List<String>>` — the chosen ids, possibly empty.
- **Side effects:** Runs the model on the device.
- **Algorithm:**
  1. Off the supported platforms, throw `GenAiException(unavailable)`.
  2. On Android, call `generate` with `maxOutputTokens: 64`, read the reply with
     [`parseChoiceReply`](output_validation.md), and throw
     `GenAiException(failed, 'unparseable reply')` when it is invalid.
  3. Elsewhere, invoke the native `choose` (constrained decoding on Apple) and keep the string
     entries of the reply; map a `PlatformException` through `failureForCode` and a
     `MissingPluginException` to `unavailable`.
- **Usage:** `OnDeviceAiService.choose`, which nothing in MyDevice calls yet.
- **Notes:** Kept so the seam and the Apple plugin match MyAnime's. Both paths return ids the caller
  is expected to validate again against its own list.

### `static GenAiFailure failureForCode(String code)` <a id="methodchannelgenaibackend-failureforcode"></a>
- **Kind:** static method of `MethodChannelGenAiBackend` (`@visibleForTesting`)
- **Source:** `lib/features/ai/services/genai_backend.dart` (line 589)
- **Purpose:** Map a platform error code to a failure.
- **Inputs:** `code` — the `PlatformException.code` sent by `GenAiChannel` or the Apple plugin.
- **Returns:** `GenAiFailure`.
- **Side effects:** None.
- **Algorithm:** A `switch` on the failure names `unavailable`, `busy`, `cancelled`, `tooLong`,
  `background`, `quota`, `guardrail` and `unsupportedLanguage`; anything else is `failed`.
- **Usage:** `download`, `generate` and `choose` in the same class.
- **Notes:** `timeout` is never sent by a platform; `OnDeviceAiService` raises it itself.
