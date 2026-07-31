# lib/features/network/models/network.dart

[网络](../../../../features/networks.md) 的模型来源。定义 `NetworkType`/`AddressMode`（两个序列化枚举）、`Network`（局域网/VPN 叠加网定义）、`NetworkDevice`（设备在网络中的成员/赋值）和由 [`../services/network_storage.md`](../services/network_storage.md) 持久化的顶层 `NetworkData` 容器。这里每个模型都遵循应用标准形态——普通/const 构造函数、`toJson`/`fromJson` 和构建在泛型 [`json_preservation.md`](../../../shared/utils/json_preservation.md) 辅助上的 `mergeUnknownFieldsFrom`——带一个刻意例外：`NetworkDevice` 完全**无 `id` 和 `modifiedAt`**。原因见 [网络 — 复合键身份及其原因](../../../../features/networks.md#composite-key-identity--and-why)（`(networkId, deviceId)` 对已是唯一键，缺失时间戳正是迫使 `sync_merge.dart` 的 `mergeAssignments` 做[内容比较合并](../../../../algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)而非每个其他模型使用的时间戳基础 `mergeRecords<T>` 的东西）。穷举持久化字段参考见 [数据格式 — 网络 / NetworkDevice](../../../../data-formats.md#network--networkdevice-libfeaturesnetworkmodelsnetworkdart)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `jsonValue` | getter（`NetworkType`） | B | 返回序列化枚举名。 |
| [`NetworkType.fromJson`](#networktype-fromjson) | 静态方法 | A | 解析 `NetworkType`，无匹配默认 `other`。 |
| [`jsonValue`](#jsonvalue) | getter（`AddressMode`） | A | 返回序列化地址模式字符串（`"dhcp"`/`"static"`）。 |
| [`AddressMode.fromJson`](#addressmode-fromjson) | 静态方法 | A | 解析 `AddressMode`，默认 `dhcp`。 |
| [`Network`](#network-new) | 构造函数 | A | 创建 `Network` 实例（默认新鲜 `id`/`modifiedAt`）。 |
| [`copyWith`](#network-copywith) | 方法（`Network`） | A | 创建带所选字段替换或清除的副本。 |
| [`toJson`](#network-tojson) | 方法（`Network`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`Network.fromJson`](#network-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `Network`。 |
| [`mergeUnknownFieldsFrom`](#network-mergeunknownfieldsfrom) | 方法（`Network`） | A | 从另一个 `Network` 三方合并未知 JSON 字段。 |
| [`NetworkDevice`](#networkdevice-new) | 构造函数 | A | 创建 `NetworkDevice` 实例（无 `id`/`modifiedAt`）。 |
| [`copyWith`](#networkdevice-copywith) | 方法（`NetworkDevice`） | A | 创建带所选字段替换或清除的副本。 |
| [`toJson`](#networkdevice-tojson) | 方法（`NetworkDevice`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`NetworkDevice.fromJson`](#networkdevice-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `NetworkDevice`。 |
| [`mergeUnknownFieldsFrom`](#networkdevice-mergeunknownfieldsfrom) | 方法（`NetworkDevice`） | A | 从另一个 `NetworkDevice` 三方合并未知 JSON 字段。 |
| [`NetworkData`](#networkdata-new) | 构造函数 | A | 创建 `NetworkData` 实例。 |
| [`toJson`](#networkdata-tojson) | 方法（`NetworkData`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`NetworkData.fromJson`](#networkdata-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `NetworkData`。 |

行数（17）与 `grep -c 'Purpose:' network.dart`（17）精确匹配。

## 文档

### `static NetworkType fromJson(String value)` <a id="networktype-fromjson"></a>
- **种类：** 枚举 `NetworkType` 的静态方法。
- **来源：** `lib/features/network/models/network.dart`（第 48 行）。
- **用途：** 从其序列化名解析 `NetworkType`，任何无法识别值默认 `other`。
- **输入：** `value`。
- **返回：** `NetworkType` — 绝不 `null`。
- **副作用：** 无。
- **算法：** `NetworkType.values.firstWhere((e) => e.name == value, orElse: () => NetworkType.other)`。
- **用法：**
  ```dart
  type: NetworkType.fromJson(json['type'] as String),
  ```
  （来自 [`Network.fromJson`](#network-fromjson)）
- **备注：** 无法识别或未来 `type` 字符串降级为 `other` 而非抛，因此新版应用创建的、此构建不知道类型的网络仍无崩溃往返。

### `String get jsonValue`（AddressMode） <a id="jsonvalue"></a>
- **种类：** 枚举 `AddressMode` 的 getter。
- **来源：** `lib/features/network/models/network.dart`（第 64 行）。
- **用途：** 返回此地址模式的序列化字符串——`"dhcp"` 或 `"static"`。
- **输入：** 无。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** `switch (this) { AddressMode.dhcp => 'dhcp', AddressMode.static_ => 'static' }`。
- **用法：**
  ```dart
  'addressMode': addressMode.jsonValue,
  ```
  （来自 [`NetworkDevice.toJson`](#networkdevice-tojson)）
- **备注：** 与 `NetworkType.jsonValue`（普通 `=> name`）不同，此 getter 不能直接用 `name`——枚举值拼写为 `static_`（尾下划线，为躲 `static` 关键词）但持久化 JSON 字符串必须是无关键词的 `"static"`。相同怪癖从数据格式侧描述见 [网络](../../../../features/networks.md)。

### `static AddressMode fromJson(String value)` <a id="addressmode-fromjson"></a>
- **种类：** 枚举 `AddressMode` 的静态方法。
- **来源：** `lib/features/network/models/network.dart`（第 74 行）。
- **用途：** 从其序列化字符串解析 `AddressMode`，除恰好 `"static"` 外任何值默认 `dhcp`。
- **输入：** `value`。
- **返回：** `AddressMode` — 绝不 `null`。
- **副作用：** 无。
- **算法：** `switch (value) { 'static' => AddressMode.static_, _ => AddressMode.dhcp }`。
- **用法：**
  ```dart
  addressMode: AddressMode.fromJson(json['addressMode'] as String? ?? 'dhcp'),
  ```
  （来自 [`NetworkDevice.fromJson`](#networkdevice-fromjson)）
- **备注：** `dhcp` 是"缺席"和"无法识别"两者的回退——匹配构造函数自己的默认（`this.addressMode = AddressMode.dhcp`）。

### `Network({String? id, required this.name, required this.type, this.subnet, this.gateway, this.dnsServers = const [], this.notes, DateTime? modifiedAt, this.extraJson = const {}})` <a id="network-new"></a>
- **种类：** `Network` 的构造函数。
- **来源：** `lib/features/network/models/network.dart`（第 97 行）。
- **用途：** 创建网络记录，两者都未提供时生成新鲜 UUID `id` 和 UTC `modifiedAt`。
- **输入：** `name`、`type` 必填；`subnet`/`gateway`/`notes` 可选；`dnsServers` 默认 `[]`；`id`/`modifiedAt` 省略时自动生成。
- **返回：** 新 `Network`。
- **副作用：** 无（除 `Uuid().v4()`/`DateTime.now()`——无 IO）。
- **算法：** 初始化器列表中 `id = id ?? const Uuid().v4()`、`modifiedAt = modifiedAt ?? DateTime.now().toUtc()`；剩余字段普通赋值。
- **用法：**
  ```dart
  final network = Network(
    id: widget.network?.id,
    name: _nameCtrl.text.trim(),
    type: _type,
    subnet: _nonEmpty(_subnetCtrl.text),
    gateway: _nonEmpty(_gatewayCtrl.text),
    dnsServers: dnsServers,
    notes: _nonEmpty(_notesCtrl.text),
    extraJson: widget.network?.extraJson ?? const {},
  );
  ```
  （来自 [`network_edit_page.md`](../views/network_edit_page.md) 的保存处理器；传 `widget.network?.id` 编辑时保留相同 `id` 而非铸造新的）
- **备注：** 除非显式覆盖 `modifiedAt` 总是刷新为"现在"——这是同步期间 `mergeRecords<Network>` 用来检测哪侧变化的时间戳（见 [三方合并](../../../../algorithms/three-way-merge.md)）。这是普通、时间戳基础合并路径——不同于下面 `NetworkDevice`，`Network` 有真实 `id`/`modifiedAt` 对。

### `Network copyWith({String? name, NetworkType? type, String? subnet, String? gateway, List<String>? dnsServers, String? notes, DateTime? modifiedAt, bool clearSubnet = false, bool clearGateway = false, bool clearNotes = false})` <a id="network-copywith"></a>
- **种类：** `Network` 的方法。
- **来源：** `lib/features/network/models/network.dart`（第 115 行）。
- **用途：** 创建此网络的带所选字段替换副本，并可选择把 `subnet`/`gateway`/`notes` 显式清除回 `null`。
- **输入：** 任何要覆盖字段；`clearSubnet`/`clearGateway`/`clearNotes` — 显式清除标志，因为否则字段传 `null` 与"不改它"无法区分。
- **返回：** 新 `Network`——`id` 总是从 `this` 保留；`modifiedAt` 未显式传入时默认"现在"。
- **副作用：** 无。
- **算法：** 对每个可空字段 `clearX ? null : (x ?? this.x)`——清除标志优先于新值和既有值两者。
- **用法：** 当前代码库任何地方不调用（`network_edit_page.dart` 改直接构造新鲜 `Network(...)`——见上面 [`Network`](#network-new)）；为与应用其他模型对等提供，可供未来调用方。
- **备注：** `extraJson` 总是从 `this` 原样带过——`copyWith` 不能改变或清除未知字段；只有 [`mergeUnknownFieldsFrom`](#network-mergeunknownfieldsfrom) 能。

### `Map<String, dynamic> toJson()` <a id="network-tojson"></a>
- **种类：** `Network` 的方法。
- **来源：** `lib/features/network/models/network.dart`（第 145 行）。
- **用途：** 把此网络序列化为持久化在 `network_data.json` 的 `networks` 数组内的 JSON。
- **输入：** 无。
- **返回：** `Map<String, dynamic>` — 先展开 `extraJson`，然后 `id`/`name`/`type` 总是、`subnet`/`gateway`/`notes`/`dnsServers` 只在已设/非空时、`modifiedAt` 为 ISO-8601。
- **副作用：** 无。
- **算法：** 对每个可选字段 `{...extraJson, if (field-present) 'field': field, ...}`。
- **用法：** 被 [`NetworkData.toJson`](#networkdata-tojson) 为 `networks` 每个条目调用，也被 [`mergeUnknownFieldsFrom`](#network-mergeunknownfieldsfrom) 调用。
- **备注：** 在已知字段前展开 `extraJson` 意味着无法识别键碰巧与已知键名碰撞时已知字段总是胜出。

### `factory Network.fromJson(Map<String, dynamic> json)` <a id="network-fromjson"></a>
- **种类：** `Network` 的工厂构造函数。
- **来源：** `lib/features/network/models/network.dart`（第 162 行）。
- **用途：** 从 JSON 解析 `Network`。
- **输入：** `json`。
- **返回：** 新 `Network`；`extraJson` 持有不在 `_networkJsonKeys` 的每个键。
- **副作用：** 无。
- **算法：** 对每个已知键直接字段提取；`type` 经 [`NetworkType.fromJson`](#networktype-fromjson)；`dnsServers` 把 `List<dynamic>` 映射为 `List<String>` 或缺席默认 `[]`；`modifiedAt` 经 `DateTime.parse`。
- **用法：** 被 [`NetworkData.fromJson`](#networkdata-fromjson) 为 `json['networks']` 每个条目调用。
- **备注：** 无。

### `Network mergeUnknownFieldsFrom(Network other, {Network? base})` <a id="network-mergeunknownfieldsfrom"></a>
- **种类：** `Network` 的方法。
- **来源：** `lib/features/network/models/network.dart`（第 181 行）。
- **用途：** 三方合并此 `Network` 的未知 JSON 字段与另一个的，使无法识别键像已知字段一样经受同步合并。
- **输入：** `other` — 另一侧（`this` 为本地时典型为远程）；可选 `base` — 上次同步快照。
- **返回：** 新 `Network`——与 `this` 相同已知字段、`extraJson` 被合并结果替换。
- **副作用：** 无。
- **算法：** 经 `Network.fromJson` 重新解析 `{...toJson(), ...mergeUnknownJsonFields(primary: extraJson, secondary: other.extraJson, base: base?.extraJson)}`——底层逐键三方合并规则见 [`mergeUnknownJsonFields`](../../../shared/utils/json_preservation.md)。
- **用法：** 被 `sync_merge.dart` 的 `mergeRecords<Network>` 与已知字段合并一起调用（见 [三方合并](../../../../algorithms/three-way-merge.md)）。
- **备注：** 这里只合并 `extraJson`——已知字段（`name`、`type` 等）总是来自 `this`（primary 侧）。

### `const NetworkDevice({required this.networkId, required this.deviceId, this.addressMode = AddressMode.dhcp, this.ipAddress, this.hostname, this.isExitNode = false, this.extraJson = const {}})` <a id="networkdevice-new"></a>
- **种类：** `NetworkDevice` 的构造函数。
- **来源：** `lib/features/network/models/network.dart`（第 208 行）。
- **用途：** 创建设备在网络中的成员/赋值记录——哪个设备、其地址模式、可选静态 IP/主机名，以及它是否充当网络退出节点。
- **输入：** `networkId`、`deviceId` 必填；`addressMode` 默认 `dhcp`；`ipAddress`/`hostname` 可选；`isExitNode` 默认 `false`。
- **返回：** 新 `NetworkDevice`。
- **副作用：** 无。
- **算法：** 带默认的平凡字段赋值——注意此类**完全无 `id` 和 `modifiedAt`** 字段。
- **用法：**
  ```dart
  NetworkDevice(networkId: widget.networkId, deviceId: device.id),
  ```
  （来自 [`network_detail_page.md`](../views/network_detail_page.md) 的 `_addDevice`，作为传给赋值配置对话框的种子）
- **备注：** `(networkId, deviceId)` 对是记录自然唯一键——合成 `id` 为何这里冗余、缺失 `modifiedAt` 为何迫使同步对此单模型用内容比较（[`mergeAssignments`](../../../../algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)）而非时间戳比较，见 [网络 — 复合键身份及其原因](../../../../features/networks.md#composite-key-identity--and-why)。

### `NetworkDevice copyWith({AddressMode? addressMode, String? ipAddress, String? hostname, bool? isExitNode, bool clearIpAddress = false, bool clearHostname = false})` <a id="networkdevice-copywith"></a>
- **种类：** `NetworkDevice` 的方法。
- **来源：** `lib/features/network/models/network.dart`（第 223 行）。
- **用途：** 创建此赋值的带所选字段替换副本，并可选择把 `ipAddress`/`hostname` 显式清除回 `null`。
- **输入：** 任何要覆盖字段；`clearIpAddress`/`clearHostname` — 显式清除标志。`networkId`/`deviceId` 不可改变（无它们的参数——它们总是来自 `this`，因为改变任一都会改变记录身份）。
- **返回：** 新 `NetworkDevice`。
- **副作用：** 无。
- **算法：** 与 [`Network.copyWith`](#network-copywith) 相同 `clearX ? null : (x ?? this.x)` 形态。
- **用法：** 当前代码库任何地方不调用（`network_detail_page.dart` 在 `_showAssignmentDialog` 改直接构造新鲜 `NetworkDevice(...)`）；为与应用其他模型对等提供。
- **备注：** 因为 `networkId`/`deviceId` 这里不是参数，`copyWith` 绝不可能意外把 `NetworkDevice` 重新键控到不同网络/设备对。

### `Map<String, dynamic> toJson()` <a id="networkdevice-tojson"></a>
- **种类：** `NetworkDevice` 的方法。
- **来源：** `lib/features/network/models/network.dart`（第 247 行）。
- **用途：** 把此赋值序列化为持久化在 `network_data.json` 的 `assignments` 数组内的 JSON。
- **输入：** 无。
- **返回：** `Map<String, dynamic>` — 先展开 `extraJson`，然后 `networkId`/`deviceId`/`addressMode` 总是、`ipAddress`/`hostname` 只在已设时、`isExitNode` 只在 `true` 时（`false` 时完全省略）。
- **副作用：** 无。
- **算法：** 与 [`Network.toJson`](#network-tojson) 相同展开-然后-已知字段形态；`addressMode` 经 [`jsonValue`](#jsonvalue) 序列化。
- **用法：** 被 [`NetworkData.toJson`](#networkdata-tojson) 为 `assignments` 每个条目调用，也被 [`mergeUnknownFieldsFrom`](#networkdevice-mergeunknownfieldsfrom) 调用。
- **备注：** 未设时 `isExitNode` 被省略（而非写 `false`）保持持久化 JSON 紧凑；[`fromJson`](#networkdevice-fromjson) 把缺席键当作与 `false` 相同。

### `factory NetworkDevice.fromJson(Map<String, dynamic> json)` <a id="networkdevice-fromjson"></a>
- **种类：** `NetworkDevice` 的工厂构造函数。
- **来源：** `lib/features/network/models/network.dart`（第 262 行）。
- **用途：** 从 JSON 解析 `NetworkDevice`。
- **输入：** `json`。
- **返回：** 新 `NetworkDevice`；`extraJson` 持有不在 `_networkDeviceJsonKeys` 的每个键。
- **副作用：** 无。
- **算法：** 直接字段提取；`addressMode` 经 [`AddressMode.fromJson`](#addressmode-fromjson)，键缺席时 `'dhcp'` 默认；`isExitNode` 缺席默认 `false`。
- **用法：** 被 [`NetworkData.fromJson`](#networkdata-fromjson) 为 `json['assignments']` 每个条目调用。
- **备注：** 无。

### `NetworkDevice mergeUnknownFieldsFrom(NetworkDevice other, {NetworkDevice? base})` <a id="networkdevice-mergeunknownfieldsfrom"></a>
- **种类：** `NetworkDevice` 的方法。
- **来源：** `lib/features/network/models/network.dart`（第 277 行）。
- **用途：** 三方合并此 `NetworkDevice` 的未知 JSON 字段与另一个的。
- **输入：** `other`；可选 `base`。
- **返回：** 带合并 `extraJson` 的新 `NetworkDevice`。
- **副作用：** 无。
- **算法：** 与 [`Network.mergeUnknownFieldsFrom`](#network-mergeunknownfieldsfrom) 相同形态。
- **用法：** 被 `sync_merge.dart` 的 `mergeAssignments` 与其复合键内容比较合并一起调用（见 [三方合并 — mergeAssignments 复合键内容比较合并](../../../../algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)）。
- **备注：** 只合并 `extraJson`；已知字段仍来自 `this`。这只是*未知字段*合并——*哪侧 `NetworkDevice` 整体胜出*的决定（因为无 `modifiedAt` 可比较）发生在上一层 `mergeAssignments` 本身，不在此方法。

### `const NetworkData({this.networks = const [], this.assignments = const [], this.extraJson = const {}})` <a id="networkdata-new"></a>
- **种类：** `NetworkData` 的构造函数。
- **来源：** `lib/features/network/models/network.dart`（第 303 行）。
- **用途：** 持有完整持久化网络数据集：每个 `Network` 加每个 `NetworkDevice` 赋值。
- **输入：** `networks`、`assignments` 都默认 `[]`。
- **返回：** 新 `NetworkData`。
- **副作用：** 无。
- **算法：** 带默认的平凡字段赋值。
- **用法：**
  ```dart
  await save(NetworkData(networks: networks, assignments: data.assignments));
  ```
  （来自 [`network_storage.md`](../services/network_storage.md) 的 `addOrUpdateNetwork`）
- **备注：** 无。

### `Map<String, dynamic> toJson()` <a id="networkdata-tojson"></a>
- **种类：** `NetworkData` 的方法。
- **来源：** `lib/features/network/models/network.dart`（第 314 行）。
- **用途：** 把完整网络数据集序列化为写入 `network_data.json` 的 JSON。
- **输入：** 无。
- **返回：** 带 `networks` 和 `assignments` 数组的 `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** `{...extraJson, 'networks': networks.map(toJson), 'assignments': assignments.map(toJson)}`。
- **用法：** 被 [`network_storage.md`](../services/network_storage.md) 的 `save` 调用。
- **备注：** 无。

### `factory NetworkData.fromJson(Map<String, dynamic> json)` <a id="networkdata-fromjson"></a>
- **种类：** `NetworkData` 的工厂构造函数。
- **来源：** `lib/features/network/models/network.dart`（第 325 行）。
- **用途：** 从 `network_data.json` 存储的 JSON 解析 `NetworkData`。
- **输入：** `json`。
- **返回：** 新 `NetworkData`；两个列表键缺席时都默认 `[]`。
- **副作用：** 无。
- **算法：** 分别经 [`Network.fromJson`](#network-fromjson)/[`NetworkDevice.fromJson`](#networkdevice-fromjson) 映射 `json['networks']`/`json['assignments']`。
- **用法：** 被 [`network_storage.md`](../services/network_storage.md) 的 `load` 调用。
- **备注：** 无。
