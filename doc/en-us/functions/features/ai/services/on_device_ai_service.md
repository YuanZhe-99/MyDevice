# lib/features/ai/services/on_device_ai_service.dart

`OnDeviceAiService`, added in 1.6.0 and ported from MyDay!!!!! (which took it from MyAnime!!!!!, an
adaptation of MyNihongo!!!!!'s `AiAssistService`), owns the on-device AI policy: whether the model may be asked anything at all,
what it can do right now, and the one-at-a-time queue in front of it. **While the user's switch is
off, the backend is never called — not even for status.** Every request re-checks the status first,
runs under a 45-second timeout, and waits while the app is not resumed. After `busy` background work
backs off from 5 seconds, doubling up to 5 minutes; after `quota` it stops for the rest of the day.
The service is a `ChangeNotifier` singleton; `AppSettingsNotifier` tells it the persisted switch
values and `main` starts its lifecycle listener. Its only generating caller in MyDevice is the insight
card store, [`AiInsightStore`](insight_service.md). See [`genai_backend.md`](genai_backend.md) for
the seam it calls and [`../../../../on-device-ai.md`](../../../../on-device-ai.md) for the policy and
the queue. **Not verified on a device** (2026-09-28).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `GenAiDownload.new` | constructor (`GenAiDownload`) | B | Describe download progress. |
| `GenAiDownload.fraction` | getter (`GenAiDownload`) | B | Return the fraction done; null when the total is unknown. |
| `AiPriority` | enum | B | Who is waiting for a request, which decides its place in the queue (`interactive`, `background`). |
| `_AiJob.attempt` | method (`_AiJob`) | B | Run the body once, with a timeout. |
| `_AiJob.succeed` | method (`_AiJob`) | B | Settle the completer with a value. |
| `_AiJob.failWith` | method (`_AiJob`) | B | Settle the completer with an error. |
| `_AiJob.fail` | method (`_AiJob`) | B | Settle the completer with a failure without running. |
| `OnDeviceAiService.new` | constructor (`OnDeviceAiService`) | B | Create the service with an injectable backend and clock; off until `setEnabled`. |
| `OnDeviceAiService.setInstanceForTest` | static method (`OnDeviceAiService`) | B | Replace the singleton for a test. |
| `OnDeviceAiService.canGenerate` | getter (`OnDeviceAiService`) | B | Report whether the model can generate right now, from the last status. |
| [`OnDeviceAiService.setEnabled`](#ondeviceaiservice-setenabled) | method (`OnDeviceAiService`) | A | Turn on-device AI on or off. |
| `OnDeviceAiService.setPreferFast` | method (`OnDeviceAiService`) | B | Choose the larger or the faster model; re-probes when enabled, otherwise only notifies. |
| [`OnDeviceAiService.refreshStatus`](#ondeviceaiservice-refreshstatus) | method (`OnDeviceAiService`) | A | Ask the device what the model can do. |
| [`OnDeviceAiService.download`](#ondeviceaiservice-download) | method (`OnDeviceAiService`) | A | Ask the system to fetch the model (Android). |
| [`OnDeviceAiService.generate`](#ondeviceaiservice-generate) | method (`OnDeviceAiService`) | A | Generate one answer through the queue. |
| `OnDeviceAiService.choose` | method (`OnDeviceAiService`) | B | Ask the model to pick from a fixed list, through the queue (background priority by default). No caller in MyDevice; kept for parity with MyAnime. |
| `OnDeviceAiService.prewarm` | method (`OnDeviceAiService`) | B | Load the model ahead of a batch; does nothing while off or not `available`. No caller in MyDevice. |
| [`OnDeviceAiService.cancelBackground`](#ondeviceaiservice-cancelbackground) | method (`OnDeviceAiService`) | A | Stop the running request and drop queued background work. |
| [`OnDeviceAiService.start`](#ondeviceaiservice-start) | method (`OnDeviceAiService`) | A | Start following the app lifecycle. |
| `OnDeviceAiService.handleLifecycle` | method (`OnDeviceAiService`) | B | Follow the app lifecycle: pause while not resumed, pump the queue on resume. |
| [`OnDeviceAiService._enqueue`](#ondeviceaiservice-_enqueue) | method (`OnDeviceAiService`) | A | Queue a request. |
| [`OnDeviceAiService._pump`](#ondeviceaiservice-_pump) | method (`OnDeviceAiService`) | A | Run the next eligible job. |
| [`OnDeviceAiService._pace`](#ondeviceaiservice-_pace) | method (`OnDeviceAiService`) | A | Adjust pacing after a job finished. |
| `OnDeviceAiService._failQueued` | method (`OnDeviceAiService`) | B | Fail queued jobs, optionally only background ones. |
| `OnDeviceAiService.dispose` | method (`OnDeviceAiService`) | B | Release the resume timer and the lifecycle listener. |
| `onDeviceAiServiceProvider` | top-level variable (`Provider<OnDeviceAiService>`) | B | Expose `OnDeviceAiService.instance` to the widget tree. |

`grep -c 'Purpose:' lib/features/ai/services/on_device_ai_service.dart` reports 24, matching 24 of
the 26 rows above.

**Reconciliation:** the two extra rows are real top-level declarations with a plain `///` summary
but no `/// Purpose:` block: the `AiPriority` enum and `onDeviceAiServiceProvider` — a plain
`Provider` over the singleton, so a rebuilt `ProviderScope` never disposes the app-wide service
(read by `AiInsightCard` and
[`AiSettingsTiles`](../widgets/ai_settings_tiles.md), which listen to it directly). Not rows: the
private `_AiJob` class's undocumented constructor and fields, the `timeout`, `maxBackoff` and
`initialBackoff` constants, `instance`, and the plain state getters (`enabled`, `preferFast`,
`report`, `coreInfo`, `downloadProgress`, `downloading`, `busy`, `pausedUntil`, and
`quotaReachedToday`, which compares the recorded quota day with today's local date) — none carries a
`/// Purpose:` block.

## Documentation

### `Future<void> setEnabled(bool value)` <a id="ondeviceaiservice-setenabled"></a>
- **Kind:** method of `OnDeviceAiService`
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (line 201)
- **Purpose:** Turn on-device AI on or off.
- **Inputs:** `value`.
- **Returns:** `Future<void>`.
- **Side effects:** On: refreshes the status. Off: fails every queued job with `unavailable`,
  resets the report to `unsupported`, forgets the core info, and cancels the running request.
  Notifies listeners.
- **Algorithm:** No-op when unchanged. Otherwise set the flag and notify; when switching on, await
  `refreshStatus()`; when switching off, remember whether a job was running, fail the queue, clear
  the status, call `backend.cancel()` only if something was running, and notify again.
- **Usage:** [`AppSettingsNotifier._loadPersisted`](../../../shared/providers/app_settings.md#loadpersisted)
  (awaited, after `setPreferFast`, so the startup probe already uses the persisted size preference)
  and `AppSettingsNotifier.setOnDeviceAiEnabled` (not awaited), which the switch in
  [`AiSettingsTiles`](../widgets/ai_settings_tiles.md) calls.
- **Notes:** Persisting the choice is `AppSettingsNotifier`'s job. The `cancel` call is the only
  backend call on the way off, and only when a request is in flight.

### `Future<void> refreshStatus({String? localeTag})` <a id="ondeviceaiservice-refreshstatus"></a>
- **Kind:** method of `OnDeviceAiService`
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (line 238)
- **Purpose:** Ask the device what the model can do.
- **Inputs:** `localeTag` — the app's locale (such as `zh_TW`), for Apple's `supportsLocale` report.
- **Returns:** `Future<void>`.
- **Side effects:** A forced `statusReport` probe and one `coreInfo` call; notifies listeners.
- **Algorithm:** Return while off. Off the supported platforms, set `unsupported` and notify.
  Otherwise store `statusReport(force: true, preferFast: ...)` and `coreInfo(localeTag: ...)`, then
  notify.
- **Usage:** `setEnabled(true)`, `setPreferFast` while on, `AiSettingsTiles.initState` (a
  post-frame callback, only while the switch is on) when Settings opens, and the *Check again*
  button, shown for `unavailable`, `unreachable`, `notEnabled`, `unknown` and `downloading` — see
  [`ai_settings_tiles.md`](../widgets/ai_settings_tiles.md).
- **Notes:** Does nothing while the switch is off — this is the status half of the gate. Calls from
  `setEnabled` and `setPreferFast` pass no `localeTag`.

### `Future<bool> download()` <a id="ondeviceaiservice-download"></a>
- **Kind:** method of `OnDeviceAiService`
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (line 256)
- **Purpose:** Ask the system to fetch the model (Android).
- **Inputs:** None.
- **Returns:** `Future<bool>` — whether the model is usable afterwards.
- **Side effects:** AICore downloads the model; `downloadProgress` updates as bytes arrive; notifies
  listeners.
- **Algorithm:**
  1. Refuse (return false) while off, while a request runs, or while a download already runs.
  2. Set `downloading` and a zero progress, notify, then call `backend.download`, keeping the last
     known total when a callback reports none.
  3. Swallow `GenAiException`; clear `downloading` and the progress in `finally`.
  4. Re-read the status (unforced) and return whether it is `available`.
- **Usage:** The Download button in [`AiSettingsTiles`](../widgets/ai_settings_tiles.md), shown
  on Android while the status is `downloadable` and disabled while a download runs.
- **Notes:** Started only from that button, never on the user's behalf (policy rule 7). A failure
  shows up through the re-read status, not as an exception.

### `Future<String> generate({required String instructions, required String prompt, int maxOutputTokens = 256, AiPriority priority = AiPriority.interactive})` <a id="ondeviceaiservice-generate"></a>
- **Kind:** method of `OnDeviceAiService`
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (line 287)
- **Purpose:** Generate one answer through the queue.
- **Inputs:** `instructions`, `prompt`, `maxOutputTokens`, `priority` (interactive by default).
- **Returns:** `Future<String>`; throws `GenAiException` on failure.
- **Side effects:** Runs the model on the device when its turn comes.
- **Algorithm:** Wraps `backend.generate` (with the default `temperature` 0 and `topK` 1) in
  [`_enqueue`](#ondeviceaiservice-_enqueue).
- **Usage:** `AiInsightStore._run` in [`insight_service.dart`](insight_service.md), with
  `maxOutputTokens: insightMaxOutputTokens` and `AiPriority.interactive` when the card's refresh
  forced it, `AiPriority.background` otherwise.
- **Notes:** Refused at once with `unavailable` while the switch is off. `choose` is the same shape
  with background priority by default.

### `Future<void> cancelBackground()` <a id="ondeviceaiservice-cancelbackground"></a>
- **Kind:** method of `OnDeviceAiService`
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (line 337)
- **Purpose:** Stop the running request and drop queued background work.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Fails queued background jobs with `cancelled`; calls `backend.cancel()` when a
  request is running and the switch is on.
- **Algorithm:** Keep the interactive jobs in order, fail and drop the rest, then cancel the
  running request.
- **Usage:** No caller in MyDevice; kept from MyAnime for a batch the user stops.
- **Notes:** Interactive requests already queued stay queued. The running request is cancelled
  whatever its priority.

### `void start()` <a id="ondeviceaiservice-start"></a>
- **Kind:** method of `OnDeviceAiService`
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (line 356)
- **Purpose:** Start following the app lifecycle.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Registers an `AppLifecycleListener` (once) whose `onStateChange` is
  `handleLifecycle`.
- **Algorithm:** `_lifecycle ??= AppLifecycleListener(onStateChange: handleLifecycle)`.
- **Usage:** [`main`](../../../main.md#main), as the last startup step, right after
  `AutoSyncService.instance.start()` and before `runApp`.
- **Notes:** Calls nothing on the backend; the switch still decides whether anything ever runs.

### `Future<T> _enqueue<T>(AiPriority priority, Future<T> Function(GenAiBackend backend) body)` <a id="ondeviceaiservice-_enqueue"></a>
- **Kind:** method of `OnDeviceAiService` (private)
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (line 376)
- **Purpose:** Queue a request.
- **Inputs:** `priority`, `body` — the backend call to make.
- **Returns:** `Future<T>` — the job's completer future.
- **Side effects:** Adds a job and schedules `_pump` in a microtask.
- **Algorithm:**
  1. While off, return `Future.error(GenAiException(unavailable))`.
  2. A background request after today's quota stop fails with `quota`.
  3. An interactive job goes in front of the first background job, behind earlier interactive
     ones; a background job goes to the end.
- **Usage:** `generate` and `choose`.
- **Notes:** None.

### `Future<void> _pump()` <a id="ondeviceaiservice-_pump"></a>
- **Kind:** method of `OnDeviceAiService` (private)
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (line 413)
- **Purpose:** Run the next eligible job.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Runs at most one job at a time; re-checks the status; notifies listeners; may
  arm a resume timer; re-arms itself.
- **Algorithm:**
  1. Return if a job is running, the queue is empty, the switch is off or the app is not resumed.
  2. For a background head: fail all background jobs with `quota` after today's quota stop; wait on
     a timer while a busy backoff is in force.
  3. Dequeue, set `busy`, notify, and re-read `statusReport(preferFast: ...)`. Fail the job with
     `unavailable` if the switch went off or the model is not `available`.
  4. Otherwise run `attempt` with the 45-second timeout, apply `_pace` (a non-`GenAiException`
     error counts as `failed`), then settle the job — so a caller that sees the failure also sees
     its effect on the queue.
  5. Clear `busy`, notify, and pump again.
- **Usage:** `_enqueue`, `handleLifecycle` on resume, the resume timer, and itself.
- **Notes:** The status check before every use is policy rule 3: the system can remove a model
  between two requests.

### `void _pace(GenAiFailure? failure)` <a id="ondeviceaiservice-_pace"></a>
- **Kind:** method of `OnDeviceAiService` (private)
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (line 462)
- **Purpose:** Adjust pacing after a job finished.
- **Inputs:** `failure` — null on success.
- **Returns:** None.
- **Side effects:** Sets the busy backoff, the quota day, or the not-resumed flag.
- **Algorithm:** `busy` → pause until now plus the current backoff, then double it up to 5 minutes;
  `quota` → record today; `background` → treat the app as not resumed until the next lifecycle
  change; success → reset the backoff to 5 seconds and clear the pause; other failures change
  nothing.
- **Usage:** `_pump`.
- **Notes:** The busy pause and the quota stop affect background jobs only; interactive jobs still
  run. In MyDevice an interactive request is a card refresh the user asked for and a background request
  is a card generated because its page opened (see the comments on `AiPriority`'s values).
