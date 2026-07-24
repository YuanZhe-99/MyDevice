# lib/features/devices/views/device_search_dialog.dart

Modal, two-phase dialog for finding a device online and importing selected fields into the
edit form. Backed by `lib/features/devices/services/device_search_service.dart` (GSMArena /
Notebookcheck scraping, gated by `AppFlavor.isStore` — see
[Online Search and Presets](../../../../features/online-search-and-presets.md)) and
`lib/shared/services/image_service.dart` for downloading a matched device photo. It is opened
both from `device_edit_page.dart` (prefilled with the form's current values, so the preview can
show "current vs. fetched" per field) and from `device_list_page.dart`'s search FAB (opened with
no current values, feeding a brand-new `DeviceEditPage`).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`showDeviceSearchDialog`](#showdevicesearchdialog) | function | A | Open the device search dialog and return the map of fields the user chose to apply. |
| `_SearchDialog` (constructor) | constructor | B | Store the initial query and all "current value" fields for the dialog widget. |
| `createState` | method (`_SearchDialog`) | B | Create the dialog's mutable state object. |
| `initState` | method (widget lifecycle) | B | Seed the query controller with the initial query. |
| `dispose` | method (widget lifecycle) | B | Dispose the query text controller. |
| [`_search`](#_search) | method (`_SearchDialogState`) | A | Run a device search against `DeviceSearchService` and update dialog state. |
| [`_selectResult`](#_selectresult) | method (`_SearchDialogState`) | A | Fetch full detail for a chosen search result and enter preview phase. |
| [`_initToggles`](#_inittoggles) | method (`_SearchDialogState`) | A | Set default checkbox state for each importable field based on what the result has. |
| [`_fetchImage`](#_fetchimage) | method (`_SearchDialogState`) | A | Download the matched device's photo and stage it as a fetched image. |
| [`_apply`](#_apply) | method (`_SearchDialogState`) | A | Assemble the field-name → value map to return to the caller from the checked toggles. |
| `build` | method (widget) | B | Build the dialog shell and switch between search/preview phases. |
| `_buildSearchView` | method (widget helper) | B | Render the search phase (header, search bar, results list). |
| `_buildSearchResults` | method (widget helper) | B | Render the loading/error/empty/list states for search results. |
| `_buildPreviewView` | method (widget helper) | B | Render the preview phase (source badge, field list, apply/cancel buttons). |
| `_buildFieldList` | method (widget helper) | B | Render one checkbox row per importable field, plus the image section. |
| `_imageColumn` | method (widget helper) | B | Render a labeled column containing an image preview. |
| `_imagePreviewFrame` | method (widget helper) | B | Wrap a child in the circular bordered image preview frame. |
| `_fieldTile` | method (widget helper) | B | Render one field's checkbox tile with current/fetched value text. |
| `_buildHeader` | method (widget helper) | B | Render the dialog's title row, with an optional back button. |

Row count note: `grep -c 'Purpose:'` on this file returns 18, one less than the 19 rows above.
The discrepancy is `showDeviceSearchDialog` itself — its doc comment (lines 10–11) is a plain
`/// Shows the device search dialog. ...` comment without the `Purpose:` tag used by every other
declaration in this file, so it doesn't match the grep pattern even though it is a real, documented
top-level function and is included here per the "every declaration gets a row" rule.

## Documentation

### `Future<Map<String, dynamic>?> showDeviceSearchDialog(BuildContext context, {String? initialQuery, String? currentBrand, String? currentModel, String? currentChipset, String? currentGpu, String? currentRam, String? currentStorage, String? currentScreenSize, int? currentScreenResW, int? currentScreenResH, String? currentBattery, String? currentOs, DateTime? currentReleaseDate, String? currentImagePath})` <a id="showdevicesearchdialog"></a>
- **Kind:** top-level function
- **Source:** `lib/features/devices/views/device_search_dialog.dart` (line 12)
- **Purpose:** Open the two-phase device search/preview dialog and return the subset of fields
  the user opted to import.
- **Inputs:** `initialQuery` — text to pre-fill the search box; the `currentXxx` parameters are
  the edit form's existing values for each field, used purely for display in the preview phase's
  "current vs. fetched" comparison (they do not affect search behavior). All are optional — the
  list-page call site (`showDeviceSearchDialog(context)`) passes none of them.
- **Returns:** `Future<Map<String, dynamic>?>` — a map keyed by field name (`brand`, `model`,
  `chipset`, `gpuName`, `ram`, `storage`, `screenSize`, `screenResolutionW`/`screenResolutionH`,
  `battery`, `os`, `releaseDate`, `image`) containing only the fields the user checked, or `null`
  if the dialog was dismissed.
- **Side effects:** Shows a `Dialog` via `showDialog`; the dialog subsequently triggers network
  requests (search, detail fetch, image download) as the user interacts with it.
- **Algorithm:**
  1. Calls `showDialog<Map<String, dynamic>>` with a builder that constructs `_SearchDialog`,
     forwarding every parameter through unchanged.
  2. Returns whatever value `Navigator.pop` resolves the dialog's future with — see
     [`_apply`](#_apply) for how that map is built.
- **Usage:**
  ```dart
  final result = await showDeviceSearchDialog(
    context,
    initialQuery: query,
    currentBrand: _nonEmpty(_brandCtrl.text),
    currentModel: _nonEmpty(_modelCtrl.text),
    currentChipset: _nonEmpty(_cpuModelCtrl.text),
    currentGpu: _nonEmpty(_gpuModelCtrl.text),
    currentRam: _combineValueUnit(_ramCtrl.text, _ramUnit),
    ...
  );
  ```
  (from `lib/features/devices/views/device_edit_page.dart`, line 816 — editing an existing device)
  and, with no current-value context, `final result = await showDeviceSearchDialog(context);`
  (from `lib/features/devices/views/device_list_page.dart`, line 230 — adding a brand-new device).
- **Notes:** This function itself performs no `AppFlavor` check; per
  [Online Search and Presets](../../../../features/online-search-and-presets.md), the online
  search entry points that lead here (the FAB in `device_list_page.dart`, the search action in
  `device_edit_page.dart`) are what's hidden for store builds.

### `Future<void> _search()` <a id="_search"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/devices/views/device_search_dialog.dart` (line 144)
- **Purpose:** Run the current query against `DeviceSearchService.search` and load the results
  into dialog state.
- **Inputs:** None (reads `_queryController.text`).
- **Returns:** `Future<void>`.
- **Side effects:** Three `setState` calls (start, success, failure); performs a network-backed
  search across GSMArena and Notebookcheck.
- **Algorithm:**
  1. Trims the query; returns immediately if empty.
  2. Sets `_searching = true`, clears `_error` and `_results`.
  3. Awaits `DeviceSearchService.search(query)`.
  4. On success, checks `mounted`, stores results, and — if the list is empty — sets `_error` to
     the localized `searchNoResults` string.
  5. On exception, checks `mounted`, stops the spinner, and stores `e.toString()` as `_error`.
- **Usage:** Wired to the search bar's `onSubmitted` and the "Search" `FilledButton` in
  `_buildSearchView` (`lib/features/devices/views/device_search_dialog.dart`, lines 357–364).
- **Notes:** Same pattern as `_ChipSearchDialogState._search` in `chip_search_dialog.dart` — raw
  exception text is shown to the user for anything other than an empty result set.

### `Future<void> _selectResult(DeviceSearchResult result)` <a id="_selectresult"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/devices/views/device_search_dialog.dart` (line 178)
- **Purpose:** Switch to the preview phase for a tapped search result and fetch its full detail
  page.
- **Inputs:** `result` — the `DeviceSearchResult` the user tapped in the results list (typically
  a summary-only result from `DeviceSearchService.search`).
- **Returns:** `Future<void>`.
- **Side effects:** `setState` to enter `_Phase.preview` immediately (showing a loading state),
  then another `setState` once detail fetching resolves; makes a network request via
  `DeviceSearchService.fetchDetail`.
- **Algorithm:**
  1. Immediately sets `_selected = result`, `_phase = _Phase.preview`, `_fetchingDetail = true`,
     and clears any previous fetched-image state and toggles.
  2. Awaits `DeviceSearchService.fetchDetail(result)` to get the fully-populated result (detail
     pages carry more fields than the search-result summary).
  3. On success, checks `mounted`, replaces `_selected` with the detailed result, clears the
     loading flag, and calls [`_initToggles`](#_inittoggles) on the detailed result.
  4. On failure, checks `mounted`, clears the loading flag, and calls `_initToggles` on the
     original (summary-only) `result` instead — so the preview still shows whatever fields the
     summary already had, rather than failing the whole flow.
- **Usage:** `onTap: () => _selectResult(r),` in `_buildSearchResults`
  (`lib/features/devices/views/device_search_dialog.dart`, line 427).
- **Notes:** A failed detail fetch is swallowed silently (no error message shown) — the user just
  sees a preview with fewer fields toggled/available than a successful fetch would have offered.

### `void _initToggles(DeviceSearchResult r)` <a id="_inittoggles"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/devices/views/device_search_dialog.dart` (line 210)
- **Purpose:** Set the default checked/unchecked state of each field's import checkbox based on
  which fields the search result actually has.
- **Inputs:** `r` — the `DeviceSearchResult` (summary or detail) to inspect.
- **Returns:** `None`.
- **Side effects:** Populates `_toggles` (a `Map<String, bool>`); does not itself call `setState`
  (callers wrap it inside their own `setState`).
- **Algorithm:** For each of `brand`, `model`, `chipset`, `gpuName`, `ram`, `storage`,
  `screenSize`, `battery`, `os`: if the field is a non-empty string, sets `_toggles[key] = true`.
  For `screenResolutionW`/`releaseDate` (non-string fields), checks non-null instead of
  non-empty. The one exception is `image`: if `r.imageUrl != null`, `_toggles['image']` is set to
  `false` — the image checkbox exists but starts **unchecked**, since fetching it is a separate,
  explicit user action (see [`_fetchImage`](#_fetchimage)). Any field absent from the result gets
  no entry in `_toggles` at all (so `_toggles[key] ?? false` downstream treats it as unchecked and
  the field's tile isn't rendered by `_buildFieldList`).
- **Usage:** Called from both branches of [`_selectResult`](#_selectresult) — success
  (`_initToggles(detail)`) and failure (`_initToggles(result)`).
- **Notes:** The image field is the only one that defaults to off despite being present, which is
  intentional (downloading a photo is a network cost the user should opt into, unlike text fields
  which are already fetched as part of the detail response).

### `Future<void> _fetchImage()` <a id="_fetchimage"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/devices/views/device_search_dialog.dart` (line 230)
- **Purpose:** Download the selected result's `imageUrl` to local storage and stage it as the
  "fetched" image candidate for the preview.
- **Inputs:** None (reads `_selected?.imageUrl`).
- **Returns:** `Future<void>`.
- **Side effects:** `setState` around a network download (`ImageService.saveImageFromUrl`) and a
  file resolve (`ImageService.resolve`); on error, shows a `SnackBar` via `ScaffoldMessenger`.
- **Algorithm:**
  1. Returns immediately if `_selected?.imageUrl` is null.
  2. Sets `_fetchingImage = true`.
  3. Awaits `ImageService.saveImageFromUrl(_selected!.imageUrl!)`, which downloads the image and
     returns a local path (or `null` on failure to save).
  4. If a path came back and the widget is still mounted, awaits `ImageService.resolve(path)` to
     get a `File`, then sets `_fetchedImagePath`, `_imagePreview = FileImage(file)`,
     `_toggles['image'] = true` (auto-checks the box now that a fetched image exists), and clears
     the loading flag.
  5. If `path` is null, just clears the loading flag (no image staged, checkbox stays unchecked).
  6. On any thrown exception, clears the loading flag and shows the exception text in a
     `SnackBar`.
- **Usage:** `onPressed: _fetchImage,` on the "fetch image" `TextButton.icon` in
  `_buildFieldList` (`lib/features/devices/views/device_search_dialog.dart`, line 596), only shown
  while `_fetchedImagePath == null` and not already fetching.
- **Notes:** Unlike `_search`/`_selectResult`, failures here surface via a `SnackBar` rather than
  inline error text, since the rest of the preview dialog remains usable regardless.

### `void _apply()` <a id="_apply"></a>
- **Kind:** method of `_SearchDialogState`
- **Source:** `lib/features/devices/views/device_search_dialog.dart` (line 261)
- **Purpose:** Build the field-name → value map for every checked toggle and close the dialog
  with it.
- **Inputs:** None (reads `_selected`, `_toggles`, `_fetchedImagePath`).
- **Returns:** `void`.
- **Side effects:** `Navigator.of(context).pop(result)` — closes the dialog and resolves the
  `showDeviceSearchDialog` future.
- **Algorithm:**
  1. Returns immediately if `_selected` is null (nothing to apply).
  2. For each of `brand`, `model`, `chipset` → `chipset`, `gpuName` → `gpuName` (key `'gpu'` in
     toggles maps to result key `'gpuName'`), `ram`, `storage`, `screenSize`, `battery`, `os`,
     `releaseDate`: if the corresponding toggle is `true` and the source field is non-null, adds
     it to the output map under its result field name.
  3. `resolution` is handled specially: if the toggle is checked, it adds **both**
     `screenResolutionW` and `screenResolutionH` independently (each only if non-null on the
     result) — a single toggle can therefore add up to two map keys.
  4. `image` is added only if the toggle is checked **and** `_fetchedImagePath != null` (i.e. the
     user must have both checked the box and successfully run `_fetchImage`), using the local
     file path as the value (not the remote URL).
  5. Pops the dialog with the assembled map.
- **Usage:** `onPressed: _toggles.values.any((v) => v) && !_fetchingDetail ? _apply : null,` in
  `_buildPreviewView` (`lib/features/devices/views/device_search_dialog.dart`, lines 490–492) —
  the apply button is disabled unless at least one toggle is checked and detail fetching has
  finished.
- **Notes:** The toggle key for GPU (`'gpu'`) intentionally differs from the output map key
  (`'gpuName'`) and from the result field name (`r.gpuName`) — this mapping is easy to miss when
  extending the field list, since every other field uses the same string for its toggle key and
  output key.
