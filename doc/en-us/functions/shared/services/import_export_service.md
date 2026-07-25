# lib/shared/services/import_export_service.dart

**Partly a facade.** The ZIP half (`exportZip` / `importZip`) delegates to the `myapps_data` package
(`lib/src/data/zip_transfer.dart`). The Markdown export and its many label formatters are deeply
domain-specific and stay here.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`exportZip(destDir)`](#exportzip) | static method | A | Write `mydevice_export_<stamp>.zip`. |
| [`importZip(filePath)`](#importzip) | static method | A | Restore data and images from an export. |
| [`exportMarkdown(destDir)`](#exportmarkdown) | static method | A | Write a Markdown inventory report. |
| [`buildMarkdown({...})`](#buildmarkdown) | static method | A | Build the Markdown body from loaded data. |
| `_categoryLabel`, `_statusLabel`, `_acquisitionTypeLabel`, `_recurringCostKindLabel`, `_billingCycleLabel`, `_moneyText`, `_networkTypeLabel`, … | private helpers | B | Domain label formatting for the report. |

## Documentation

### `exportZip(destDir)` <a id="exportzip"></a>
- **Returns:** `Future<String?>` — the written path, or null on failure.
- **Side effects:** Writes `mydevice_export_<yyyyMMdd_HHmmss>.zip`.
- **Notes:** Bundles the registry's four data files in registry order plus flat `images/<basename>`
  entries. Config, `.sync_base/`, and `backups/` are never included.

### `importZip(filePath)` <a id="importzip"></a>
- **Returns:** `Future<bool>` — true on success.
- **Side effects:** Overwrites allowlisted data files and images.
- **Notes:** Only allowlisted entries are extracted (the registry's data files and flat files under
  `images/`), and every entry must resolve inside the app dir.

  **Behavior change from the extraction:** every entry is classified before any is written, so an
  archive containing a path-traversal entry is now rejected outright — the call returns false and
  nothing is written — rather than skipping the bad entry and importing the rest. Unknown entries are
  still skipped, so an archive from a newer build still imports. Payloads are written as raw bytes
  without UTF-8 or model validation, as before.

### `exportMarkdown(destDir)` <a id="exportmarkdown"></a>
- **Returns:** `Future<String?>` — the written path, or null on failure.
- **Side effects:** Loads all four storage hubs and writes
  `mydevice_export_<yyyyMMdd_HHmmss>.md`.

### `buildMarkdown({...})` <a id="buildmarkdown"></a>
- **Purpose:** Render devices, networks, datasets, and services into the Markdown report body.
- **Notes:** Unchanged by the extraction; kept app-side because it is entirely domain-specific.

## Where the engine documentation lives

`packages/myapps_data/doc/en-us/functions/src/data/zip_transfer.md`.
