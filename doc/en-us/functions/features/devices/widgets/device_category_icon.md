# lib/features/devices/widgets/device_category_icon.dart

A single top-level helper mapping a `DeviceCategory` (see
[`../../models/device.md`](../models/device.md)) to a Material outline `IconData`. Used by
[`DeviceAvatar`](device_avatar.md) as the fallback icon when a device has no emoji or image, and
directly by device list/detail views wherever a bare category glyph is needed. See
[Devices](../../../../features/devices.md#device-avatar-rendering) for how this fits into avatar
rendering.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`deviceCategoryIcon`](#devicecategoryicon) | top-level function | A | Map a `DeviceCategory` to its outline icon. |

Row count (1) matches `grep -c 'Purpose:' device_category_icon.dart` (1) exactly.

## Documentation

### `IconData deviceCategoryIcon(DeviceCategory category)` <a id="devicecategoryicon"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/devices/widgets/device_category_icon.dart` (line 10).
- **Purpose:** Return a consistent Material outline icon for a device category, used anywhere a
  device needs a category glyph (avatar fallback, list/detail chips).
- **Inputs:** `category` — a `DeviceCategory` enum value.
- **Returns:** `IconData` — one specific outline icon per category (e.g. `desktop_windows_outlined`
  for `desktop`, `smartphone_outlined` for `phone`, `devices_other_outlined` for `other`).
- **Side effects:** None.
- **Algorithm:** A single exhaustive `switch` expression over all eleven `DeviceCategory` values,
  each mapped to one fixed `Icons.*_outlined` constant.
- **Usage:**
  ```dart
  Icon(
    deviceCategoryIcon(category),
    size: size * 0.5,
    color: cs.onPrimaryContainer,
  )
  ```
  (from `DeviceAvatar._fallbackIcon`/`_fallbackIconContent`, `lib/features/devices/widgets/device_avatar.dart`)
- **Notes:** The `switch` is exhaustive over the `DeviceCategory` enum, so adding a new category
  without a case here is a compile error, not a silent runtime fallback.
