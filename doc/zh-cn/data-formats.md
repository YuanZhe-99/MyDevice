# 数据格式

本页文档化每个持久化模型、`extraJson` 未知字段保留模式和完整持久化数据清单。这些文件在磁盘上的位置见 [架构](architecture.md)，如何跨设备合并见 [WebDAV 同步](sync.md)。

所示所有字段都是从 `lib/features/*/models/*.dart` 当前源码读取的实际构造函数/`toJson()`/`fromJson()` 字段，不是通用 Flutter 数据模型猜测。

## 设备（`lib/features/devices/models/device.dart`）

`Device` 字段：

- **身份：** `id`（UUID v4，省略时生成）、`name`。
- **类别：** `category`（`DeviceCategory`：`desktop`、`laptop`、`phone`、`tablet`、`headphone`、`watch`、`router`、`gameConsole`、`vps`、`devBoard`、`other`）、`emoji`、`imagePath`、`brand`、`model`、`serialNumber`。
- **CPU/GPU：** `cpu`（`CpuInfo`：`model`、`architecture`、`frequency`、`performanceCores`、`efficiencyCores`、`threads`、`cache`，加 `extraJson`）、`gpu`（`GpuInfo`：`model`、`architecture`，加 `extraJson`）。
- **RAM：** `ram`（自由文本大小字符串）、`ramType`（`RamType`：`ddr3`、`lpddr3`、`ddr4`、`lpddr4`、`lpddr4x`、`ddr5`、`lpddr5`、`lpddr5x`、`lpddr6`，各带 `'LPDDR5X'` 风格的 `displayName` getter）。
- **存储：** `storage`（`List<StorageInfo>`；每个 `StorageInfo` 有 `capacity`、`type`（`StorageType`：`ssd`、`sdCard`、`hdd`）、`interface_`（`StorageInterface`：`m2Nvme`、`sata25`、`m2Sata`、`usb`）、`serialNumber`、`brand`，加 `extraJson`）。`StorageInfo.fromJson` 为向后兼容也接受遗留普通字符串格式（如 `"512 GB"`）。
- **显示/电池/操作系统：** `screenSize`、`screenResolutionW`、`screenResolutionH`、`battery`、`os`。派生 `ppi` getter 从分辨率和解析屏幕对角线计算像素密度。
- **生命周期/财务**（`v0.4.0` 添加）：
  - `purchaseDate`、`releaseDate`、`acquisitionType`（`DeviceAcquisitionType`：`purchased`、`leased`、`purchasedWithSubscription`、`other`）。
  - `isRetired`、`retiredDate`；`isSold`、`soldPrice`（`MoneyValue`）。
  - `purchasePrice`（`MoneyValue`）。
  - `recurringCosts`（`List<DeviceRecurringCost>`；每个有 `id`、`kind`（`RecurringCostKind`：`lease`、`insurance`、`subscription`、`other`）、`name`、`price`（`MoneyValue`）、`billingCycle`（`BillingCycle`：`monthly`、`yearly`））。
  - 派生 getter：`lifecycleStatus`（`DeviceLifecycleStatus`：`inService`、`retired`、`sold`——售出优先于退役）、`hasFinancialData`、`serviceDays()`、`recurringCostThrough()`、`totalCost()`（`purchasePrice + accrued recurring costs - soldPrice`）、`averageDailyCost()`。
- **其他：** `notes`、`modifiedAt`（UTC `DateTime`）、`extraJson`。

`MoneyValue`（`purchasePrice`、`soldPrice` 和每个循环成本 `price` 使用的货币转换包装）：`amount`、`currency`、`defaultCurrency`、`convertedAmount`、`exchangeRate`、`autoRate`、`rateUpdatedAt`，加 `extraJson`。

## 网络 / NetworkDevice（`lib/features/network/models/network.dart`）

- **`Network`：** `id`、`name`、`type`（`NetworkType`：`lan`、`tailscale`、`zerotier`、`easytier`、`wireguard`、`other`）、`subnet`、`gateway`、`dnsServers`（`List<String>`）、`notes`、`modifiedAt`、`extraJson`。
- **`NetworkDevice`：** 网络与设备之间的赋值——`networkId`、`deviceId`、`addressMode`（`AddressMode`：`dhcp`、`static_`——序列化为 `"dhcp"` / `"static"`）、`ipAddress`、`hostname`、`isExitNode`、`extraJson`。

`NetworkDevice` **刻意没有 `id` 和 `modifiedAt` 字段**——源码确认：其构造函数只取 `networkId`、`deviceId`、`addressMode`、`ipAddress`、`hostname`、`isExitNode`、`extraJson`。其身份是**复合键** `(networkId, deviceId)`，因为无时间戳，同步合并把*序列化 JSON 内容*对照上次同步基础快照比较而非比较 `modifiedAt` 值。见 [WebDAV 同步 — NetworkDevice 复合键合并](sync.md#networkdevice-composite-key-merge) 和 [三方合并 — mergeAssignments 复合键内容比较合并](algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)。

`NetworkData`（顶层容器）持有 `networks: List<Network>` 和 `assignments: List<NetworkDevice>` 加 `extraJson`。

## DataSet / DataSetStorageLink（`lib/features/datasets/models/dataset.dart`）

- **`DataSet`：** `id`、`name`、`emoji`（解析时缺席默认 `'📁'`）、`storageLinks`（`List<DataSetStorageLink>`）、`modifiedAt`、`extraJson`。
- **`DataSetStorageLink`：** `deviceId` 加 `storageIndices`（`List<int>`）——该设备 `storage` 列表上属于此数据集的存储槽*索引*。设备存储列表变化时这些索引如何保持有效见 [数据集](features/datasets.md)。

## ServiceNode / ServiceEndpoint / ServiceRoute / ServiceRouteHop（`lib/features/services/models/service.dart`）

- **`ServiceNode`：** 设备上的服务实例——`id`、`deviceId`、`name`、`templateId`、`icon`、`kind`（`ServiceKind`：`web`、`reverseProxy`、`tunnel`、`media`、`storage`、`git`、`dev`、`game`、`network`、`database`、`monitoring`、`ai`、`custom`）、`runtime`（`ServiceRuntime`：`docker`、`compose`、`native`、`systemd`、`launchd`、`routerApp`、`container`、`custom`）、`state`（`ServiceState`：`active`、`paused`、`deprecated`、`unknown`）、`endpoints`（`List<ServiceEndpoint>`）、`tags`、`notes`、`dockerCompose`（纯文本）、`modifiedAt`、`extraJson`。
- **`ServiceEndpoint`：** 手动记录的本地/监听端点——`id`、`label`、`protocol`（`ServiceProtocol`：`http`、`https`、`tcp`、`udp`、`ssh`、`minecraft`、`rtsp`、`vnc`、`custom`）、`transport`（`ServiceTransport`：`tcp`、`udp`、`tcpUdp`）、`bindAddress`、`port`、`portEnd`（端口范围用——不同时 `portText` getter 渲染 `"$port-$portEnd"`，否则 `"$port"`）、`path`、`networkId`、`scope`（`ServiceScope`：`localhost`、`lan`、`vpn`、`public`、`custom`）、`isPrimary`、`notes`、`extraJson`。
- **`ServiceRoute`：** 手动记录的访问路径——`id`、`name`、`sourceServiceId`、`sourceEndpointId`、`hops`（`List<ServiceRouteHop>`）、`finalUrl`（第一/主目标，为向后兼容保留）、`accessLevel`（`ServiceAccessLevel`：`lan`、`vpn`、`authenticated`、`public`、`custom`）、`notes`、`modifiedAt`、`extraJson`。共享相同访问路径的额外分组 URL/域存储在 `extraJson['publicTargets']`（见 [服务与拓扑](features/services-topology.md)）。
- **`ServiceRouteHop`：** 路由中的一跳——`id`、`type`（`ServiceRouteHopType`：`origin`、`reverseProxy`、`tunnel`、`portForward`、`publicEndpoint`、`internalEndpoint`、`dns`、`manual`）、可选 `serviceId`/`endpointId`/`deviceId` 回指清单，或自由形式 `label`/`scheme`/`host`/`port`/`path`、`method`（`ServiceRouteMethod`：`caddy`、`nginx`、`traefik`、`frp`、`cloudflareTunnel`、`pangolin`、`tailscaleFunnel`、`routerPortForward`、`direct`、`custom`）、`notes`、`extraJson`。

`ServiceData`（顶层容器）持有 `services: List<ServiceNode>` 和 `routes: List<ServiceRoute>` 加 `extraJson`。

## `extraJson`：未知字段保留

上面每个模型都带由 `lib/shared/utils/json_preservation.dart` 的 `unknownJsonFields(json, knownKeys)` 填充的 `extraJson` 字段：

```dart
Map<String, dynamic> unknownJsonFields(
  Map<String, dynamic> json,
  Set<String> knownKeys,
) => {
  for (final entry in json.entries)
    if (!knownKeys.contains(entry.key)) entry.key: entry.value,
};
```

每个模型的 `toJson()` 先展开 `extraJson`（`...extraJson, 'id': id, ...`），因此额外字段即使经当前应用构建不知道的模型也往返（如新版本添加的字段）。每个模型的已知键集合声明为类旁的顶层 `const _xxxJsonKeys = {...}` 常量（如 `_deviceJsonKeys`、`_networkDeviceJsonKeys`、`_serviceNodeJsonKeys`）。

同步两侧都改变记录 `extraJson` 时，同文件的 `mergeUnknownJsonFields()` 用三方基础逐键调和：

```dart
Map<String, dynamic> mergeUnknownJsonFields({
  required Map<String, dynamic> primary,
  required Map<String, dynamic> secondary,
  Map<String, dynamic>? base,
})
```

对 `primary`/`secondary`/`base` 间每个键：只有 `secondary` 相对 `base` 改变键时其值胜出；否则 `primary` 胜出（包括都变时——primary 是调用方对该合并当作"获胜"记录的那侧）。`jsonValueEquals()` 经规范化（递归键排序）JSON 编码比较值，使映射键顺序绝不造成虚假"已变"检测。每个模型自己的 `mergeUnknownFieldsFrom(other, {base})` 方法（如 `Device.mergeUnknownFieldsFrom`、`ServiceNode.mergeUnknownFieldsFrom`）调用此辅助并递归进嵌套模型（如 `Device` 合并 `cpu`、`gpu`、每个 `storage` 槽按索引、`purchasePrice`、`soldPrice` 和每个 `recurringCosts` 条目）。这如何插入完整记录合并见 [三方合并](algorithms/three-way-merge.md)。

## 捆绑设备模板（`assets/presets/device_templates.json`）

随应用打包的只读资源，由 `PresetService.loadTemplates()` 加载，并交由 `DeviceTemplate.fromJson` 解析。
与上面各持久化格式不同，它从不参与同步，用户也无法编辑；要改动目录内容必须更新应用。

注意形态上的不对称：`cpus.json`、`gpus.json` 和 `brands.json` 都把数组包在一个对象里（`{"cpus": [...]}`），
而本文件是一个**裸数组**。

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | Yes | 显示名称；必须唯一，文件按其小写形式排序。 |
| `category` | string | Yes | `DeviceCategory` 取值之一。未知取值会静默退化为 `other`。 |
| `brand` | string | No | |
| `model` | string | No | |
| `cpu` | string **或** object | No | 两种形态见下。 |
| `gpu` | string | No | 只读取字符串形态。 |
| `ram` | string | No | 例如 `"12 GB"`。 |
| `storage` | array | No | 一个或多个容量；每项为字符串，或带 `capacity` 的对象。 |
| `screenSize` | string | No | 例如 `"16.2\""`。 |
| `screenResolutionW` / `screenResolutionH` | integer | No | |
| `battery` | string | No | 例如 `"100 Wh"` 或 `"4800 mAh"`。 |
| `os` | string | No | |
| `releaseDate` | string | No | ISO-8601；用 `DateTime.parse` 解析。 |

多数条目使用的普通形态：

```json
{
  "name": "MacBook Pro 16\" (M4 Pro)",
  "category": "laptop",
  "brand": "Apple",
  "cpu": "Apple M4 Pro",
  "storage": ["512 GB", "1 TB", "2 TB", "4 TB"]
}
```

VPS 条目使用的对象形态，用于承载那些有意不收入 `cpus.json` 的芯片的详细信息：

```json
{
  "name": "Hetzner CX22",
  "category": "vps",
  "cpu": { "model": "Intel Xeon", "architecture": "x86_64", "performanceCores": 2 },
  "storage": [{ "capacity": "40 GB", "type": "ssd" }]
}
```

`DeviceTemplate` 两者都会保留：`cpu` 存放型号字符串，而使用对象形态时 `cpuDetail` 存放完整的 `CpuInfo`。
`toDevice()` 的优先顺序是：先 `cpuDetail`，再 `cpuPresets` 中的精确匹配，最后才是裸型号字符串。

**新增设备：** 追加条目，运行 `dart run tool/sort_templates.dart` 恢复排序，再运行
`dart run tool/validate_json.dart`。校验器会检查必填字段、类型、类别枚举、重名以及排序顺序——未排序或格式错误
的文件会在这里失败，而不是到应用里才出问题。

## UTC `modifiedAt`

每个带 `modifiedAt` 字段的模型在其构造函数和 `copyWith()` 中默认 `DateTime.now().toUtc()`，并经 `.toIso8601String()` 序列化。不同时区设备间同步冲突检测正确工作需要（见 [架构 — 核心架构规则](architecture.md#core-architecture-rules)）。`NetworkDevice` 是唯一完全无 `modifiedAt` 的模型，按设计（见上面）。

## 持久化数据清单

（复制自 `AGENTS.md`，上面已验证字段/键名。）

| 数据 | 文件 | 同步 | 合并策略 |
| --- | --- | --- | --- |
| 设备 | `device_data.json` | 是 | 按 `id` 和 `modifiedAt` 逐记录 |
| 网络 | `network_data.json` | 是 | 按 `id` 和 `modifiedAt` 逐记录 |
| 网络赋值 | `network_data.json` | 是 | 复合键加内容比较 |
| 数据集 | `dataset_data.json` | 是 | 按 `id` 和 `modifiedAt` 逐记录 |
| 服务与服务路由 | `service_data.json` | 是 | 按 `id` 和 `modifiedAt` 逐记录服务/路由 |
| 图像 | `images/` | 是 | 仅引用文件名比较 |
| 主题、语言区域、备份设置、排序偏好、列表列数偏好、默认货币、汇率设置 | `storage_config.json` | 否 | 本地偏好 |
| WebDAV 凭据 | `webdav_config.json` | 否 | 仅本地机密/配置 |
| 同步基础快照 | `.sync_base/*.json` | 否 | 本地合并跟踪 |
| 备份 | `backups/backup_*.json` | 否 | 本地恢复；v2 捆绑引用去重图像 blob |
| 备份图像 blob | `backups/blobs/` | 否 | 内容寻址（`sha256`），跨备份共享，引用计数 GC |
| 汇率缓存 | `exchange_rates.json` | 否 | 本地缓存/回退数据 |

默认应用数据目录是桌面 `Documents/MyDevice` 或移动平台应用文档目录。自定义存储路径存储在 `storage_config.json`；更改路径迁移数据文件、备份和图像（见 [架构 — 核心架构规则](architecture.md#core-architecture-rules)、`DeviceStorage.getAppDir()`）。

- **`storage_config.json`** — 本地、不同步偏好（主题、语言区域、备份设置、排序偏好、默认货币、汇率设置、自定义存储路径、托盘/最小化/关闭到托盘标志、本地 API 端口/凭据，以及四个列表列数偏好 `deviceListColumns`、`networkListColumns`、`dataSetListColumns` 和 `serviceListColumns`——钉住时为 1–4 的整数，自动时缺席；见[自适应布局](adaptive-layout.md#多少列)）。
- **`webdav_config.json`** — 仅本地 WebDAV 凭据/配置；绝不同步。
- **`.sync_base/`** — 上次成功同步的逐数据文件基础快照（`device_data.json`、`network_data.json`、`dataset_data.json`、`service_data.json`），用于三方合并；也持有 `upload_lock.json`，用于下次启动检测中断上传的进行中上传本地记录。见 [WebDAV 同步](sync.md)。
- **`backups/`** — 完整 v2 捆绑格式和 blob 存储布局见 [备份与恢复](backup-restore.md)。

## 交叉引用规则

- 删除设备必须移除相关网络赋值、数据集存储链接、服务记录和服务路由引用。
- 退役或出售设备也应把它从赋值/链接和选择器中移除（见 [设备](features/devices.md)）。
- 删除网络在 `NetworkStorage.deleteNetwork()` 中过滤赋值。
- 删除数据集删除其包含的存储链接。
- **已知限制：** 同步合并当前在合并后不运行完整交叉引用验证（见 [WebDAV 同步 — 已知限制](sync.md#known-limitation)）。
