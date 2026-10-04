# lib/features/devices/widgets/storage_health_label.dart

一个顶层辅助（自 1.8.2 起），给出硬盘 `StorageHealth`（见 [`../models/device.md`](../models/device.md)）的本地化名称——存储槽记录的状态：正常、故障或离线。硬盘健康状况与 RAID 阵列见 [设备](../../../../features/devices.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`storageHealthLabel`](#storagehealthlabel) | 顶层函数 | A | 返回 `StorageHealth` 的本地化名称。 |

行数（1）与 `grep -c 'Purpose:' storage_health_label.dart`（1）精确匹配。

## 文档

### `String storageHealthLabel(AppLocalizations l10n, StorageHealth health)` <a id="storagehealthlabel"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/devices/widgets/storage_health_label.dart`（第 10 行）。
- **用途：** 返回硬盘健康状况的本地化名称。
- **输入：** `l10n`；`health`。
- **返回：** `String`——`storageStatusOk`、`storageStatusFailed` 或 `storageStatusOffline`。
- **副作用：** 无。
- **算法：** 对三个 `StorageHealth` 值的穷举 `switch`。
- **用法：** [`device_edit_page.md`](../views/device_edit_page.md) 中存储行的状态下拉框；[`device_detail_page.md`](../views/device_detail_page.md) 中的存储状态行；[`dataset_edit_page.md`](../../datasets/views/dataset_edit_page.md#buildplacetile) 以及 [`dataset_topology_page.md`](../../datasets/views/dataset_topology_page.md) 的框和详情中故障或离线槽的状态。
- **备注：** 健康值到名称的唯一映射，因此新增一个值只需在这里加一个分支（`switch` 是穷举的，缺少分支会编译报错）。
