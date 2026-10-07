# 数据格式

P3 公共资料实现与适配见 [shared-ui.md](shared-ui.md)，格式和模块顺序保持不变。

本页文档化每个持久化模型、`extraJson` 未知字段保留模式和完整持久化数据清单。这些文件在磁盘上的位置见 [架构](architecture.md)，如何跨设备合并见 [WebDAV 同步](sync.md)。

所示所有字段都是从 `lib/features/*/models/*.dart` 当前源码读取的实际构造函数/`toJson()`/`fromJson()` 字段，不是通用 Flutter 数据模型猜测。

## 设备（`lib/features/devices/models/device.dart`） <a id="device-libfeaturesdevicesmodelsdevicedart"></a>

### 多 GPU 和显示器（1.9.0）

`gpus` 和 `displays` 是具有稳定条目 ID 的有序列表。GPU 条目包含
`model`、`architecture`、`kind`（integrated/discrete/external/unspecified）和 `notes`。
显示器条目包含 `name`、`role`（builtIn/inner/outer/external/unspecified）、
`screenSize`、`screenResolutionW`、`screenResolutionH`、`refreshRate` 和 `notes`。
两者保留未知字段。列表优先，即使列表显式为空；缺少列表时将旧 GPU/屏幕字段读为
一个条目。第一项投影至旧字段供旧版读取。旧版保留列表，但无法编辑列表。
保存空列表时省略列表及其旧字段，防止删除的规格重新出现。
每块屏幕独立计算 PPI。模板资源接受相同列表。

`Device` 字段：

- **身份：** `id`（UUID v4，省略时生成）、`name`。
- **类别：** `category`（`DeviceCategory`：`desktop`、`laptop`、`phone`、`tablet`、`headphone`、`watch`、`router`、`gameConsole`、`vps`、`devBoard`、`other`）、`emoji`、`imagePath`、`templateImage`、`brand`、`model`、`serialNumber`。`templateImage`（自 1.6.1 起，可选，为 null 时省略）是用户手选的内置缩略图，写法与模板的 `image` 完全相同（`assets/device_images/<file>.png`）。旧版构建经 `extraJson` 保留它，并回退到自动匹配。
- **CPU/GPU：** `cpu`（`CpuInfo`：`model`、`architecture`、`frequency`、`performanceCores`、`efficiencyCores`、`threads`、`cache`，加 `extraJson`）、`gpu`（`GpuInfo`：`model`、`architecture`，加 `extraJson`）。
- **RAM：** `ram`（自由文本大小字符串）、`ramType`（`RamType`：`ddr3`、`lpddr3`、`ddr4`、`lpddr4`、`lpddr4x`、`ddr5`、`lpddr5`、`lpddr5x`、`lpddr6`，各带 `'LPDDR5X'` 风格的 `displayName` getter）。
- **存储：** `storage`（`List<StorageInfo>`；每个 `StorageInfo` 有 `capacity`、`type`（`StorageType`：`ssd`、`sdCard`、`hdd`）、`interface_`（`StorageInterface`：`m2Nvme`、`sata25`、`m2Sata`、`usb`）、`serialNumber`、`brand`、`status`（`StorageHealth`：`ok`、`failed`、`offline`；自 1.8.2 起，仅在不为 `ok` 时写入）、`statusNote`（自 1.8.2 起），加 `extraJson`）。`StorageInfo.fromJson` 为向后兼容也接受遗留普通字符串格式（如 `"512 GB"`）；它不认识的 `status` 值读作 `ok` 并保留在 `extraJson` 中，因此较新构建写入的值在保存后依然存在。
- **RAID 阵列**（自 1.8.2 起）：`storageArrays`（`List<StorageArray>`，为空时省略）；每个有 `id`（UUID，稳定——数据集链接到它）、`name`（为空时省略）、`level`（`RaidLevel`：`raid0`、`raid1`、`raid5`、`raid6`、`raid10`、`raidz1`、`raidz2`、`raidz3`、`jbod`、`other`）、`memberIndices`（`List<int>`，指向 `storage` 的索引），加 `extraJson`。一块硬盘最多属于一个阵列（由编辑器保证）。`Device.mergeUnknownFieldsFrom` 按 `id` 合并阵列的未知字段。旧构建通过 `extraJson` 保留整个 `storageArrays` 键，以及每个存储条目中的 `status`/`statusNote`。
- **显示/电池/操作系统：** `screenSize`、`screenResolutionW`、`screenResolutionH`、`battery`、`os`。派生 `ppi` getter 从分辨率和解析屏幕对角线计算像素密度。
- **位置：** `locationName`、`latitude`、`longitude`（由 [地图](features/map.md) 使用）。
- **生命周期/财务**（`v0.4.1` 添加）：
  - `purchaseDate`、`releaseDate`、`acquisitionType`（`DeviceAcquisitionType`：`purchased`、`leased`、`purchasedWithSubscription`、`other`）。
  - `isRetired`、`retiredDate`；`isSold`、`soldPrice`（`MoneyValue`）。
  - `purchasePrice`（`MoneyValue`）。
  - `recurringCosts`（`List<DeviceRecurringCost>`；每个有 `id`、`kind`（`RecurringCostKind`：`lease`、`insurance`、`subscription`、`other`）、`name`、`price`（`MoneyValue`）、`billingCycle`（`BillingCycle`：`monthly`、`yearly`））。
  - 派生 getter：`lifecycleStatus`（`DeviceLifecycleStatus`：`inService`、`retired`、`sold`——售出优先于退役）、`hasFinancialData`、`serviceDays()`、`recurringCostThrough()`、`totalCost()`（`purchasePrice + accrued recurring costs - soldPrice`）、`averageDailyCost()`。
- **其他：** `notes`、`modifiedAt`（UTC `DateTime`）、`extraJson`。

`MoneyValue`（`purchasePrice`、`soldPrice` 和每个循环成本 `price` 使用的货币转换包装）：`amount`、`currency`、`defaultCurrency`、`convertedAmount`、`exchangeRate`、`autoRate`、`rateUpdatedAt`，加 `extraJson`。

## 网络 / NetworkDevice（`lib/features/network/models/network.dart`） <a id="network--networkdevice-libfeaturesnetworkmodelsnetworkdart"></a>

### 配置与 Tailscale CSV（1.9.0）

网络分配可包含 `configFormat`（yaml/toml）、`configText`（EasyTier 配置原文）、
`ipAddresses`（全部叠加网络地址）和 `tailscale`（原始 CSV 列名及字符串值映射，
包括未知列）。`ipAddress` 保留主要 IPv4 地址，无 IPv4 时使用 IPv6。
导入目标为当前网络，先预览设备匹配，先按 Device ID 匹配已有节点，再建议精确
主机名/设备名匹配。空字段表示未提供；快照不代表在线状态。导入不会删除缺失设备，
也不会覆盖已有设备规格。

- **`Network`：** `id`、`name`、`type`（`NetworkType`：`lan`、`tailscale`、`zerotier`、`easytier`、`wireguard`、`other`）、`subnet`、`gateway`、`dnsServers`（`List<String>`）、`notes`、`modifiedAt`、`extraJson`。
- **`NetworkDevice`：** 网络与设备之间的赋值——`networkId`、`deviceId`、`addressMode`（`AddressMode`：`dhcp`、`static_`——序列化为 `"dhcp"` / `"static"`）、`ipAddress`、`hostname`、`isExitNode`、`extraJson`。

`NetworkDevice` **刻意没有 `id` 和 `modifiedAt` 字段**——源码确认：其构造函数只取 `networkId`、`deviceId`、`addressMode`、`ipAddress`、`hostname`、`isExitNode`、`extraJson`。其身份是**复合键** `(networkId, deviceId)`，因为无时间戳，同步合并把*序列化 JSON 内容*对照上次同步基础快照比较而非比较 `modifiedAt` 值。见 [WebDAV 同步 — NetworkDevice 复合键合并](sync.md#networkdevice-composite-key-merge) 和 [三方合并 — mergeAssignments 复合键内容比较合并](algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)。

`NetworkData`（顶层容器）持有 `networks: List<Network>` 和 `assignments: List<NetworkDevice>` 加 `extraJson`。

## DataSet / DataSetStorageLink（`lib/features/datasets/models/dataset.dart`） <a id="dataset--datasetstoragelink-libfeaturesdatasetsmodelsdatasetdart"></a>

- **`DataSet`：** `id`、`name`、`emoji`（解析时缺席默认 `'📁'`）、`storageLinks`（`List<DataSetStorageLink>`）、`modifiedAt`、`extraJson`。
- **`DataSetStorageLink`：** `deviceId` 加 `storageIndices`（`List<int>`）——该设备 `storage` 列表上属于此数据集的存储槽*索引*——以及自 1.8.2 起的 `arrayIds`（`List<String>`，为空时省略）——该设备 `storageArrays` 的 id。列出的每个槽和每个阵列都保存该数据集一份完整、对等的副本——数据集从不拆分到多块存储上，一个阵列无论跨多少块硬盘都只算一份副本——因此可解析的位置数就是它的副本数。位于故障或离线硬盘上、或位于失去的硬盘数超过其级别容错能力的阵列上的副本，仍计入该数，但不计入*可用*副本。旧构建通过 `extraJson` 保留 `arrayIds`，但不计入这些副本。设备存储列表变化时这些索引如何保持有效见 [数据集](features/datasets.md)。

## ServiceNode / ServiceEndpoint / ServiceRoute / ServiceRouteHop（`lib/features/services/models/service.dart`） <a id="servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart"></a>

- **`ServiceNode`：** 设备上的服务实例——`id`、`deviceId`、`name`、`templateId`、`icon`、`kind`（`ServiceKind`：`web`、`reverseProxy`、`tunnel`、`media`、`storage`、`git`、`dev`、`game`、`network`、`database`、`monitoring`、`ai`、`custom`）、`runtime`（`ServiceRuntime`：`docker`、`compose`、`native`、`systemd`、`launchd`、`routerApp`、`container`、`custom`）、`state`（`ServiceState`：`active`、`paused`、`deprecated`、`unknown`）、`endpoints`（`List<ServiceEndpoint>`）、`tags`、`notes`、`dockerCompose`（纯文本）、`modifiedAt`、`extraJson`。
- **`ServiceEndpoint`：** 手动记录的本地/监听端点——`id`、`label`、`protocol`（`ServiceProtocol`：`http`、`https`、`tcp`、`udp`、`ssh`、`minecraft`、`rtsp`、`vnc`、`custom`）、`transport`（`ServiceTransport`：`tcp`、`udp`、`tcpUdp`）、`bindAddress`、`port`、`portEnd`（端口范围用——不同时 `portText` getter 渲染 `"$port-$portEnd"`，否则 `"$port"`）、`path`、`networkId`、`scope`（`ServiceScope`：`localhost`、`lan`、`vpn`、`public`、`custom`）、`isPrimary`、`notes`、`extraJson`。
- **`ServiceRoute`：** 手动记录的访问路径——`id`、`name`、`sourceServiceId`、`sourceEndpointId`、`hops`（`List<ServiceRouteHop>`）、`finalUrl`（第一/主目标，为向后兼容保留）、`accessLevel`（`ServiceAccessLevel`：`lan`、`vpn`、`authenticated`、`public`、`custom`）、`notes`、`modifiedAt`、`extraJson`。共享相同访问路径的额外分组 URL/域存储在 `extraJson['publicTargets']`（见 [服务与拓扑](features/services-topology.md)）。自 1.5.6 起，路由还可带 `extraJson['accessLane']`，用于固定拓扑绘制该路由时所在的车道（见 [下文](#app-written-extrajson-keys)）。
- **`ServiceRouteHop`：** 路由中的一跳——`id`、`type`（`ServiceRouteHopType`：`origin`、`reverseProxy`、`tunnel`、`portForward`、`publicEndpoint`、`internalEndpoint`、`dns`、`manual`）、可选 `serviceId`/`endpointId`/`deviceId` 回指清单，或自由形式 `label`/`scheme`/`host`/`port`/`path`、`method`（`ServiceRouteMethod`：`caddy`、`nginx`、`traefik`、`frp`、`cloudflareTunnel`、`pangolin`、`tailscaleFunnel`、`routerPortForward`、`direct`、`custom`）、`notes`、`extraJson`。

`ServiceData`（顶层容器）持有 `services: List<ServiceNode>` 和 `routes: List<ServiceRoute>` 加 `extraJson`。

## `extraJson`：未知字段保留 <a id="extrajson-unknown-field-preservation"></a>

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

### 应用写入的 `extraJson` 键 <a id="app-written-extrajson-keys"></a>

有两个 `ServiceRoute` 键由应用自身写入，而不是模型字段。两者都可选且只做增量添加，因此不认识它们的构建会经上述机制保留它们，行为与这两个键出现之前完全相同：

| 键 | 值 | 写入方 | 含义 |
|---|---|---|---|
| `publicTargets` | 字符串列表 | 两个路由编辑器，在路由有多个目标时 | 路由的每个访问目标，第一个等于 `finalUrl`。 |
| `accessLane` | `"local"`、`"vpn"` 或 `"public"` | 引导式访问路径页（总是写入，取自所选的可达范围）；高级编辑器的车道下拉框（选*自动*时再次移除） | 固定拓扑绘制该路由时所在的车道。1.5.6 新增。 |

`serviceAccessLaneForRoute` 先读取 `accessLane`，没有时回退到 1.5.6 之前的推断：公网风格的跳方法（FRP、路由器端口转发、Caddy、Nginx、Traefik、Cloudflare Tunnel、Pangolin）无论访问级别如何都意味着公网；其次，Tailscale Funnel 或 `vpn` 访问级别意味着 VPN；再次，`public` 或 `authenticated` 访问级别意味着公网；其余一律为本地。值缺失或未知就意味着原样沿用该推断，因此旧路由和旧构建会继续把每条路由画在它一贯所在的位置。设立此键是因为该推断无法表达仅限局域网的反向代理（使用分离 DNS 的 Caddy）：单凭它的方法就会被判为公网。

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
| `gpu` | string or object | No | 旧第一块 GPU，缺少 `gpus` 时使用。 |
| `gpus` | array | No | GPU 字符串或对象，含型号、架构、类型和备注。 |
| `displays` | array | No | 独立屏幕对象，含角色、尺寸、分辨率和刷新率。 |
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

可选的 `image` 指向该设备本身的内置缩略图：

```json
{ "name": "iPhone 15 Pro", "category": "phone", "brand": "Apple", "model": "iPhone 15 Pro",
  "image": "assets/device_images/apple-iphone-15-pro-back.png" }
```

缩略图是 256 px 见方、背景透明的 PNG，每个可见像素（alpha > 8）都位于内切圆内，因为每个头像都按该圆裁剪。
缩略图在显示时与设备匹配；只有用户手选的缩略图会作为设备的 `templateImage` 存储。由模板创建的设备也会把模板的 `image` 存在那里（见
[在线搜索与预设](features/online-search-and-presets.md#device-thumbnails)）。

**新增设备：** 追加条目，运行 `dart run tool/sort_templates.dart` 恢复排序，再运行
`dart run tool/validate_json.dart`。校验器会检查必填字段、类型、类别枚举、重名以及排序顺序——未排序或格式错误
的文件会在这里失败，而不是到应用里才出问题。对于 `image`，它还会检查路径、透明四角以及圆内规则。

## UTC `modifiedAt`

每个带 `modifiedAt` 字段的模型在其构造函数和 `copyWith()` 中默认 `DateTime.now().toUtc()`，并经 `.toIso8601String()` 序列化。不同时区设备间同步冲突检测正确工作需要（见 [架构 — 核心架构规则](architecture.md#core-architecture-rules)）。`NetworkDevice` 是唯一完全无 `modifiedAt` 的模型，按设计（见上面）。

## 持久化数据清单 <a id="persisted-data-inventory"></a>

（复制自 `AGENTS.md`，上面已验证字段/键名。）

| 数据 | 文件 | 同步 | 合并策略 |
| --- | --- | --- | --- |
| 设备 | `device_data.json` | 是 | 按 `id` 和 `modifiedAt` 逐记录 |
| 网络 | `network_data.json` | 是 | 按 `id` 和 `modifiedAt` 逐记录 |
| 网络分配 | `network_data.json` | 是 | 复合键加内容比较 |
| 数据集 | `dataset_data.json` | 是 | 按 `id` 和 `modifiedAt` 逐记录 |
| 服务与服务路由 | `service_data.json` | 是 | 按 `id` 和 `modifiedAt` 逐记录服务/路由 |
| 个人资料（名称和头像） | `profile.json` | 是 | 自 1.7.0 起：每个字段按各自的 `displayNameUpdatedAt` / `avatarUpdatedAt` 后写者胜；从不冲突 |
| 图像和头像 | `images/` | 是 | 仅引用文件名比较；包含个人资料头像 |
| 主题、界面风格（`uiStyle`）、导航栏位置（`navPlacement`、`navRailRight`）、语言区域、备份设置、排序偏好、数据集分组（`datasetGroupMode`）、首页状态筛选、列表列数偏好、默认货币、汇率设置、端侧 AI 开关、自定义存储路径 | `storage_config.json`（默认文件夹） | 否 | 本地偏好 |
| WebDAV 凭据 | `webdav_config.json` | 否 | 仅本地机密/配置 |
| 同步基础快照 | `.sync_base/*.json` | 否 | 本地合并跟踪 |
| 备份 | `backups/backup_*.json` | 否 | 本地恢复；v2 捆绑引用去重图像 blob |
| 备份图像 blob | `backups/blobs/` | 否 | 内容寻址（`sha256`），跨备份共享，引用计数 GC |
| 汇率缓存 | `exchange_rates.json` | 否 | 本地缓存/回退数据 |
| 端侧 AI 洞察 | `ai_insights.json` | 否 | 本设备已生成洞察卡片的缓存（v1.6.0）；从不同步、备份或导出；可重建，因此不可读的文件读作空 |

默认应用数据目录是桌面 `Documents/MyDevice` 或移动平台应用文档目录。自定义存储路径存储在 `storage_config.json`，而它本身总是留在默认文件夹；更改路径会移动存储文件夹中的其他一切——数据文件、备份、图像、`.sync_base/`、`webdav_config.json`、`ai_insights.json`——并报告留下的任何东西（见 [`storage_config.json`](#storage_configjson)、[架构 — 核心架构规则](architecture.md#core-architecture-rules)、`DeviceStorage.getAppDir()`）。

- **`storage_config.json`** — 平台默认文件夹中的唯一文件（见[下文](#storage_configjson)），保存本地、不同步偏好（主题、语言区域、备份设置、排序偏好、数据集列表的分组 `datasetGroupMode`（不分组时缺席；见[下文](#storage_configjson-key-datasetgroupmode)）、首页列表上次的状态筛选 `deviceStatusFilter`（为“全部”时缺席）、默认货币、汇率设置、自定义存储路径、托盘/最小化/关闭到托盘标志、本地 API 端口/凭据，以及四个列表列数偏好 `deviceListColumns`、`networkListColumns`、`dataSetListColumns` 和 `serviceListColumns`——钉住时为 1–4 的整数，自动时缺席；见[自适应布局](adaptive-layout.md#how-many-columns)），以及端侧 AI 开关 `onDeviceAiEnabled` 和 `onDeviceAiPreferFast`（v1.6.0）——只在为 `true` 时写入、关闭时移除，属于本设备，因为是否有模型是设备的属性；见[端侧 AI](on-device-ai.md)）。
- **`webdav_config.json`** — 仅本地 WebDAV 凭据/配置；绝不同步。
- **`.sync_base/`** — 上次成功同步的逐数据文件基础快照（`device_data.json`、`network_data.json`、`dataset_data.json`、`service_data.json`），用于三方合并；也持有 `upload_lock.json`，用于下次启动检测中断上传的进行中上传本地记录。见 [WebDAV 同步](sync.md)。
- **`backups/`** — 完整 v2 捆绑格式和 blob 存储布局见 [备份与恢复](backup-restore.md)。

### `storage_config.json` <a id="storage_configjson"></a>

- **一个文件，位于默认文件夹。** 无论存储路径如何，`storage_config.json` 总是位于平台默认文件夹（桌面上为 `Documents/MyDevice`），因为应用必须先读到自定义路径才知道数据在哪里。它保存每个本地偏好*以及*自定义路径（`storagePath`）。`DeviceStorage.readConfig`/`writeConfig` 以及共享引擎使用的 `DeviceStorageAdapter` 都读写这一个文件，因此移动数据从不会重置或复制偏好。
- **`storagePath` 归 `setStoragePath` 所有。** 偏好写入会把映射中 `storagePath` 下的任何内容替换为当前自定义路径，没有自定义路径时删除该键，因此保存主题或列数选择永远不会移动或丢失数据。
- **收编游离副本（1.5.7）。** 1.5.7 之前，`readConfig`/`writeConfig` 使用当前存储文件夹，而自定义路径位于默认文件夹，因此移动后偏好读作默认值，新偏好写进自定义文件夹里的第二个 `storage_config.json`。现在对某个自定义路径的首次配置访问会检查该文件夹：那里的游离 `storage_config.json` 被合并进默认文件——它的键较新，因此胜出，`storagePath` 除外——然后被删除。无法读取或解析的游离文件保持不动。
- **更改存储路径。** 旧文件夹中除顶层 `storage_config.json` 外的一切都移到新文件夹（见 [`DeviceStorage.setStoragePath`](functions/features/devices/services/device_storage.md#setstoragepath)）。目标位置已存在的文件胜出，其源副本留在原处。留在旧文件夹中的每个文件——复制失败的，或因目标已有同名文件而被跳过的——都会被报告回来，设置页连同旧文件夹路径一起列出它们，因为应用在新位置看不到它们。

## `profile.json` <a id="profilejson"></a>

`profile.json`（1.7.0）是第五个已注册的模块，因此它同样会同步、会备份、包含在 ZIP 导出中，并有自己的 `.sync_base/profile.json`。它保存用户的名称和头像（见 [`features/profile.md`](features/profile.md)）：

```json
{
  "version": 1,
  "displayName": "Yuan",
  "displayNameUpdatedAt": "2026-10-01T14:06:42.530801Z",
  "avatar": "images/avatar_2953ac52-337e-4271-a8e1-bcd97ee416ba.jpg",
  "avatarUpdatedAt": "2026-10-01T14:08:59.163627Z"
}
```

- `displayName` / `displayNameUpdatedAt`——名称及其最后更改时间（UTC）。保存时会去除首尾空白；清除它会写入 `"displayName": null` 和新的时间戳。
- `avatar` / `avatarUpdatedAt`——相对于数据目录的头像路径（`images/avatar_<uuid>.jpg`，512 x 512 的 JPEG）及其最后更改时间（UTC）。被移除的头像写作显式的 `"avatar": null` 加时间戳，因此移除也会同步。
- 字段只有在有时间戳后才会写出；没有时间戳的字段表示“从未设置”，合并时总是输给设置过的一侧。每个字段独立地按后写者胜合并——见 [`sync.md`](sync.md#the-profile-file)。未知键会保留。`version` 为 `1`。
- 头像图片是 `images/` 中的普通文件，因此经由引擎的仅引用添加式图像阶段同步（该模块通过 `profileReferencedImages` 报告它），并与其他图像一起备份和导出。每个新头像都使用全新的文件名，因为图像同步从不覆盖已存在的文件；被替换的头像只在本地删除，因此旧头像会留在 WebDAV 服务器和其他设备上。
- 1.7.0 之前的构建从不请求 `profile.json`，因此它不会影响它们。

### `storage_config.json` 键 `uiStyle`

自 1.7.0 起，`storage_config.json` 可能包含 `"uiStyle": "material3"`。只存储非默认的 Material 3 风格；默认的 Expressive 风格（悬浮导航栏、更圆的形状、更粗的标题）就是没有这个键。本地偏好，从不同步。

### `storage_config.json` 键 `navPlacement`、`navRailRight`

自 1.7.1 起，`storage_config.json` 可能包含两个决定导航位置的可选键。每个都**仅在与默认值不同时写入**，否则移除，因此默认安装的配置里一个都没有。本地偏好，从不同步。

| 键 | 取值 | 含义 | 适用范围 |
|---|---|---|---|
| `navPlacement` | `"sideOnWide"`、`"side"` | 缺省 = 任何窗口都用底栏（默认）。`"sideOnWide"` = 宽窗口用侧边导航栏，窄窗口用底栏。`"side"` = 任何窗口都用侧边导航栏，含手机（不推荐）。未知值按默认读。 | 两种风格 |
| `navRailRight` | `true` | 侧边导航栏在右侧而不是左侧。 | 两种风格，只要显示导航栏 |

### `storage_config.json` 键 `datasetGroupMode` <a id="storage_configjson-key-datasetgroupmode"></a>

自 1.8.0 起，`storage_config.json` 可能包含 `"datasetGroupMode"`：`"device"` 或 `"storage"`——数据集列表如何对其列表块分组。仅在开启分组时写入，选择*不分组*时移除，因此默认安装的配置里没有这个键；未知值按不分组读。本地偏好，从不同步。数据集文件本身不变：数据集的副本数由其现有的 `storageLinks` 推导而来。

## `ai_insights.json` <a id="ai_insightsjson"></a>

端侧 AI 洞察缓存（v1.6.0），通过 `AiInsightsCache` 以其自己的写队列原子写入存储文件夹（`DeviceStorage.getAppDir()`），因此会随自定义存储路径一起移动。它**不是**已登记的数据模块：从不同步，从不出现在备份捆绑或 ZIP 导出中，也没有保留模式。与数据文件不同，不可读或格式错误的文件读作空——它是缓存，丢失它的代价只是每张卡片重新生成一次。设置中的*清除已生成的洞察*会删除它。

```json
{
  "version": 1,
  "insights": {
    "deviceFinance": {
      "fingerprint": "3f9a…",
      "generatedAt": "2026-09-28T01:02:03.000Z",
      "language": "zh_CN",
      "lines": ["…", "…", "…", "…"],
      "model": "stable/full · nano-v3",
      "promptVersion": 1,
      "slots": ["costSummary", "costAdvice", "recurringSummary", "reviewDevice"],
      "status": "ok"
    }
  }
}
```

- `insights` 下的键是 `deviceFinance` 和 `services`。未知键和格式错误的条目在读取时丢弃。
- `fingerprint` 是 [on-device-ai.md](on-device-ai.md#cache-and-fingerprint) 中描述的十六进制 SHA-256；卡片只在它变化时重新生成。
- `lines` 按槽位顺序保存经过校验的句子，`slots` 保存每句对应的槽位 id，因此即使前面的某个槽位被丢弃，卡片也能把各行归到对应的分区标题下。
- `status` 为 `ok`，或在模型拒绝（`guardrail`）或无法使用该语言写作时为 `skipped`；跳过的条目没有行，在指纹变化之前不会重试。
- `generatedAt` 是 UTC。

## 交叉引用规则 <a id="cross-reference-rules"></a>

- 删除设备必须移除相关网络分配、数据集存储链接、服务记录和服务路由引用。
- 退役或出售设备也应把它从赋值/链接和选择器中移除（见 [设备](features/devices.md)）。
- 删除网络在 `NetworkStorage.deleteNetwork()` 中过滤赋值。
- 删除数据集删除其包含的存储链接。
- **已知限制：** 同步合并当前在合并后不运行完整交叉引用验证（见 [WebDAV 同步 — 已知限制](sync.md#known-limitation)）。

## 写入安全（自 1.6.2 起）

数据文件（`device_data.json`、`network_data.json`、`dataset_data.json`、`service_data.json`，自 1.7.0 起还有 `profile.json`）、`storage_config.json` 和 `exchange_rates.json` 都是原子替换的：新内容先写入同文件夹的 `<name>.tmp-<微秒>` 文件，再重命名覆盖目标（若 Windows 报告目标被锁定则短暂重试）。数据存储还按文件路径串行化其读-改-写操作。磁盘上的 JSON 形态以及同步/备份格式不变；游离的 `*.tmp-*` 文件只可能在崩溃后残留，可安全删除。

## AI 来源与 WebDAV 隐私

MyApps-AI v0.5.2 显式拆分运行时、平台、模型、本地 UI 和 llama.cpp 包。设置使用统一分区骨架。全局来源选择保存在设备本地（`aiSourceSelection`），默认系统 AI，不会自动回退到在线来源。Qwen3.5 0.8B/2B Q4_K_M 与 Gemma 4 E2B Q4_0 在 CPU 上运行。下载仅由明确操作触发，使用固定地址与 SHA-256，保存在 `ai_models/`，不进入数据模块、同步、备份或 ZIP。模型租约避免使用中移除文件。切换来源取消旧任务并释放模型资源。MyNihongo 的系统校对保持独立。

WebDAV 第 1 版提醒必须在每个设备上确认后，才能测试连接、手动/强制同步或后台同步。记录保存在设备本地 storage_config.json。已有配置保持不变，同步暂停时 WebDAV 页面显示查看提醒横幅。拒绝不保存配置、不发出请求。JSON/图片没有应用层加密；HTTPS 加密传输，HTTP 不加密。线格式、锁和冲突策略保持不变。
