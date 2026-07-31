# lib/features/settings/views/settings_page.dart

`SettingsPage` 是应用顶层设置屏：主题/语言区域/货币偏好（经 [`appSettingsProvider`](../../../shared/providers/app_settings.md)）、数据导出/导入/存储位置、仅桌面托盘/自动启动/本地 API 服务器小节，并链接到 [`WebDAVConfigPage`](../../../shared/views/webdav_config_page.md)、[`BackupPage`](backup_page.md)、[`PrivacyPolicyPage`](privacy_policy_page.md) 和 [`LicensePage`](license_page.md)。它经 [`AutoSyncService`](../../../shared/services/auto_sync_service.md) 内联浮出 WebDAV 同步健康，并驱动 [`ImportExportService`](../../../shared/services/import_export_service.md) 做 ZIP/Markdown 导出和 ZIP 导入——那些调用依赖的格式细节和路径遍历保护见 [备份、恢复与导出 — ZIP 导出/导入](../../../../backup-restore.md#zip-exportimport)。仅桌面小节遵循 [平台说明 — 桌面本地 API 服务器](../../../../platform-notes.md#desktop-local-api-server)。

**行数说明：** `grep -c 'Purpose:' settings_page.dart` 返回 **21**，与本文件 21 个真实声明精确匹配——每个块都恰好坐在其文档化声明上方；本文件无错附块、无未文档化声明。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `SettingsPage`（构造函数） | 构造函数 | B | 创建页面组件（无参数）。 |
| `createState` | 方法（`SettingsPage`） | B | 创建页面可变状态对象。 |
| [`initState`](#initstate) | 方法（组件生命周期） | A | 注册同步状态监听器并启动所有初始设置加载。 |
| `_refreshSyncStatus` | 方法（`_SettingsPageState`） | B | 响应 `AutoSyncService` 状态变化重建。 |
| `dispose` | 方法（组件生命周期） | B | 注销同步状态监听器。 |
| [`_webDavStatusText`](#_webdavstatustext) | 方法（`_SettingsPageState`） | A | 为设置块副标题构建短 WebDAV 同步状态行。 |
| [`_loadStoragePath`](#_loadstoragepath) | 方法（`_SettingsPageState`） | A | 加载当前设备数据存储路径。 |
| [`_loadVersion`](#_loadversion) | 方法（`_SettingsPageState`） | A | 加载应用版本/构建号供显示。 |
| [`_loadExchangeRateSettings`](#_loadexchangeratesettings) | 方法（`_SettingsPageState`） | A | 加载默认货币和自动更新汇率标志。 |
| `_buildSection` | 方法（组件辅助） | B | 渲染一个带标题的设置小节。 |
| `_isDesktop` | getter（`_SettingsPageState`） | B | 应用是否运行在桌面平台。 |
| [`_exportData`](#_exportdata) | 方法（`_SettingsPageState`） | A | 让用户选 ZIP 或 Markdown 导出并写到所选文件夹。 |
| [`_importData`](#_importdata) | 方法（`_SettingsPageState`） | A | 让用户挑 ZIP 备份并在确认后导入。 |
| [`_openDataFolder`](#_opendatafolder) | 方法（`_SettingsPageState`） | A | 在操作系统文件管理器打开应用数据目录。 |
| [`_showStoragePathDialog`](#_showstoragepathdialog) | 方法（`_SettingsPageState`） | A | 让用户设置或重置自定义设备数据存储路径。 |
| [`_loadTraySettings`](#_loadtraysettings) | 方法（`_SettingsPageState`） | A | 加载持久化最小化到托盘/关闭到托盘标志。 |
| [`_loadAutoStartStatus`](#_loadautostartstatus) | 方法（`_SettingsPageState`） | A | 查询启动时启动当前是否启用。 |
| [`_loadApiSettings`](#_loadapisettings) | 方法（`_SettingsPageState`） | A | 加载持久化本地 API 服务器设置。 |
| [`_showApiSettingsDialog`](#_showapisettingsdialog) | 方法（`_SettingsPageState`） | A | 让用户编辑并保存本地 API 服务器设置，然后重启服务器。 |
| [`_refreshExchangeRates`](#_refreshexchangerates) | 方法（`_SettingsPageState`） | A | 手动刷新并保存最新汇率。 |
| `build` | 方法（组件） | B | 渲染通用/数据/桌面/关于小节。 |

## 文档

### `void initState()` <a id="initstate"></a>
- **种类：** `_SettingsPageState` 的方法（组件生命周期覆盖）
- **来源：** `lib/features/settings/views/settings_page.dart`（第 62 行）
- **用途：** 注册本页接收后台同步状态变化并启动页面需要的每个设置加载，含仅桌面的。
- **输入：** 无。
- **返回：** `None`。
- **副作用：** 把 `_refreshSyncStatus` 注册到 `AutoSyncService.instance.addOnStatusChanged`；启动几个独立异步加载链（这里都不 await）。
- **算法：**
  1. 调用 `super.initState()`。
  2. 即发即忘调用 `_loadVersion()`、`_loadStoragePath()`、`_loadExchangeRateSettings()`。
  3. 把 `_refreshSyncStatus` 注册为 `AutoSyncService` 状态变更监听器，使 WebDAV 状态副标题随后台同步完成保持最新。
  4. `_isDesktop` 时额外即发即忘调用 `_loadTraySettings()`、`_loadAutoStartStatus()`、`_loadApiSettings()`。
- **用法：** `_SettingsPageState` 首次插入树时由 Flutter 框架自动调用。
- **备注：** 对应 `dispose()`（第 90 行）调用 `AutoSyncService.instance.removeOnStatusChanged(_refreshSyncStatus)` 避免泄漏监听器。

### `String? _webDavStatusText(AppLocalizations l10n)` <a id="_webdavstatustext"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 100 行）
- **用途：** 为设置块副标题产生单行 WebDAV 同步健康摘要，尚无可报告时 `null`。
- **输入：** `l10n`。
- **返回：** `String?` — 错误/冲突行、上次成功行或 `null`。
- **副作用：** 无（只读 `AutoSyncService.instance` 字段）。
- **算法：**
  1. `AutoSyncService.instance.lastError` 已设时按 `hasPendingConflicts` 返回冲突风格或普通失败行。
  2. 否则 `lastSuccessAt` 已设时返回带本地时间戳的上次成功行。
  3. 否则返回 `null`（尚无同步运行）。
- **用法：** `build` 顶部 `final webDavStatus = _webDavStatusText(l10n);`（`lib/features/settings/views/settings_page.dart`，第 522 行），显示为 WebDAV 同步块副标题，`lastError` 已设时用 error 色样式。
- **备注：** 与 [`webdav_config_page.dart`](../../../shared/views/webdav_config_page.md#_syncstatustext) 的 `_syncStatusText` 结构相同——两者都读相同 `AutoSyncService` 字段构建相同三态状态行，一次供设置块副标题、一次供 WebDAV 页本身。

### `Future<void> _loadStoragePath()` <a id="_loadstoragepath"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 118 行）
- **用途：** 加载当前配置设备数据存储路径供显示。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `DeviceStorage.getStoragePath()`；挂载时 `setState`。
- **算法：** Await `DeviceStorage.getStoragePath()`，然后仍挂载时设 `_storagePath`。
- **用法：** 从 [`initState`](#initstate) 调用；成功路径更改后从 [`_showStoragePathDialog`](#_showstoragepathdialog) 重新调用。
- **备注：** 无。

### `Future<void> _loadVersion()` <a id="_loadversion"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 128 行）
- **用途：** 加载运行中应用版本和构建号供关于小节。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `PackageInfo.fromPlatform()`；挂载时 `setState`。
- **算法：** Await `PackageInfo.fromPlatform()`，然后仍挂载时设 `_version` 为 `'${info.version}+${info.buildNumber}'`。
- **用法：** 从 [`initState`](#initstate) 调用一次；结果 `_version` 字符串也传入 `build` 中 `showLicensePage(applicationVersion: _version)`。
- **备注：** 无。

### `Future<void> _loadExchangeRateSettings()` <a id="_loadexchangeratesettings"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 140 行）
- **用途：** 加载用户默认货币和自动汇率更新是否启用。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `DeviceExchangeRateService.getDefaultCurrency()` 和 `getAutoUpdateEnabled()`；挂载时 `setState`。
- **算法：** Await 两个服务调用，然后在一次 `setState` 一起设 `_defaultCurrency` 和 `_autoUpdateExchangeRates`。
- **用法：** 从 [`initState`](#initstate) 调用一次。
- **备注：** 无。

### `Future<void> _exportData()` <a id="_exportdata"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 186 行）
- **用途：** 让用户选 ZIP 或 Markdown 导出格式、挑目标文件夹并写导出。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 显示格式选择对话框和目录选择器（`FilePicker`）；调用 `ImportExportService.exportMarkdown` 或 `exportZip`（写文件到磁盘）；显示 snackbar。
- **算法：**
  1. 显示带"Export as ZIP" / "Export as Markdown"选项的 `SimpleDialog`；关闭返回。
  2. 经 `FilePicker.platform.getDirectoryPath()` 提示目标目录；取消返回。
  3. 按先前选择调用 `ImportExportService.exportMarkdown(dir)` 或 `exportZip(dir)`。
  4. 返回非 null 路径时显示 `exportSuccess`。
- **用法：** `build` 中"Export data"块的 `onTap: _exportData`（`lib/features/settings/views/settings_page.dart`，第 663 行）。
- **备注：** 无失败 snackbar 路径——`path` 为 `null` 时方法无反馈地落入；导出何时可返回 `null` 见 [`import_export_service.dart`](../../../shared/services/import_export_service.md)。

### `Future<void> _importData()` <a id="_importdata"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 245 行）
- **用途：** 让用户挑 ZIP 备份文件并在确认后导入。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 打开限制 `.zip` 的文件选择器；显示确认对话框；调用 `ImportExportService.importZip`（覆盖本地数据文件）；显示结果 snackbar。
- **算法：**
  1. 经 `FilePicker.platform.pickFiles` 挑单个 `.zip` 文件；没挑返回。
  2. 显示取消/导入确认对话框；未确认返回。
  3. Await `ImportExportService.importZip(path)` 并按布尔结果显示 `importSuccess`/`importFailed`。
- **用法：** `build` 中"Import data"块的 `onTap: _importData`（`lib/features/settings/views/settings_page.dart`，第 668 行）。
- **备注：** ZIP 条目名的路径遍历保护住在 `ImportExportService.importZip` 本身，不在这里——见 [备份、恢复与导出 — ZIP 导出/导入](../../../../backup-restore.md#zip-exportimport)。

### `Future<void> _openDataFolder()` <a id="_opendatafolder"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 286 行）
- **用途：** 在平台原生文件管理器打开应用数据目录（仅桌面）。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 生成平台进程（`explorer`、`open` 或 `xdg-open`）。
- **算法：** 解析 `DeviceStorage.getAppDir()`，然后按 `Platform.isWindows` / `isMacOS` / `isLinux` 分支用目录路径运行匹配操作系统命令（Linux 经 `uri.toFilePath()` 用 `file://` URI 形态）。
- **用法：** `build` 中"Data Migration"块的 `onTap: _openDataFolder`（`lib/features/settings/views/settings_page.dart`，第 688 行），只在 `_isDesktop` 时显示。
- **备注：** `Process.run` 周围无错误处理——文件管理器启动失败不浮出给用户。

### `Future<void> _showStoragePathDialog(BuildContext context)` <a id="_showstoragepathdialog"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 303 行）
- **用途：** 让用户输入自定义存储目录或重置为默认，然后应用。
- **输入：** `context`。
- **返回：** `Future<void>`。
- **副作用：** 显示带文本字段的对话框；调用 `DeviceStorage.setStoragePath`；重载路径并在成功时显示 snackbar。
- **算法：**
  1. 显示带预填 `_storagePath` 的 `TextField` 和取消 / "Reset to default"（返回 `''`）/ 保存操作的 `AlertDialog`。
  2. 对话框被关闭（`newPath == null`）返回。
  3. 空字符串当作"用默认"（`pathToSet = null`），否则修剪文本。
  4. Await `DeviceStorage.setStoragePath(pathToSet)`；报告成功时经 [`_loadStoragePath`](#_loadstoragepath) 重载并显示 `settingsResetDefaultLocation` 或 `settingsStoragePathUpdated`。
- **用法：** `build` 中"Storage Location"块的 `onTap: () => _showStoragePathDialog(context)`（`lib/features/settings/views/settings_page.dart`，第 681 行），只在 `_isDesktop` 时显示。
- **备注：** 用本地 `context` 参数的 `.mounted`（`context.mounted`，第 351 行）而非 State 自己 `mounted`，因为此方法显式接收 `context`。

### `Future<void> _loadTraySettings()` <a id="_loadtraysettings"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 370 行）
- **用途：** 加载持久化最小化到托盘和关闭到托盘偏好。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `DeviceStorage.readConfig()`；挂载时 `setState`。
- **算法：** 读取配置映射，缺席时 `minimizeToTray` 和 `closeToTray` 都默认 `false`，然后经 `setState` 应用两者。
- **用法：** `_isDesktop` 时从 [`initState`](#initstate) 调用。
- **备注：** 无。

### `Future<void> _loadAutoStartStatus()` <a id="_loadautostartstatus"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 384 行）
- **用途：** 查询操作系统级启动时启动注册状态。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `launchAtStartup.isEnabled()`（查询平台启动项状态，按 [平台说明 — launch_at_startup](../../../../platform-notes.md#launch_at_startup)）；挂载时 `setState`。
- **算法：** Await `launchAtStartup.isEnabled()`，仍挂载时设 `_autoStart`。
- **用法：** `_isDesktop` 时从 [`initState`](#initstate) 调用。
- **备注：** 无。

### `Future<void> _loadApiSettings()` <a id="_loadapisettings"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 395 行）
- **用途：** 加载持久化本地 API 服务器配置（启用标志、端口、监听地址、凭据）。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `DeviceStorage.readConfig()`；挂载时 `setState`。
- **算法：** 读取配置映射并带默认应用五个键（`apiEnabled: false`、`apiPort: 7789`、`apiListenAddress: 'localhost'`、`apiUsername`/`apiPassword: ''`）——`7789` 默认匹配 `LocalApiServer` 自己默认端口（见 [平台说明 — 桌面本地 API 服务器](../../../../platform-notes.md#desktop-local-api-server)）。
- **用法：** `_isDesktop` 时从 [`initState`](#initstate) 调用。
- **备注：** 无。

### `Future<void> _showApiSettingsDialog()` <a id="_showapisettingsdialog"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 412 行）
- **用途：** 让用户编辑本地 API 服务器监听地址、端口、用户名和密码，持久化变更并用新设置重启服务器。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 显示带四个文本字段的对话框；经 `DeviceStorage.readConfig()`/`writeConfig()` 写四个设置；调用 `LocalApiServer.restart()`；显示带结果端口的 snackbar。
- **算法：**
  1. 显示从当前状态预填、带取消/保存操作的 `AlertDialog`。
  2. 未保存或未挂载返回。
  3. 用 `int.tryParse(...) ?? 7789` 解析端口字段；空白地址回退 `'localhost'`；空白用户名/密码在配置映射中存为 `null`（非空字符串）。
  4. 经 `DeviceStorage.writeConfig` 写回更新配置映射、把新值镜像进本地状态，然后 await `LocalApiServer.restart()` 并显示 `settingsApiRestarted(LocalApiServer.port)`。
- **用法：** `build` 中"API Server"设置块的 `onTap: _apiEnabled ? _showApiSettingsDialog : null`（`lib/features/settings/views/settings_page.dart`，第 763 行）——只在 API 服务器启用时可点击。
- **备注：** 空白用户名/密码存 `null` 而非 `''` 重要，因为 `LocalApiServer` 把已配置（非 null）凭据对当作"需 Basic Auth"——见 [平台说明 — 桌面本地 API 服务器](../../../../platform-notes.md#desktop-local-api-server)。

### `Future<void> _refreshExchangeRates()` <a id="_refreshexchangerates"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 496 行）
- **用途：** 手动获取并持久化配置默认货币的最新汇率。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `DeviceExchangeRateService.fetchAndSaveLatest(_defaultCurrency)`（网络请求加本地写）；显示结果 snackbar。
- **算法：** Await 获取/保存调用，返回非 null 时显示 `exchangeRateUpdated`，否则 `exchangeRateUpdateFailed`。
- **用法：** `build` 中"Refresh Exchange Rates"块的 `onTap: _refreshExchangeRates`（`lib/features/settings/views/settings_page.dart`，第 625 行）。
- **备注：** 无。
