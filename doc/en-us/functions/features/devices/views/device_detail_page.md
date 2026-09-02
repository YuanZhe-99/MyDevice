# lib/features/devices/views/device_detail_page.dart

A read-only, single-`StatelessWidget` detail view for one `Device` (model source
`lib/features/devices/models/device.dart`, see [Devices](../../../../features/devices.md)).
It renders the hero header, lifecycle/finance summary, CPU/GPU/memory/storage/display/other
spec cards, an optional static location map (`flutter_map`), and notes — pulling in a brand/
model/storage/OS logo whenever it can fuzzy-match the device's text fields against a bundled
`assets/logos/*.svg` set. Editing is delegated entirely to `device_edit_page.dart`, opened from
the app bar's edit action.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DeviceDetailPage` (constructor) | constructor | B | Store the `device` and `onDeviceChanged` callback for the page widget. |
| [`_detectBrandLogo`](#_detectbrandlogo) | method (`DeviceDetailPage`) | A | Fuzzy-match `device.brand` against the brand logo table. |
| [`_detectModelLogo`](#_detectmodellogo) | method (`DeviceDetailPage`) | A | Fuzzy-match a CPU/GPU model string against the brand logo table, with ARM Mali/Immortalis special-casing. |
| [`_detectStorageBrandLogo`](#_detectstoragebrandlogo) | method (`DeviceDetailPage`) | A | Fuzzy-match a storage device's brand against the storage logo table. |
| [`_detectOsLogo`](#_detectoslogo) | method (`DeviceDetailPage`) | A | Fuzzy-match `device.os` against the OS logo table. |
| `_statusLabel` | method (`DeviceDetailPage`) | B | Map `device.lifecycleStatus` to its localized label. |
| `_acquisitionTypeLabel` | method (`DeviceDetailPage`) | B | Map a `DeviceAcquisitionType` to its localized label. |
| `_recurringCostKindLabel` | method (`DeviceDetailPage`) | B | Map a `RecurringCostKind` to its localized label. |
| `_billingCycleLabel` | method (`DeviceDetailPage`) | B | Map a `BillingCycle` to its localized label. |
| [`_moneyText`](#_moneytext) | method (`DeviceDetailPage`) | A | Format a `MoneyValue`, appending the converted amount when it differs from the device's default currency. |
| [`_defaultMoneyText`](#_defaultmoneytext) | method (`DeviceDetailPage`) | A | Format a raw amount using the device's inferred default currency symbol. |
| `build` | method (widget) | B | Build the scaffold (app bar with the edit action) around `_buildBody`. |
| `_buildBody` | method (widget helper) | B | Choose the layout: a single `ListView` (header, specs, map, notes) unless `useDetailTwoPane` passes and there is at least one spec section, in which case a `Row` of a `detailLeftPaneWidth`-wide scrolling left pane (header, map, notes) and a right `ListView` of the spec cards. |
| `_buildSpecSections` | method (widget helper) | B | The six conditional spec sections (finance, CPU, GPU, memory, display, other), extracted from `build` unchanged. |
| `_buildTrailingSections` | method (widget helper) | B | The conditional map and notes blocks that end the single column and sit under the header on the left. |
| `_buildHeader` | method (widget helper) | B | Render the hero card (avatar, name, brand/model, logo, purchase/release dates). |
| `_sectionTitle` | method (widget helper) | B | Render a section heading row with icon and optional brand logo. |
| `_specCard` | method (widget helper) | B | Wrap a list of spec rows in a `Card`, or render nothing if all rows are empty. |
| `_specRow` | method (widget helper) | B | Render one label/value row, or `null` if the value is empty. |
| `_specRowWithLogo` | method (widget helper) | B | Render one label/value row with an optional small logo before the value. |

## Documentation

### `String? _detectBrandLogo()` <a id="_detectbrandlogo"></a>
- **Kind:** method of `DeviceDetailPage`
- **Source:** `lib/features/devices/views/device_detail_page.dart` (line 114)
- **Purpose:** Find an SVG logo asset path matching the device's brand, if any.
- **Inputs:** None (reads `device.brand`).
- **Returns:** `String?` — an `assets/logos/*.svg` path, or `null` if `device.brand` is unset or
  matches no entry in `_brandLogoMap`.
- **Side effects:** None.
- **Algorithm:**
  1. Returns `null` immediately if `device.brand` is null.
  2. Lowercases the brand string.
  3. Iterates `_brandLogoMap` (a `const Map<String, String>` of ~39 lowercase brand-name-substring
     → SVG-path entries, covering device OEMs, chip vendors, and cloud/hosting providers) in
     declaration order and returns the value for the first key that the lowercased brand
     *contains* as a substring.
  4. Returns `null` if no entry matches.
- **Usage:** `final logoPath = _detectBrandLogo();` in `_buildHeader`
  (`lib/features/devices/views/device_detail_page.dart`, line 522).
- **Notes:** Match is substring-based and first-match-wins in map declaration order, so a brand
  string containing two vendor names (unlikely in practice) would resolve to whichever entry is
  declared first in `_brandLogoMap`.

### `String? _detectModelLogo(String? model)` <a id="_detectmodellogo"></a>
- **Kind:** static method of `DeviceDetailPage`
- **Source:** `lib/features/devices/views/device_detail_page.dart` (line 128)
- **Purpose:** Find an SVG logo asset path matching a CPU/GPU model string (e.g. `device.cpu.model`,
  `device.gpu.model`), reusing the brand logo table plus ARM GPU special cases.
- **Inputs:** `model` — a free-text CPU/GPU model string, or `null`.
- **Returns:** `String?` — an `assets/logos/*.svg` path, or `null`.
- **Side effects:** None.
- **Algorithm:**
  1. Returns `null` if `model` is null.
  2. Lowercases the model string.
  3. Iterates `_brandLogoMap` and returns the value for the first key the lowercased model
     *starts with* (note: `startsWith`, unlike `_detectBrandLogo`'s `contains` — model strings
     typically lead with the vendor name, e.g. `"Apple M2"`, `"Qualcomm Snapdragon..."`).
  4. If nothing matched, checks two ARM Mali GPU special cases: a model starting with `'mali'` or
     `'immortalis'` resolves to `_brandLogoMap['arm']` (Mali/Immortalis GPUs don't carry "ARM" in
     their model name, so the generic brand table alone wouldn't catch them).
  5. Returns `null` if still unmatched.
- **Usage:**
  ```dart
  _sectionTitle(
    theme,
    cs,
    l10n.cpuInfo,
    Icons.memory,
    logoPath: _detectModelLogo(device.cpu.model),
  ),
  ```
  (from `build`, `lib/features/devices/views/device_detail_page.dart`, lines 350–356; also used
  for the GPU section at line 376)
- **Notes:** Shares `_brandLogoMap` with `_detectBrandLogo` but uses `startsWith` instead of
  `contains`, and layers on the two ARM GPU fallbacks — the two functions are not
  interchangeable despite matching against the same table.

### `String? _detectStorageBrandLogo(String? brand)` <a id="_detectstoragebrandlogo"></a>
- **Kind:** static method of `DeviceDetailPage`
- **Source:** `lib/features/devices/views/device_detail_page.dart` (line 146)
- **Purpose:** Find an SVG logo asset path matching a storage device's brand (e.g. an SSD/HDD
  vendor), using a separate, storage-specific brand table.
- **Inputs:** `brand` — a storage entry's brand string, or `null`.
- **Returns:** `String?` — an `assets/logos/*.svg` path, or `null`.
- **Side effects:** None.
- **Algorithm:** Same substring-`contains` loop as `_detectBrandLogo`, but iterates
  `_storageBrandLogoMap` instead — a separate ~14-entry table that includes storage-only vendors
  (Western Digital/WD, Seagate, Kingston, Crucial/Micron, SanDisk, SK hynix, Toshiba, Kioxia) not
  present in `_brandLogoMap`, alongside brands that overlap (Samsung, Intel, Apple).
- **Usage:**
  ```dart
  if (device.storage[i].brand != null)
    _specRowWithLogo(
      l10n.storageBrand,
      device.storage[i].brand!,
      _detectStorageBrandLogo(device.storage[i].brand),
      cs,
    ),
  ```
  (from `build`, `lib/features/devices/views/device_detail_page.dart`, lines 402–408)
- **Notes:** `_storageBrandLogoMap` deliberately duplicates a few keys across synonymous brand
  spellings (`'western digital'` and `'wd'` both map to the same SVG; `'sk hynix'`, `'skhynix'`,
  and `'hynix'` all map to the same SVG) to tolerate whichever spelling ends up in the field.

### `String? _detectOsLogo(String? os)` <a id="_detectoslogo"></a>
- **Kind:** static method of `DeviceDetailPage`
- **Source:** `lib/features/devices/views/device_detail_page.dart` (line 162)
- **Purpose:** Find an SVG logo asset path matching a free-text OS string.
- **Inputs:** `os` — `device.os`, or `null`.
- **Returns:** `String?` — an `assets/logos/*.svg` path, or `null`.
- **Side effects:** None.
- **Algorithm:** Same substring-`contains` loop pattern, iterating `_osLogoMap` (~17 entries:
  Windows, Android, iOS/iPadOS both → the iOS logo, macOS (two spellings), Linux and named
  distros, ChromeOS (two spellings), HarmonyOS (two spellings), OpenWrt, FreeBSD). Because the
  match is `contains` rather than an exact match, free-text values like `"Windows 11 LTSC"` or
  `"Ubuntu Server"` still resolve correctly (per the source doc comment's own examples).
- **Usage:**
  ```dart
  _sectionTitle(
    theme,
    cs,
    l10n.os,
    Icons.info_outline,
    logoPath: _detectOsLogo(device.os),
  ),
  ```
  (from `build`, `lib/features/devices/views/device_detail_page.dart`, lines 442–448)
- **Notes:** `'ipados'` and `'ios'` both map to the same iOS SVG; `'chromeos'` and `'chrome os'`
  both map to the same ChromeOS SVG; `'harmonyos'` and `'harmony'` both map to the same HarmonyOS
  SVG — these are deliberate spelling-variant duplicates, not distinct logos.

### `String _moneyText(MoneyValue money)` <a id="_moneytext"></a>
- **Kind:** method of `DeviceDetailPage`
- **Source:** `lib/features/devices/views/device_detail_page.dart` (line 235)
- **Purpose:** Format a `MoneyValue` for display, showing the converted default-currency amount
  alongside the original when the two currencies differ.
- **Inputs:** `money` — a `MoneyValue` (amount + currency + a computed `convertedAmount` in
  `money.defaultCurrency`).
- **Returns:** `String` — either `"{symbol}{amount}"` (currency matches the default) or
  `"{symbol}{amount} ({baseSymbol}{convertedAmount} {defaultCurrency})"` (currency differs).
- **Side effects:** None (calls `DeviceExchangeRateService.currencySymbol` for lookups only).
- **Algorithm:**
  1. Looks up the display symbol for `money.currency` and for `money.defaultCurrency` via
     `DeviceExchangeRateService.currencySymbol`.
  2. Formats the original amount to 2 decimal places with its symbol.
  3. If `money.currency == money.defaultCurrency`, returns just the original string.
  4. Otherwise appends the converted amount (also 2 decimals) with the base symbol and the
     default-currency code in parentheses, e.g. `"$50.00 (¥360.00 JPY)"`.
- **Usage:**
  ```dart
  _specRow(
    l10n.purchasePrice,
    device.purchasePrice != null ? _moneyText(device.purchasePrice!) : null,
  ),
  ```
  (from `build`, `lib/features/devices/views/device_detail_page.dart`, lines 319–324; also used
  for `soldPrice` and each recurring cost's `price`)
- **Notes:** None.

### `String _defaultMoneyText(double amount)` <a id="_defaultmoneytext"></a>
- **Kind:** method of `DeviceDetailPage`
- **Source:** `lib/features/devices/views/device_detail_page.dart` (line 250)
- **Purpose:** Format a plain amount (already expressed in the device's default currency, such as
  a computed total/daily cost) with the correct currency symbol.
- **Inputs:** `amount` — a `double` already converted to the device's default currency.
- **Returns:** `String` — `"{symbol}{amount.toStringAsFixed(2)}"`.
- **Side effects:** None.
- **Algorithm:**
  1. Determines the default currency code by falling back through, in order:
     `device.purchasePrice?.defaultCurrency`, then `device.soldPrice?.defaultCurrency`, then
     `device.recurringCosts.firstOrNull?.price.defaultCurrency`, then `''` if none of the three
     financial fields are present.
  2. Looks up the symbol for that currency code and formats `amount` to 2 decimals.
- **Usage:**
  ```dart
  if (device.hasFinancialData)
    _specRow(l10n.financialTotalCost, _defaultMoneyText(device.totalCost())),
  if (device.averageDailyCost() != null)
    _specRow(l10n.financialDailyCost, _defaultMoneyText(device.averageDailyCost()!)),
  ```
  (from `build`, `lib/features/devices/views/device_detail_page.dart`, lines 334–343)
- **Notes:** `device.totalCost()`/`device.averageDailyCost()` (see
  [Devices](../../../../features/devices.md#lifecycle-and-finance-tracking)) already return
  amounts in the default currency, so this function only needs to resolve which currency that is
  — it performs no conversion itself.
