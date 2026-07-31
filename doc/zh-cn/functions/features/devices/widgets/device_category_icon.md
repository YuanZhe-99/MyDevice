# lib/features/devices/widgets/device_category_icon.dart

把 `DeviceCategory`（见 [`device.md`](../models/device.md)）映射到 Material 轮廓 `IconData` 的单个顶层辅助。被 [`DeviceAvatar`](device_avatar.md) 用作设备无 emoji 或图像时的回退图标，并被设备列表/详情视图直接用于任何需要裸类别字形的地方。这如何融入头像渲染见 [设备 — 设备头像渲染](../../../../features/devices.md#device-avatar-rendering)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`deviceCategoryIcon`](#devicecategoryicon) | 顶层函数 | A | 把 `DeviceCategory` 映射到其轮廓图标。 |

行数（1）与 `grep -c 'Purpose:' device_category_icon.dart`（1）精确匹配。

## 文档

### `IconData deviceCategoryIcon(DeviceCategory category)` <a id="devicecategoryicon"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/devices/widgets/device_category_icon.dart`（第 10 行）。
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
