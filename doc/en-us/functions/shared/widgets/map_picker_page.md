# lib/shared/widgets/map_picker_page.dart

`MapPickerPage` is the full-screen location picker described in
[../../../features/map.md](../../../features/map.md): tap-to-place on a map, plus a Nominatim
text-search shortcut, returning a `LatLng` via `Navigator.pop`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `MapPickerPage` constructor | constructor | B | Create the picker with an optional initial position. |
| `createState` | method (`MapPickerPage`) | B | Create the picker's state object. |
| [`initState`](#initstate) | method (`_MapPickerPageState`) | A | Seed the selected point from the initial position or Tokyo. |
| `dispose` | method (`_MapPickerPageState`) | B | Dispose the search text controller. |
| [`_search`](#search) | method (`_MapPickerPageState`) | A | Geocode the search text via Nominatim and recenter. |
| `build` | method (`_MapPickerPageState`) | B | Compose the search bar, coordinate readout, and map. |

## Documentation

### `void initState()` <a id="initstate"></a>
- **Kind:** method of `_MapPickerPageState`.
- **Source:** `lib/shared/widgets/map_picker_page.dart` (line 41).
- **Purpose:** Seed the initially-selected point.
- **Inputs:** None (reads `widget.initialPosition`).
- **Returns:** None.
- **Side effects:** Sets `_selected`.
- **Algorithm:** `_selected = widget.initialPosition ?? const LatLng(35.6762, 139.6503)` (Tokyo
  default, matching [device_map_page.md](../views/device_map_page.md)'s default center).
- **Usage:** Called once by the Flutter framework when the state object is created.
- **Notes:** None.

### `Future<void> _search()` <a id="search"></a>
- **Kind:** method of `_MapPickerPageState`.
- **Source:** `lib/shared/widgets/map_picker_page.dart` (line 62).
- **Purpose:** Geocode the free-text search query via the Nominatim API and recenter the map on
  the first result.
- **Inputs:** None (reads `_searchCtrl.text`).
- **Returns:** `Future<void>`.
- **Side effects:** Network request to `nominatim.openstreetmap.org`; updates `_searching` and
  `_selected` state.
- **Algorithm:** No-op on empty query. Set `_searching = true`; `GET
  https://nominatim.openstreetmap.org/search?q=<query>&format=json&limit=1` with a
  `User-Agent: MyDevice/0.2.0` header. On HTTP 200 with a non-empty JSON array result, parse
  `lat`/`lon` from the first result and update `_selected`. Any exception (network failure, parse
  failure) is silently swallowed (`catch (_) {}` with a comment "Silently ignore search failure").
  `_searching` is reset to `false` in a `finally` block, guarded by `mounted`.
- **Usage:** Called on search-field submit and on tapping the search icon button.
- **Notes:** Search failures are silent — the UI simply doesn't move and stops showing the
  spinner; no error message is surfaced to the user.

`MapPickerPage`'s constructor, `createState`, `_MapPickerPageState.dispose`, and `build` are Tier
B: trivial widget-lifecycle boilerplate and pure composition (a search `TextField`, a coordinate
readout, and a `FlutterMap` whose `onTap` directly sets `_selected`).
