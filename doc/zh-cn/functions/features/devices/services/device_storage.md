# lib/features/devices/services/device_storage.dart

`DeviceStorage` 持久化设备列表（`device_data.json`），并兼作应用规范存储位置/配置服务：`getAppDir()` 被 `DataSetStorage` 和 `NetworkStorage`（`../../../network/services/network_storage.dart`、`../../../datasets/services/dataset_storage.dart`）调用，解析那些模块自己数据文件所在的*相同*应用目录，`readConfig`/`writeConfig` 支撑一个小的通用键/值存储（`themeMode`、`locale`、`defaultCurrency`、`autoUpdateExchangeRates`、列表列数等），`AppSettings`（`../../../../shared/providers/app_settings.md`）和 [`exchange_rate_service.md`](exchange_rate_service.md) 也经它读写。该存储就是平台默认文件夹中唯一的 `storage_config.json`，它还保存自定义存储路径，因此移动数据从不触及偏好；其规则见 [数据格式](../../../../data-formats.md#storage_configjson)。本文件序列化的 `DeviceData`/`Device` JSON 形态见 [数据格式](../../../../data-formats.md)，`deleteDevice`/`addOrUpdate` 实现的级联删除规则见 [设备](../../../../features/devices.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `DeviceStorage` | 类 | B | 纯静态存储中枢：设备列表、应用目录和 `storage_config.json`。 |
| `_dataFileName` | 静态常量（私有） | B | 设备列表的文件名：来自 `data_modules.dart` 的 `deviceDataFileName`（`'device_data.json'`）。 |
| `_configFileName` | 静态常量（私有） | B | `'storage_config.json'`，本地偏好文件名。 |
| `_customPath` | 静态字段（私有） | B | 缓存的自定义存储路径；`null` 表示默认目录。 |
| `_configLoaded` | 静态字段（私有） | B | 本进程中 `_loadCustomPath` 是否已运行。 |
| [`_getDefaultAppDir`](#_getdefaultappdir) | 静态方法（私有） | A | 解析（并创建）默认 `~/Documents/MyDevice` 目录。 |
| [`_getConfigFile`](#_getconfigfile) | 静态方法（私有） | A | 解析 `storage_config.json` 文件，总是在默认目录。 |
| [`_loadCustomPath`](#_loadcustompath) | 静态方法（私有） | A | 从配置加载自定义存储路径，每进程一次。 |
| [`getAppDir`](#getappdir) | 静态方法 | A | 解析应用数据目录（配置了自定义路径则自定义，否则默认）。 |
| [`getStoragePath`](#getstoragepath) | 静态方法 | A | 返回当前存储目录显示路径。 |
| [`setStoragePath`](#setstoragepath) | 静态方法 | A | 更改存储位置，把整个存储文件夹移过去，并报告留下了什么。 |
| [`_leftoverEntries`](#_leftoverentries) | 静态方法（私有） | A | 列出存储移动留在旧文件夹中的文件，顶层配置除外。 |
| `_strayCheckedFor` | 静态字段（私有） | B | 上次检查过其文件夹中游离 `storage_config.json` 的自定义路径。 |
| [`_adoptStrayConfig`](#_adoptstrayconfig) | 静态方法（私有） | A | 把旧构建留在自定义文件夹中的 `storage_config.json` 合并进默认文件，然后删除它。 |
| [`_readConfigFromDefault`](#_readconfigfromdefault) | 静态方法（私有） | A | 从默认目录读取 `storage_config.json`——唯一的副本。 |
| [`_writeConfigToDefault`](#_writeconfigtodefault) | 静态方法（私有） | A | 向默认目录写 `storage_config.json`。 |
| [`_getFile`](#_getfile) | 静态方法（私有） | A | 解析当前应用目录内命名文件。 |
| [`load`](#load) | 静态方法 | A | 加载持久化 `DeviceData`（设备列表）。 |
| [`save`](#save) | 静态方法 | A | 持久化 `DeviceData` 并通知自动同步服务。 |
| [`addOrUpdate`](#addorupdate) | 静态方法 | A | 按 id 插入或替换设备；离开服务时清理引用。 |
| [`deleteDevice`](#deletedevice) | 静态方法 | A | 按 id 删除设备并清理跨模块引用。 |
| [`_removeDeviceReferences`](#_removedevicereferences) | 静态方法（私有） | A | 剥离网络/数据集/服务对设备 id 的引用。 |
| [`readConfig`](#readconfig) | 静态方法 | A | 从默认文件夹的 `storage_config.json` 读取偏好映射。 |
| [`writeConfig`](#writeconfig) | 静态方法 | A | 把偏好映射写入默认文件夹的 `storage_config.json`，`storagePath` 仍归 `setStoragePath` 所有。 |
| [`getThemeMode`](#getthememode) | 静态方法 | A | 读取持久化主题模式字符串。 |
| [`setThemeMode`](#setthememode) | 静态方法 | A | 持久化（或清除）主题模式字符串。 |
| [`getLocaleTag`](#getlocaletag) | 静态方法 | A | 读取持久化语言区域标签。 |
| [`setLocaleTag`](#setlocaletag) | 静态方法 | A | 持久化（或清除）语言区域标签。 |
| [`_getListColumns`](#getlistcolumns) | 静态方法（私有） | A | 从 `storage_config.json` 读取一个列表页的列数偏好。 |
| [`_setListColumns`](#setlistcolumns) | 静态方法（私有） | A | 持久化一个列表页的列数偏好，自动时删除该键。 |
| `getDeviceListColumns` | 静态方法 | B | `_getListColumns('deviceListColumns')`：设备列表的列数偏好。 |
| `setDeviceListColumns` | 静态方法 | B | `_setListColumns('deviceListColumns', columns)`。 |
| `getNetworkListColumns` | 静态方法 | B | `_getListColumns('networkListColumns')`：网络列表的列数偏好。 |
| `setNetworkListColumns` | 静态方法 | B | `_setListColumns('networkListColumns', columns)`。 |
| `getDataSetListColumns` | 静态方法 | B | `_getListColumns('dataSetListColumns')`：数据集列表的列数偏好。 |
| `setDataSetListColumns` | 静态方法 | B | `_setListColumns('dataSetListColumns', columns)`。 |
| `getServiceListColumns` | 静态方法 | B | `_getListColumns('serviceListColumns')`：一个偏好服务设备、链路和端口三个视图；概览始终为单列。 |
| `setServiceListColumns` | 静态方法 | B | `_setListColumns('serviceListColumns', columns)`。 |
| `StoragePathResult` | 类 | B | `setStoragePath` 做了什么：路径是否已记录，以及移动留下了哪些条目。 |
| `saved` | 字段（`StoragePathResult`） | B | 新路径是否已记录；false 表示什么都没变。 |
| `unmoved` | 字段（`StoragePathResult`） | B | 移动留在旧文件夹中的相对路径；全部移动或无需移动时为空。 |
| `from` | 字段（`StoragePathResult`） | B | 存放未移动条目的旧文件夹；未移动任何东西时为 null。 |
| [`StoragePathResult`](#storagepathresult-new) | 构造函数 | A | 创建结果；`saved` 默认为 true，`unmoved` 默认为空。 |
| [`complete`](#complete) | getter（`StoragePathResult`） | A | 变更是否完全成功：已保存且未留下任何东西。 |

行数（44）比 `grep -c '/// Purpose:' device_storage.dart`（34）多十。32 个静态方法（包括八个列表列数访问器中的每一个）各有自己的行和自己的 `Purpose:` 块，`StoragePathResult` 构造函数及其 `complete` getter 也是。多出的十行是 `DeviceStorage` 类本身、私有静态常量 `_dataFileName` 和 `_configFileName`、私有静态字段 `_customPath`、`_configLoaded` 和 `_strayCheckedFor`、`StoragePathResult` 类，以及其字段 `saved`、`unmoved` 和 `from`，它们带普通 `///` 描述或没有注释，因每个声明都出现在表中而列出。Tier A：26 行。

## 文档

### `static Future<Directory> _getDefaultAppDir()` <a id="_getdefaultappdir"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 32 行）。
- **用途：** 解析默认 `<Documents>/MyDevice` 目录，缺失时创建。
- **输入：** 无。
- **返回：** `Future<Directory>`。
- **副作用：** 目录尚不存在时创建（递归）。
- **算法：** `getApplicationDocumentsDirectory()` 然后连接 `'MyDevice'`；缺席时递归创建。
- **用法：** 未配置自定义路径时被 [`getAppDir`](#getappdir) 调用。
- **备注：** 这是用户从设置更改存储位置前使用的目录。

### `static Future<File> _getConfigFile()` <a id="_getconfigfile"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 47 行）。
- **用途：** 解析 `storage_config.json` 文件路径，无论配置任何自定义存储路径它总是住在*默认*应用目录。
- **输入：** 无。
- **返回：** `Future<File>`。
- **副作用：** 无（不创建文件）。
- **算法：** 把 `_getDefaultAppDir()` 路径与 `_configFileName` 连接。
- **用法：** 被 [`_loadCustomPath`](#_loadcustompath)、[`_adoptStrayConfig`](#_adoptstrayconfig)、[`_readConfigFromDefault`](#_readconfigfromdefault) 和 [`_writeConfigToDefault`](#_writeconfigtodefault) 调用。
- **备注：** 刻意绕过 `getAppDir()`/任何自定义路径——即使它命名的自定义路径本身无效或在未挂载存储上，此文件也必须可发现，否则应用永远无法恢复存储路径设置。

### `static Future<void> _loadCustomPath()` <a id="_loadcustompath"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 58 行）。
- **用途：** 从 `storage_config.json` 把自定义存储路径（如有）加载进静态 `_customPath` 缓存，每进程恰好一次。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 读取 `storage_config.json`；设置静态 `_customPath`/`_configLoaded` 字段。
- **算法：** 1. `_configLoaded` 已为 true 时立即返回（不重读）。2. 否则在吞掉任何错误（缺失文件、格式错误 JSON）的 `try`/`catch` 内读取并解析配置文件，提取 `json['storagePath']`。3. 即使出错也无条件设 `_configLoaded = true`，使损坏配置文件不强制每次调用重读尝试。
- **用法：** 在 [`getAppDir`](#getappdir) 和 [`_adoptStrayConfig`](#_adoptstrayconfig) 开头调用。
- **备注：** 格式错误配置文件被当作与"无自定义路径"相同（回退默认）而非向调用方浮出错误。

### `static Future<Directory> getAppDir()` <a id="getappdir"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 78 行）。
- **用途：** 解析应用当前数据目录——已设且非空的自定义路径，否则默认 `<Documents>/MyDevice` 目录。
- **输入：** 无。
- **返回：** `Future<Directory>`。
- **副作用：** 解析目录尚不存在时创建。
- **算法：** 确保 `_loadCustomPath()` 已运行；`_customPath` 已设且非空时返回（需要时创建）那个目录；否则委托 `_getDefaultAppDir()`。
- **用法：**
  ```dart
  final appDir = await DeviceStorage.getAppDir();
  ```
  （来自 `NetworkStorage`/`DataSetStorage` 的等价目录解析器，和本文件每个其他方法内部）——`DeviceStorage.getAppDir()` 是本应用*所有*数据文件（不只设备数据）住在哪里的单一真相源。
- **备注：** 因为其他功能存储调用此相同方法，经 [`setStoragePath`](#setstoragepath) 更改存储路径移动每个模块的数据，不只设备。

### `static Future<String> getStoragePath()` <a id="getstoragepath"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 96 行）。
- **用途：** 返回当前存储目录绝对路径，供设置显示。
- **输入：** 无。
- **返回：** `Future<String>`。
- **副作用：** 除 `getAppDir()` 的目录创建副作用外无。
- **算法：** `(await getAppDir()).path`。
- **用法：**
  ```dart
  final path = await DeviceStorage.getStoragePath();
  ```
  （来自 `settings_page.dart`，显示当前存储位置）
- **备注：** 无。

### `static Future<StoragePathResult> setStoragePath(String? newPath)` <a id="setstoragepath"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 127 行）。
- **用途：** 更改应用存储位置，把旧存储文件夹中的一切移到新位置，并报告移动留下了什么。
- **输入：** `newPath` — 新自定义路径，或 `null`/空回退默认目录。
- **返回：** `Future<StoragePathResult>`（见 [`StoragePathResult`](#storagepathresult-new)）— 只有异常逸出时（例如读写 `storage_config.json` 时）为 `saved: false`，此时什么都没变；否则为 `saved: true`，`unmoved` 列出仍在旧文件夹中的相对路径，`from` 给出该文件夹（路径未变时分别为空和 null）。
- **副作用：** 可能先收编游离配置（[`_adoptStrayConfig`](#_adoptstrayconfig)）；设置 `_customPath`；把 `storagePath` 持久化到默认目录的 `storage_config.json`；经 `myapps_data` 的 `migrateStorageContents`（`packages/myapps_data/lib/src/storage/storage_migration.dart`）把旧文件夹内容移入新文件夹。
- **算法：** 1. `_adoptStrayConfig()`，使当前自定义文件夹中的游离副本在该文件夹被清空前合并。2. 把当前目录捕获为 `oldDir`。3. 设 `_customPath = newPath`，并经 [`_readConfigFromDefault`](#_readconfigfromdefault) / [`_writeConfigToDefault`](#_writeconfigtodefault) 持久化进 `storage_config.json`，`newPath` 为 null 或空时移除该键。4. 经 `getAppDir()`（会创建目录）解析 `newDir`；其路径等于 `oldDir` 时返回 `const StoragePathResult()`（无需移动）。5. `await migrateStorageContents(from: oldDir, to: newDir)`：除 `storage_config.json` 外的每个顶层文件和目录逐文件复制进 `newDir`，每个原件在复制后删除；源目录只在变空后才移除。它返回未能移动的路径。6. 把这些路径与 [`_leftoverEntries(oldDir)`](#_leftoverentries) 求并集——后者也捕获因目标已有同名文件而被跳过的文件——排序，并返回 `StoragePathResult(unmoved: ..., from: oldDir.path)`。整个方法体位于返回 `StoragePathResult(saved: false)` 的 `try`/`catch` 中。
- **用法：**
  ```dart
  final result = await DeviceStorage.setStoragePath(pathToSet);
  ```
  （来自 `settings_page.dart` 的"更改存储位置"流程，它显示失败 snackbar、在 `result.from` 下列出 `result.unmoved` 的对话框，或通常的成功 snackbar——见 [`_showStoragePathDialog`](../../settings/views/settings_page.md#_showstoragepathdialog)）
- **备注：** 移动覆盖整个文件夹而非枚举列表：全部四个数据文件、`images/`、`.sync_base/`、含 `backups/blobs/` 的 `backups/` 以及 `webdav_config.json`，因此以后新增的数据文件会自动随之移动。它取代了按目录复制的旧做法：旧做法把 `backups/blobs/` 留在原处（恢复的备份丢失其图像），并完全漏掉 `.sync_base/`，使下一次同步把其他设备已删除的记录当作新的本地记录并使其复活。目标位置已存在的文件胜出，其源副本留在原处，因此不会凭对哪个副本更新的猜测丢弃任何东西——但该副本应用已无法读取，所以它与失败项一起被报告。`storage_config.json` 留在平台默认目录：它保存自定义路径本身和其他每个偏好，[`readConfig`](#readconfig)/[`writeConfig`](#writeconfig) 总是使用那个副本，因此移动从不触及偏好。（1.5.7 之前偏好从当前存储文件夹读取，因此移动后看似被重置。）`test/storage_path_test.dart` 覆盖跨移动的偏好以及因目标已被占用而留下的条目。

### `static Future<List<String>> _leftoverEntries(Directory oldDir)` <a id="_leftoverentries"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 166 行）。
- **用途：** 列出存储移动留在旧文件夹中的文件。
- **输入：** `oldDir` — 数据移出的文件夹。
- **返回：** `Future<List<String>>` — 仍在 `oldDir` 下的每个文件相对于它的路径，顶层 `storage_config.json` 除外；文件夹不存在或无法列出时为空。
- **副作用：** 列出该文件夹（递归，不跟随链接）。
- **算法：** `oldDir` 不存在时返回 `[]`。否则遍历 `oldDir.list(recursive: true, followLinks: false)`，只保留 `File` 实体，并在 `p.relative(entity.path, from: oldDir.path)` 不等于 `_configFileName` 时加入它。任何异常都被吞掉，返回已收集的列表。
- **用法：** 移动后被 [`setStoragePath`](#setstoragepath) 调用。
- **备注：** `migrateStorageContents` 报告复制失败的文件，但不报告因目标已有同名文件而跳过的文件；两者都留在原处且应用看不到，因此以旧文件夹本身为准。空目录不列出。

### `static Future<void> _adoptStrayConfig()` <a id="_adoptstrayconfig"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 198 行）。
- **用途：** 收编旧构建写进自定义存储文件夹的 `storage_config.json`。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 设置 `_strayCheckedFor`；可能重写默认文件夹的 `storage_config.json` 并删除游离文件。
- **算法：** 1. `_loadCustomPath()`。2. 没有自定义路径或 `_strayCheckedFor` 已等于它时返回；否则把它记入 `_strayCheckedFor`。3. 在吞掉一切异常的 `try`/`catch` 内：解析游离文件 `<custom>/storage_config.json`；它就是默认配置文件本身（`p.equals`）或不存在时返回。4. 解析它（空文件算 `{}`），按 `{...default, ...stray}` 合并使游离键胜出，把 `storagePath` 强制设回自定义路径，经 [`_writeConfigToDefault`](#_writeconfigtodefault) 写出结果，然后删除游离文件。
- **用法：** 被 [`setStoragePath`](#setstoragepath)、[`readConfig`](#readconfig) 和 [`writeConfig`](#writeconfig) 最先调用。
- **备注：** 1.5.7 之前 `readConfig`/`writeConfig` 使用当前存储文件夹，而自定义路径位于默认文件夹，因此移动后偏好看似被重置，新偏好写进自定义文件夹里的第二个文件；那些是较新的值，所以它们胜出。`storagePath` 是例外，因为只有默认文件可以保存它。每进程对每个自定义路径检查一次；无法读取或解析的游离文件留在原处（直到自定义路径改变或应用重启才会重试）。

### `static Future<Map<String, dynamic>> _readConfigFromDefault()` <a id="_readconfigfromdefault"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 228 行）。
- **用途：** 从默认目录读取 `storage_config.json`——偏好和自定义路径的唯一副本。
- **输入：** 无。
- **返回：** `Future<Map<String, dynamic>>` — 文件缺席或为空时 `{}`。
- **副作用：** 无（只读）。
- **算法：** 存在性检查、空内容检查，然后 `jsonDecode`。
- **用法：** 被 [`setStoragePath`](#setstoragepath)、[`_adoptStrayConfig`](#_adoptstrayconfig) 和 [`readConfig`](#readconfig) 调用。
- **备注：** 经 [`_getConfigFile`](#_getconfigfile) 解析，从不经 `getAppDir()`：存储路径设置必须无论当前指向哪里都能被找到，而把每个偏好都放在它旁边意味着移动永远不会把偏好丢在后面。

### `static Future<void> _writeConfigToDefault(Map<String, dynamic> config)` <a id="_writeconfigtodefault"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 242 行）。
- **用途：** 向默认目录写 `storage_config.json`。
- **输入：** `config`。
- **返回：** `Future<void>`。
- **副作用：** 写 `storage_config.json`（美化打印、非原子直接写）。
- **算法：** `JsonEncoder.withIndent('  ')` 然后 `writeAsString`。
- **用法：** 被 [`setStoragePath`](#setstoragepath)、[`_adoptStrayConfig`](#_adoptstrayconfig) 和 [`writeConfig`](#writeconfig) 调用。
- **备注：** 非原子（无临时文件然后重命名），不同于 `WebDAVService`（`../../../../shared/services/webdav_service.md`）中同步关键的写——这是小本地设置文件，非四个同步数据文件之一。

### `static Future<File> _getFile(String name)` <a id="_getfile"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 254 行）。
- **用途：** 解析*当前*应用目录内命名文件（尊重任何自定义存储路径）。
- **输入：** `name` — 裸文件名（如 `device_data.json`）。
- **返回：** `Future<File>`。
- **副作用：** 除 `getAppDir()` 的目录创建副作用外无。
- **算法：** `File(p.join((await getAppDir()).path, name))`。
- **用法：** 被 [`load`](#load) 和 [`save`](#save) 调用。[`DeviceExchangeRateService._getFile`](exchange_rate_service.md#_getfile) 不调用它；它直接把自己的文件名拼接到 [`getAppDir`](#getappdir) 上。
- **备注：** 1.5.7 之前 [`readConfig`](#readconfig)/[`writeConfig`](#writeconfig) 也经此方法解析 `storage_config.json`，偏好正是因此落进了自定义文件夹。

### `static Future<DeviceData> load()` <a id="load"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 266 行）。
- **用途：** 从 `device_data.json` 加载持久化设备列表。
- **输入：** 无。
- **返回：** `Future<DeviceData>` — 文件缺席或为空时 `const DeviceData()`（空）。
- **副作用：** 读取 `device_data.json`。
- **算法：** 存在性/空检查，然后 `DeviceData.fromJson(jsonDecode(...))`（见 [`device.md`](../models/device.md#devicedata-fromjson)）。
- **用法：**
  ```dart
  final data = await DeviceStorage.load();
  ```
  （来自 `device_list_page.dart`、`dataset_edit_page.dart`、`dataset_list_page.dart` 和其他需要只读设备列表的模块）
- **备注：** 无。

### `static Future<void> save(DeviceData data)` <a id="save"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 280 行）。
- **用途：** 把完整设备列表持久化到 `device_data.json` 并通知自动同步服务本地数据已变。
- **输入：** `data`。
- **返回：** `Future<void>`。
- **副作用：** 写 `device_data.json`（美化打印、非原子）；调用 `AutoSyncService.instance.notifySaved()`（见 [`auto_sync_service.md`](../../../shared/services/auto_sync_service.md)）。
- **算法：** JSON 编码 `data.toJson()`、写它、然后通知自动同步。
- **用法：**
  ```dart
  await DeviceStorage.save(DeviceData(devices: _devices));
  ```
  （来自 `device_list_page.dart`，本地重排/编辑后）
- **备注：** 设备列表每次写入都应经此方法（直接或经 [`addOrUpdate`](#addorupdate)/[`deleteDevice`](#deletedevice)），使 `AutoSyncService` 总是被通知。

### `static Future<void> addOrUpdate(Device device)` <a id="addorupdate"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 293 行）。
- **用途：** 插入新设备或替换既有设备（按 `id` 匹配），然后设备不再在用时清理跨模块引用。
- **输入：** `device`。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `device_data.json`；可能调用 [`_removeDeviceReferences`](#_removedevicereferences)。
- **算法：** 1. 加载当前列表。2. 找相同 `id` 的既有设备索引；找到替换否则追加。3. 保存。4. `!device.isInService`（退役或出售——见 [`device.md`](../models/device.md#lifecyclestatus)）时从网络分配、数据集存储链接和服务记录移除此设备引用。
- **用法：**
  ```dart
  await DeviceStorage.addOrUpdate(device);
  ```
  （来自 `device_edit_page.dart` 的保存处理器，和 `local_api_server.dart` 本地 HTTP API 设备更新端点）
- **备注：** 这正是"退役/出售设备必须从网络/存储选择器移除"级联规则（[设备 — 退役/出售/删除的级联规则](../../../../features/devices.md#cascade-rules-on-retiresell-delete) 文档化）被触发的地方——每次把设备翻出服务的保存都运行与彻底删除相同的清理。

### `static Future<void> deleteDevice(String id)` <a id="deletedevice"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 314 行）。
- **用途：** 按 id 删除设备并清理每个对它的跨模块引用。
- **输入：** `id`。
- **返回：** `Future<void>`。
- **副作用：** 重写 `device_data.json`；调用 [`_removeDeviceReferences`](#_removedevicereferences)。
- **算法：** 把设备从加载列表过滤、保存，然后清理引用。
- **用法：**
  ```dart
  await DeviceStorage.deleteDevice(device.id);
  ```
  （来自 `device_list_page.dart` 的删除确认流程）
- **备注：** 无。

### `static Future<void> _removeDeviceReferences(String id)` <a id="_removedevicereferences"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 326 行）。
- **用途：** 从网络分配、数据集存储链接和服务记录剥离对设备 id 的每个引用——退役/出售设备和彻底删除两者使用的共享清理。
- **输入：** `id`。
- **返回：** `Future<void>`。
- **副作用：** 可能经 `NetworkStorage.save` 重写 `network_data.json` 和/或经 `DataSetStorage.save` 重写 `dataset_data.json`；总是调用 `ServiceStorage.removeDeviceReferences(id)`。
- **算法：** 1. 加载网络数据；过滤掉任何 `deviceId == id` 的赋值；只在实际移除东西时保存（长度比较）。2. 加载数据集数据；对每个数据集过滤其 `storageLinks` 丢弃引用 `id` 的条目，跟踪是否*任何*数据集变化；至少一个变时才保存整个数据集列表。3. 无条件委托 `ServiceStorage.removeDeviceReferences(id)` 做服务记录/路由清理。
- **用法：** 被 [`addOrUpdate`](#addorupdate)（设备离开服务时）和 [`deleteDevice`](#deletedevice) 两者调用。
- **备注：** 这是 [设备 — 退役/出售/删除的级联规则](../../../../features/devices.md#cascade-rules-on-retiresell-delete) 的"删除设备必须移除相关网络分配、数据集存储链接、服务记录和服务路由引用"规则的唯一实现——网络和数据集清理条件保存（只在实际变化时），而服务清理无论那里是否实际变化都无条件委托。

### `static Future<Map<String, dynamic>> readConfig()` <a id="readconfig"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 372 行）。
- **用途：** 读取应用本地偏好——默认文件夹 `storage_config.json` 中的通用键/值映射，用于主题、语言区域、默认货币、列表列数和其他不值得单独文件简单设置的共享配置存储。
- **输入：** 无。
- **返回：** `Future<Map<String, dynamic>>` — 缺席/为空时 `{}`。
- **副作用：** 可能先从自定义存储文件夹收编游离配置（[`_adoptStrayConfig`](#_adoptstrayconfig)）；从默认文件夹读取 `storage_config.json`。
- **算法：** `await _adoptStrayConfig()`，然后 [`_readConfigFromDefault`](#_readconfigfromdefault)（存在性/空检查，然后 `jsonDecode`）。
- **用法：**
  ```dart
  final config = await DeviceStorage.readConfig();
  return (config['defaultCurrency'] as String? ?? defaultDefaultCurrency).toUpperCase();
  ```
  （来自 [`exchange_rate_service.md`](exchange_rate_service.md) 的 `getDefaultCurrency`；也被 `dataset_list_page.dart` 直接用于自己的小配置标志）
- **备注：** 这是通用、模型无关映射——任何模块无需共享模式就能在此存自己的键，精神上类似应用别处的 `extraJson` 保留，但是本地设置而非同步记录。无论存储路径如何文件都是同一个——平台默认文件夹中、与 `storagePath` 并列的那个——因此移动数据从不重置偏好。1.5.7 之前它读取*当前*存储文件夹，而移动后那里并不存在配置。

### `static Future<void> writeConfig(Map<String, dynamic> config)` <a id="writeconfig"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 385 行）。
- **用途：** 把应用本地偏好写回默认文件夹的 `storage_config.json`。
- **输入：** `config` — 典型经 [`readConfig`](#readconfig) 读取、修改、然后传回。
- **返回：** `Future<void>`。
- **副作用：** 可能先收编游离配置（[`_adoptStrayConfig`](#_adoptstrayconfig)）；重写默认文件夹中的 `storage_config.json`（美化打印、非原子）。
- **算法：** `await _adoptStrayConfig()`；复制 `config`，移除 `storagePath`，当前 `_customPath` 已设且非空时把它放回 `storagePath`，然后 [`_writeConfigToDefault`](#_writeconfigtodefault)。
- **用法：**
  ```dart
  config['defaultCurrency'] = currency.toUpperCase();
  await DeviceStorage.writeConfig(config);
  ```
  （来自 `exchange_rate_service.md` 的 `setDefaultCurrency`）
- **备注：** 调用方必须读-改-写（无合并辅助）——并发写者可破坏彼此键，但此文件只从单线程 UI/本地 API 层写，绝无后台 isolate。`storagePath` 归 [`setStoragePath`](#setstoragepath) 所有：`config` 在该键下的任何内容都被替换为当前自定义路径，没有自定义路径时被移除，因此偏好写入永远不会移动或丢失数据（由 `test/storage_path_test.dart` 覆盖）。

### `static Future<String?> getThemeMode()` <a id="getthememode"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 398 行）。
- **用途：** 读取持久化主题模式字符串（`'light'`/`'dark'`/`'system'`，或未设）。
- **输入：** 无。
- **返回：** `Future<String?>`。
- **副作用：** 经 [`readConfig`](#readconfig) 读取 `storage_config.json`。
- **算法：** `(await readConfig())['themeMode'] as String?`。
- **用法：**
  ```dart
  final modeStr = await DeviceStorage.getThemeMode();
  ```
  （来自 `app_settings.md` 的 `AppSettings` 初始化）
- **备注：** 无。

### `static Future<void> setThemeMode(String? mode)` <a id="setthememode"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 408 行）。
- **用途：** 持久化主题模式字符串，`mode` 为 null 时完全清除。
- **输入：** `mode`。
- **返回：** `Future<void>`。
- **副作用：** 读取然后重写 `storage_config.json`。
- **算法：** 读取配置；`mode` 为 null 时 `remove('themeMode')`，否则设置它；写回。
- **用法：**
  ```dart
  DeviceStorage.setThemeMode(str);
  ```
  （来自 `AppSettings`，主题变化即发即忘）
- **备注：** 无。

### `static Future<String?> getLocaleTag()` <a id="getlocaletag"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 423 行）。
- **用途：** 读取持久化语言区域标签（如 `'en'`、`'zh'`），未设（跟随系统语言区域）为 `null`。
- **输入：** 无。
- **返回：** `Future<String?>`。
- **副作用：** 经 [`readConfig`](#readconfig) 读取 `storage_config.json`。
- **算法：** `(await readConfig())['locale'] as String?`。
- **用法：** 与 `getThemeMode` 一起从 `AppSettings` 初始化调用。
- **备注：** 无。

### `static Future<void> setLocaleTag(String? tag)` <a id="setlocaletag"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 433 行）。
- **用途：** 持久化语言区域标签，`tag` 为 null 时完全清除（恢复系统语言区域）。
- **输入：** `tag`。
- **返回：** `Future<void>`。
- **副作用：** 读取然后重写 `storage_config.json`。
- **算法：** 读取配置；`tag` 为 null 时 `remove('locale')`，否则设置它；写回。
- **用法：**
  ```dart
  DeviceStorage.setLocaleTag(null);   // follow system locale
  DeviceStorage.setLocaleTag(tag);    // pin to an explicit locale
  ```
  （来自 `AppSettings` 的语言区域变更处理器）
- **备注：** 无。

### `static Future<int> _getListColumns(String key)` <a id="getlistcolumns"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 451 行）。
- **用途：** 读取一个列表页的列数偏好。
- **输入：** `key` — 该页在 `storage_config.json` 中的键。
- **返回：** `Future<int>` — 已存的列数，键缺席、不是整数或超出 1..`listMaxColumns` 时为 `listColumnsAuto`。
- **副作用：** 经 `readConfig` 读 `storage_config.json`。
- **用法：** 四个 `get…ListColumns` 访问器。
- **备注：** 偏好在渲染时会再由 `listColumnCount` 按当前宽度钳制；这里只拒绝永远无效的值。

### `static Future<void> _setListColumns(String key, int columns)` <a id="setlistcolumns"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 466 行）。
- **用途：** 持久化一个列表页的列数偏好。
- **输入：** `key`；`columns` — `listColumnsAuto` 或钉住的列数。
- **返回：** 无。
- **副作用：** 读取并重写 `storage_config.json`。
- **用法：** 四个 `set…ListColumns` 访问器，由列表页以即发即忘方式调用。
- **备注：** 1..`listMaxColumns` 内的列数被存储；其他值删除该键，所以默认值在文件中缺席而非写成零——与 `setThemeMode` 一致。

### `const StoragePathResult({bool saved = true, List<String> unmoved = const [], String? from})` <a id="storagepathresult-new"></a>
- **种类：** `StoragePathResult` 的构造函数；该顶层类告诉调用方 [`setStoragePath`](#setstoragepath) 做了什么。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 560 行）。
- **用途：** 创建结果。
- **输入：** `saved` — 新路径是否已记录（默认 `true`；`false` 表示什么都没变）；`unmoved` — 移动留在旧文件夹中的相对路径（默认为空）；`from` — 存放它们的旧文件夹（未移动任何东西时为 null）。
- **返回：** 新的 `StoragePathResult`。
- **副作用：** 无。
- **算法：** 字段赋值。
- **用法：** 路径未变时 `setStoragePath` 返回 `const StoragePathResult()`，移动后返回 `StoragePathResult(unmoved: unmoved, from: oldDir.path)`，异常时返回 `const StoragePathResult(saved: false)`。
- **备注：** 未移动的条目在新位置无法被应用读取，因此调用方必须把 `unmoved` 告知用户；设置页用它的 `storage-unmoved-dialog` 做到这一点。

### `bool get complete` <a id="complete"></a>
- **种类：** `StoragePathResult` 的 getter。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 571 行）。
- **用途：** 报告变更是否完全成功。
- **输入：** 无。
- **返回：** `bool` — `saved && unmoved.isEmpty`。
- **副作用：** 无。
- **算法：** `saved && unmoved.isEmpty`。
- **用法：** 供只需要是/否的调用方和测试使用；`settings_page.dart` 分别检查 `saved` 和 `unmoved` 来选择提示。
- **备注：** 无。
