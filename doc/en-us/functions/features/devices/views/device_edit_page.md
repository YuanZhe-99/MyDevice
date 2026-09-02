# lib/features/devices/views/device_edit_page.dart

The add/edit form for a single `Device` (model source `lib/features/devices/models/device.dart`;
full field list in
[Data Formats](../../../../data-formats.md#device-libfeaturesdevicesmodelsdevicedart)).
`DeviceEditPage`/`_DeviceEditPageState` own one `TextEditingController` (or plain field) per
editable property — including one set of controllers per storage row and per recurring-cost
draft — and assemble all of it into a new `Device` on save. It integrates with `PresetService`
(bundled CPU/GPU/brand presets, browsed via the private `_CpuPresetPicker`/`_GpuPresetPicker`
bottom sheets), the online search dialogs in `chip_search_dialog.dart`/`device_search_dialog.dart`
(gated by `AppFlavor.isFull` — see
[Online Search and Presets](../../../../features/online-search-and-presets.md)), and
`DeviceExchangeRateService` (currency conversion for purchase/sold price and each recurring cost).
Saving is also the one place in the app that keeps [DataSet](../../../../features/datasets.md)
storage links valid: this file tracks each storage row's original slot index across adds/removes
and passes the resulting old→new map to `DataSetStorage.remapDeviceStorageLinks()` on save — see
[`_save`](#_save) and [Datasets](../../../../features/datasets.md#remapdevicestoragelinks). See
also [Devices](../../../../features/devices.md) for the broader feature and lifecycle/finance
model this form edits.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DeviceEditPage` (constructor) | constructor | B | Store the optional `device` (edit target) and `searchResult` (prefill map) for the widget. |
| `createState` | method (`DeviceEditPage`) | B | Create `_DeviceEditPageState`. |
| `_isEditing` | getter (`_DeviceEditPageState`) | B | True when editing an existing device (`widget.device != null`) rather than adding a new one. |
| [`initState`](#initstate) | method (widget lifecycle) | A | Seed every controller/field from `widget.device` (or defaults) and kick off async preset/financial-settings loading. |
| [`_loadFinancialSettings`](#_loadfinancialsettings) | method (`_DeviceEditPageState`) | A | Load the app default currency/auto-rate setting and adopt the new default for not-yet-customized price fields. |
| [`_loadPresets`](#_loadpresets) | method (`_DeviceEditPageState`) | A | Load CPU/GPU/brand presets, then apply a carried-in search result once presets are ready. |
| `dispose` | method (widget lifecycle) | B | Dispose every controller this state owns, including per-storage-slot and per-recurring-cost-draft controllers. |
| [`_parseValueUnit`](#_parsevalueunit) | static method (`_DeviceEditPageState`) | A | Parse `"16 GB"`-style text into a `(value, unit)` pair. |
| `_combineValueUnit` | method (`_DeviceEditPageState`) | B | Join a trimmed value and unit into `"value unit"`, or `null` if the value is blank. |
| `_nonEmpty` | method (`_DeviceEditPageState`) | B | Trim a string and return `null` in place of an empty result. |
| `_parseInt` | method (`_DeviceEditPageState`) | B | Parse a trimmed string to `int`, or `null`. |
| [`_parseMoney`](#_parsemoney) | method (`_DeviceEditPageState`) | A | Parse a user-typed amount, tolerating thousands-separator commas. |
| [`_parseRate`](#_parserate) | method (`_DeviceEditPageState`) | A | Resolve a manual exchange-rate override, but only when the currency differs from the default. |
| `_acquisitionTypeLabel` | method (`_DeviceEditPageState`) | B | Map a `DeviceAcquisitionType` to its localized label. |
| `_recurringCostKindLabel` | method (`_DeviceEditPageState`) | B | Map a `RecurringCostKind` to its localized label. |
| `_billingCycleLabel` | method (`_DeviceEditPageState`) | B | Map a `BillingCycle` to its localized label. |
| [`_save`](#_save) | method (`_DeviceEditPageState`) | A | Validate, assemble and persist the edited `Device`, and remap dataset storage links for any moved/removed storage slots. |
| `_pickDate` | method (`_DeviceEditPageState`) | B | Show a date picker (2000..+365 days) and set `_purchaseDate` on selection. |
| `_pickReleaseDate` | method (`_DeviceEditPageState`) | B | Show a date picker and set `_releaseDate` on selection. |
| `_pickRetiredDate` | method (`_DeviceEditPageState`) | B | Show a date picker and set `_retiredDate` on selection. |
| `_storageTypeLabel` | method (`_DeviceEditPageState`) | B | Map a `StorageType` to its localized label. |
| `_storageInterfaceLabel` | method (`_DeviceEditPageState`) | B | Map a `StorageInterface` to its localized label. |
| `_categoryLabel` | method (`_DeviceEditPageState`) | B | Map a `DeviceCategory` to its localized label. |
| `_applyCpuPreset` | method (`_DeviceEditPageState`) | B | Copy a `CpuInfo` preset's fields into the CPU controllers and bump `_cpuAutoKey` to refresh the `Autocomplete`. |
| `_applyGpuPreset` | method (`_DeviceEditPageState`) | B | Copy a `GpuInfo` preset's fields into the GPU controllers and bump `_gpuAutoKey`. |
| `_searchCpuOnline` | method (`_DeviceEditPageState`) | B | Open the CPU search dialog and apply the chosen result via `_applyCpuPreset`. |
| `_searchGpuOnline` | method (`_DeviceEditPageState`) | B | Open the GPU search dialog and apply the chosen result via `_applyGpuPreset`. |
| `_pickCpuPreset` | method (`_DeviceEditPageState`) | B | Open the CPU preset bottom sheet (`_CpuPresetPicker`) and apply the chosen preset. |
| `_pickGpuPreset` | method (`_DeviceEditPageState`) | B | Open the GPU preset bottom sheet (`_GpuPresetPicker`) and apply the chosen preset. |
| [`_showSearchDialog`](#_showsearchdialog) | method (`_DeviceEditPageState`) | A | Open the online device-search dialog seeded with current field values and apply the chosen result. |
| [`_applySearchResult`](#_applysearchresult) | method (`_DeviceEditPageState`) | A | Apply a search-result field map onto the form, fuzzy-matching CPU/GPU text against loaded presets. |
| [`_detectLogoForModel`](#_detectlogoformodel) | method (`_DeviceEditPageState`) | A | Find an SVG logo path for a live-typed CPU/GPU model string. |
| `_brandLogoWidget` | method (widget helper) | B | Render a small SVG logo (tinted to `onSurface`), or nothing if `logoPath` is null. |
| `_showEmojiPicker` | method (`_DeviceEditPageState`) | B | Show a bottom-sheet grid of `_commonEmojis`; tapping one sets `_emoji` and clears `_imagePath`. |
| [`_pickImage`](#_pickimage) | method (`_DeviceEditPageState`) | A | Let the user pick a photo and adopt it as the device's icon, clearing any emoji. |
| `_removeIcon` | method (`_DeviceEditPageState`) | B | Clear both `_emoji` and `_imagePath`. |
| `_buildIconSection` | method (widget helper) | B | Render the avatar preview plus image-pick/emoji-pick/remove actions; `avatarSize` (56, or `editAvatarSize` in the two-pane left pane) and `stacked` (chips centred under the preview rather than beside it). |
| `_buildNameField` | method (widget helper) | B | The validated name `TextFormField`, shared by the single column and the two-pane left pane. |
| `_buildCategoryField` | method (widget helper) | B | The category `DropdownButtonFormField`, shared likewise. |
| `_buildFormBody` | method (widget helper) | B | Choose the layout inside the one `Form`: the single-column `ListView` of `_buildFields`, or — when `useDetailTwoPane` passes — a `Row` of a `detailLeftPaneWidth`-wide left pane (stacked icon section at `editAvatarSize`, name, category; a `SingleChildScrollView` pinned to the pane height as the soft-keyboard fallback) and a right `ListView` of the remaining fields. |
| `_buildFields` | method (widget helper) | B | The full field list in its original order; `twoPane` omits the name, category and icon section that the left pane renders itself. |
| `_currencyItems` | method (widget helper) | B | Build the currency dropdown's items from `supportedCurrencies`, plus `current` if not already listed. |
| `_buildMoneyFields` | method (widget helper) | B | Render an amount+currency row and, for a non-default currency, an auto-rate checkbox and manual-rate field. |
| `_addRecurringCost` | method (`_DeviceEditPageState`) | B | Append a new blank `_RecurringCostDraft` (default kind `other`, currency = `_defaultCurrency`). |
| `_buildRecurringCostCard` | method (widget helper) | B | Render one recurring-cost draft's editable card (kind/name/billing cycle/money fields/remove button). |
| `_buildFinancialSection` | method (widget helper) | B | Render the acquisition/lifecycle/purchase/sold/recurring-costs financial section. |
| `build` | method (widget) | B | Build the scaffold and app bar (save + online-search actions) around `_buildFormBody`. |
| `_RecurringCostDraft` (constructor) | constructor | B | Create a draft with fresh amount/name/rate controllers, defaulting `billingCycle` to monthly and `autoRate` to true. |
| [`_RecurringCostDraft.fromCost`](#_recurringcostdraft-fromcost) | factory constructor (`_RecurringCostDraft`) | A | Convert a persisted `DeviceRecurringCost` into an editable draft. |
| `dispose` | method (`_RecurringCostDraft`) | B | Dispose the draft's three controllers. |
| `_CpuPresetPicker` (constructor) | constructor | B | Store the `presets` list for the bottom sheet widget. |
| `createState` | method (`_CpuPresetPicker`) | B | Create `_CpuPresetPickerState`. |
| [`_filtered`](#_filtered-cpu) (CPU) | getter (`_CpuPresetPickerState`) | A | Filter `widget.presets` to entries whose model/architecture contains the current search query. |
| `_coresLabel` | method (`_CpuPresetPickerState`) | B | Join present P/E-core and thread counts into an `"8P+4E+16T"`-style label. |
| `build` | method (widget, `_CpuPresetPickerState`) | B | Render the draggable sheet: a search field plus a list of `_filtered` presets. |
| `_GpuPresetPicker` (constructor) | constructor | B | Store the `presets` list for the bottom sheet widget. |
| `createState` | method (`_GpuPresetPicker`) | B | Create `_GpuPresetPickerState`. |
| [`_filtered`](#_filtered-gpu) (GPU) | getter (`_GpuPresetPickerState`) | A | Filter `widget.presets` to entries whose model/architecture contains the current search query. |
| `build` | method (widget, `_GpuPresetPickerState`) | B | Render the draggable sheet: a search field plus a list of `_filtered` presets. |

Row-count note: `grep -c 'Purpose:'` on this file returns 55, matching the 55 rows above exactly —
every declaration in this file (including every field-mapping label helper) carries the repo's
standard `/// Purpose:` doc-comment block.

Anchor-collision note: `_filtered` is declared twice (once in `_CpuPresetPickerState`, once in
`_GpuPresetPickerState`, both Tier A). Per the bare-name anchor rule these would collide, so this
page disambiguates with `_filtered-cpu` / `_filtered-gpu` instead of the usual bare-name anchor —
use the links in the table above rather than guessing the anchor from the name alone.

## Documentation

### `void initState()` <a id="initstate"></a>
- **Kind:** method of `_DeviceEditPageState` (widget lifecycle)
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 129)
- **Purpose:** Initialize every text controller and editable field from `widget.device` (or
  defaults, for a new device), including reconstructing the per-slot storage editor rows, then
  kick off async preset/financial-settings loading.
- **Inputs:** None (reads `widget.device`; `widget.searchResult` is consumed later, inside
  `_loadPresets`).
- **Returns:** None.
- **Side effects:** Creates roughly two dozen `TextEditingController`s (plus one pair per existing
  storage slot); sets ~20 plain state fields; calls `_loadPresets()` and
  `_loadFinancialSettings()` (each does async IO and later calls `setState`).
- **Algorithm:**
  1. Captures `d = widget.device` (`null` when adding a new device).
  2. For each simple text field (name, brand, model, serial number, screen size, battery, OS,
     location, notes), creates a controller seeded with `d?.field ?? ''`.
  3. RAM: parses `d?.ram` via [`_parseValueUnit`](#_parsevalueunit) into a `(value, unit)` pair;
     seeds `_ramCtrl`/`_ramUnit` from it; copies `d?.ramType`.
  4. Purchase/sold price: seeds the amount controller with `.amount.toString()`; seeds the *rate*
     controller only when the price exists **and** its `currency != defaultCurrency` (otherwise
     leaves it blank) — the same rule [`_parseRate`](#_parserate) enforces again at save time.
  5. CPU/GPU: seeds each controller from `d?.cpu`/`d?.gpu` fields (numeric fields via `.toString()`).
  6. Screen resolution width/height seeded the same way.
  7. Copies `category` (defaulting to `DeviceCategory.phone`), and the lifecycle/finance fields:
     purchase/release/retired dates, acquisition type, retired/sold flags, purchase/sold
     currencies and auto-rate flags.
  8. Converts `d?.recurringCosts` to drafts via
     [`_RecurringCostDraft.fromCost`](#_recurringcostdraft-fromcost).
  9. Storage: if `d != null && d.storage.isNotEmpty`, loops `i` over `d.storage`, parsing each
     slot's `capacity` with `_parseValueUnit` and populating five parallel lists, plus
     `_storageOriginalIndices.add(i)` — recording the slot's original index for later remap.
     Otherwise seeds a single empty row with `_storageOriginalIndices = [null]`.
  10. Calls `_loadPresets()` then `_loadFinancialSettings()` (fire-and-forget async, not awaited).
- **Usage:** Invoked automatically by the Flutter framework when `DeviceEditPage` is first built;
  not called directly anywhere in the codebase.
- **Notes:** `_storageOriginalIndices` is the field that makes storage-slot remapping possible on
  save — see [`_save`](#_save) and
  [Datasets](../../../../features/datasets.md#remapdevicestoragelinks). Rows added later in the
  session get `null` here so they're never mistaken for a pre-existing slot.

### `Future<void> _loadFinancialSettings()` <a id="_loadfinancialsettings"></a>
- **Kind:** method of `_DeviceEditPageState`
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 252)
- **Purpose:** Load the app-wide default currency and auto-update-rate preference, and adopt the
  new default currency for purchase/sold price fields that hadn't been customized away from the
  old default.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Two awaited `DeviceExchangeRateService` calls (`getDefaultCurrency`,
  `getAutoUpdateEnabled`); one `setState`.
- **Algorithm:**
  1. Awaits `DeviceExchangeRateService.getDefaultCurrency()` and `getAutoUpdateEnabled()`.
  2. Returns early if the widget is no longer mounted.
  3. In `setState`: captures the old `_defaultCurrency` before overwriting it and
     `_autoUpdateRates`.
  4. If this is a new device (`widget.device?.purchasePrice == null`) and `_purchaseCurrency`
     still equals the *old* default, updates `_purchaseCurrency` to the new default (same check
     for `_soldCurrency`/`soldPrice`). An existing device's already-set currency is left untouched
     even if it happens to equal the old default.
- **Usage:** Called once from `initState` (line 244); not called elsewhere.
- **Notes:** Runs independently of `_loadPresets()` — both are fire-and-forget from `initState`
  and each checks `mounted` on its own before calling `setState`.

### `Future<void> _loadPresets()` <a id="_loadpresets"></a>
- **Kind:** method of `_DeviceEditPageState`
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 276)
- **Purpose:** Load the bundled CPU/GPU/brand preset lists, then — for a device created from an
  online search result — apply that result to the form once presets are available.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Three awaited `PresetService` loads; one `setState`; may call
  `_applySearchResult` (which itself calls `setState` again).
- **Algorithm:**
  1. Awaits `PresetService.loadCpus()`, `loadGpus()`, `loadBrands()`.
  2. If mounted, `setState`s `_cpuPresets`/`_gpuPresets`/`_brandPresets`.
  3. If `widget.searchResult != null` (page opened via `DeviceEditPage(searchResult: result)` from
     the device list's search flow, see `device_list_page.dart`), calls
     `_applySearchResult(widget.searchResult!)` so CPU/GPU fuzzy-matching against the now-loaded
     presets can run.
- **Usage:** Called once from `initState` (line 243).
- **Notes:** The search-result application is sequenced *after* the preset `setState` (rather than
  fired independently from `initState`) specifically so CPU/GPU preset matching in
  `_applySearchResult` has data to match against.

### `static (String, String) _parseValueUnit(String? value)` <a id="_parsevalueunit"></a>
- **Kind:** static method of `_DeviceEditPageState`
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 345)
- **Purpose:** Parse a free-text capacity/size string like `"16 GB"` or `"512 GB NVMe SSD"` into a
  `(value, unit)` pair for the editor's separate amount+unit fields.
- **Inputs:** `value` — raw string (e.g. `Device.ram` or a `StorageInfo.capacity`), nullable.
- **Returns:** `(String, String)` record — e.g. `('16', 'GB')`; `('', 'GB')` if `value` is
  null/blank; `(trimmed, 'GB')` if no recognized unit is found.
- **Side effects:** None.
- **Algorithm:**
  1. Returns `('', 'GB')` immediately for null/blank input.
  2. Matches the trimmed string against `^(\d+(?:\.\d+)?)\s*(MB|GB|TB)\b` (case-insensitive).
  3. On match, returns the numeric group and the unit group uppercased.
  4. On no match, returns the whole trimmed string as the value with unit defaulted to `'GB'` (so
     unparseable legacy text isn't dropped, just filed under the wrong unit).
- **Usage:**
  ```dart
  final ramParsed = _parseValueUnit(d?.ram);
  _ramCtrl = TextEditingController(text: ramParsed.$1);
  _ramUnit = ramParsed.$2;
  ```
  (`initState`, line 138); also used per storage slot in `initState` (line 222) and for the
  RAM/storage fields inside `_applySearchResult` (lines 888, 895).
- **Notes:** Only recognizes `MB`/`GB`/`TB` — matches `_memoryUnits` (line 336); callers use
  Dart's positional-record `.$1`/`.$2` accessors on the return value.

### `double? _parseMoney(String value)` <a id="_parsemoney"></a>
- **Kind:** method of `_DeviceEditPageState`
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 388)
- **Purpose:** Parse a user-typed amount field into a `double`, tolerating thousands-separator
  commas.
- **Inputs:** `value` — raw text from a price/amount `TextEditingController`.
- **Returns:** `double?` — `null` if blank or unparseable.
- **Side effects:** None.
- **Algorithm:** Trims the string and strips every `,` character, then returns `null` for an empty
  result or `double.tryParse` of the cleaned string otherwise.
- **Usage:**
  `purchasePrice = await DeviceExchangeRateService.convertOptional(amount:
  _parseMoney(_purchasePriceCtrl.text), ...)` (`_save`, line 500); also used for the sold price and
  each recurring cost's amount (line 521).
- **Notes:** Comma-stripping means `"1,234.56"` parses to `1234.56`; there's no handling for other
  grouping/decimal conventions (e.g. `.` as a thousands separator).

### `double? _parseRate(TextEditingController controller, String currency)` <a id="_parserate"></a>
- **Kind:** method of `_DeviceEditPageState`
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 399)
- **Purpose:** Resolve the manual exchange-rate override for a currency field, but only when that
  currency actually differs from the device's default currency.
- **Inputs:** `controller` — the rate `TextEditingController`; `currency` — the currency code the
  paired amount field currently uses.
- **Returns:** `double?` — `null` when `currency == _defaultCurrency` (no conversion needed, so any
  leftover rate text is ignored) or when the field doesn't parse; otherwise the parsed rate.
- **Side effects:** None.
- **Algorithm:** Returns `null` immediately if `currency == _defaultCurrency`; otherwise delegates
  to [`_parseMoney`](#_parsemoney)`(controller.text)`.
- **Usage:** `manualRate: _purchaseAutoRate ? null : _parseRate(_purchaseRateCtrl,
  _purchaseCurrency)` (`_save`, line 506); same pattern for sold price and each recurring cost.
- **Notes:** Callers already gate on `autoRate` before calling this (passing `null` directly when
  auto-rate is on), so `_parseRate` only has to handle the "same as default currency" case — the
  two guards are complementary, not redundant.

### `Future<void> _save()` <a id="_save"></a>
- **Kind:** method of `_DeviceEditPageState`
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 456)
- **Purpose:** Validate the form, assemble a `Device` from all editor state (recomputing storage
  slot indices and converting money fields), persist it, and remap any dataset storage links
  affected by storage-slot changes.
- **Inputs:** None (reads the entire widget state).
- **Returns:** `Future<void>`.
- **Side effects:** May show a `SnackBar` (currency conversion failure); calls
  `DeviceStorage.addOrUpdate`; calls `DataSetStorage.remapDeviceStorageLinks` when editing an
  existing device; calls `AutoSyncService.instance.notifySaved()`; pops the page.
- **Algorithm:**
  1. Returns immediately if `_formKey.currentState!.validate()` fails.
  2. Builds `storageList` (`List<StorageInfo>`) and `storageIndexMap` (`Map<int,int>`, old slot
     index → new slot index) by looping over `_storageEntries`. A row survives only if it has a
     non-empty capacity value, a storage type, an interface, a brand, or a serial number — an
     all-blank row is dropped entirely. For each kept row whose `_storageOriginalIndices[i]` is
     non-null, records `storageIndexMap[originalIndex] = storageList.length` (the row's *new*
     position) before appending — exactly the `indexMap` shape
     [`DataSetStorage.remapDeviceStorageLinks`](../../../../features/datasets.md#remapdevicestoragelinks)
     expects. Rows with no original index (added this session) contribute to `storageList` but not
     to `storageIndexMap`. Each kept row's `extraJson` is carried over from
     `widget.device!.storage[originalIndex]` when that original slot still exists, else `{}`.
  3. Inside a `try`/`on ExchangeRateException`: awaits `DeviceExchangeRateService.convertOptional`
     for purchase price and sold price, and `.convert` for each `_recurringCostDrafts` entry with a
     parseable amount (a draft with no parseable amount is skipped — dropped from the saved
     device). On `ExchangeRateException`, shows a localized snackbar
     (`exchangeRateManualRequired` or `exchangeRateUnavailable`, chosen by `e.message`) and returns
     without saving anything.
  4. Computes `isSold = _isSold`; `isRetired = _isRetired || isSold` (selling always implies
     retired, mirroring [Devices](../../../../features/devices.md#lifecycle-and-finance-tracking)'s
     `lifecycleStatus` priority).
  5. Constructs a new `Device(...)`, reusing `widget.device?.id` (editing keeps the same id;
     omitting it when adding lets the constructor generate a fresh UUID), the freshly built
     `storageList`, and `extraJson` copied from each corresponding original nested object (`cpu`,
     `gpu`, the device itself) or `{}` for a new device.
  6. Awaits `DeviceStorage.addOrUpdate(device)`.
  7. If editing an existing device (`widget.device != null`), awaits
     `DataSetStorage.remapDeviceStorageLinks(deviceId: ..., oldSlotCount:
     widget.device!.storage.length, indexMap: storageIndexMap)` — the integration point that keeps
     `DataSet` storage links valid after slots are removed/compacted (see
     [Datasets](../../../../features/datasets.md#remapdevicestoragelinks); its identity-map
     short-circuit makes this a no-op whenever no slot actually moved).
  8. Calls `AutoSyncService.instance.notifySaved()` (see [WebDAV Sync](../../../../sync.md)) and,
     if still mounted, pops the page via `Navigator.of(context).pop()`.
- **Usage:** `TextButton(onPressed: _save, child: Text(l10n.save))` (`build`, line 1513).
- **Notes:** A brand-new device (`widget.device == null`) never calls `remapDeviceStorageLinks` —
  there is nothing to remap yet. Recurring-cost drafts with an empty/unparseable amount are
  silently dropped rather than saved with a zero amount.

### `Future<void> _showSearchDialog()` <a id="_showsearchdialog"></a>
- **Kind:** method of `_DeviceEditPageState`
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 810)
- **Purpose:** Open the online device-search dialog, seeded with the form's current field values,
  and apply whatever fields the user chooses to import from the result.
- **Inputs:** None (reads current controller/state values).
- **Returns:** `Future<void>`.
- **Side effects:** Awaits `showDeviceSearchDialog` (network search plus optional image download
  inside the dialog, see [device_search_dialog.md](device_search_dialog.md)); calls
  `_applySearchResult` on a non-null result.
- **Algorithm:**
  1. Builds the dialog's initial query: `"$brand $model"` if a model is set, else falls back to
     the device name.
  2. Calls `showDeviceSearchDialog` with that query plus every other "current value" (brand,
     model, chipset, GPU, combined RAM, the *first* storage slot's combined capacity, screen
     size/resolution, battery, OS, release date, image path) so the dialog can show a
     current-vs-fetched comparison per field.
  3. Returns early if the dialog was dismissed (`result == null`) or the widget unmounted
     meanwhile.
  4. Otherwise calls `_applySearchResult(result)`.
- **Usage:** `IconButton(icon: const Icon(Icons.travel_explore), onPressed: _showSearchDialog)`,
  shown only `if (AppFlavor.isFull)` (`build`, lines 1507–1512; see
  [Online Search and Presets](../../../../features/online-search-and-presets.md) for the
  store-build gating).
- **Notes:** Only the *first* storage slot's capacity is offered as "current" context to the
  search dialog — additional slots aren't represented in the query/current-value payload.

### `void _applySearchResult(Map<String, dynamic> result)` <a id="_applysearchresult"></a>
- **Kind:** method of `_DeviceEditPageState`
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 845)
- **Purpose:** Apply the field map returned by the online search dialog (or carried in via
  `DeviceEditPage(searchResult: ...)`) onto the edit form, fuzzy-matching CPU/GPU text against the
  loaded presets where possible.
- **Inputs:** `result` — a loosely-typed map keyed by field name (`brand`, `model`, `chipset`,
  `gpuName`, `ram`, `storage`, `screenSize`, `screenResolutionW`/`H`, `battery`, `os`,
  `releaseDate`, `image`); every key is optional and type-checked before use.
- **Returns:** None.
- **Side effects:** One `setState` covering all field updates.
- **Algorithm** (all inside one `setState`):
  1. `brand`/`model`: copied straight into their controllers if present as `String`.
  2. `chipset`: lowercased and compared against every loaded `_cpuPresets` entry's lowercased
     `model` using **mutual substring containment**
     (`chipsetLower.contains(presetLower) || presetLower.contains(chipsetLower)`); the first match
     is applied via `_applyCpuPreset`. If no preset matches, the raw chipset string is written
     directly into `_cpuModelCtrl` and `_cpuAutoKey` is bumped (forces the `Autocomplete` widget to
     rebuild, since setting `.text` alone doesn't refresh it — see `build`'s
     `ValueKey('cpu_auto_$_cpuAutoKey')`, line 1705).
  3. `gpuName`: identical mutual-substring matching against `_gpuPresets`, same raw-text fallback.
  4. `ram`: parsed via `_parseValueUnit` into `_ramCtrl`/`_ramUnit`.
  5. `storage`: parsed via `_parseValueUnit` and written into slot **0 only**
     (`_storageEntries[0]`/`_storageUnits[0]`), if any storage rows exist.
  6. `screenSize`, `battery`, `os`: copied straight into their controllers.
  7. `screenResolutionW`/`screenResolutionH`: copied (as `int`) via `.toString()`.
  8. `releaseDate`: copied straight into `_releaseDate` if it's a `DateTime`.
  9. `image`: if present, sets `_imagePath` and clears `_emoji` (an imported photo always wins over
     any previously chosen emoji).
- **Usage:** `_applySearchResult(widget.searchResult!)` from `_loadPresets` when the page was
  opened with a search result (line 287); `_applySearchResult(result)` from `_showSearchDialog`
  after an in-place dialog search (line 837).
- **Notes:** CPU/GPU matching is intentionally loose (mutual substring, not exact) so e.g. a
  result's `"Apple A17 Pro"` can match a shorter preset name or vice versa; because it's
  substring-based, ambiguous/short model strings could match the wrong preset — the same tradeoff
  as `_detectLogoForModel` and `device_detail_page.dart`'s brand/model logo detectors.

### `String? _detectLogoForModel(String model)` <a id="_detectlogoformodel"></a>
- **Kind:** method of `_DeviceEditPageState`
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 947)
- **Purpose:** Find an SVG logo asset path for a CPU/GPU model string as it's typed, using a small
  local brand table plus a Mali-specific ARM mapping.
- **Inputs:** `model` — the live text of `_cpuModelCtrl`/`_gpuModelCtrl`.
- **Returns:** `String?` — an `assets/logos/*.svg` path, or `null`.
- **Side effects:** None.
- **Algorithm:** Lowercases `model`; iterates this file's own `_brandLogoMap` (an 11-entry
  `const` map: nvidia, amd, intel, apple, qualcomm, mediatek, samsung, broadcom, mali→arm.svg,
  google, razer) in declaration order and returns the first entry whose key the lowercased model
  *starts with*; returns `null` if none match.
- **Usage:** `_brandLogoWidget(_detectLogoForModel(_cpuModelCtrl.text))` and
  `_brandLogoWidget(_detectLogoForModel(_gpuModelCtrl.text))`, rebuilt live on every `build` call
  next to the CPU/GPU section headers (lines 1681, 1783).
- **Notes:** This file's `_brandLogoMap` is a smaller, separate table from
  `device_detail_page.dart`'s `_brandLogoMap`/`_detectModelLogo` (~39 entries, `contains`-based
  there vs `startsWith` here) — the two are not shared and can drift out of sync with each other.

### `Future<void> _pickImage()` <a id="_pickimage"></a>
- **Kind:** method of `_DeviceEditPageState`
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 1068)
- **Purpose:** Let the user pick a photo from the device's gallery/filesystem and adopt it as the
  device's icon.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Calls `ImageService.pickAndSaveImage()` (file picker plus copying the chosen
  image into app storage); on success, `setState`s `_imagePath` and clears `_emoji`.
- **Algorithm:** Awaits `ImageService.pickAndSaveImage()`; if it returns a non-null local path,
  `setState`s `_imagePath = path` and `_emoji = null` (an image always replaces any emoji,
  matching `_applySearchResult`'s `image` handling and the reverse in `_showEmojiPicker`/
  `_removeIcon`).
- **Usage:** `IconButton(..., onPressed: _pickImage)` in `_buildIconSection` (line 1123).
- **Notes:** If the user cancels the picker (`path == null`), nothing changes — no error is
  surfaced either way.

### `factory _RecurringCostDraft.fromCost(DeviceRecurringCost cost)` <a id="_recurringcostdraft-fromcost"></a>
- **Kind:** factory constructor of `_RecurringCostDraft`
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 2221)
- **Purpose:** Convert a persisted `DeviceRecurringCost` into an editable draft (with its own text
  controllers) for the recurring-costs section.
- **Inputs:** `cost` — an existing `DeviceRecurringCost` from `widget.device.recurringCosts`.
- **Returns:** A new `_RecurringCostDraft` instance seeded from `cost`.
- **Side effects:** Creates 3 `TextEditingController`s.
- **Algorithm:** Copies `kind`, `billingCycle`, `price.currency`, `price.autoRate`, `name`, and
  `price.amount.toString()` directly. For the rate field, seeds it with
  `price.exchangeRate.toString()` only if `price.currency != price.defaultCurrency`, else leaves it
  blank — the same "only show a manual rate when currency differs from default" rule `initState`
  applies to the purchase/sold rate fields. Keeps a reference to the original `cost` in `existing`
  (used by [`_save`](#_save) to preserve the record's `id` and `extraJson`).
- **Usage:** `_recurringCostDrafts.addAll(d?.recurringCosts.map(_RecurringCostDraft.fromCost) ??
  const [])` (`initState`, line 210).
- **Notes:** `existing` is what lets `_save` distinguish an edited pre-existing recurring cost
  (keeps its `id`/`extraJson`) from a brand-new one added via `_addRecurringCost` (`existing ==
  null`, gets a fresh `id`).

### `List<CpuInfo> get _filtered` (in `_CpuPresetPickerState`) <a id="_filtered-cpu"></a>
- **Kind:** getter of `_CpuPresetPickerState`
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 2275)
- **Purpose:** Filter the bottom sheet's preset list down to entries whose model or architecture
  text contains the current search query.
- **Inputs:** None (reads `_query`, `widget.presets`).
- **Returns:** `List<CpuInfo>` — all presets if `_query` is empty, else the filtered subset.
- **Side effects:** None.
- **Algorithm:** Returns `widget.presets` unfiltered when `_query` is empty; otherwise lowercases
  the query and keeps only presets whose lowercased `model` or `architecture` contains it (a
  preset with a null `model`/`architecture` is treated as an empty string for the check).
- **Usage:** `final items = _filtered;` at the top of `build` (line 2305), used both for the item
  count and as the `ListView.builder`'s items.
- **Notes:** Matching is substring/case-insensitive only, no fuzzy or multi-token matching — a
  two-word query won't match a model containing both words in a different order.

### `List<GpuInfo> get _filtered` (in `_GpuPresetPickerState`) <a id="_filtered-gpu"></a>
- **Kind:** getter of `_GpuPresetPickerState`
- **Source:** `lib/features/devices/views/device_edit_page.dart` (line 2384)
- **Purpose:** Filter the bottom sheet's preset list down to entries whose model or architecture
  text contains the current search query.
- **Inputs:** None (reads `_query`, `widget.presets`).
- **Returns:** `List<GpuInfo>` — all presets if `_query` is empty, else the filtered subset.
- **Side effects:** None.
- **Algorithm:** Identical to
  [`_CpuPresetPickerState._filtered`](#_filtered-cpu), over `GpuInfo`/`widget.presets` instead of
  `CpuInfo`.
- **Usage:** `final items = _filtered;` at the top of `build` (line 2401).
- **Notes:** Same substring/case-insensitive-only caveat as the CPU picker's `_filtered`.
