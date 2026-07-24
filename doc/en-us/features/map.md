# Map

Sources: `lib/shared/views/device_map_page.dart` and
`lib/shared/widgets/map_picker_page.dart`. See
[Data Formats](../data-formats.md#device-libfeaturesdevicesmodelsdevicedart) for the
`Device.latitude` / `Device.longitude` fields these views read and write.

## `device_map_page.dart` — read-only device map

Provides a **read-only** OpenStreetMap view of every device that has coordinates set
(`latitude`/`longitude` both non-null). It picks a center point with a fallback chain,
confirmed in source:

1. If any located devices exist, center on the first one.
2. If multiple, center on the midpoint of the min/max latitude and longitude bounds.
3. Default fallback center, when there are no located devices:

   ```dart
   LatLng center = const LatLng(35.6762, 139.6503); // default Tokyo
   ```

## `map_picker_page.dart` — full-screen location picker

`MapPickerPage` is the full-screen picker used from the device editor to set a
device's location. It supports address search against the **Nominatim** (OpenStreetMap)
geocoding API — confirmed in source:

```dart
final uri = Uri.https('nominatim.openstreetmap.org', '/search', { ... });
```

The picker's `initialCenter` defaults to the currently selected location if the device
already has coordinates, otherwise the same Tokyo default used by the read-only map.

## Related

- [Devices](devices.md) for the `Device.locationName`/`latitude`/`longitude` fields.
