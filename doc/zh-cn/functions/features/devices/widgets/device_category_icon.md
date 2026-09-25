# lib/features/devices/widgets/device_category_icon.dart

`DeviceCategory`（见 [`device.md`](../models/device.md)）的两个顶层辅助：其 Material 轮廓 `IconData`，以及——1.5.6 起——其本地化名称，服务拓扑的节点详情用它显示节点所在设备的类别。图标被 [`DeviceAvatar`](device_avatar.md) 用作设备无 emoji 或图像时的回退图标，并被设备列表/详情视图直接用于任何需要裸类别字形的地方。这如何融入头像渲染见 [设备 — 设备头像渲染](../../../../features/devices.md#device-avatar-rendering)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`deviceCategoryIcon`](#devicecategoryicon) | 顶层函数 | A | 把 `DeviceCategory` 映射到其轮廓图标。 |
| [`deviceCategoryLabel`](#devicecategorylabel) | 顶层函数 | A | 返回 `DeviceCategory` 的本地化名称。 |

行数（2）与 `grep -c 'Purpose:' device_category_icon.dart`（2）精确匹配。

## 文档

### `IconData deviceCategoryIcon(DeviceCategory category)` <a id="devicecategoryicon"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/devices/widgets/device_category_icon.dart`（第 11 行）。
- **用途：** 为设备类别返回一致的 Material 轮廓图标，用于任何设备需要类别字形的地方（头像回退、列表/详情 chip）。
- **输入：** `category` — `DeviceCategory` 枚举值。
- **返回：** `IconData` — 每类别一个特定轮廓图标（如 `desktop` 为 `desktop_windows_outlined`、`phone` 为 `smartphone_outlined`、`other` 为 `devices_other_outlined`）。
- **副作用：** 无。
- **算法：** 覆盖全部十一个 `DeviceCategory` 值的单个穷举 `switch` 表达式，各映射到一个固定 `Icons.*_outlined` 常量。
- **用法：**
  ```dart
  Icon(
    deviceCategoryIcon(category),
    size: size * 0.5,
    color: cs.onPrimaryContainer,
  )
  ```
  （来自 `DeviceAvatar._fallbackIcon`/`_fallbackIconContent`，`lib/features/devices/widgets/device_avatar.dart`）
- **备注：** `switch` 对 `DeviceCategory` 枚举穷举，因此添加无此 case 的新类别是编译错误，非静默运行时回退。

### `String deviceCategoryLabel(AppLocalizations l10n, DeviceCategory category)` <a id="devicecategorylabel"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/devices/widgets/device_category_icon.dart`（第 34 行）。
- **用途：** 返回设备类别的本地化名称。
- **输入：** `l10n`；`category`。
- **返回：** `String` — 该类别的 `deviceCategory*` ARB 字符串。
- **副作用：** 无。
- **算法：** 覆盖十一个 `DeviceCategory` 值的穷举 `switch`。
- **用法：** 应用显示类别名称的每一处：[`device_edit_page.dart`](../views/device_edit_page.md) 中的类别下拉框；[`device_list_page.dart`](../views/device_list_page.md) 中的类别分组标题和 `_DeviceCard` 副标题；[`device_finance_overview_page.dart`](../views/device_finance_overview_page.md) 中的资产分布分桶；[`network_detail_page.dart`](../../network/views/network_detail_page.md) 中的设备分组标题；服务拓扑的节点详情（`service_topology_page.dart`），用作设备 tile 的副标题；以及拓扑画布上设备节点的副标题（[`service_topology_widgets.dart`](../../services/views/service_topology_widgets.md#nodesubtitle)）。
- **备注：** 类别到名称的唯一映射。1.5.7 之前，设备编辑器、设备列表、财务总览和网络详情页各自保留一份私有副本（`_categoryLabel`）；它们现在都调用此辅助，因此新增类别只需在这里加一个 case。
