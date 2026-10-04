# lib/features/devices/widgets/storage_health_label.dart

One top-level helper (since 1.8.2) giving the localized name of a drive's `StorageHealth` (see
[`../models/device.md`](../models/device.md)) — the status a storage slot records: working, failed
or offline. See [Devices](../../../../features/devices.md) for drive health and RAID arrays.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`storageHealthLabel`](#storagehealthlabel) | top-level function | A | Return a `StorageHealth`'s localized name. |

Row count (1) matches `grep -c 'Purpose:' storage_health_label.dart` (1) exactly.

## Documentation

### `String storageHealthLabel(AppLocalizations l10n, StorageHealth health)` <a id="storagehealthlabel"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/devices/widgets/storage_health_label.dart` (line 10).
- **Purpose:** Return the localized name of a drive's health.
- **Inputs:** `l10n`; `health`.
- **Returns:** `String` — `storageStatusOk`, `storageStatusFailed` or `storageStatusOffline`.
- **Side effects:** None.
- **Algorithm:** An exhaustive `switch` over the three `StorageHealth` values.
- **Usage:** The status dropdown of a storage row in
  [`device_edit_page.md`](../views/device_edit_page.md); the storage status row in
  [`device_detail_page.md`](../views/device_detail_page.md); a failed or offline slot's state in
  [`dataset_edit_page.md`](../../datasets/views/dataset_edit_page.md#buildplacetile) and in the
  boxes and details of [`dataset_topology_page.md`](../../datasets/views/dataset_topology_page.md).
- **Notes:** The one mapping of a health value to its name, so a new value needs only one case
  here (the `switch` is exhaustive, so a missing case is a compile error).
