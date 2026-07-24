# lib/features/devices/views/chip_search_dialog.dart

Modal dialog UI for searching CPU/GPU specs, backed by
`lib/features/devices/services/chip_search_service.dart`. It is opened from
`device_edit_page.dart`'s "search online" actions (see the Store-flavor gating
requirements in [Online Search and Presets](../../../../features/online-search-and-presets.md),
call site 3) and returns the selected `CpuInfo`/`GpuInfo` back to the editor. The dialog
itself holds no scraping logic — it forwards the query to `ChipSearchService.searchCpu`/
`searchGpu` (which merges bundled presets with live TechPowerUp/AMD/Intel results) and
renders whatever comes back.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`showCpuSearchDialog`](#showcpusearchdialog) | function | A | Open the CPU search dialog and return the CPU the user picked. |
| [`showGpuSearchDialog`](#showgpusearchdialog) | function | A | Open the GPU search dialog and return the GPU the user picked. |
| `_ChipSearchDialog` (constructor) | constructor | B | Store the search mode, initial query, and presets for the dialog widget. |
| `createState` | method (`_ChipSearchDialog`) | B | Create the dialog's mutable state object. |
| `initState` | method (widget lifecycle) | B | Seed the query controller with the initial query. |
| `dispose` | method (widget lifecycle) | B | Dispose the query text controller. |
| [`_search`](#_search) | method (`_ChipSearchDialogState`) | A | Run a CPU/GPU search against `ChipSearchService` and update dialog state. |
| `_select` | method (`_ChipSearchDialogState`) | B | Pop the dialog with the chosen result converted to `CpuInfo`/`GpuInfo`. |
| `build` | method (widget) | B | Build the dialog shell (header, search bar, results area). |
| `_buildResults` | method (widget helper) | B | Render the loading/error/empty/list states for search results. |
| [`_coresLabel`](#_coreslabel) | method (`_ChipSearchDialogState`) | A | Format a CPU result's performance/efficiency core counts into a short label. |

## Documentation

### `Future<CpuInfo?> showCpuSearchDialog(BuildContext context, {String? initialQuery, required List<CpuInfo> presets})` <a id="showcpusearchdialog"></a>
- **Kind:** top-level function
- **Source:** `lib/features/devices/views/chip_search_dialog.dart` (line 14)
- **Purpose:** Open a modal dialog that lets the user search for a CPU (online sources plus
  bundled presets) and pick one.
- **Inputs:** `context` — hosting `BuildContext`; `initialQuery` — text to pre-fill the search
  box with (e.g. the CPU model already typed into the device edit form); `presets` — the
  caller's loaded `CpuInfo` preset list, passed through unchanged to `ChipSearchService.searchCpu`
  so preset matches appear alongside live results.
- **Returns:** `Future<CpuInfo?>` — the selected `CpuInfo`, or `null` if the dialog is dismissed
  without a selection.
- **Side effects:** Shows a `Dialog` via `showDialog`; the dialog itself triggers network requests
  once the user searches.
- **Algorithm:**
  1. Calls `showDialog<CpuInfo>` with a builder that constructs `_ChipSearchDialog` in
     `_ChipMode.cpu` mode, passing `initialQuery` and `cpuPresets: presets` (`gpuPresets` is left
     empty since this mode never uses it).
  2. Returns whatever value the dialog's `Navigator.pop` call resolves the `showDialog` future
     with (see [`_select`](#_select)).
- **Usage:**
  ```dart
  Future<void> _searchCpuOnline() async {
    final cpu = await showCpuSearchDialog(
      context,
      initialQuery: _cpuModelCtrl.text,
      presets: _cpuPresets,
    );
    if (cpu != null) _applyCpuPreset(cpu);
  }
  ```
  (from `lib/features/devices/views/device_edit_page.dart`, line 754)
- **Notes:** Gated behind the same store-flavor rules as the underlying service — see
  [Online Search and Presets](../../../../features/online-search-and-presets.md) for the four
  required gating call sites; this function does not itself check `AppFlavor`, the search button
  that triggers it is what's hidden for store builds in `device_edit_page.dart`.

### `Future<GpuInfo?> showGpuSearchDialog(BuildContext context, {String? initialQuery, required List<GpuInfo> presets})` <a id="showgpusearchdialog"></a>
- **Kind:** top-level function
- **Source:** `lib/features/devices/views/chip_search_dialog.dart` (line 37)
- **Purpose:** Open a modal dialog that lets the user search for a GPU (online sources plus
  bundled presets) and pick one.
- **Inputs:** `context`; `initialQuery` — pre-filled search text; `presets` — the caller's loaded
  `GpuInfo` preset list, passed through as `gpuPresets` (`cpuPresets` is left empty).
- **Returns:** `Future<GpuInfo?>` — the selected `GpuInfo`, or `null` if dismissed without a pick.
- **Side effects:** Shows a `Dialog` via `showDialog`; triggers network requests once searched.
- **Algorithm:** Same shape as [`showCpuSearchDialog`](#showcpusearchdialog) but constructs
  `_ChipSearchDialog` in `_ChipMode.gpu` mode.
- **Usage:**
  ```dart
  Future<void> _searchGpuOnline() async {
    final gpu = await showGpuSearchDialog(
      context,
      initialQuery: _gpuModelCtrl.text,
      presets: _gpuPresets,
    );
    if (gpu != null) _applyGpuPreset(gpu);
  }
  ```
  (from `lib/features/devices/views/device_edit_page.dart`, line 768)
- **Notes:** Same store-flavor gating caveat as `showCpuSearchDialog`.

### `Future<void> _search()` <a id="_search"></a>
- **Kind:** method of `_ChipSearchDialogState`
- **Source:** `lib/features/devices/views/chip_search_dialog.dart` (line 115)
- **Purpose:** Run the current query against `ChipSearchService.searchCpu`/`searchGpu` and load
  the results into dialog state.
- **Inputs:** None (reads `_queryCtrl.text` and `widget.mode`/`widget.cpuPresets`/
  `widget.gpuPresets` from enclosing state).
- **Returns:** `Future<void>`.
- **Side effects:** Calls `setState` three times (loading start, success, and empty-result-with-
  localized-error), makes a network-backed async call through `ChipSearchService`, and mutates
  `_results`/`_searching`/`_error`.
- **Algorithm:**
  1. Trims the query text; returns immediately (no-op) if it is empty.
  2. Sets `_searching = true`, clears `_error`, and clears `_results` to show a spinner.
  3. Awaits `ChipSearchService.searchCpu(query, widget.cpuPresets)` or `searchGpu(query,
     widget.gpuPresets)` depending on `widget.mode`.
  4. On success, checks `mounted`, then stores the results; if the result list is empty, sets
     `_error` to the localized `searchNoResults` string (still using the empty-results state
     rather than a distinct "no results" widget).
  5. On any thrown exception, checks `mounted`, stops the spinner, and stores `e.toString()` as
     `_error` for display.
- **Usage:**
  ```dart
  onSubmitted: (_) => _search(),
  ...
  FilledButton(
    onPressed: _searching ? null : _search,
    child: Text(l10n.searchButton),
  ),
  ```
  (from `build`, `lib/features/devices/views/chip_search_dialog.dart` lines 216–223)
- **Notes:** Errors from the underlying HTTP scraping (network failures, parse errors) surface to
  the user as raw `e.toString()` text rather than a friendly message — only the "no results" case
  is localized.

### `String _coresLabel(ChipSearchResult r)` <a id="_coreslabel"></a>
- **Kind:** method of `_ChipSearchDialogState`
- **Source:** `lib/features/devices/views/chip_search_dialog.dart` (line 317)
- **Purpose:** Build a short "P+E core" label for a CPU search result's subtitle line.
- **Inputs:** `r` — a `ChipSearchResult` whose `performanceCores`/`efficiencyCores` may each be
  present or absent.
- **Returns:** `String` — one of `'{p}P+{e}E'`, `'{p}C'`, `'{e}E'`, or `''` depending on which
  core counts are known.
- **Side effects:** None.
- **Algorithm:**
  1. If both `performanceCores` and `efficiencyCores` are non-null, format as
     `'${p}P+${e}E'` (hybrid architecture, e.g. Intel P/E-cores).
  2. Else if only `performanceCores` is known, format as `'${p}C'` (a plain core count).
  3. Else if only `efficiencyCores` is known, format as `'${e}E'`.
  4. Else return `''` (subtitle building code only includes this label when at least one of the
     two is non-null, so the empty-string branch is effectively unreachable in normal use).
- **Usage:**
  ```dart
  if (r.performanceCores != null || r.efficiencyCores != null)
    _coresLabel(r),
  ```
  (from `_buildResults`, `lib/features/devices/views/chip_search_dialog.dart` line 272)
- **Notes:** Only called from the CPU subtitle-building branch in `_buildResults`; GPU results use
  `r.architecture` directly instead.
