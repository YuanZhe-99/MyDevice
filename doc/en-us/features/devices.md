# Devices

The device inventory is the app's primary feature. Model source:
`lib/features/devices/models/device.dart`. See [Data Formats](../data-formats.md#device-libfeaturesdevicesmodelsdevicedart)
for the exhaustive field list; this page focuses on behavior.

## Device model

`Device` tracks identity, category, emoji/image, brand/model/serial number, CPU, GPU,
RAM, storage, display, battery, OS, location, purchase/release dates, lifecycle status,
retirement/sale state, purchase price, sold price, recurring costs, notes, `modifiedAt`,
and unknown JSON fields (`extraJson`).

`DeviceCategory` values: `desktop`, `laptop`, `phone`, `tablet`, `headphone`, `watch`,
`router`, `gameConsole`, `vps`, `devBoard`, `other`.

## Drive status and RAID arrays

Since 1.8.2 each storage entry has a **status** — *Working* (default), *Failed* or *Offline* — and,
when not working, a free-text **status note**. A failed drive is kept rather than deleted: the
device details show its status in the error colour, and data set copies on it stop counting as
usable (see [Datasets](datasets.md#drive-health-and-raid-arrays)).

Below the storage rows the editor has a **RAID Arrays** section. Each array has a name, a level
(`RaidLevel`: RAID 0/1/5/6/10, RAID-Z1/Z2/Z3, JBOD, Other) and member drives picked as chips from
the device's storage rows; a drive already in another array is disabled, so a drive belongs to at
most one. Members follow their rows through edits: removing a storage row drops it from its array,
and the saved `memberIndices` are the compacted positions. On save, data set links to a slot that
joined an array move to the array, and links to a removed array are dropped
(`remapDeviceStorageLinks`).

The device details list, per drive, the array it belongs to, and one row per array:
"level · n drives", plus *Degraded* or *Data lost* in the error colour. An array's health comes
from `RaidLevel.faultTolerance`: with failed members within the tolerance (RAID 1: n − 1;
RAID 5/RAID-Z1/RAID 10: 1; RAID 6/RAID-Z2: 2; RAID-Z3: 3; RAID 0/JBOD: 0) it is *degraded*,
beyond it *data lost*; *Other* has no defined tolerance and is at worst degraded. RAID 10 counts
conservatively as tolerating one failure. The Markdown export and the local API include both
fields.

## Lifecycle and finance tracking

Added in `v0.4.0`. Confirmed in source (`Device.lifecycleStatus`):

```dart
DeviceLifecycleStatus get lifecycleStatus {
  if (isSold) return DeviceLifecycleStatus.sold;
  if (isRetired) return DeviceLifecycleStatus.retired;
  return DeviceLifecycleStatus.inService;
}
```

`isSold` takes priority over `isRetired` when both are set. Related finance getters:

- `hasFinancialData` — true if `purchasePrice`, `soldPrice`, or any `recurringCosts`
  entry is present.
- `serviceDays({asOf})` — days from `purchaseDate` through now (if in service) or
  `retiredDate` (if not), minimum 1 day; `null` if no `purchaseDate`.
- `recurringCostThrough({asOf})` — sum of each recurring cost's
  `dailyConvertedAmount * serviceDays`.
- `totalCost({asOf})` — `purchasePrice.convertedAmount + recurringCostThrough -
  soldPrice.convertedAmount`.
- `averageDailyCost({asOf})` — `totalCost / serviceDays`, or `null` without financial
  data or a purchase date.

`DeviceRecurringCost.dailyConvertedAmount` derives from `billingCycle`
(`BillingCycle.monthly` → `price.convertedAmount * 12`, `yearly` → `price.convertedAmount`
directly) divided by 365.

### Cascade rules on retire/sell/delete <a id="cascade-rules-on-retiresell-delete"></a>

- Retired or sold devices must be removed from network assignments and dataset storage
  links, and excluded from network/storage pickers.
- Deleting a device must remove related network assignments, dataset storage links,
  service records, and service route references (see
  [Data Formats](../data-formats.md#cross-reference-rules)).
- Device detail and Markdown export include lifecycle and finance information when
  relevant (see [Backup and Restore](../backup-restore.md#markdown-export)).

## Financial overview page

`lib/features/devices/views/device_finance_overview_page.dart`
(`DeviceFinanceOverviewPage`) opens from the device list's financial overview card. It
shows two views built with `fl_chart`:

1. **Asset distribution** — total-cost by device category.
2. **Daily-cost trend** — a combined historical/future line chart. The future segment
   is rendered dashed (confirmed: `dashArray: series.dashed ? [7, 5] : null` on the
   `LineChartBarData`), using the selected range as the forward projection window.

The daily-cost axis always uses a **log-style transform**, confirmed in source:

```dart
double _logTransform(double value) {
  final sign = value < 0 ? -1.0 : 1.0;
  return sign * math.log(value.abs() + 1) / math.ln10;
}
```

(a signed `log10(|x| + 1)` transform, with `_logInverse` undoing it for axis labels and
tooltips) — this keeps small daily costs readable on the same chart as large one-time
purchase spikes.

When on-device AI is on, an **AI insight** card follows the trend: the overall cost picture, one
spending suggestion and one device worth reviewing under *Costs*, and a recurring-cost summary under
*Recurring Costs*. It is built from aggregates and device names only — never serial numbers, notes
or locations — and renders nothing otherwise. See [On-device AI](../on-device-ai.md#insight-cards).

## Device avatar rendering

`lib/features/devices/widgets/device_avatar.dart` (`DeviceAvatar`,
`DeviceAvatar.fromDevice`) is the shared circular avatar renderer used anywhere a
device needs an icon:

- If `emoji` is set, it's centered over a `primaryContainer`-colored circle.
- Else if `imagePath` is set, `ImageService.resolve()` loads the file and it's rendered
  `ClipOval` + `BoxFit.cover`, center-cropped over a `surfaceContainerHighest`
  background with a subtle `outlineVariant` border — this keeps transparent PNGs
  visible against the circular frame.
- Else, if `templateImage` (a thumbnail the user chose by hand) names a bundled thumbnail that
  still exists, that is shown (since 1.6.1; a path a later release removed is ignored).
- Else, if the device's brand+model (or name) equals a bundled template that has an `image`,
  that transparent thumbnail is shown (`PresetService.matchTemplateImage`; normalized exact match,
  so `iPhone 15` never takes the `iPhone 15 Pro` photo). This match is display-only: nothing is
  written to the device, so existing devices get thumbnails too and older builds just show the icon.
- Any missing/failed image (including `Image.file`'s `errorBuilder`) falls back to a
  consistent outline category icon (`deviceCategoryIcon(category)` from
  `device_category_icon.dart`).

## Icon and image <a id="icon-and-image"></a>

The editor's icon section (`_buildIconSection` in `device_edit_page.dart`) shows the live avatar
and these chips; each choice clears the others, since only one of them can show:

| Chip | Does | Stored as |
|---|---|---|
| **Icon** | Emoji picker | `emoji` |
| **Pick Image** / **Change** | File picker, then the image editor | `imagePath` (a new file under `images/`) |
| **Edit Image** (when a photo is set) | Re-opens the current photo in the image editor | `imagePath` (a new file) |
| **Thumbnail** | Searchable grid of bundled thumbnails, best candidates first, with **Automatic** first ([details](online-search-and-presets.md#device-thumbnails)) | `templateImage`, or nothing for Automatic |
| **Remove Icon** | Clears all three | — |

**Image editor (since 1.6.1)** — `lib/features/devices/views/device_image_editor_page.dart`,
opened by `showDeviceImageEditor`. A picked photo is decoded by the platform codec (so formats
Flutter can show, and EXIF orientation, behave as on screen; `package:image` is the fallback),
reduced to 1024 px while decoding, and edited with:

- **Crop** — drag and pinch/scroll-zoom a square view with a circle guide; the visible part is
  the region kept.
- **Remove background** with a **Tolerance** slider — the same edge flood fill as the thumbnail
  tooling, which clears a plain background connected to the border and keeps a white screen or
  logo inside the device.
- **Rounded corners** — a rounded-rectangle mask instead of removal, for a phone or tablet
  cropped tightly against a busy background.
- **Size in circle** (40–100 %) — how much of the circle the trimmed device fills; lower values
  leave more margin around it.

A small preview (384 px source, 256 px output) runs in an isolate about 150 ms after each change,
shown both large and at list size on the avatar's own fill colour. **Use** makes the final image —
a 512 px transparent PNG — and saves it as a new `images/<uuid>.png`. When adding a photo, **Use
Original** (or a file neither decoder can read) stores the file unchanged as before 1.6.1;
cancelling adds nothing. The previous file of an edited or replaced photo stays on disk
unreferenced, as it always has. The pipeline is `processDeviceImage` in
`lib/shared/utils/device_image_processing.dart`, shared with `tool/prepare_device_image.dart`.

## Related

- [Data Formats](../data-formats.md) for the full field list and `MoneyValue`/
  `DeviceRecurringCost` shape.
- [Online Search and Presets](online-search-and-presets.md) for how device specs get
  populated from online sources or bundled presets.
- [Backup and Restore](../backup-restore.md) for how device data (and images) back up,
  restore, and export.
