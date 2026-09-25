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
- **Usage:** Every place the app shows a category's name: the category dropdown in
  [`device_edit_page.dart`](../views/device_edit_page.md); the category group headers and the
  `_DeviceCard` subtitles in [`device_list_page.dart`](../views/device_list_page.md); the asset
  distribution buckets in
  [`device_finance_overview_page.dart`](../views/device_finance_overview_page.md); the device
  group headers in [`network_detail_page.dart`](../../network/views/network_detail_page.md); the
  service topology's node details (`service_topology_page.dart`), for the device tile's subtitle;
  and a device node's subtitle on the topology canvas
  ([`service_topology_widgets.dart`](../../services/views/service_topology_widgets.md#nodesubtitle)).
- **Notes:** The one mapping of a category to its name. Before 1.5.7 the device editor, device
  list, finance overview and network detail page each kept a private copy (`_categoryLabel`); they
  now all call this helper, so a new category needs only one case here.
