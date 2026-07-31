# lib/features/network/services/network_storage.dart

`NetworkStorage` 与应用其他功能存储一起持久化 `network_data.json` 文件（`Network` 定义和 `NetworkDevice` 赋值两者）。它经 `DeviceStorage.getAppDir()`（`../../../devices/services/device_storage.md`，应用数据目录单一真相源）解析文件位置，并在每次写入后通知 [`AutoSyncService`](../../../shared/services/auto_sync_service.md)，使后台同步拾取变更。本文件读/写的模型形态见 [网络](../../../../features/networks.md)，精确持久化 JSON 形态见 [数据格式 — 网络 / NetworkDevice](../../../../data-formats.md#network--networkdevice-libfeaturesnetworkmodelsnetworkdart)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`_getFile`](#getfile) | 静态方法（私有） | A | 解析应用目录内 `network_data.json` 文件。 |
| [`load`](#load) | 静态方法 | A | 加载持久化 `NetworkData`（网络 + 赋值）。 |
| [`save`](#save) | 静态方法 | A | 持久化 `NetworkData` 并通知自动同步服务。 |
| [`addOrUpdateNetwork`](#addorupdatenetwork) | 静态方法 | A | 按 id 插入或替换网络。 |
| [`deleteNetwork`](#deletenetwork) | 静态方法 | A | 删除网络和每个引用它的赋值。 |
| [`setAssignment`](#setassignment) | 静态方法 | A | 插入或替换设备对网络的赋值。 |
| [`removeAssignment`](#removeassignment) | 静态方法 | A | 从网络移除一个设备的赋值。 |

行数（7）与 `grep -c 'Purpose:' network_storage.dart`（7）精确匹配。

## 文档

### `static Future<File> _getFile()` <a id="getfile"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/network/services/network_storage.dart`（第 16 行）。
- **用途：** 解析当前应用目录内 `network_data.json` 文件。
- **输入：** 无。
- **返回：** `Future<File>`。
- **副作用：** 除 `DeviceStorage.getAppDir()` 的目录创建副作用外无。
- **算法：** `File('${(await DeviceStorage.getAppDir()).path}/network_data.json')`。
- **用法：** 被 [`load`](#load) 和 [`save`](#save) 调用。
- **备注：** 委托 `DeviceStorage.getAppDir()`（而非解析自己的目录）正是让 `network_data.json` 即使用户在设置更改存储位置后也住在 `device_data.json` 旁的东西。

### `static Future<NetworkData> load()` <a id="load"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/network/services/network_storage.dart`（第 26 行）。
- **用途：** 从 `network_data.json` 加载持久化网络数据集。
- **输入：** 无。
- **返回：** `Future<NetworkData>` — 文件缺席或为空时 `const NetworkData()`（空）。
- **副作用：** 读取 `network_data.json`。
- **算法：** 存在性/空内容检查，然后 `NetworkData.fromJson(jsonDecode(...))`（见 [`network.md`](../models/network.md#networkdata-fromjson)）。
- **用法：**
  ```dart
  final data = await NetworkStorage.load();
  ```
  （来自 [`network_list_page.md`](../views/network_list_page.md) 和 [`network_detail_page.md`](../views/network_detail_page.md)，页面每次（重）加载时）
- **备注：** 无。

### `static Future<void> save(NetworkData data)` <a id="save"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/network/services/network_storage.dart`（第 40 行）。
- **用途：** 把完整网络数据集持久化到 `network_data.json` 并通知自动同步服务本地数据已变。
- **输入：** `data`。
- **返回：** `Future<void>`。
- **副作用：** 写 `network_data.json`（美化打印、非原子）；调用 `AutoSyncService.instance.notifySaved()`（见 [`auto_sync_service.md`](../../../shared/services/auto_sync_service.md#notifysaved)）。
- **算法：** JSON 编码 `data.toJson()`、写它、然后通知自动同步。
- **用法：**
  ```dart
  await NetworkStorage.save(
    NetworkData(networks: _networks, assignments: data.assignments),
  );
  ```
  （来自 [`network_list_page.md`](../views/network_list_page.md) 的 `_onReorder`）
- **备注：** 网络数据每次写入都应经此方法（直接，或经 [`addOrUpdateNetwork`](#addorupdatenetwork)/[`deleteNetwork`](#deletenetwork)/[`setAssignment`](#setassignment)/[`removeAssignment`](#removeassignment)），使 `AutoSyncService` 总是被通知。与 `DeviceStorage.addOrUpdate` 不同，本文件任何修改器自己都不调用 `AutoSyncService.notifySaved()`——视图层调用方（如 `network_edit_page.dart` 的 `_save`）await 存储调用后显式调用它，在 `save` 自己内部通知之外。

### `static Future<void> addOrUpdateNetwork(Network network)` <a id="addorupdatenetwork"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/network/services/network_storage.dart`（第 52 行）。
- **用途：** 插入新网络或按 `id` 替换既有网络。
- **输入：** `network`。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `network_data.json`；赋值原样带过。
- **算法：** 加载当前列表；找相同 `id` 的既有网络索引，找到替换否则追加；带（可能未变）`assignments` 列表保存。
- **用法：**
  ```dart
  await NetworkStorage.addOrUpdateNetwork(network);
  ```
  （来自 [`network_edit_page.md`](../views/network_edit_page.md) 的 `_save`）
- **备注：** 无。

### `static Future<void> deleteNetwork(String id)` <a id="deletenetwork"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/network/services/network_storage.dart`（第 69 行）。
- **用途：** 按 id 删除网络并移除每个引用它的赋值。
- **输入：** `id`。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `network_data.json`。
- **算法：** 把网络从加载列表过滤；过滤掉每个 `networkId == id` 的赋值；一次写入一起保存两个列表。
- **用法：**
  ```dart
  await NetworkStorage.deleteNetwork(widget.networkId);
  ```
  （来自 [`network_detail_page.md`](../views/network_detail_page.md) 的 `_deleteNetwork`）
- **备注：** 这是网络的级联规则：删除网络总是在同一次写入删除其设备赋值，使指向不存在 `networkId` 的悬空 `NetworkDevice` 绝不持久化。

### `static Future<void> setAssignment(NetworkDevice assignment)` <a id="setassignment"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/network/services/network_storage.dart`（第 83 行）。
- **用途：** 插入新设备赋值或按 `(networkId, deviceId)` 复合键替换既有赋值。
- **输入：** `assignment`。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `network_data.json`；`networks` 不变。
- **算法：** 加载当前列表；找相同 `networkId` *和* `deviceId` 的既有赋值索引，找到替换否则追加；保存。
- **用法：**
  ```dart
  await NetworkStorage.setAssignment(result);
  ```
  （来自 [`network_detail_page.md`](../views/network_detail_page.md) 的 `_addDevice` 和 `_editAssignment`）
- **备注：** 因为 `NetworkDevice` 无 `id`，此方法索引查找是 [网络 — 复合键身份及其原因](../../../../features/networks.md#composite-key-identity--and-why) 描述复合键身份的实践表达——对 `(networkId, deviceId)` 是这里"替换既有"的含义，非任何合成标识符。

### `static Future<void> removeAssignment(String networkId, String deviceId)` <a id="removeassignment"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/network/services/network_storage.dart`（第 104 行）。
- **用途：** 从网络移除单个设备的赋值。
- **输入：** `networkId`、`deviceId`。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `network_data.json`；`networks` 不变。
- **算法：** 过滤掉同时匹配 `networkId` 和 `deviceId` 的赋值；保存。
- **用法：**
  ```dart
  await NetworkStorage.removeAssignment(
    assignment.networkId,
    assignment.deviceId,
  );
  ```
  （来自 [`network_detail_page.md`](../views/network_detail_page.md) 的 `_removeAssignment`）
- **备注：** 无。
