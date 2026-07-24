# lib/shared/services/sync_wake_lock.dart

A tiny static-only helper wrapping `wakelock_plus` so foreground WebDAV operations (manual sync,
conflict finalize, force upload/download) keep the screen/device awake while they run. It is used
exclusively from `lib/shared/views/webdav_config_page.dart`; background `auto_sync_service.dart`
(see [`auto_sync_service.md`](auto_sync_service.md)) never calls it, per the WebDAV sync rules in
`../../../AGENTS.md`. See also `../../../sync.md` for how this fits into the overall sync flow.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`SyncWakeLock`](#syncwakelock) | class | A | Keep the device/screen awake while a foreground sync operation is running. |
| `SyncWakeLock._()` | constructor | B | Prevent instantiation; this class only has static members. |
| [`acquire`](#acquire) | static method (`SyncWakeLock`) | A | Acquire the sync wake lock for one foreground operation. |
| [`release`](#release) | static method (`SyncWakeLock`) | A | Release the sync wake lock for one foreground operation. |

Row count (4) matches `grep -c 'Purpose:' sync_wake_lock.dart` (4) exactly — unlike this batch's
other files, the `SyncWakeLock` class doc comment itself uses the `Purpose:` format, so it gets its
own row here in addition to its members.

## Documentation

### `class SyncWakeLock` <a id="syncwakelock"></a>
- **Kind:** class (static-members-only)
- **Source:** `lib/shared/services/sync_wake_lock.dart` (approx. line 14)
- **Purpose:** Keep the device/screen awake while a foreground sync operation (manual sync,
  conflict finalize, force upload/download) is running.
- **Inputs:** None (all state is static).
- **Returns:** None.
- **Side effects:** Enables/disables the platform wake lock through `wakelock_plus` via its static
  `acquire()`/`release()` methods.
- **Algorithm:** Holds two static fields — `_refCount` (int) and `_enabledBySync` (bool) — that
  `acquire()`/`release()` use to reference-count overlapping callers and to track whether this class
  is the one that turned the wake lock on. See [`acquire`](#acquire) and [`release`](#release) for
  the per-call logic.
- **Usage:** Not instantiated directly; call the static `SyncWakeLock.acquire()` /
  `SyncWakeLock.release()` methods.
- **Notes:** Reference-counted so overlapping foreground operations share one lock.
  Ownership-tracked so releasing never disables a wake lock some other feature (e.g. a page-held
  lock) enabled first. Background auto-sync must not use this class. All plugin calls swallow
  errors so a wake-lock failure can never break a sync operation.

### `static Future<void> acquire()` <a id="acquire"></a>
- **Kind:** static method of `SyncWakeLock`
- **Source:** `lib/shared/services/sync_wake_lock.dart` (approx. line 33)
- **Purpose:** Acquire the sync wake lock for one foreground operation, reference-counting
  overlapping callers.
- **Inputs:** None.
- **Returns:** A future that completes once the wake lock state is applied.
- **Side effects:** Increments `_refCount`; on the first concurrent acquire (`_refCount` going from
  0 to 1), enables the platform wake lock via `WakelockPlus.enable()` unless another feature already
  holds it.
- **Algorithm:** 1. Increment `_refCount`. 2. If this was not the first acquire (`_refCount > 1`),
  return immediately — a lock is already held. 3. Otherwise check `WakelockPlus.enabled`; if not
  already enabled, call `WakelockPlus.enable()` and record `_enabledBySync = true` so `release()`
  knows this class turned it on. 4. Any plugin exception is swallowed.
- **Usage:**
  ```dart
  await SyncWakeLock.acquire();
  SyncResult result;
  try {
    result = await WebDAVService.sync(_currentConfig);
  } finally {
    await SyncWakeLock.release();
  }
  ```
  (from `lib/shared/views/webdav_config_page.dart`, `_syncNow()`)
- **Notes:** Always pair with `release()` in a `finally` block. Reference-counted so nested/parallel
  foreground operations share one underlying lock; ownership-tracked (`_enabledBySync`) so releasing
  never disables a wake lock some other feature enabled first.

### `static Future<void> release()` <a id="release"></a>
- **Kind:** static method of `SyncWakeLock`
- **Source:** `lib/shared/services/sync_wake_lock.dart` (approx. line 53)
- **Purpose:** Release the sync wake lock for one foreground operation.
- **Inputs:** None.
- **Returns:** A future that completes once the wake lock state is applied.
- **Side effects:** Decrements `_refCount`; on the last concurrent release, disables the platform
  wake lock via `WakelockPlus.disable()` if and only if `acquire()` originally enabled it.
- **Algorithm:** 1. If `_refCount == 0`, return immediately (nothing held). 2. Decrement
  `_refCount`. 3. If other callers still hold the lock (`_refCount > 0`) or this class never enabled
  it (`!_enabledBySync`), return. 4. Otherwise clear `_enabledBySync` and call
  `WakelockPlus.disable()`, swallowing any plugin exception.
- **Usage:** See [`acquire`](#acquire) — always called in the matching `finally` block.
- **Notes:** Safe to call even when nothing is held (no-op). Plugin errors are swallowed so a
  wake-lock failure can never break a sync operation.
