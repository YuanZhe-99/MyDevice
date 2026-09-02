# lib/shared/widgets/adaptive_tile_grid.dart

列表页按 [`listColumnCount`](../utils/adaptive_layout.md#listcolumncount) 返回的列数渲染 tile 所需的三个助手：一行 tile 对应一个 `Row`、整个列表的所有行，以及选择列数的应用栏控件。被 `device_list_page.dart`、`network_list_page.dart`、`dataset_list_page.dart` 和 `service_list_page.dart` 使用。列数规则背后的推理见 [../../../adaptive-layout.md](../../../adaptive-layout.md#多少列)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`adaptiveTileRow`](#adaptivetilerow) | 顶层函数 | A | 构建多列列表的一行，从左到右填充。 |
| [`adaptiveTileRows`](#adaptivetilerows) | 顶层函数 | A | 把列表的 children 构建为行，单列或多列。 |
| [`listColumnsButton`](#listcolumnsbutton) | 顶层函数 | A | 构建选择列表列数的应用栏控件。 |

## 文档

### `Widget adaptiveTileRow({required int rowIndex, required int columns, required int itemCount, required Widget Function(int index) itemBuilder, double gap = listTileGap})` <a id="adaptivetilerow"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/widgets/adaptive_tile_grid.dart`。
- **用途：** 构建多列列表的一行，从左到右填充。
- **输入：** `rowIndex` — 从零开始的行号；`columns` — 每行 tile 数；`itemCount` — tile 总数；`itemBuilder` — 按扁平索引构建一个 tile；`gap` — 列间距。
- **返回：** 一个 `Row`（`crossAxisAlignment: start`），含 `columns` 个由 `gap` 分隔的 `Expanded` 格子；超过 `itemCount` 的格子放 `SizedBox.shrink()`。
- **副作用：** 无。
- **用法：** 设备、网络和数据集列表从 item 数为 `listRowCount` 的 `ListView.builder` 里调用它，保住虚拟化。
- **备注：** 刻意用 `Row` 而非 `GridView`，让 builder 驱动的列表保持惰性、已物化的列表无需嵌套滚动。用空格子补齐不满的末行，让剩余 tile 保持宽度而不是横向拉伸。

### `List<Widget> adaptiveTileRows({required int columns, required int itemCount, required Widget Function(int index) itemBuilder, double gap = listTileGap})` <a id="adaptivetilerows"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/widgets/adaptive_tile_grid.dart`。
- **用途：** 把列表的 children 构建为行，单列或多列。
- **输入：** `columns`、`itemCount`、`itemBuilder`、`gap`。
- **返回：** 一列时就是 tile 本身；否则每个 `listRowCount` 行一个 `adaptiveTileRow`。
- **副作用：** 无。
- **用法：** 分组设备列表的每个类别，以及服务页的设备、链路和端口视图，它们的卡片本来就是同一个 `ListView` 的 children。
- **备注：** 一列时原样返回 tile，正是让把单列 tile 包在 `Dismissible` 里的调用方保持原有组件树不变的原因。

### `Widget listColumnsButton(BuildContext context, {required int preference, required int capacity, required ValueChanged<int> onChanged})` <a id="listcolumnsbutton"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/widgets/adaptive_tile_grid.dart`。
- **用途：** 构建选择列表列数的应用栏控件。
- **输入：** `context`；`preference` — 已存的选择；`capacity` — 当前宽度最多容纳的列数；`onChanged` — 接收新偏好。
- **返回：** 提供 `listColumnsAuto` 和直到 `listMaxColumns` 每个数的 `PopupMenuButton<int>`（`Icons.view_column_outlined`），`capacity <= 1` 时为 `SizedBox.shrink()`。
- **副作用：** 除调用 `onChanged` 外无。
- **用法：** 各列表页的 `AppBar.actions`，位于排序菜单之前；调用方在重排模式与服务概览中隐藏它。
- **备注：** 容量为一时隐藏而非禁用，所以手机或折叠外屏永远不会显示一个什么也做不了的控件。菜单始终提供每个数值，让偏好可在折叠时设置、展开时生效；勾选跟随已存偏好，而渲染的是钳到可容纳范围的值。
