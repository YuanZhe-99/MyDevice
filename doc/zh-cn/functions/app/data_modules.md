# lib/app/data_modules.dart

**本应用与共享 `myapps_data` 包之间的接缝**，MyDevice 四个数据文件的单一真相源。硬编码 `_dataFileNames` 列表和备份模块映射现在都从这里声明的注册表读取。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`DeviceStorageAdapter`](#devicestorageadapter) | 类 | A | 在 `DeviceStorage` 上实现包的 `StorageAdapter`。 |
| [`deviceDefaultRemotePath`](#constants) | 常量 | A | `'/MyDevice'`。 |
| [`deviceArchiveNamePrefix`](#constants) | 常量 | A | `'mydevice_export_'`。 |
| [`deviceDataFileName`](#constants) | 常量 | A | `'device_data.json'`。 |
| [`deviceModuleId`](#constants) | 常量 | A | `'devices'`。 |
| [`networkDataFileName`](#constants) | 常量 | A | `'network_data.json'`。 |
| [`dataSetDataFileName`](#constants) | 常量 | A | `'dataset_data.json'`。 |
| [`serviceDataFileName`](#constants) | 常量 | A | `'service_data.json'`。 |
| [`deviceReferencedImages(json)`](#devicereferencedimages) | 函数 | A | 记录引用的设备图像基名。 |
| [`buildDevicesModule()`](#modules) | 函数 | A | 设备 `DataModule`（唯一图像源）。 |
| [`buildNetworksModule()`](#modules) | 函数 | A | 网络 `DataModule`。 |
| [`buildDataSetsModule()`](#modules) | 函数 | A | 数据集 `DataModule`。 |
| [`buildServicesModule()`](#services) | 函数 | A | 服务 `DataModule`（两个记录容器）。 |
| [`deviceModuleRegistry`](#registry) | 字段 | A | 应用的有序 `ModuleRegistry`。 |

## 文档

### `class DeviceStorageAdapter` <a id="devicestorageadapter"></a>
- **用途：** 给共享引擎存储根和 `storage_config.json` 访问，包无需知道 `DeviceStorage` 任何东西。
- **构造函数：** `const DeviceStorageAdapter({Future<Directory> Function()? appDir})`。
- **方法：** `getAppDir()`、`readConfig()`、`writeConfig(config)`，全部委托给枢纽。配置这一对无论存储路径如何，总是读写平台默认文件夹中唯一的 `storage_config.json`，且 `writeConfig` 不能改变 `storagePath` 键（见 [`DeviceStorage.writeConfig`](../features/devices/services/device_storage.md#writeconfig)）。
- **备注：** 可选 `appDir` 解析器存在使 `BackupService` 能继续尊重其 `@visibleForTesting appDirProvider`。每次调用都咨询它。`DeviceStorage.getAppDir()` 对照内存中的自定义路径解析，而 `setStoragePath` 会更新该路径，因此自定义存储路径变更立即被拾取。

### 常量 <a id="constants"></a>
- **备注：** 文件名和模块 id 是持久化兼容契约——旧构建和新构建必须对照相同 WebDAV 服务器和相同备份捆绑互操作。绝不要改变它们。四个 `*DataFileName` 常量是写出数据文件名的唯一位置：这里的模块构建器使用它们，存储枢纽也使用它们——`DeviceStorage._dataFileName`、`NetworkStorage._dataFileName`、`DataSetStorage._dataFileName` 和 `ServiceStorage.dataFileName` 分别是 `deviceDataFileName`、`networkDataFileName`、`dataSetDataFileName` 和 `serviceDataFileName` 的别名。

### `deviceReferencedImages(json)` <a id="devicereferencedimages"></a>
- **返回：** 来自 `Device.imagePath` 的图像基名；格式错误输入为空集合。
- **备注：** 设备是 MyDevice 的唯一图像源。引擎并集本地和远程结果，复现先前规则：同步任一侧引用的图像，绝不孤儿。

### 单容器模块 <a id="modules"></a>
- **用途：** 设备、网络和数据集各包装一个产生一个记录容器的合并函数，因此共享私有构建器。
- **备注：** `buildNetworksModule` 包装 `mergeNetworkData`，它内部也运行 `mergeAssignments`——MyDevice 对 `NetworkDevice` 记录的复合键、无时间戳合并。那留在应用侧。三者都用 `JsonEncoder.withIndent('  ')` 编码以匹配枢纽本地保存格式，因此未变文件下次同步仍命中原始相等快速路径。

### `buildServicesModule()` <a id="services"></a>
- **备注：** 直接构建而非经共享构建器，因为服务合并两个记录容器（节点和路由）。`ServiceMergeResult.buildResolved` 已按运行时类型消歧共享 ID，因此普通记录 ID 仍是有效解决键，无需命名空间。

### `deviceModuleRegistry` <a id="registry"></a>
- **备注：** 顺序是设备、网络、数据集、服务——匹配先前 `_dataFileNames` 列表。顺序对同步顺序、进度报告和备份键顺序行为重要。

## 契约文档在哪里

`packages/myapps_data/doc/en-us/functions/src/modules/data_module.md` 和 `packages/myapps_data/doc/en-us/functions/src/storage/storage_adapter.md`。
