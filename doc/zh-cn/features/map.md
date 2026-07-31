# 地图

来源：`lib/shared/views/device_map_page.dart` 和 `lib/shared/widgets/map_picker_page.dart`。这些视图读写 的 `Device.latitude` / `Device.longitude` 字段见 [数据格式 — 设备](../data-formats.md#device-libfeaturesdevicesmodelsdevicedart)。

## `device_map_page.dart` — 只读设备地图

提供每个已设坐标（`latitude`/`longitude` 都非 null）设备的**只读** OpenStreetMap 视图。它带回退链挑选中心点，源码确认：

1. 任何已定位设备存在时以第一个为中心。
2. 多个时以最小/最大纬度经度边界的中间点为中心。
3. 无已定位设备时的默认回退中心：

   ```dart
   LatLng center = const LatLng(35.6762, 139.6503); // default Tokyo
   ```

## `map_picker_page.dart` — 全屏位置选择器

`MapPickerPage` 是从设备编辑器设置设备位置使用的全屏选择器。它支持针对 **Nominatim**（OpenStreetMap）地理编码 API 的地址搜索——源码确认：

```dart
final uri = Uri.https('nominatim.openstreetmap.org', '/search', { ... });
```

选择器 `initialCenter` 在设备已有坐标时默认当前所选位置，否则用与只读地图相同的东京默认。

## 相关

- [设备](devices.md) 了解 `Device.locationName`/`latitude`/`longitude` 字段。
