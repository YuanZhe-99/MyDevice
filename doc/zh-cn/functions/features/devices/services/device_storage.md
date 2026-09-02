# lib/features/devices/services/device_storage.dart

`DeviceStorage` 持久化设备列表（`device_data.json`），并兼作应用规范存储位置/配置服务：`getAppDir()` 被 `DataSetStorage` 和 `NetworkStorage`（`../../../network/services/network_storage.dart`、`../../../datasets/services/dataset_storage.dart`）调用，解析那些模块自己数据文件所在的*相同*应用目录，`readConfig`/`writeConfig` 支撑一个小的类 `storage_config.json` 通用键/值存储（`theme`、`locale`、`defaultCurrency`、`autoUpdateExchangeRates` 等），`AppSettings`（`../../../../shared/providers/app_settings.md`）和 [`exchange_rate_service.md`](exchange_rate_service.md) 也经它读写。本文件序列化的 `DeviceData`/`Device` JSON 形态见 [数据格式](../../../../data-formats.md)，`deleteDevice`/`addOrUpdate` 实现的级联删除规则见 [设备](../../../../features/devices.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`_getDefaultAppDir`](#_getdefaultappdir) | 静态方法（私有） | A | 解析（并创建）默认 `~/Documents/MyDevice` 目录。 |
| [`_getConfigFile`](#_getconfigfile) | 静态方法（私有） | A | 解析 `storage_config.json` 文件，总是在默认目录。 |
| [`_loadCustomPath`](#_loadcustompath) | 静态方法（私有） | A | 从配置加载自定义存储路径，每进程一次。 |
| [`getAppDir`](#getappdir) | 静态方法 | A | 解析应用数据目录（配置了自定义路径则自定义，否则默认）。 |
| [`getStoragePath`](#getstoragepath) | 静态方法 | A | 返回当前存储目录显示路径。 |
| [`setStoragePath`](#setstoragepath) | 静态方法 | A | 更改存储位置，需要时迁移数据/备份/图像。 |
| [`_readConfigFromDefault`](#_readconfigfromdefault) | 静态方法（私有） | A | 从默认（非自定义）目录读取 `storage_config.json`。 |
| [`_writeConfigToDefault`](#_writeconfigfromdefault) | 静态方法（私有） | A | 向默认目录写 `storage_config.json`。 |
| [`_getFile`](#_getfile) | 静态方法（私有） | A | 解析当前应用目录内命名文件。 |
| [`load`](#load) | 静态方法 | A | 加载持久化 `DeviceData`（设备列表）。 |
| [`save`](#save) | 静态方法 | A | 持久化 `DeviceData` 并通知自动同步服务。 |
| [`addOrUpdate`](#addorupdate) | 静态方法 | A | 按 id 插入或替换设备；离开服务时清理引用。 |
| [`deleteDevice`](#deletedevice) | 静态方法 | A | 按 id 删除设备并清理跨模块引用。 |
| [`_removeDeviceReferences`](#_removedevicereferences) | 静态方法（私有） | A | 剥离网络/数据集/服务对设备 id 的引用。 |
| [`readConfig`](#readconfig) | 静态方法 | A | 读取通用 `storage_config.json` 键/值映射。 |
| [`writeConfig`](#writeconfig) | 静态方法 | A | 写通用 `storage_config.json` 键/值映射。 |
| [`getThemeMode`](#getthememode) | 静态方法 | A | 读取持久化主题模式字符串。 |
| [`setThemeMode`](#setthememode) | 静态方法 | A | 持久化（或清除）主题模式字符串。 |
| [`getLocaleTag`](#getlocaletag) | 静态方法 | A | 读取持久化语言区域标签。 |
| [`setLocaleTag`](#setlocaletag) | 静态方法 | A | 持久化（或清除）语言区域标签。 |
| [`_getListColumns`](#getlistcolumns) | 静态方法 | A | 从 `storage_config.json` 读取一个列表页的列数偏好。 |
| [`_setListColumns`](#setlistcolumns) | 静态方法 | A | 持久化一个列表页的列数偏好，自动时删除该键。 |
| `getDeviceListColumns` / `setDeviceListColumns` | 静态方法 | B | 以 `deviceListColumns` 调用 `_getListColumns` / `_setListColumns`。 |
| `getNetworkListColumns` / `setNetworkListColumns` | 静态方法 | B | 同上，键为 `networkListColumns`。 |
| `getDataSetListColumns` / `setDataSetListColumns` | 静态方法 | B | 同上，键为 `dataSetListColumns`。 |
| `getServiceListColumns` / `setServiceListColumns` | 静态方法 | B | 同上，键为 `serviceListColumns`；一个偏好服务设备、链路和端口三个视图。 |

行数（26 行，30 个声明——四个成对访问器行各含两个）与 `grep -c 'Purpose:' device_storage.dart`（30）精确匹配。

## 文档

### `static Future<Directory> _getDefaultAppDir()` <a id="_getdefaultappdir"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 29 行）。
- **用途：** 解析默认 `<Documents>/MyDevice` 目录，缺失时创建。
- **输入：** 无。
- **返回：** `Future<Directory>`。
- **副作用：** 目录尚不存在时创建（递归）。
- **算法：** `getApplicationDocumentsDirectory()` 然后连接 `'MyDevice'`；缺席时递归创建。
- **用法：** 未配置自定义路径时被 [`getAppDir`](#getappdir) 调用。
- **备注：** 这是用户从设置更改存储位置前使用的目录。

### `static Future<File> _getConfigFile()` <a id="_getconfigfile"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 44 行）。
- **用途：** 解析 `storage_config.json` 文件路径，无论配置任何自定义存储路径它总是住在*默认*应用目录。
- **输入：** 无。
- **返回：** `Future<File>`。
- **副作用：** 无（不创建文件）。
- **算法：** 把 `_getDefaultAppDir()` 路径与 `_configFileName` 连接。
- **用法：** 被 [`_loadCustomPath`](#_loadcustompath)、[`_readConfigFromDefault`](#_readconfigfromdefault) 和 [`_writeConfigToDefault`](#_writeconfigfromdefault) 调用。
- **备注：** 刻意绕过 `getAppDir()`/任何自定义路径——即使它命名的自定义路径本身无效或在未挂载存储上，此文件也必须可发现，否则应用永远无法恢复存储路径设置。

### `static Future<void> _loadCustomPath()` <a id="_loadcustompath"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 55 行）。
- **用途：** 从 `storage_config.json` 把自定义存储路径（如有）加载进静态 `_customPath` 缓存，每进程恰好一次。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 读取 `storage_config.json`；设置静态 `_customPath`/`_configLoaded` 字段。
- **算法：** 1. `_configLoaded` 已为 true 时立即返回（不重读）。2. 否则在吞掉任何错误（缺失文件、格式错误 JSON）的 `try`/`catch` 内读取并解析配置文件，提取 `json['storagePath']`。3. 即使出错也无条件设 `_configLoaded = true`，使损坏配置文件不强制每次调用重读尝试。
- **用法：** 在 [`getAppDir`](#getappdir) 开头调用。
- **备注：** 格式错误配置文件被当作与"无自定义路径"相同（回退默认）而非向调用方浮出错误。

### `static Future<Directory> getAppDir()` <a id="getappdir"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 75 行）。
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
- **来源：** `lib/features/devices/services/device_storage.dart`（第 93 行）。
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

### `static Future<bool> setStoragePath(String? newPath)` <a id="setstoragepath"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 105 行）。
- **用途：** 更改应用存储位置，新位置尚无自己数据时把既有数据/备份/图像迁移到新位置。
- **输入：** `newPath` — 新自定义路径，或 `null`/空回退默认目录。
- **返回：** `Future<bool>` — 成功 `true`，任何步骤抛出 `false`。
- **副作用：** 把 `storagePath` 持久化到 `storage_config.json`（默认目录）；从旧位置复制（然后删除）`device_data.json`/`network_data.json`/`dataset_data.json`/`service_data.json` 加 `backups/` 和 `images/` 目录到新位置。
- **算法：** 1. 把当前目录捕获为 `oldDir`。2. 设 `_customPath = newPath` 并持久化进 `storage_config.json`（`newPath` 为 null/空时完全移除键）。3. 经 `getAppDir()` 解析 `newDir`；与 `oldDir` 相同则立即返回 `true`（无需迁移）。4. 对四个数据文件名各：新位置已有该文件则保持原样（其数据胜出）；否则旧位置有它则复制然后删除（移动语义）。5. 旧 `backups/` 目录存在且新位置尚无一个时创建新的并移动每个文件过去，然后移除旧目录。6. 对 `images/` 重复步骤 5。7. 把整个方法包在返回任何异常 `false` 的 `try`/`catch`。
- **用法：**
  ```dart
  final ok = await DeviceStorage.setStoragePath(pathToSet);
  ```
  （来自 `settings_page.dart` 的"更改存储位置"流程）
- **备注：** 对给定名称已有自己数据文件的位置绝不被覆盖——新位置副本总是胜过迁移旧副本，逐文件/目录，因此把应用指向既有 MyDevice 数据文件夹采用那个文件夹的数据而非破坏它。

### `static Future<Map<String, dynamic>> _readConfigFromDefault()` <a id="_readconfigfromdefault"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 185 行）。
- **用途：** 从默认目录读取 `storage_config.json`（只用于 `storagePath` 持久化，区别于从*当前*、可能自定义目录读取的通用 [`readConfig`](#readconfig)/[`writeConfig`](#writeconfig) 对）。
- **输入：** 无。
- **返回：** `Future<Map<String, dynamic>>` — 文件缺席或为空时 `{}`。
- **副作用：** 无（只读）。
- **算法：** 存在性检查、空内容检查，然后 `jsonDecode`。
- **用法：** 只被 [`setStoragePath`](#setstoragepath) 调用。
- **备注：** 刻意与对照 `getAppDir()`（*当前*、可能自定义目录）解析的 `readConfig()`/`_getFile()` 分离——存储路径设置本身必须总是住在默认目录，使无论它当前指向什么都能被找到。

### `static Future<void> _writeConfigToDefault(Map<String, dynamic> config)` <a id="_writeconfigfromdefault"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 199 行）。
- **用途：** 向默认目录写 `storage_config.json`。
- **输入：** `config`。
- **返回：** `Future<void>`。
- **副作用：** 写 `storage_config.json`（美化打印、非原子直接写）。
- **算法：** `JsonEncoder.withIndent('  ')` 然后 `writeAsString`。
- **用法：** 只被 [`setStoragePath`](#setstoragepath) 调用。
- **备注：** 非原子（无临时文件然后重命名），不同于 `WebDAVService`（`../../../../shared/services/webdav_service.md`）中同步关键的写——这是小本地设置文件，非四个同步数据文件之一。

### `static Future<File> _getFile(String name)` <a id="_getfile"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 211 行）。
- **用途：** 解析*当前*应用目录内命名文件（尊重任何自定义存储路径）。
- **输入：** `name` — 裸文件名（如 `device_data.json`）。
- **返回：** `Future<File>`。
- **副作用：** 除 `getAppDir()` 的目录创建副作用外无。
- **算法：** `File(p.join((await getAppDir()).path, name))`。
- **用法：** 被 [`load`](#load)、[`save`](#save)、[`readConfig`](#readconfig)、[`writeConfig`](#writeconfig) 和（经 `getAppDir` 间接）[`exchange_rate_service.md`](exchange_rate_service.md) 自己的文件解析调用。
- **备注：** 无。

### `static Future<DeviceData> load()` <a id="load"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 223 行）。
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
- **来源：** `lib/features/devices/services/device_storage.dart`（第 237 行）。
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
- **来源：** `lib/features/devices/services/device_storage.dart`（第 250 行）。
- **用途：** 插入新设备或替换既有设备（按 `id` 匹配），然后设备不再在用时清理跨模块引用。
- **输入：** `device`。
- **返回：** `Future<void>`。
- **副作用：** 经 [`save`](#save) 重写 `device_data.json`；可能调用 [`_removeDeviceReferences`](#_removedevicereferences)。
- **算法：** 1. 加载当前列表。2. 找相同 `id` 的既有设备索引；找到替换否则追加。3. 保存。4. `!device.isInService`（退役或出售——见 [`device.md`](../models/device.md#lifecyclestatus)）时从网络赋值、数据集存储链接和服务记录移除此设备引用。
- **用法：**
  ```dart
  await DeviceStorage.addOrUpdate(device);
  ```
  （来自 `device_edit_page.dart` 的保存处理器，和 `local_api_server.dart` 本地 HTTP API 设备更新端点）
- **备注：** 这正是"退役/出售设备必须从网络/存储选择器移除"级联规则（[设备 — 退役/出售/删除的级联规则](../../../../features/devices.md#cascade-rules-on-retiresell-delete) 文档化）被触发的地方——每次把设备翻出服务的保存都运行与彻底删除相同的清理。

### `static Future<void> deleteDevice(String id)` <a id="deletedevice"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 271 行）。
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
- **来源：** `lib/features/devices/services/device_storage.dart`（第 283 行）。
- **用途：** 从网络赋值、数据集存储链接和服务记录剥离对设备 id 的每个引用——退役/出售设备和彻底删除两者使用的共享清理。
- **输入：** `id`。
- **返回：** `Future<void>`。
- **副作用：** 可能经 `NetworkStorage.save` 重写 `network_data.json` 和/或经 `DataSetStorage.save` 重写 `dataset_data.json`；总是调用 `ServiceStorage.removeDeviceReferences(id)`。
- **算法：** 1. 加载网络数据；过滤掉任何 `deviceId == id` 的赋值；只在实际移除东西时保存（长度比较）。2. 加载数据集数据；对每个数据集过滤其 `storageLinks` 丢弃引用 `id` 的条目，跟踪是否*任何*数据集变化；至少一个变时才保存整个数据集列表。3. 无条件委托 `ServiceStorage.removeDeviceReferences(id)` 做服务记录/路由清理。
- **用法：** 被 [`addOrUpdate`](#addorupdate)（设备离开服务时）和 [`deleteDevice`](#deletedevice) 两者调用。
- **备注：** 这是 [设备 — 退役/出售/删除的级联规则](../../../../features/devices.md#cascade-rules-on-retiresell-delete) 的"删除设备必须移除相关网络赋值、数据集存储链接、服务记录和服务路由引用"规则的唯一实现——网络和数据集清理条件保存（只在实际变化时），而服务清理无论那里是否实际变化都无条件委托。

### `static Future<Map<String, dynamic>> readConfig()` <a id="readconfig"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 325 行）。
- **用途：** 从*当前*应用目录读取通用 `storage_config.json` 键/值映射——用于主题、语言区域、默认货币和其他不值得单独文件简单设置的共享配置存储。
- **输入：** 无。
- **返回：** `Future<Map<String, dynamic>>` — 缺席/为空时 `{}`。
- **副作用：** 读取 `storage_config.json`（经 [`_getFile`](#_getfile)，即从当前、可能自定义目录——区别于 [`_readConfigFromDefault`](#_readconfigfromdefault)）。
- **算法：** 存在性/空检查，然后 `jsonDecode`。
- **用法：**
  ```dart
  final config = await DeviceStorage.readConfig();
  return (config['defaultCurrency'] as String? ?? defaultDefaultCurrency).toUpperCase();
  ```
  （来自 [`exchange_rate_service.md`](exchange_rate_service.md) 的 `getDefaultCurrency`；也被 `dataset_list_page.dart` 直接用于自己的小配置标志）
- **备注：** 这是通用、模型无关映射——任何模块无需共享模式就能在此存自己的键，精神上类似应用别处的 `extraJson` 保留，但是本地设置而非同步记录。

### `static Future<void> writeConfig(Map<String, dynamic> config)` <a id="writeconfig"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 338 行）。
- **用途：** 把通用 `storage_config.json` 键/值映射写回当前应用目录。
- **输入：** `config` — 典型经 [`readConfig`](#readconfig) 读取、修改、然后传回。
- **返回：** `Future<void>`。
- **副作用：** 写 `storage_config.json`（美化打印、非原子）。
- **算法：** `JsonEncoder.withIndent('  ')` 然后 `writeAsString`。
- **用法：**
  ```dart
  config['defaultCurrency'] = currency.toUpperCase();
  await DeviceStorage.writeConfig(config);
  ```
  （来自 `exchange_rate_service.md` 的 `setDefaultCurrency`）
- **备注：** 调用方必须读-改-写（无合并辅助）——并发写者可破坏彼此键，但此文件只从单线程 UI/本地 API 层写，绝无后台 isolate。

### `static Future<String?> getThemeMode()` <a id="getthememode"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 350 行）。
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
- **来源：** `lib/features/devices/services/device_storage.dart`（第 360 行）。
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
- **来源：** `lib/features/devices/services/device_storage.dart`（第 375 行）。
- **用途：** 读取持久化语言区域标签（如 `'en'`、`'zh'`），未设（跟随系统语言区域）为 `null`。
- **输入：** 无。
- **返回：** `Future<String?>`。
- **副作用：** 经 [`readConfig`](#readconfig) 读取 `storage_config.json`。
- **算法：** `(await readConfig())['locale'] as String?`。
- **用法：** 与 `getThemeMode` 一起从 `AppSettings` 初始化调用。
- **备注：** 无。

### `static Future<void> setLocaleTag(String? tag)` <a id="setlocaletag"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`（第 385 行）。
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
- **种类：** `DeviceStorage` 的静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`。
- **用途：** 读取一个列表页的列数偏好。
- **输入：** `key` — 该页在 `storage_config.json` 中的键。
- **返回：** `Future<int>` — 已存的列数，键缺席、不是整数或超出 1..`listMaxColumns` 时为 `listColumnsAuto`。
- **副作用：** 经 `readConfig` 读 `storage_config.json`。
- **用法：** 四个 `get…ListColumns` 访问器。
- **备注：** 偏好在渲染时会再由 `listColumnCount` 按当前宽度钳制；这里只拒绝永远无效的值。

### `static Future<void> _setListColumns(String key, int columns)` <a id="setlistcolumns"></a>
- **种类：** `DeviceStorage` 的静态方法。
- **来源：** `lib/features/devices/services/device_storage.dart`。
- **用途：** 持久化一个列表页的列数偏好。
- **输入：** `key`；`columns` — `listColumnsAuto` 或钉住的列数。
- **返回：** 无。
- **副作用：** 读取并重写 `storage_config.json`。
- **用法：** 四个 `set…ListColumns` 访问器，由列表页以即发即忘方式调用。
- **备注：** 1..`listMaxColumns` 内的列数被存储；其他值删除该键，所以默认值在文件中缺席而非写成零——与 `setThemeMode` 一致。
