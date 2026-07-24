# lib/shared/views/device_map_page.dart

`DeviceMapPage` is the read-only OpenStreetMap view of devices with recorded coordinates,
described in [../../../features/map.md](../../../features/map.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DeviceMapPage` constructor | constructor | B | Create the map page with a title and device list. |
| [`_locatedDevices`](#locateddevices) | getter (`DeviceMapPage`) | A | Filter to devices with non-null lat/lng. |
| [`build`](#build-devicemappage) | method (`DeviceMapPage`) | A | Compute center/zoom and render the map or an empty state. |
| `_DeviceMarker` constructor | constructor | B | Create one map marker widget. |
| `build` (`_DeviceMarker`) | method (`_DeviceMarker`) | B | Render the marker's icon/label chip. |

## Documentation

### `List<Device> get _locatedDevices` <a id="locateddevices"></a>
- **Kind:** getter of `DeviceMapPage`.
- **Source:** `lib/shared/views/device_map_page.dart` (line 26).
- **Purpose:** Filter the page's `devices` list down to those with both `latitude` and
  `longitude` set.
- **Inputs:** None (reads `devices`).
- **Returns:** `List<Device>`.
- **Side effects:** None.
- **Algorithm:** `devices.where((d) => d.latitude != null && d.longitude != null).toList()`.
- **Usage:** Called by `build` to decide between the empty state and the map, and to build
  markers.
- **Notes:** Devices without coordinates are simply omitted from the map — there is no separate
  "unlocated devices" list shown on this page.

### `Widget build(BuildContext context)` <a id="build-devicemappage"></a>
- **Kind:** method of `DeviceMapPage`.
- **Source:** `lib/shared/views/device_map_page.dart` (line 35).
- **Purpose:** Compute a sensible map center/zoom for the located devices and render either an
  empty-state message or a `FlutterMap` with one marker per located device.
- **Inputs:** `context`.
- **Returns:** The page's widget tree.
- **Side effects:** None beyond building widgets.
- **Algorithm:**
  1. Default center is Tokyo (`LatLng(35.6762, 139.6503)`), zoom `3`.
  2. If exactly one located device, center on it directly at zoom `13`.
  3. If more than one, compute the bounding box (min/max lat/lng) over all located devices, center
     on its midpoint, and pick a zoom level from the larger of the lat/lng span using six
     hand-tuned thresholds (span `< 0.01` → zoom 15, down to span `>= 50` → zoom 2).
  4. If `_locatedDevices` is empty, show a centered `l10n.mapNoLocations` message instead of a map.
  5. Otherwise render `FlutterMap` with an OpenStreetMap `TileLayer`
     (`tile.openstreetmap.org`) and a `MarkerLayer` with one `_DeviceMarker` per located device.
- **Usage:** Rendered when a caller navigates to this page (e.g. from the device list's map
  entry point) with a title and a device list.
- **Notes:** The zoom-from-span heuristic is a fixed lookup table, not a continuous formula — it
  favors simplicity over precisely fitting the bounding box to the viewport.

`DeviceMapPage`'s constructor and `_DeviceMarker` (both its constructor and `build`) are Tier B:
trivial `const` widget construction and pure widget composition (an icon + device name chip plus a
location pin), with no branching logic beyond straightforward property reads.
