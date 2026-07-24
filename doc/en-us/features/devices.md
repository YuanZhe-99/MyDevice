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

### Cascade rules on retire/sell/delete

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

## Device avatar rendering

`lib/features/devices/widgets/device_avatar.dart` (`DeviceAvatar`,
`DeviceAvatar.fromDevice`) is the shared circular avatar renderer used anywhere a
device needs an icon:

- If `emoji` is set, it's centered over a `primaryContainer`-colored circle.
- Else if `imagePath` is set, `ImageService.resolve()` loads the file and it's rendered
  `ClipOval` + `BoxFit.cover`, center-cropped over a `surfaceContainerHighest`
  background with a subtle `outlineVariant` border — this keeps transparent PNGs
  visible against the circular frame.
- Any missing/failed image (including `Image.file`'s `errorBuilder`) falls back to a
  consistent outline category icon (`deviceCategoryIcon(category)` from
  `device_category_icon.dart`).

## Related

- [Data Formats](../data-formats.md) for the full field list and `MoneyValue`/
  `DeviceRecurringCost` shape.
- [Online Search and Presets](online-search-and-presets.md) for how device specs get
  populated from online sources or bundled presets.
- [Backup and Restore](../backup-restore.md) for how device data (and images) back up,
  restore, and export.
