# 设备

设备清单是应用的主要功能。模型来源：`lib/features/devices/models/device.dart`。穷举字段列表见 [数据格式 — 设备](../data-formats.md#device-libfeaturesdevicesmodelsdevicedart)；本页聚焦行为。

## 设备模型

`Device` 跟踪身份、类别、emoji/图像、品牌/型号/序列号、CPU、GPU、RAM、存储、显示、电池、操作系统、位置、购买/发布日期、生命周期状态、退役/出售状态、购买价格、出售价格、循环成本、备注、`modifiedAt` 和未知 JSON 字段（`extraJson`）。

`DeviceCategory` 值：`desktop`、`laptop`、`phone`、`tablet`、`headphone`、`watch`、`router`、`gameConsole`、`vps`、`devBoard`、`other`。

## 生命周期与财务跟踪

`v0.4.0` 添加。源码确认（`Device.lifecycleStatus`）：

```dart
DeviceLifecycleStatus get lifecycleStatus {
  if (isSold) return DeviceLifecycleStatus.sold;
  if (isRetired) return DeviceLifecycleStatus.retired;
  return DeviceLifecycleStatus.inService;
}
```

两者都设时 `isSold` 优先于 `isRetired`。相关财务 getter：

- `hasFinancialData` — `purchasePrice`、`soldPrice` 或任何 `recurringCosts` 条目存在时为 true。
- `serviceDays({asOf})` — 从 `purchaseDate` 到现在的天数（在用中）或 `retiredDate`（否则），最少 1 天；无 `purchaseDate` 为 `null`。
- `recurringCostThrough({asOf})` — 每个循环成本的 `dailyConvertedAmount * serviceDays` 之和。
- `totalCost({asOf})` — `purchasePrice.convertedAmount + recurringCostThrough - soldPrice.convertedAmount`。
- `averageDailyCost({asOf})` — `totalCost / serviceDays`，无财务数据或购买日期为 `null`。

`DeviceRecurringCost.dailyConvertedAmount` 从 `billingCycle` 派生（`BillingCycle.monthly` → `price.convertedAmount * 12`，`yearly` → 直接 `price.convertedAmount`）除以 365。

### 退役/出售/删除的级联规则

- 退役或出售设备必须从网络赋值和数据集存储链接移除，并从网络/存储选择器排除。
- 删除设备必须移除相关网络赋值、数据集存储链接、服务记录和服务路由引用（见 [数据格式 — 交叉引用规则](../data-formats.md#cross-reference-rules)）。
- 设备详情和 Markdown 导出相关时含生命周期和财务信息（见 [备份与恢复 — Markdown 导出](../backup-restore.md#markdown-export)）。

## 财务总览页

`lib/features/devices/views/device_finance_overview_page.dart`（`DeviceFinanceOverviewPage`）从设备列表的财务总览卡片打开。它显示用 `fl_chart` 构建的两个视图：

1. **资产分布** — 按设备类别的总成本。
2. **每日成本趋势** — 组合历史/未来折线图。未来段渲染为虚线（确认：`LineChartBarData` 上 `dashArray: series.dashed ? [7, 5] : null`），用所选范围作为前向投影窗口。

每日成本轴总是用**对数风格变换**，源码确认：

```dart
double _logTransform(double value) {
  final sign = value < 0 ? -1.0 : 1.0;
  return sign * math.log(value.abs() + 1) / math.ln10;
}
```

（带符号 `log10(|x| + 1)` 变换，`_logInverse` 为轴标签和工具提示撤销它）——这让小每日成本与一次性大购买尖峰在同一图表上可读。

## 设备头像渲染

`lib/features/devices/widgets/device_avatar.dart`（`DeviceAvatar`、`DeviceAvatar.fromDevice`）是任何设备需要图标时使用的共享圆形头像渲染器：

- `emoji` 已设时在 `primaryContainer` 色圆上居中。
- 否则 `imagePath` 已设时 `ImageService.resolve()` 加载文件，渲染为 `ClipOval` + `BoxFit.cover`，在 `surfaceContainerHighest` 背景上中心裁剪，带微妙 `outlineVariant` 边框——这让透明 PNG 在圆形框内可见。
- 任何缺失/失败图像（含 `Image.file` 的 `errorBuilder`）回退一致轮廓类别图标（来自 `device_category_icon.dart` 的 `deviceCategoryIcon(category)`）。

## 相关

- [数据格式](../data-formats.md) 了解完整字段列表和 `MoneyValue`/`DeviceRecurringCost` 形态。
- [在线搜索与预设](online-search-and-presets.md) 了解设备规格如何从在线源或捆绑预设填充。
- [备份与恢复](../backup-restore.md) 了解设备数据（和图像）如何备份、恢复和导出。
