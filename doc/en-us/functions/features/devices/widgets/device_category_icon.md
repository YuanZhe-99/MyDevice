# lib/features/devices/widgets/device_category_icon.dart

Two top-level helpers for a `DeviceCategory` (see
[`../../models/device.md`](../models/device.md)): its Material outline `IconData`, and — since
1.5.6 — its localized name, which the service topology's node details show for a node's device.
The icon is used by
[`DeviceAvatar`](device_avatar.md) as the fallback icon when a device has no emoji or image, and
directly by device list/detail views wherever a bare category glyph is needed. See
[Devices](../../../../features/devices.md#device-avatar-rendering) for how this fits into avatar
rendering.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`deviceCategoryIcon`](#devicecategoryicon) | top-level function | A | Map a `DeviceCategory` to its outline icon. |
| [`deviceCategoryLabel`](#devicecategorylabel) | top-level function | A | Return a `DeviceCategory`'s localized name. |

Row count (2) matches `grep -c 'Purpose:' device_category_icon.dart` (2) exactly.

## Documentation

### `IconData deviceCategoryIcon(DeviceCategory category)` <a id="devicecategoryicon"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/devices/widgets/device_category_icon.dart` (line 11).
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

### `String deviceCategoryLabel(AppLocalizations l10n, DeviceCategory category)` <a id="devicecategorylabel"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/devices/widgets/device_category_icon.dart` (line 34).
- **Purpose:** Return the localized name of a device category.
- **Inputs:** `l10n`; `category`.
- **Returns:** `String` — the `deviceCategory*` ARB string of the category.
- **Side effects:** None.
- **Algorithm:** An exhaustive `switch` over the eleven `DeviceCategory` values.
- **Usage:** The service topology's node details (`service_topology_page.dart`), for the device
  tile's subtitle.
- **Notes:** The device editor, device list and finance overview each still keep a private copy
  of the same mapping (`_categoryLabel`); folding them onto this helper is left out of the 1.5.6
  topology work to keep its diff scoped.
