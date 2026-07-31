# lib/shared/widgets/map_picker_page.dart

`MapPickerPage` 是 [地图](../../../features/map.md) 描述的全屏位置选择器：地图上点击放置，加 Nominatim 文本搜索快捷方式，经 `Navigator.pop` 返回 `LatLng`。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `MapPickerPage` 构造函数 | 构造函数 | B | 带可选初始位置创建选择器。 |
| `createState` | 方法（`MapPickerPage`） | B | 创建选择器状态对象。 |
| [`initState`](#initstate) | 方法（`_MapPickerPageState`） | A | 从初始位置或东京播种所选点。 |
| `dispose` | 方法（`_MapPickerPageState`） | B | 释放搜索文本控制器。 |
| [`_search`](#search) | 方法（`_MapPickerPageState`） | A | 经 Nominatim 地理编码搜索文本并重新居中。 |
| `build` | 方法（`_MapPickerPageState`） | B | 组合搜索栏、坐标读出和地图。 |

## 文档

### `void initState()` <a id="initstate"></a>
- **种类：** `_MapPickerPageState` 的方法。
- **来源：** `lib/shared/widgets/map_picker_page.dart`（第 41 行）。
- **用途：** 播种初始所选点。
- **输入：** 无（读取 `widget.initialPosition`）。
- **返回：** 无。
- **副作用：** 设置 `_selected`。
- **算法：** `_selected = widget.initialPosition ?? const LatLng(35.6762, 139.6503)`（东京默认，匹配 [device_map_page.md](../views/device_map_page.md) 默认中心）。
- **用法：** 状态对象创建时由 Flutter 框架调用一次。
- **备注：** 无。

### `Future<void> _search()` <a id="search"></a>
- **种类：** `_MapPickerPageState` 的方法。
- **来源：** `lib/shared/widgets/map_picker_page.dart`（第 62 行）。
- **用途：** 经 Nominatim API 地理编码自由文本搜索查询并把地图重新居中到第一结果。
- **输入：** 无（读取 `_searchCtrl.text`）。
- **返回：** `Future<void>`。
- **副作用：** 对 `nominatim.openstreetmap.org` 的网络请求；更新 `_searching` 和 `_selected` 状态。
- **算法：** 空查询空操作。设 `_searching = true`；带 `User-Agent: MyDevice/0.2.0` 页头的 `GET https://nominatim.openstreetmap.org/search?q=<query>&format=json&limit=1`。HTTP 200 且非空 JSON 数组结果时从第一结果解析 `lat`/`lon` 并更新 `_selected`。任何异常（网络失败、解析失败）被静默吞掉（带注释 "Silently ignore search failure" 的 `catch (_) {}`）。`_searching` 在 `finally` 块重置为 `false`，由 `mounted` 守卫。
- **用法：** 搜索字段提交和点击搜索图标按钮时调用。
- **备注：** 搜索失败静默——UI 简单不移动并停止显示转圈；不向用户浮出错误消息。

`MapPickerPage` 构造函数、`createState`、`_MapPickerPageState.dispose` 和 `build` 是 Tier B：平凡组件生命周期样板和纯组合（搜索 `TextField`、坐标读出和 `onTap` 直接设 `_selected` 的 `FlutterMap`）。
