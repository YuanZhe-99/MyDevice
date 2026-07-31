# lib/shared/views/device_map_page.dart

`DeviceMapPage` 是记录坐标设备的只读 OpenStreetMap 视图，描述于 [地图](../../../features/map.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `DeviceMapPage` 构造函数 | 构造函数 | B | 带标题和设备列表创建地图页。 |
| [`_locatedDevices`](#locateddevices) | getter（`DeviceMapPage`） | A | 过滤到经纬度都非 null 的设备。 |
| [`build`](#build-devicemappage) | 方法（`DeviceMapPage`） | A | 计算中心/缩放并渲染地图或空状态。 |
| `_DeviceMarker` 构造函数 | 构造函数 | B | 创建一个地图标记组件。 |
| `build`（`_DeviceMarker`） | 方法（`_DeviceMarker`） | B | 渲染标记图标/标签 chip。 |

## 文档

### `List<Device> get _locatedDevices` <a id="locateddevices"></a>
- **种类：** `DeviceMapPage` 的 getter。
- **来源：** `lib/shared/views/device_map_page.dart`（第 26 行）。
- **用途：** 把页面 `devices` 列表过滤到 `latitude` 和 `longitude` 都设置的。
- **输入：** 无（读取 `devices`）。
- **返回：** `List<Device>`。
- **副作用：** 无。
- **算法：** `devices.where((d) => d.latitude != null && d.longitude != null).toList()`。
- **用法：** 被 `build` 调用决定空状态与地图之间，并构建标记。
- **备注：** 无坐标设备简单从地图省略——本页不显示单独"未定位设备"列表。

### `Widget build(BuildContext context)` <a id="build-devicemappage"></a>
- **种类：** `DeviceMapPage` 的方法。
- **来源：** `lib/shared/views/device_map_page.dart`（第 35 行）。
- **用途：** 为已定位设备计算合理地图中心/缩放并渲染空状态消息或每已定位设备一个标记的 `FlutterMap`。
- **输入：** `context`。
- **返回：** 页面组件树。
- **副作用：** 除构建组件外无。
- **算法：**
  1. 默认中心是东京（`LatLng(35.6762, 139.6503)`），缩放 `3`。
  2. 恰好一个已定位设备时直接以它为中心，缩放 `13`。
  3. 多个时计算覆盖所有已定位设备的包围盒（min/max 经纬度）、以其中点为中心，并从纬/经跨度较大者用六个手工调优阈值挑缩放级别（跨度 `< 0.01` → 缩放 15，降到跨度 `>= 50` → 缩放 2）。
  4. `_locatedDevices` 为空时显示居中 `l10n.mapNoLocations` 消息而非地图。
  5. 否则渲染带 OpenStreetMap `TileLayer`（`tile.openstreetmap.org`）和每已定位设备一个 `_DeviceMarker` 的 `MarkerLayer` 的 `FlutterMap`。
- **用法：** 调用方带标题和设备列表导航到本页时渲染（如从设备列表地图入口点）。
- **备注：** 跨度到缩放启发式是固定查找表，非连续公式——偏好简单性而非把包围盒精确适配到视口。

`DeviceMapPage` 构造函数和 `_DeviceMarker`（其构造函数和 `build`）是 Tier B：平凡 `const` 组件构造和纯组件组合（图标 + 设备名 chip 加位置针），除直接属性读取外无分支逻辑。
