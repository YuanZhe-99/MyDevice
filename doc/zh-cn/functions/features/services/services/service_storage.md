# lib/features/services/services/service_storage.dart

`ServiceStorage` 持久化手动服务清单（`service_data.json`）：[`../models/service.md`](../models/service.md) 描述的 `ServiceNode` 列表和 `ServiceRoute` 列表。它搭 [`../../devices/services/device_storage.md`](../../devices/services/device_storage.md) 的 `getAppDir()` 顺风车获取实际存储目录（因此总是住在 `device_data.json`/`network_data.json`/`dataset_data.json` 旁，存储位置变化时随它们移动），这里每个修改方法都经 `save` 通知 [`../../../shared/services/auto_sync_service.md`](../../../shared/services/auto_sync_service.md)。本文件方法尊重的仅手动清单约束（无发现、无扫描——每次写入都是直接、用户发起清单编辑）见 [服务与拓扑](../../../../features/services-topology.md)，本文件读写的精确 `ServiceData` JSON 形态见 [数据格式 — ServiceNode / ServiceEndpoint / ServiceRoute / ServiceRouteHop](../../../../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`_getFile`](#_getfile) | 静态方法（私有） | A | 解析当前应用目录内 `service_data.json` 文件。 |
| [`load`](#load) | 静态方法 | A | 加载持久化 `ServiceData`（服务 + 路由）。 |
| [`save`](#save) | 静态方法 | A | 持久化 `ServiceData` 并通知自动同步服务。 |
| [`addOrUpdateService`](#addorupdateservice) | 静态方法 | A | 按 id 插入或替换服务。 |
| [`deleteService`](#deleteservice) | 静态方法 | A | 按 id 删除服务并剥离引用它的路由跳。 |
| [`addOrUpdateRoute`](#addorupdateroute) | 静态方法 | A | 按 id 插入或替换路由。 |
| [`deleteRoute`](#deleteroute) | 静态方法 | A | 按 id 删除路由。 |
| [`removeDeviceReferences`](#removedevicereferences) | 静态方法 | A | 移除对已删除或退役设备的每个服务/路由引用。 |

行数（8）与 `grep -c 'Purpose:' service_storage.dart`（8）精确匹配。

## 文档

### `static Future<File> _getFile()` <a id="_getfile"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/services/services/service_storage.dart`（第 16 行）。
- **用途：** 解析应用当前数据目录内 `service_data.json` 文件（尊重经 [`DeviceStorage.setStoragePath`](../../devices/services/device_storage.md#setstoragepath) 配置的任何自定义存储路径）。
- **输入：** 无。
- **返回：** `Future<File>`。
- **副作用：** 除 `DeviceStorage.getAppDir()` 的目录创建副作用外无。
- **算法：** `File('${(await DeviceStorage.getAppDir()).path}/$dataFileName')`，`dataFileName` 是常量 `'service_data.json'`。
- **用法：** 只被 [`load`](#load) 和 [`save`](#save) 内部调用；不暴露到此类外。
- **备注：** 与 `DeviceStorage` 自己的等价（`_getFile`，也逐文件私有）不同，本文件无单独"默认目录"变体——它总是对照 `DeviceStorage.getAppDir()` 当前报告的任何东西解析。

### `static Future<ServiceData> load()` <a id="load"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/services/services/service_storage.dart`（第 26 行）。
- **用途：** 从 `service_data.json` 加载持久化服务清单。
- **输入：** 无。
- **返回：** `Future<ServiceData>` — 文件缺席或其内容空白时 `const ServiceData()`（空）。
- **副作用：** 读取 `service_data.json`。
- **算法：** 1. 经 [`_getFile`](#_getfile) 解析文件。2. 不存在时返回空 `ServiceData`。3. 读取其内容；修剪文本为空时也返回空 `ServiceData`。4. 否则 `jsonDecode` 并经 [`ServiceData.fromJson`](../models/service.md#servicedata-fromjson) 解析。
- **用法：**
  ```dart
  final serviceData = await ServiceStorage.load();
  final deviceData = await DeviceStorage.load();
  final networkData = await NetworkStorage.load();
  ```
  （来自 `service_list_page.dart` 的 `_load`；也被 `service_route_edit_page.dart`、`import_export_service.dart` 的 Markdown/备份导出和 [`local_api_server.md`](../../../shared/services/local_api_server.md) 的只读 `/service/*` 端点读取）
- **备注：** 无。

### `static Future<void> save(ServiceData data)` <a id="save"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/services/services/service_storage.dart`（第 40 行）。
- **用途：** 把完整服务清单（服务和路由一起）持久化到 `service_data.json` 并通知自动同步服务本地数据已变。
- **输入：** `data` — 要写的完整 `ServiceData`；此类每个修改器都用新重建 `ServiceData` 调用它，绝不用部分更新。
- **返回：** `Future<void>`。
- **副作用：** 写 `service_data.json`（美化打印、非原子直接写）；调用 `AutoSyncService.instance.notifySaved()`（见 [`auto_sync_service.md`](../../../shared/services/auto_sync_service.md)）。
- **算法：** 用两空格缩进 JSON 编码 `data.toJson()`、写它、然后通知自动同步。
- **用法：** 被本文件每个其他修改方法（[`addOrUpdateService`](#addorupdateservice)、[`deleteService`](#deleteservice)、[`addOrUpdateRoute`](#addorupdateroute)、[`deleteRoute`](#deleteroute)、[`removeDeviceReferences`](#removedevicereferences)）调用；不从此类外直接调用。
- **备注：** 因为这里每个方法总是先加载完整列表并用重建 `ServiceData` 调用 `save`，两个并发修改（如来自两个 isolate）可竞争并互相破坏——匹配 [`DeviceStorage.writeConfig`](../../devices/services/device_storage.md#writeconfig) 注明的相同读-改-写注意，但本应用存储层只从单线程 UI/本地 API 路径驱动。

### `static Future<void> addOrUpdateService(ServiceNode service)` <a id="addorupdateservice"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/services/services/service_storage.dart`（第 52 行）。
- **用途：** 插入新服务或按 `id` 替换既有服务。
- **输入：** `service`。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `service_data.json`；路由原样带过。
- **算法：** 1. 加载当前 `ServiceData`。2. 复制服务列表；找相同 `id` 的既有服务索引。3. 找到替换否则追加。4. 保存带更新服务列表、路由/`extraJson` 不动的 新 `ServiceData`。
- **用法：**
  ```dart
  await ServiceStorage.addOrUpdateService(service);
  ```
  （来自 `service_edit_page.dart` 的保存处理器）
- **备注：** 与 [`DeviceStorage.addOrUpdate`](../../devices/services/device_storage.md#addorupdate) 不同，此方法自己不做级联清理——服务编辑从不需要移除跨模块引用（只有删除或设备离开服务需要，见 [`deleteService`](#deleteservice) 和 [`removeDeviceReferences`](#removedevicereferences)）。

### `static Future<void> deleteService(String id)` <a id="deleteservice"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/services/services/service_storage.dart`（第 75 行）。
- **用途：** 按 id 删除服务并剥离任何引用它的路由跳，使已删除服务不能作为跳 `serviceId` 悬空。
- **输入：** `id`。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `service_data.json`。
- **算法：** 1. 加载当前 `ServiceData`。2. 把服务从服务列表过滤。3. 对每条路由丢弃任何 `serviceId == id` 的跳（经 `route.copyWith(hops: ...)`）——路由本身即使跳列表被清空也保留；只移除引用已删除服务的跳。4. 保存更新服务和路由。
- **用法：**
  ```dart
  await ServiceStorage.deleteService(service.id);
  ```
  （来自 `service_edit_page.dart` 的删除确认流程）
- **备注：** 此方法**不**删除 `sourceServiceId == id` 的路由（源自分删除服务的路由留在原地，带其现已无效 `sourceServiceId`）——这里只清理跳引用。对比 [`removeDeviceReferences`](#removedevicereferences)，它作为整设备清理一部分确实丢弃源服务被移除的路由。

### `static Future<void> addOrUpdateRoute(ServiceRoute route)` <a id="addorupdateroute"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/services/services/service_storage.dart`（第 100 行）。
- **用途：** 插入新路由或按 `id` 替换既有路由。
- **输入：** `route`。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `service_data.json`；服务原样带过。
- **算法：** 与 [`addOrUpdateService`](#addorupdateservice) 相同插入-或-按-`id`-替换形态，应用于路由列表。
- **用法：**
  ```dart
  await ServiceStorage.addOrUpdateRoute(route);
  ```
  （来自 `service_list_page.dart` 的快速访问路由流程和 `service_route_edit_page.dart` 的高级路由编辑器保存处理器——两个流程见 [服务与拓扑 — 快速访问路由创建 vs 高级编辑器](../../../../features/services-topology.md#quick-access-route-creation-vs-the-advanced-editor)）
- **备注：** 无。

### `static Future<void> deleteRoute(String id)` <a id="deleteroute"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/services/services/service_storage.dart`（第 123 行）。
- **用途：** 按 id 删除路由。
- **输入：** `id`。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `service_data.json`。
- **算法：** 把路由从加载路由列表过滤，然后服务不变地保存。
- **用法：**
  ```dart
  await ServiceStorage.deleteRoute(route.id);
  ```
  （来自 `service_route_edit_page.dart` 的删除确认流程）
- **备注：** 与 [`deleteService`](#deleteservice) 不同，此方法不进一步清理——路由在此模型内无要清理的依赖者。

### `static Future<void> removeDeviceReferences(String deviceId)` <a id="removedevicereferences"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/services/services/service_storage.dart`（第 139 行）。
- **用途：** 移除对已删除或离开服务（退役/出售）设备的每个服务和路由引用——[`DeviceStorage`](../../devices/services/device_storage.md) 跨模块级联删除规则的服务层半边。
- **输入：** `deviceId`。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `service_data.json`，但**只**在实际有变化时（见算法步骤 4）。
- **算法：** 1. 加载当前 `ServiceData`。2. 计算 `removedServiceIds` — 每个 `deviceId == deviceId` 服务的 id。3. 构建丢弃那些服务的新服务列表，和新路由列表——丢弃任何 `sourceServiceId` 在 `removedServiceIds` 中的路由，然后（对剩余路由）过滤掉任何 `deviceId == deviceId` 或其 `serviceId` 在 `removedServiceIds` 中的跳。4. 只在服务列表长度变化、路由列表长度变化、或任何幸存路由跳数缩水（对照相同 `id` 原始路由比较每个新路由跳数检查）时调用 `save`——否则这是无写入的空操作。
- **用法：**
  ```dart
  await ServiceStorage.removeDeviceReferences(id);
  ```
  （来自 [`DeviceStorage._removeDeviceReferences`](../../devices/services/device_storage.md#_removedevicereferences)，设备被删除或编辑出服务时无条件调用）
- **备注：** 这是本文件唯一条件保存的方法——这里每个其他修改器总是写。三部分"有变化吗"检查（服务数、路由数或任何路由跳数）存在因为丢弃*服务*和从*幸存*路由丢弃*跳*都是值得持久化的变化，但任一单独都不足以检测另一个。
