# lib/shared/services/sync_merge.dart

**拆分文件。** 通用三方记录合并——`mergeRecords<T>`、`RecordConflict<T>` 和 `RecordMergeResult<T>`——移到 `myapps_data` 包（`lib/src/merge/sync_merge.dart`）并在此重新导出。MyDevice 自己的合并逻辑留下。

MyDevice 的签名是**包采用的超集**：它携带用于模型级 `extraJson` 保留的可选 `mergeUnknownFields` 回调。共享实现因此这里行为相同，设备合并仍传该回调。

本文件自己声明的是应用类型化的那一半：`mergeAssignments`，以及四个数据文件各自的一个 `…MergeResult` 类加一个 `merge…Data` 函数。每个结果携带其合并列表、冲突列表和保留的顶层 `extraJson`。同步引擎把结果作为不透明 `state` 携带，这正是冲突对话框仍收到真实模型对象的方式；[`data_modules.md`](../../app/data_modules.md#modules) 中的模块描述符调用 `merge…Data` 函数和 `buildResolved` 方法。`ServiceMergeResult.buildResolved` 按运行时类型消歧共享记录 ID，这正是单个扁平解析映射能服务每个模块的原因。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `RecordConflict` / `RecordMergeResult` / `mergeRecords` | 重新导出（`export … show`） | B | 来自 `myapps_data` 的通用引擎，重新导出使既有 import 继续编译。 |
| [`mergeAssignments`](#mergeassignments) | 顶层函数 | A | MyDevice 独有网络设备分配复合键合并。 |
| `key`（嵌套于 `mergeAssignments`） | 局部函数 | B | 复合键 `networkId:deviceId`。 |
| `content`（嵌套于 `mergeAssignments`） | 局部函数 | B | `jsonEncode(a.toJson())`，与基线比较的文本。 |
| `DeviceMergeResult` | 类 | B | 合并 `device_data.json` 的结果。 |
| `DeviceMergeResult` 构造函数 | 构造函数 | B | 存储 `merged`、`conflicts`（默认空）和 `extraJson`（默认空）。 |
| `hasConflicts` | getter（`DeviceMergeResult`） | B | `conflicts.isNotEmpty`。 |
| [`buildResolved`](#devicemergeresult-buildresolved) | 方法（`DeviceMergeResult`） | A | 由合并列表加每个冲突的一个选择构建最终 `DeviceData`。 |
| [`mergeDeviceData`](#mergedevicedata) | 顶层函数 | A | `device_data.json` 的三方合并。 |
| `NetworkMergeResult` | 类 | B | 合并 `network_data.json` 的结果：网络和分配。 |
| `NetworkMergeResult` 构造函数 | 构造函数 | B | 存储 `mergedNetworks`、`mergedAssignments`、`conflicts` 和 `extraJson`。 |
| `hasConflicts` | getter（`NetworkMergeResult`） | B | `conflicts.isNotEmpty`；分配从不冲突。 |
| [`buildResolved`](#networkmergeresult-buildresolved) | 方法（`NetworkMergeResult`） | A | 构建最终 `NetworkData`，原样携带合并后的分配。 |
| [`mergeNetworkData`](#mergenetworkdata) | 顶层函数 | A | `network_data.json` 的三方合并：网络经 `mergeRecords`，分配经 `mergeAssignments`。 |
| `DataSetMergeResult` | 类 | B | 合并 `dataset_data.json` 的结果。 |
| `DataSetMergeResult` 构造函数 | 构造函数 | B | 存储 `merged`、`conflicts` 和 `extraJson`。 |
| `hasConflicts` | getter（`DataSetMergeResult`） | B | `conflicts.isNotEmpty`。 |
| [`buildResolved`](#datasetmergeresult-buildresolved) | 方法（`DataSetMergeResult`） | A | 由合并列表加每个冲突的一个选择构建最终 `DataSetData`。 |
| [`mergeDataSetData`](#mergedatasetdata) | 顶层函数 | A | `dataset_data.json` 的三方合并。 |
| `ServiceMergeResult` | 类 | B | 合并 `service_data.json` 的结果：服务节点和路由。 |
| `ServiceMergeResult` 构造函数 | 构造函数 | B | 存储两个合并列表、两个冲突列表和 `extraJson`。 |
| `hasConflicts` | getter（`ServiceMergeResult`） | B | 任一冲突列表非空时为真。 |
| `allConflicts` | getter（`ServiceMergeResult`） | B | 服务冲突在前、路由冲突在后，合为一个无类型列表。 |
| [`buildResolved`](#servicemergeresult-buildresolved) | 方法（`ServiceMergeResult`） | A | 构建最终 `ServiceData`，按运行时类型挑选每个解析。 |
| [`mergeServiceData`](#mergeservicedata) | 顶层函数 | A | `service_data.json` 的三方合并：两遍 `mergeRecords`。 |

行数（25）比 `grep -c '/// Purpose:' sync_merge.dart`（18）多七。每个函数、构造函数、getter 和方法都有自己的行和自己的 `Purpose:` 块（18）。多出的七行是四个结果类和嵌套在 `mergeAssignments` 中的两个局部函数（它们没有文档注释），以及 `export … show` 指令——它不是本文件的声明，但列出以便在此找到被重新导出的名称。Tier A：9 行。

## 文档

### `List<NetworkDevice> mergeAssignments(List<NetworkDevice> local, List<NetworkDevice> remote, List<NetworkDevice>? base)` <a id="mergeassignments"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/services/sync_merge.dart`（第 37 行）。
- **用途：** 对没有 `modifiedAt` 的 `NetworkDevice` 分配记录做三方合并。
- **输入：** `local`、`remote` — 两侧的分配列表；`base` — 上次成功同步时的分配，没有基线快照时为 `null`。
- **返回：** `List<NetworkDevice>` — 合并后的分配。它从不报告冲突。
- **副作用：** 无。
- **算法：** 以 `networkId:deviceId` 为每个分配作键，并把 `jsonEncode(toJson())` 与基线的序列化内容比较。对三个映射键并集中的每个键：
  1. 两侧都有且有基线：只有远程变化时取远程，否则取本地；无论哪种，保留的记录都经 `mergeUnknownFieldsFrom(…, base: b)` 从另一侧取未知字段。
  2. 两侧都有但无基线（都是新增）：取本地，带远程的未知字段。
  3. 只有本地、有基线（远程已删除）：仅当本地自基线以来有变化才保留。只有本地、无基线：保留（本地新增）。
  4. 只有远程、有基线（本地已删除）：仅当远程自基线以来有变化才保留。只有远程、无基线：保留（远程新增）。
  5. 只在基线中：丢弃（两侧都已删除）。
- **用法：** 被 [`mergeNetworkData`](#mergenetworkdata) 调用。
- **备注：** 刻意**不**抽取到 `myapps_data`。因为没有时间戳挑胜者，都变时解析为本地；该冲突从不展示给用户。演练见 [三方合并](../../../algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)。

### `DeviceData DeviceMergeResult.buildResolved(Map<String, Device> resolutions)` <a id="devicemergeresult-buildresolved"></a>
- **种类：** `DeviceMergeResult` 的方法。
- **来源：** `lib/shared/services/sync_merge.dart`（第 126 行）。
- **用途：** 把合并结果加用户的冲突选择变成要写入的 `DeviceData`。
- **输入：** `resolutions` — 冲突 ID → 所选 `Device`。
- **返回：** `DeviceData`，含 `merged` 后接每个冲突一个设备，以及保留的 `extraJson`。
- **副作用：** 无。
- **算法：** 复制 `merged`；对每个冲突追加 `resolutions[c.id]`，映射中没有该条目时追加 `c.localRecord`。
- **用法：** [`data_modules.md`](../../app/data_modules.md#modules) 中的 `buildDevicesModule`，传入过滤为 `Device` 值的映射。没有冲突时设备模块直接编码 `DeviceData(devices: r.merged, extraJson: r.extraJson)`。
- **备注：** 未解决的冲突回退到本地记录，绝不回退到远程记录。

### `DeviceMergeResult mergeDeviceData(String localJson, String remoteJson, String? baseJson, {bool autoResolve = false})` <a id="mergedevicedata"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/services/sync_merge.dart`（第 140 行）。
- **用途：** 两侧 `device_data.json` 的三方合并。
- **输入：** `localJson`、`remoteJson` — 文件内容；`baseJson` — 基线快照，或 `null`；`autoResolve` — 传给 `mergeRecords`。
- **返回：** `DeviceMergeResult`。
- **副作用：** 无。
- **算法：** 1. 用 `DeviceData.fromJson` 解析三者。2. 以 `mergeUnknownJsonFields(primary: local, secondary: remote, base: base)` 合并顶层 `extraJson`。3. 运行 `mergeRecords<Device>`：按 `id` 作键、按 `modifiedAt` 计时、按 `name` 命名、按 `jsonEncode(toJson())` 比较，`mergeUnknownFields` 调用 `primary.mergeUnknownFieldsFrom`。4. 包装合并列表、冲突和 `extraJson`。
- **用法：** [`data_modules.md`](../../app/data_modules.md#modules) 中的 `buildDevicesModule`；`test/audit_fixes_test.dart` 和 `test/sync_unknown_fields_test.dart`。
- **备注：** `autoResolve` 来自同步引擎，引擎在每个调用点都保持其为 `false`，因此真实冲突会到达用户。

### `NetworkData NetworkMergeResult.buildResolved(Map<String, Network> resolutions)` <a id="networkmergeresult-buildresolved"></a>
- **种类：** `NetworkMergeResult` 的方法。
- **来源：** `lib/shared/services/sync_merge.dart`（第 213 行）。
- **用途：** 把合并结果加用户的冲突选择变成要写入的 `NetworkData`。
- **输入：** `resolutions` — 冲突 ID → 所选 `Network`。
- **返回：** `NetworkData`，含 `mergedNetworks` 后接每个冲突一个网络、原样的 `mergedAssignments`，以及保留的 `extraJson`。
- **副作用：** 无。
- **算法：** 同 [`DeviceMergeResult.buildResolved`](#devicemergeresult-buildresolved)，外加分配。
- **用法：** [`data_modules.md`](../../app/data_modules.md#modules) 中的 `buildNetworksModule`，用于干净合并（`buildResolved(const {})`）和用户解决冲突之后。
- **备注：** 无。

### `NetworkMergeResult mergeNetworkData(String localJson, String remoteJson, String? baseJson, {bool autoResolve = false})` <a id="mergenetworkdata"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/services/sync_merge.dart`（第 231 行）。
- **用途：** 两侧 `network_data.json` 的三方合并。
- **输入：** 同 [`mergeDeviceData`](#mergedevicedata)。
- **返回：** `NetworkMergeResult`。
- **副作用：** 无。
- **算法：** 用 `NetworkData.fromJson` 解析；合并顶层 `extraJson`；以与设备相同的回调对 `networks` 运行 `mergeRecords<Network>`；对 `assignments` 运行 [`mergeAssignments`](#mergeassignments)；包装两者。
- **用法：** [`data_modules.md`](../../app/data_modules.md#modules) 中的 `buildNetworksModule`；`test/sync_unknown_fields_test.dart`。
- **备注：** 只有网络会冲突；分配上的分歧由 `mergeAssignments` 静默决定。

### `DataSetData DataSetMergeResult.buildResolved(Map<String, DataSet> resolutions)` <a id="datasetmergeresult-buildresolved"></a>
- **种类：** `DataSetMergeResult` 的方法。
- **来源：** `lib/shared/services/sync_merge.dart`（第 309 行）。
- **用途：** 把合并结果加用户的冲突选择变成要写入的 `DataSetData`。
- **输入：** `resolutions` — 冲突 ID → 所选 `DataSet`。
- **返回：** `DataSetData`，含 `merged` 后接每个冲突一个数据集，以及保留的 `extraJson`。
- **副作用：** 无。
- **算法：** 同 [`DeviceMergeResult.buildResolved`](#devicemergeresult-buildresolved)。
- **用法：** [`data_modules.md`](../../app/data_modules.md#modules) 中的 `buildDataSetsModule`，用于干净合并和冲突解决之后。
- **备注：** 无。

### `DataSetMergeResult mergeDataSetData(String localJson, String remoteJson, String? baseJson, {bool autoResolve = false})` <a id="mergedatasetdata"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/services/sync_merge.dart`（第 323 行）。
- **用途：** 两侧 `dataset_data.json` 的三方合并。
- **输入：** 同 [`mergeDeviceData`](#mergedevicedata)。
- **返回：** `DataSetMergeResult`。
- **副作用：** 无。
- **算法：** 用 `DataSetData.fromJson` 解析；合并顶层 `extraJson`；以与设备相同的回调对 `datasets` 运行 `mergeRecords<DataSet>`；包装结果。
- **用法：** [`data_modules.md`](../../app/data_modules.md#modules) 中的 `buildDataSetsModule`。
- **备注：** 无。

### `ServiceData ServiceMergeResult.buildResolved(Map<String, dynamic> resolutions)` <a id="servicemergeresult-buildresolved"></a>
- **种类：** `ServiceMergeResult` 的方法。
- **来源：** `lib/shared/services/sync_merge.dart`（第 409 行）。
- **用途：** 把合并结果加用户的冲突选择变成要写入的 `ServiceData`。
- **输入：** `resolutions` — 冲突 ID → 所选记录，`ServiceNode` 或 `ServiceRoute`。
- **返回：** `ServiceData`，含两个合并列表、每个冲突追加一条记录，以及保留的 `extraJson`。
- **副作用：** 无。
- **算法：** 1. 复制 `mergedServices`；对每个服务冲突，`resolutions[c.id]` 是 `ServiceNode` 时取它，否则取 `c.localRecord`。2. 复制 `mergedRoutes`；对每个路由冲突，`resolutions[c.id]` 是 `ServiceRoute` 时取它，否则取 `c.localRecord`。3. 连同 `extraJson` 包装两者。
- **用法：** [`data_modules.md`](../../app/data_modules.md#services) 中的 `buildServicesModule`，用于干净合并（`buildResolved(const {})`）和冲突解决后的 `buildResolvedJson`。
- **备注：** 运行时类型检查使一个扁平映射能容纳两种记录：若某服务与某路由共享 ID，每个列表只接受自己类型的值，否则保留本地。

### `ServiceMergeResult mergeServiceData(String localJson, String remoteJson, String? baseJson, {bool autoResolve = false})` <a id="mergeservicedata"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/services/sync_merge.dart`（第 435 行）。
- **用途：** 两侧 `service_data.json` 的三方合并。
- **输入：** 同 [`mergeDeviceData`](#mergedevicedata)。
- **返回：** `ServiceMergeResult`。
- **副作用：** 无。
- **算法：** 用 `ServiceData.fromJson` 解析；合并顶层 `extraJson`；对 `services` 运行 `mergeRecords<ServiceNode>`、对 `routes` 运行 `mergeRecords<ServiceRoute>`，均按 `id` 作键、按 `modifiedAt` 计时、按 `name` 命名并合并未知字段；包装两个结果。
- **用法：** [`data_modules.md`](../../app/data_modules.md#services) 中的 `buildServicesModule`；`test/service_module_test.dart`。
- **备注：** 服务和路由独立合并；这里不检查合并后路由的跳是否仍引用合并列表中存在的服务。

## 通用引擎文档在哪里

`packages/myapps_data/doc/en-us/functions/src/merge/sync_merge.md`。
