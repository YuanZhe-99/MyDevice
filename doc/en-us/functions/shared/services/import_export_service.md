# lib/shared/services/import_export_service.dart

`ImportExportService` provides ZIP export/import of all four data files plus `images/`, and a
Markdown export for LLM-friendly device/network/dataset/service summaries, as described in
[../../../backup-restore.md](../../../backup-restore.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`exportZip`](#exportzip) | static method | A | ZIP-export all data files and images. |
| [`importZip`](#importzip) | static method | A | Import data files and images from a ZIP, with path-traversal protection. |
| [`exportMarkdown`](#exportmarkdown) | static method | A | Write a Markdown inventory summary to a file. |
| [`buildMarkdown`](#buildmarkdown) | static method | A | Build the Markdown inventory summary string. |
| `_categoryLabel` | static method | B | Device category → English label. |
| `_statusLabel` | static method | B | Lifecycle status → English label. |
| `_acquisitionTypeLabel` | static method | B | Acquisition type → English label. |
| `_recurringCostKindLabel` | static method | B | Recurring cost kind → English label. |
| `_billingCycleLabel` | static method | B | Billing cycle → English label. |
| `_networkTypeLabel` | static method | B | Network type → English label. |
| [`_moneyText`](#moneytext) | static method | A | Format a `MoneyValue` with optional converted-currency suffix. |
| [`_serviceEndpointText`](#serviceendpointtext) | static method | A | Format a `ServiceEndpoint` as a compact descriptive string. |
| [`_serviceEndpointById`](#serviceendpointbyid) | static method | A | Look up an endpoint on a service by id. |
| [`_serviceRouteHopText`](#serviceroutehoptext) | static method | A | Format a `ServiceRouteHop` as a compact descriptive string. |

## Documentation

### `static Future<String?> exportZip(String destDir)` <a id="exportzip"></a>
- **Kind:** static method of `ImportExportService`.
- **Source:** `lib/shared/services/import_export_service.dart` (line 33).
- **Purpose:** Bundle all four data JSON files plus every file under `images/` into a single ZIP.
- **Inputs:** `destDir` — directory to write the ZIP into.
- **Returns:** `Future<String?>` — the written file's path, or `null` on any exception.
- **Side effects:** Reads the app directory's data files and `images/`; writes
  `<destDir>/mydevice_export_<yyyyMMdd_HHmmss>.zip`.
- **Algorithm:** For each of the four fixed data file names (`_dataFileNames`: `device_data.json`,
  `network_data.json`, `dataset_data.json`, `service_data.json`), add it to an `Archive` if it
  exists; then add every file under `images/` with a `images/<basename>` archive path; encode via
  `ZipEncoder`; write the bytes to a timestamped filename.
- **Usage:** Called from the settings/export UI's ZIP export action.
- **Notes:** Uses `mydevice_export_` as its archive filename prefix (shared with
  `exportMarkdown`, distinguished only by the `.zip`/`.md` extension).

### `static Future<bool> importZip(String filePath)` <a id="importzip"></a>
- **Kind:** static method of `ImportExportService`.
- **Source:** `lib/shared/services/import_export_service.dart` (line 77).
- **Purpose:** Restore data files and images from a previously exported ZIP, with strict
  path-traversal protection.
- **Inputs:** `filePath` — path to the ZIP file to import.
- **Returns:** `Future<bool>` — `true` on success, `false` if the file is missing or any exception
  occurs.
- **Side effects:** File-system writes under the app directory (data files and `images/`).
- **Algorithm:** Decode the ZIP; for each file entry, normalize its name (`p.normalize` +
  backslash-to-forward-slash); an entry is **allowed** only if its normalized name is exactly one
  of the four `_dataFileNames`, or it starts with `images/` **and** has exactly two path segments
  (i.e. a flat file directly under `images/`, not a nested subdirectory) — this two-segment check
  is the fix applied in the sibling apps' v1.2.2 release after an earlier version's check (a bare
  `startsWith('images/')`) was found to always admit nested paths. Entries containing `..` are
  also rejected outright. As a second, independent layer of defense, the resolved output path is
  additionally verified to stay within the app directory via `p.isWithin` before any write.
  Allowed entries have their parent directory created if needed, then are written verbatim.
- **Usage:** Called from the settings/import UI's ZIP import action.
- **Notes:** This function implements two independent traversal defenses (the allowlist/segment
  check, and the `p.isWithin` containment check on the resolved absolute path) — see
  [../../../backup-restore.md](../../../backup-restore.md) for the historical context on why the
  first check alone was once insufficient.

### `static Future<String?> exportMarkdown(String destDir)` <a id="exportmarkdown"></a>
- **Kind:** static method of `ImportExportService`.
- **Source:** `lib/shared/services/import_export_service.dart` (line 122).
- **Purpose:** Load all four data stores and write a Markdown inventory summary file.
- **Inputs:** `destDir`.
- **Returns:** `Future<String?>` — the written file's path, or `null` on any exception.
- **Side effects:** Reads all four storages (`DeviceStorage`, `NetworkStorage`, `DataSetStorage`,
  `ServiceStorage`); writes `<destDir>/mydevice_export_<yyyyMMdd_HHmmss>.md`.
- **Algorithm:** Load the four data sets, call `buildMarkdown`, write the result to a timestamped
  `.md` file.
- **Usage:** Called from the settings/export UI's Markdown export action.
- **Notes:** None.

### `static String buildMarkdown({required DeviceData deviceData, required NetworkData networkData, required DataSetData datasetData, required ServiceData serviceData, DateTime? exportedAt})` <a id="buildmarkdown"></a>
- **Kind:** static method of `ImportExportService`.
- **Source:** `lib/shared/services/import_export_service.dart` (line 150).
- **Purpose:** Render the full device/network/dataset/service inventory as a single
  LLM-personalization-friendly Markdown document.
- **Inputs:** The four loaded data sets; optional `exportedAt` (defaults to now) for a
  deterministic export timestamp in tests.
- **Returns:** `String` — the complete Markdown document.
- **Side effects:** None (pure string building).
- **Algorithm:** Sort devices by `purchaseDate` (nulls last, then by name), services by device
  name then service name, and routes by source-service name then display target. Build lookup
  maps (`deviceMap`/`networkMap`/`serviceMap`) by id for cross-referencing. Emit a header with an
  export timestamp and summary counts, then one `##` section per device (category, brand/model/
  serial, CPU/GPU/RAM/storage/screen/battery/OS/location, purchase/release/retirement dates,
  lifecycle status, acquisition type, purchase/sold price via `_moneyText`, recurring costs,
  notes), one `##` per network (type, subnet/gateway/DNS, notes, and its assigned devices via
  `network_data.json`'s assignments), one `##` per dataset (linked device storage slots), one `##`
  per service (device, kind, state, runtime, tags, notes, endpoints via `_serviceEndpointText`, and
  a fenced ` ```yaml ` block for `dockerCompose` notes when present), and one `##` per service
  route (source service/endpoint, access level, targets via `compactAccessTargetLabel`, notes, and
  hops via `_serviceRouteHopText`).
- **Usage:** Called by `exportMarkdown`, and is directly unit-testable (accepts data objects
  rather than reading storage itself, and accepts `exportedAt` for deterministic test output).
- **Notes:** Every section is conditionally emitted only when its collection is non-empty, so an
  app with e.g. no networks configured produces a document with no "# Networks" section at all
  rather than an empty one.

### `static String _moneyText(MoneyValue money)` <a id="moneytext"></a>
- **Kind:** static method of `ImportExportService`.
- **Source:** `lib/shared/services/import_export_service.dart` (line 569).
- **Purpose:** Format a `MoneyValue` for Markdown, appending a converted-currency amount in
  parentheses when the value's currency differs from the device's default currency.
- **Inputs:** `money`.
- **Returns:** `String`, e.g. `"$120.00"` or `"€99.00 ($108.50 USD)"`.
- **Side effects:** None (reads currency symbols via `DeviceExchangeRateService.currencySymbol`,
  a pure lookup).
- **Algorithm:** Format `money.amount` with its own currency symbol; if `money.currency ==
  money.defaultCurrency`, return that alone; otherwise append
  `" ($baseSymbol$convertedAmount $defaultCurrency)"`.
- **Usage:** Called from `buildMarkdown` for purchase price, sold price, and each recurring cost.
- **Notes:** None.

### `static String _serviceEndpointText(ServiceEndpoint endpoint, Map<String, Network> networkMap)` <a id="serviceendpointtext"></a>
- **Kind:** static method of `ImportExportService`.
- **Source:** `lib/shared/services/import_export_service.dart` (line 598).
- **Purpose:** Render one `ServiceEndpoint` as a single comma-joined descriptive line for
  Markdown.
- **Inputs:** `endpoint`; `networkMap` — for resolving `networkId` to a display name.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** Conditionally include, in order: trimmed label, `protocol/transport`, port text
  (`endpoint.portText`), bind address, path, scope name, the resolved network name (or raw id if
  unresolved), a literal `'primary'` flag when `isPrimary`, and trimmed notes — join with `', '`,
  omitting any empty/absent part.
- **Usage:** Called from `buildMarkdown` (service endpoints list) and from
  `_serviceRouteHopText` (a hop's associated endpoint, if any).
- **Notes:** None.

### `static ServiceEndpoint? _serviceEndpointById(ServiceNode service, String? endpointId)` <a id="serviceendpointbyid"></a>
- **Kind:** static method of `ImportExportService`.
- **Source:** `lib/shared/services/import_export_service.dart` (line 627).
- **Purpose:** Find a service's endpoint by id.
- **Inputs:** `service`; `endpointId` (nullable).
- **Returns:** `ServiceEndpoint?` — `null` if `endpointId` is null or no endpoint matches.
- **Side effects:** None.
- **Algorithm:** `service.endpoints.where((e) => e.id == endpointId).firstOrNull`.
- **Usage:** Called from `buildMarkdown` (route source endpoint) and `_serviceRouteHopText` (hop
  endpoint).
- **Notes:** None.

### `static String _serviceRouteHopText(ServiceRouteHop hop, Map<String, ServiceNode> serviceMap, Map<String, Device> deviceMap, Map<String, Network> networkMap)` <a id="serviceroutehoptext"></a>
- **Kind:** static method of `ImportExportService`.
- **Source:** `lib/shared/services/import_export_service.dart` (line 642).
- **Purpose:** Render one `ServiceRouteHop` as a single comma-joined descriptive line for
  Markdown.
- **Inputs:** `hop`; `serviceMap`/`deviceMap`/`networkMap` — id-to-object lookups for cross-
  referencing.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** Resolve the hop's referenced `service`/`endpoint`/`device` (any may be absent for
  a free-form hop); build a host string from `scheme://host:port/path` fragments where present;
  assemble the final line from, in order: a method/type label (`serviceRouteMethodLabel(hop.method)`
  if set, else `hop.type.name`), trimmed label, `'service <name>'`, `'endpoint <text>'` (via
  `_serviceEndpointText`), `'device <name>'`, the joined host string, and trimmed notes.
- **Usage:** Called from `buildMarkdown` for each hop in a service route's hop list.
- **Notes:** Handles fully free-form hops (no linked service/endpoint/device at all) gracefully —
  every referenced-object part is conditionally omitted, so a hop can be described purely by its
  host string and notes.

The six `_*Label` methods (`_categoryLabel`, `_statusLabel`, `_acquisitionTypeLabel`,
`_recurringCostKindLabel`, `_billingCycleLabel`, `_networkTypeLabel`) are Tier B: each is a plain
exhaustive `switch` mapping one enum to a fixed English display string, with no branching logic
beyond the switch itself and no I/O.
