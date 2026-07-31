# lib/shared/views/webdav_config_page.dart

`WebDAVConfigPage` 是 WebDAV 同步设置页：它编辑/保存 `WebDAVConfig`、测试连接，并经 [`WebDAVService`](../services/webdav_service.md) 驱动每个前台同步操作（手动同步、强制上传、强制下载、冲突解决），经 [`AutoSyncService`](../services/auto_sync_service.md) 报告结果并在传输在途时持有 [`SyncWakeLock`](../services/sync_wake_lock.md)。这是 [WebDAV 同步](../../../sync.md)（9 步流程、手动-vs-自动同步语义、唤醒锁和强制上传/下载）端到端描述、[同步演练](../../../examples/sync-walkthrough.md) 具体走查的页面。嵌套 `_ConflictDialog` 是 [三方合并](../../../algorithms/three-way-merge.md) 冲突输出的 UI 半边——每个 `RecordConflict` 一个对话框，由 `_resolveConflicts` 顺序显示。

**行数说明：** `grep -c 'Purpose:' webdav_config_page.dart` 返回 **23**，与本文件 23 个真实声明精确匹配——每个块都恰好坐在其文档化声明上方；本文件无错附块、无未文档化声明。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `WebDAVConfigPage`（构造函数） | 构造函数 | B | 创建页面组件（无参数）。 |
| `createState` | 方法（`WebDAVConfigPage`） | B | 创建页面可变状态对象。 |
| [`initState`](#initstate) | 方法（组件生命周期） | A | 注册同步状态监听器并加载保存配置。 |
| `_refreshSyncStatus` | 方法（`_WebDAVConfigPageState`） | B | 响应 `AutoSyncService` 状态变化重建。 |
| [`_loadConfig`](#_loadconfig) | 方法（`_WebDAVConfigPageState`） | A | 把保存 `WebDAVConfig` 加载进文本控制器。 |
| `dispose` | 方法（组件生命周期） | B | 注销监听器并释放四个文本控制器。 |
| `_currentConfig` | getter（`_WebDAVConfigPageState`） | B | 从当前控制器文本和 `_autoSync` 构建 `WebDAVConfig`。 |
| [`_saveConfig`](#_saveconfig) | 方法（`_WebDAVConfigPageState`） | A | 把当前表单持久化为 WebDAV 配置，完整配置时触发立即同步。 |
| [`_testConnection`](#_testconnection) | 方法（`_WebDAVConfigPageState`） | A | 测试到配置 WebDAV 服务器的连通性。 |
| [`_syncNow`](#_syncnow) | 方法（`_WebDAVConfigPageState`） | A | 运行手动前台同步并把结果路由到冲突解决或普通结果对话框。 |
| [`_showSyncResult`](#_showsyncresult) | 方法（`_WebDAVConfigPageState`） | A | 呈现非冲突同步/强制结果：失败对话框、警告对话框或成功 snackbar。 |
| [`_forceUpload`](#_forceupload) | 方法（`_WebDAVConfigPageState`） | A | 确认并运行破坏性强制上传（本地覆盖远程）。 |
| [`_forceDownload`](#_forcedownload) | 方法（`_WebDAVConfigPageState`） | A | 确认并运行破坏性强制下载（远程覆盖本地）。 |
| `_confirmForceAction` | 方法（组件辅助） | B | 为破坏性强制操作显示取消/确认对话框。 |
| `_progressText` | 方法（`_WebDAVConfigPageState`） | B | 把 `SyncProgress` 阶段映射到本地化状态行。 |
| [`_resolveConflicts`](#_resolveconflicts) | 方法（`_WebDAVConfigPageState`） | A | 每个挂起冲突显示一个对话框，然后上传解决数据。 |
| [`_disconnect`](#_disconnect) | 方法（`_WebDAVConfigPageState`） | A | 删除保存 WebDAV 配置并清除表单。 |
| `_fillNextcloud` | 方法（`_WebDAVConfigPageState`） | B | 用 Nextcloud WebDAV URL/路径预设填充表单。 |
| [`_syncStatusText`](#_syncstatustext) | 方法（`_WebDAVConfigPageState`） | A | 构建显示用短同步健康摘要。 |
| `build` | 方法（组件） | B | 渲染配置表单、同步状态卡片、进度条和同步/强制/断开操作。 |
| `_ConflictDialog`（构造函数） | 构造函数 | B | 存储要显示的冲突。 |
| [`_modifiedAtOf`](#_modifiedatof) | 方法（`_ConflictDialog`，静态） | A | 从动态冲突记录提取显示就绪 `modifiedAt` 时间戳（如有）。 |
| `build`（`_ConflictDialog`） | 方法（组件） | B | 渲染冲突对话框：记录名、两侧时间戳/ID、保留本地/保留远程操作。 |

## 文档

### `void initState()` <a id="initstate"></a>
- **种类：** `_WebDAVConfigPageState` 的方法（组件生命周期覆盖）
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 44 行）
- **用途：** 把本页接入后台同步状态通知并加载先前保存 WebDAV 配置。
- **输入：** 无。
- **返回：** `None`。
- **副作用：** 把 `_refreshSyncStatus` 注册到 `AutoSyncService.instance.addOnStatusChanged`；启动（不 await）`_loadConfig()` 加载。
- **算法：** 调用 `super.initState()`、注册状态变更监听器，然后不 await 地调用 `_loadConfig()`。
- **用法：** `_WebDAVConfigPageState` 首次插入树时由 Flutter 框架自动调用。
- **备注：** 对应 `dispose()`（第 83 行）移除相同监听器并释放四个 `TextEditingController`（`_urlController`、`_userController`、`_passController`、`_pathController`）。

### `Future<void> _loadConfig()` <a id="_loadconfig"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 64 行）
- **用途：** 把持久化 `WebDAVConfig`（如有）加载进表单文本控制器和自动同步开关。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `WebDAVService.loadConfig()`（读取 `webdav_config.json`）；直接修改四个控制器 `.text`（非经 `setState`，因为那在末尾一次发生）；`setState` 清除 `_loading`。
- **算法：** Await `WebDAVService.loadConfig()`；非 null 时把 `serverUrl`/`username`/`password`/`remotePath` 复制进匹配控制器、`isConfigured`/`autoSync` 复制进 `_isConfigured`/`_autoSync`；然后无论配置是否曾存在，仍挂载时设 `_loading = false`。
- **用法：** 从 [`initState`](#initstate) 调用一次。
- **备注：** 尚无配置时控制器保持初始值（`_pathController` 默认 `/MyDevice`）且 `_isConfigured` 保持 `false`。

### `Future<void> _saveConfig()` <a id="_saveconfig"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 110 行）
- **用途：** 把表单当前值持久化为 WebDAV 配置，结果完整配置且自动同步开启时请求立即同步。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `WebDAVService.saveConfig`（写 `webdav_config.json`）；可能调用 `AutoSyncService.instance.requestSyncNow()`；`setState`；显示 snackbar。
- **算法：**
  1. 从 `_currentConfig`（当前控制器文本 + `_autoSync`）构建 `config`。
  2. Await `WebDAVService.saveConfig(config)`。
  3. 经 `setState` 设 `_isConfigured = config.isConfigured`。
  4. `config.isConfigured && config.autoSync` 时调用 `AutoSyncService.instance.requestSyncNow()`——见 [WebDAV 同步 — 自动同步触发器](../../../sync.md#auto-sync-triggers)（"保存/启用完整配置的自动同步 WebDAV 设置"触发器）。
  5. 仍挂载时显示 `settingsWebDAVConfigSaved`。
- **用法：** `build` 中"保存"按钮的 `onPressed: _saveConfig`（`lib/shared/views/webdav_config_page.dart`，第 568 行）。
- **备注：** 无。

### `Future<void> _testConnection()` <a id="_testconnection"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 133 行）
- **用途：** 验证当前输入凭据/URL 能否到达 WebDAV 服务器，不保存它们。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 设 `_testing`（驱动按钮转圈）；调用 `WebDAVService.testConnection(_currentConfig)`（网络请求）；显示结果 snackbar。
- **算法：** 设 `_testing = true`；await `WebDAVService.testConnection(_currentConfig)`；仍挂载时清除 `_testing` 并按布尔结果显示 `settingsWebDAVConnectionSuccess` 或 `settingsWebDAVConnectionFailed`。
- **用法：** `build` 中"测试连接"按钮的 `onPressed: _testing ? null : _testConnection`（`lib/shared/views/webdav_config_page.dart`，第 575 行）——测试已运行时禁用。
- **备注：** 用内存 `_currentConfig` 而非保存配置，使用户能在保存前测试变更。

### `Future<void> _syncNow()` <a id="_syncnow"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 159 行）
- **用途：** 运行手动、前台三方同步并把结果路由到冲突解决或普通结果对话框/snackbar。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 设 `_syncing`；获取/释放 `SyncWakeLock`；调用 `WebDAVService.sync(_currentConfig)`（完整 9 步流程）；记录结果并经 `AutoSyncService` 通知本地数据变更监听器；可能经 [`_resolveConflicts`](#_resolveconflicts) 或 [`_showSyncResult`](#_showsyncresult) 显示对话框/snackbar。
- **算法：**
  1. 设 `_syncing = true` 并获取 `SyncWakeLock`（前台手动同步整个操作持有唤醒锁，按 [WebDAV 同步 — 唤醒锁](../../../sync.md#wake-lock)）。
  2. 在总是释放唤醒锁、仍挂载时清除 `_syncing` 的 `try`/`finally` 内 await `WebDAVService.sync(_currentConfig)`。
  3. 同步完成后未挂载提前返回。
  4. 调用 `AutoSyncService.instance.recordSyncResult(result)` 然后 `notifyLocalDataChangedIfNeeded()`，使其他打开页面拾取任何合并数据。
  5. `result.hasConflicts` 时委托 [`_resolveConflicts(result)`](#_resolveconflicts) 并返回；否则委托 [`_showSyncResult(result)`](#_showsyncresult)。
- **用法：** `build` 中"立即同步"按钮的 `onPressed: _syncing ? null : _syncNow`（`lib/shared/views/webdav_config_page.dart`，第 632 行）——同步已运行时禁用。隐式用 `autoResolve: false`，因为从此手动路径调用的 `WebDAVService.sync` 总是浮出冲突而非自动解决（见 [WebDAV 同步 — 手动 vs 自动同步](../../../sync.md#manual-vs-auto-sync)）。
- **备注：** 唤醒锁和 `_syncing` 标志都在 `finally` 释放/清除，因此 `WebDAVService.sync` 的异常不能使页面卡在"同步中"状态或泄漏唤醒锁。

### `Future<void> _showSyncResult(SyncResult result)` <a id="_showsyncresult"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 186 行）
- **用途：** 呈现完成（非冲突）同步或强制上传/下载结果：带错误文本的失败对话框、列出每个警告的成功带警告对话框，或普通成功 snackbar。
- **输入：** `result` — 无挂起冲突的 `SyncResult`。
- **返回：** `Future<void>`。
- **副作用：** 显示对话框（失败或警告 case）或 `SnackBar`（普通成功 case）。
- **算法：**
  1. 未挂载立即返回。
  2. `!result.success` 时显示把 `result.error` 放 `SelectableText` 的 `AlertDialog` 并返回。
  3. 否则 `result.warnings.isNotEmpty`（如逐图像同步失败——见 [WebDAV 同步 — 图像同步](../../../sync.md#image-sync)）时显示列出每个警告字符串的 `AlertDialog` 并返回。
  4. 否则显示普通 `settingsWebDAVSyncSuccess` snackbar。
- **用法：** 无冲突时从 [`_syncNow`](#_syncnow) 调用，传输完成后从 [`_forceUpload`](#_forceupload)/[`_forceDownload`](#_forcedownload) 调用。
- **备注：** 三分支互斥并按此顺序检查——失败结果绝不落入警告分支。

### `Future<void> _forceUpload()` <a id="_forceupload"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 256 行）
- **用途：** 显式破坏性操作确认后，用本地副本覆盖远程数据文件和图像，不合并。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 显示确认对话框；设 `_syncing`；获取/释放 `SyncWakeLock`；调用 `WebDAVService.forceUpload(_currentConfig)`（覆盖远程文件）；记录结果；经 `_showSyncResult` 显示结果。
- **算法：**
  1. 显示带强制上传文案的共享 `_confirmForceAction` 对话框；未确认或未挂载返回。
  2. 设 `_syncing = true`、获取 `SyncWakeLock`。
  3. 在释放唤醒锁并清除 `_syncing` 的 `try`/`finally` 内 await `WebDAVService.forceUpload(_currentConfig)`。
  4. 记录结果并通知本地数据变更监听器，然后调用 [`_showSyncResult(result)`](#_showsyncresult)。
- **用法：** `build` 中"强制上传"按钮的 `onPressed: _syncing ? null : _forceUpload`（`lib/shared/views/webdav_config_page.dart`，第 651 行）。
- **备注：** 唤醒锁只在*用户确认后*获取，不在确认对话框本身显示时——见 [WebDAV 同步 — 唤醒锁](../../../sync.md#wake-lock)。`forceUpload` 完全不合并或不检查冲突（见 [WebDAV 同步 — 强制上传/强制下载](../../../sync.md#force-upload--force-download)），因此此按钮只在破坏性操作确认后提供。

### `Future<void> _forceDownload()` <a id="_forcedownload"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 287 行）
- **用途：** 显式破坏性操作确认后，用远程副本覆盖本地数据文件和图像，不合并。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 显示确认对话框；设 `_syncing`；获取/释放 `SyncWakeLock`；调用 `WebDAVService.forceDownload(_currentConfig)`（覆盖本地文件）；记录结果；经 `_showSyncResult` 显示结果。
- **算法：** 与 [`_forceUpload`](#_forceupload) 相同形态，替换 `WebDAVService.forceDownload(_currentConfig)` 和强制下载确认文案。
- **用法：** `build` 中"强制下载"按钮的 `onPressed: _syncing ? null : _forceDownload`（`lib/shared/views/webdav_config_page.dart`，第 659 行）。
- **备注：** `forceDownload` 仅下载且不取远程锁（见 [WebDAV 同步 — 强制上传/强制下载](../../../sync.md#force-upload--force-download)）——与 [`_forceUpload`](#_forceupload) 不同，远程绝不被此路径写。

### `Future<void> _resolveConflicts(SyncResult result)` <a id="_resolveconflicts"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 386 行）
- **用途：** 走每个挂起记录冲突，让用户为每个保留本地或远程版本，完全解决后上传合并结果。
- **输入：** `result` — `result.pending` 已设（`result.hasConflicts == true`）的 `SyncResult`。
- **返回：** `Future<void>`。
- **副作用：** 每个冲突显示一个不可关闭 `_ConflictDialog`；获取/释放 `SyncWakeLock`；调用 `WebDAVService.finalizePendingSync`；经 `AutoSyncService` 记录结果；显示 snackbar。
- **算法：**
  1. 按顺序迭代 `result.pending!.allConflicts`。
  2. 对每个冲突，未挂载立即返回；否则显示 `_ConflictDialog(conflict: conflict)` 并 await 所选记录。
  3. 用户未选择地关闭对话框（`chosen == null`）——如系统返回手势——方法调用 `AutoSyncService.instance.recordSyncResult(result)`（记录为仍挂起/失败）、显示 `settingsWebDAVSyncFailed` 并立即返回：**不上传任何东西、不显示剩余冲突**，匹配 [WebDAV 同步 — 手动 vs 自动同步](../../../sync.md#manual-vs-auto-sync) 的"关闭任何冲突对话框中止整个解决"规则。
  4. 否则在 `resolutions[conflict.id]` 下记录所选记录并继续下一冲突。
  5. 每个冲突都有解决后，获取 `SyncWakeLock`、在总是释放唤醒锁的 `try`/`finally` 内 await `WebDAVService.finalizePendingSync(_currentConfig, pending, resolutions)`，并调用 `AutoSyncService.instance.recordFinalizeResult(ok)`。
  6. 按 `ok` 显示 `settingsWebDAVSyncSuccess` 或 `settingsWebDAVSyncFailed`。
- **用法：** `result.hasConflicts` 为 true 时从 [`_syncNow`](#_syncnow) 调用。
- **备注：** `NetworkDevice` 冲突无可显示 `modifiedAt`，因此 `_ConflictDialog` 为它们回退记录 ID（见下面 [`_modifiedAtOf`](#_modifiedatof) 和 [WebDAV 同步 — NetworkDevice 复合键合并](../../../sync.md#networkdevice-composite-key-merge)）。

### `Future<void> _disconnect()` <a id="_disconnect"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 445 行）
- **用途：** 移除保存 WebDAV 配置并把表单重置为空白/默认状态。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `WebDAVService.deleteConfig()`（删除 `webdav_config.json`）；清除全部四个控制器（`_pathController` 重置为 `/MyDevice` 而非清空）；`setState` 清除 `_isConfigured`/`_autoSync`；显示 snackbar。
- **算法：** Await `WebDAVService.deleteConfig()`、清除 URL/用户名/密码控制器、把路径控制器重置为 `/MyDevice`、设 `_isConfigured = false` 和 `_autoSync = false`，然后仍挂载时显示 `settingsWebDAVConfigRemoved`。
- **用法：** `build` 中"断开"按钮的 `onPressed: _disconnect`（`lib/shared/views/webdav_config_page.dart`，第 683 行）。
- **备注：** 这不碰本地数据文件或 `.sync_base/` 快照——只移除 WebDAV 连接配置，因此稍后重新添加相同服务器以新鲜（不存在）基础快照恢复，而非从中途同步状态恢复。

### `String? _syncStatusText(AppLocalizations l10n)` <a id="_syncstatustext"></a>
- **种类：** `_WebDAVConfigPageState` 的方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 483 行）
- **用途：** 产生短同步健康摘要卡片文本，尚无可报告时 `null`。
- **输入：** `l10n`。
- **返回：** `String?`。
- **副作用：** 无（只读 `AutoSyncService.instance` 字段）。
- **算法：** 与 [`settings_page.dart`](../../features/settings/views/settings_page.md#_webdavstatustext) 的 `_webDavStatusText` 相同逻辑：`lastError` 已设时返回冲突或失败风格行；否则 `lastSuccessAt` 已设时返回上次成功行；否则返回 `null`。
- **用法：** `build` 中 `final syncStatus = _syncStatusText(l10n);`（`lib/shared/views/webdav_config_page.dart`，第 505 行），`_isConfigured` 为 true 且此返回非 null 时显示在同步进度指示器上方着色 `Card` 中。
- **备注：** 无。

### `static String? _modifiedAtOf(dynamic record)` <a id="_modifiedatof"></a>
- **种类：** `_ConflictDialog` 的静态方法
- **来源：** `lib/shared/views/webdav_config_page.dart`（第 714 行）
- **用途：** 从具体类型（`Device`、`Network`、`DataSet`、`ServiceNode`……或 `NetworkDevice`）在此调用点未知的冲突记录尽力提取 `modifiedAt` 时间戳。
- **输入：** `record` — `conflict.localRecord` 或 `conflict.remoteRecord`，类型 `dynamic`。
- **返回：** `String?` — 记录 `modifiedAt` 转换为本地时间并字符串化，记录无该字段（或不是 `DateTime`）时 `null`。
- **副作用：** 无。
- **算法：** 把动态 `record.modifiedAt` 访问包进 `try`/`catch`；访问成功且值是 `DateTime` 时返回 `value.toLocal().toString()`；访问抛（无 `modifiedAt` getter 类型如 `NetworkDevice` 的 `NoSuchMethodError`）或值不是 `DateTime` 时落入返回 `null`。
- **用法：** `_ConflictDialog.build` 调用两次（`lib/shared/views/webdav_config_page.dart`，第 732-733 行），`conflict.localRecord` 一次、`conflict.remoteRecord` 一次。
- **备注：** 这是 [WebDAV 同步 — NetworkDevice 复合键合并](../../../sync.md#networkdevice-composite-key-merge) 文档化回退背后的机制：因为 `NetworkDevice` 无 `modifiedAt`，这为它返回 `null`，对话框回退 `l10n.syncConflictRecordId(conflict.id)`（复合键，如 `net-home:dev-1`）而非时间戳——每个其他记录类型显示真实 `modifiedAt`。
