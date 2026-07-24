# lib/shared/services/sync_progress.dart

Defines the value type published by `WebDAVService.progress` (see
[`webdav_service.md`](webdav_service.md)) to report live sync status to the UI. The file also
declares the `SyncPhase` enum (`idle`, `connecting`, `downloadingData`, `merging`, `uploadingData`,
`uploadingImages`, `downloadingImages`, `done`, `error`) that `SyncProgress.phase` holds, and the
`SyncProgress.idle` constant resting value; both are plain data declarations with no behavior, so
they are described here rather than given their own table rows. `WebDAVConfigPage` (the WebDAV
settings page) binds a `ValueListenableBuilder<SyncProgress>` to `WebDAVService.progress` and maps
phases to localized strings and a `LinearProgressIndicator`. See `../../../sync.md` for the overall
sync architecture this progress reporting is part of.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`SyncProgress`](#syncprogress-new) | constructor | A | Create an immutable sync progress snapshot. |
| [`fraction`](#fraction) | getter (`SyncProgress`) | A | Return the completed fraction of the current phase. |
| [`isRunning`](#isrunning) | getter (`SyncProgress`) | A | Return whether a sync/force operation is currently running. |
| [`SyncProgressListenable`](#syncprogresslistenable) | typedef | B | Expose a `ValueListenable` type alias for sync progress consumers. |

Row count (4) matches `grep -c 'Purpose:' sync_progress.dart` (4). The `SyncPhase` enum and the
`SyncProgress.idle` static constant are real declarations in the file but carry plain (non-
`Purpose:`) doc comments, consistent with AGENTS.md's Function Explanation Layer, which scopes the
`Purpose:`-comment convention to functions/methods/constructors/getters/setters — not bare enums or
data constants; they are covered in the overview above instead of a table row.

## Documentation

### `const SyncProgress(this.phase, {this.detail, this.current = 0, this.total = 0})` <a id="syncprogress-new"></a>
- **Kind:** constructor of `SyncProgress`
- **Source:** `lib/shared/services/sync_progress.dart` (approx. line 38)
- **Purpose:** Create an immutable snapshot of sync progress (phase, optional detail string, and a
  current/total pair for measurable phases).
- **Inputs:** `phase` (`SyncPhase`); optional `detail` (raw file/image name or error message),
  `current` (1-based index), `total` (0 means indeterminate).
- **Returns:** A new `SyncProgress` instance.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment via an initializer list; no computation.
- **Usage:**
  ```dart
  progress.value = SyncProgress(
    phase,
    detail: detail,
    current: current,
    total: total,
  );
  ```
  (from `WebDAVService._reportProgress`, `lib/shared/services/webdav_service.dart`)
- **Notes:** `total == 0` means the phase has no measurable item count (indeterminate progress).

### `double? get fraction` <a id="fraction"></a>
- **Kind:** getter of `SyncProgress`
- **Source:** `lib/shared/services/sync_progress.dart` (approx. line 53)
- **Purpose:** Return the completed fraction of the current phase for progress-bar binding.
- **Inputs:** None.
- **Returns:** `double?` in `0..1`, or `null` when `total` is zero (indeterminate).
- **Side effects:** None.
- **Algorithm:** 1. If `total > 0`, compute `current / total`, clamp to `[0.0, 1.0]`. 2. Otherwise
  return `null`.
- **Usage:**
  ```dart
  ValueListenableBuilder<SyncProgress>(
    valueListenable: WebDAVService.progress,
    builder: (context, progress, _) => LinearProgressIndicator(value: progress.fraction),
  )
  ```
  (adapted from `lib/shared/views/webdav_config_page.dart`, which binds to `WebDAVService.progress`)
- **Notes:** Bind directly to `LinearProgressIndicator.value`, which already accepts a nullable
  fraction for indeterminate mode.

### `bool get isRunning` <a id="isrunning"></a>
- **Kind:** getter of `SyncProgress`
- **Source:** `lib/shared/services/sync_progress.dart` (approx. line 61)
- **Purpose:** Return whether a sync/force operation is currently running.
- **Inputs:** None.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** True when `phase` is none of `idle`, `done`, or `error` (the three non-running
  states).
- **Usage:** Consumed the same way as [`fraction`](#fraction), via a
  `ValueListenableBuilder<SyncProgress>` on `WebDAVService.progress`, to decide whether to show the
  progress UI at all.
- **Notes:** `done` and `error` are terminal, not running, states — a caller must reset to `idle`
  or start a new operation to see `isRunning` become true again.

### `typedef SyncProgressListenable = ValueListenable<SyncProgress>` <a id="syncprogresslistenable"></a>
- **Kind:** typedef (top-level)
- **Source:** `lib/shared/services/sync_progress.dart` (approx. line 72)
- **Purpose:** Give the `ValueListenable<SyncProgress>` type a descriptive alias for consumers.
- **Inputs:** None.
- **Returns:** None (type alias only).
- **Side effects:** None.
- **Algorithm:** None — pure type alias, no runtime behavior.
- **Usage:** Not referenced by name elsewhere in the repo; `WebDAVService.progress` is declared and
  consumed as `ValueNotifier<SyncProgress>` / `ValueListenableBuilder<SyncProgress>` directly.
- **Notes:** UI pages listen with `ValueListenableBuilder<SyncProgress>` rather than this alias in
  current code.
