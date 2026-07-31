# lib/features/settings/views/backup_page.dart

`BackupPage` 是本地备份的设置子页：它经 [`BackupService`](../../../shared/services/backup_service.md) 列出既有 `backups/backup_*.json` 捆绑、让用户创建新备份、切换自动备份和保留，并恢复或删除既有。恢复是本文件安全关键路径——它经 [`WebDAVService`](../../../shared/services/webdav_service.md) 和 [`AutoSyncService`](../../../shared/services/auto_sync_service.md) 直接与 WebDAV 自动同步交互，并在 [`SyncWakeLock`](../../../shared/services/sync_wake_lock.md) 下强制上传。本页流程所坐的完整备份格式、去重和恢复验证模型见 [备份、恢复与导出](../../../../backup-restore.md)，`_handlePostRestoreSync` 触发的同步语义见 [WebDAV 同步](../../../../sync.md)。

**行数说明：** `grep -c 'Purpose:' backup_page.dart` 返回 **16**，与本文件 16 个真实声明精确匹配——每个块都恰好坐在其文档化声明上方；本文件无错附块、无未文档化尾部声明。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `BackupPage`（构造函数） | 构造函数 | B | 创建页面组件（无参数）。 |
| `createState` | 方法（`BackupPage`） | B | 创建页面可变状态对象。 |
| `initState` | 方法（组件生命周期） | B | 启动初始备份列表/设置加载。 |
| [`_load`](#_load) | 方法（`_BackupPageState`） | A | 从 `BackupService` 加载备份设置和当前备份列表。 |
| [`_createBackup`](#_createbackup) | 方法（`_BackupPageState`） | A | 创建新备份并报告成功/失败。 |
| [`_restoreBackup`](#_restorebackup) | 方法（`_BackupPageState`） | A | 挑模块、确认并恢复备份，为安全先禁用自动同步。 |
| [`_handlePostRestoreSync`](#_handlepostrestoresync) | 方法（`_BackupPageState`） | A | 配置 WebDAV 时成功恢复后提供强制上传。 |
| [`_deleteBackup`](#_deletebackup) | 方法（`_BackupPageState`） | A | 确认并删除备份捆绑，然后重载列表。 |
| [`_toggleAutoBackup`](#_toggleautobackup) | 方法（`_BackupPageState`） | A | 持久化自动备份启用标志。 |
| [`_setRetention`](#_setretention) | 方法（`_BackupPageState`） | A | 持久化备份保留天数设置。 |
| `build` | 方法（组件） | B | 渲染信息卡片、设置小节、创建备份块和备份历史列表。 |
| `_buildSection` | 方法（组件辅助） | B | 渲染一个带标题的设置小节。 |
| `_RestoreModuleDialog`（构造函数） | 构造函数 | B | 存储可从捆绑恢复的模块列表。 |
| `createState`（`_RestoreModuleDialog`） | 方法（`_RestoreModuleDialog`） | B | 创建对话框可变状态对象。 |
| `initState`（`_RestoreModuleDialogState`） | 方法（组件生命周期） | B | 默认把所选模块集合播种为"全部模块"。 |
| `build`（`_RestoreModuleDialogState`） | 方法（组件） | B | 渲染全选复选框加每个可恢复模块一个复选框。 |

## 文档

### `Future<void> _load()` <a id="_load"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 51 行）
- **用途：** 从 `BackupService` 加载备份设置（自动备份标志、保留天数）和当前备份历史，并刷新页面。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `BackupService.loadSettings()` 和 `BackupService.listBackups()`（`backups/` 下文件系统读取）；成功时 `setState`。
- **算法：**
  1. Await `BackupService.loadSettings()` 填充服务静态 `autoBackupEnabled`/`retentionDays`。
  2. Await `BackupService.listBackups()` 获取当前 `List<BackupInfo>`（每个条目其 JSON 解析失败时已标记 `corrupt: true`——见 [备份、恢复与导出 — 原子写与损坏捆绑处理](../../../../backup-restore.md#atomic-writes-and-corrupt-bundle-handling)）。
  3. 仍挂载时在单个 `setState` 复制全部四个值进本地状态（`_backups`、`_autoBackup`、`_retentionDays`、`_loading = false`）。
- **用法：** 首次加载从 `initState()` 调用，每次创建/恢复/删除后再次刷新可见列表（如 [`_createBackup`](#_createbackup) 末尾）。
- **备注：** 无。

### `Future<void> _createBackup()` <a id="_createbackup"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 69 行）
- **用途：** 创建新本地备份捆绑并显示成功或失败 snackbar。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `BackupService.createBackup()`（写新 `backup_*.json` 和 `backups/blobs/` 下任何新内容寻址 blob）；显示 `SnackBar`；成功时重载列表。
- **算法：** Await `BackupService.createBackup()`；返回非 null 文件时显示 `backupCreated` snackbar 并调用 [`_load`](#_load) 刷新历史；否则显示 `backupFailed` snackbar。
- **用法：** `build` 中"Create backup"列表块的 `onTap: _createBackup`（`lib/features/settings/views/backup_page.dart`，第 373 行）。
- **备注：** 无。

### `Future<void> _restoreBackup(BackupInfo backup)` <a id="_restorebackup"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 96 行）
- **用途：** 让用户挑从捆绑恢复哪些模块、确认破坏性操作并恢复它——作为安全措施先禁用 WebDAV 自动同步。
- **输入：** `backup` — 用户点恢复的 `BackupInfo` 条目。
- **返回：** `Future<void>`。
- **副作用：** 读取捆绑可用模块；显示模块选择器对话框和确认对话框；可能调用 `WebDAVService.saveConfig` 禁用（并在空操作失败时重新启用）自动同步；调用 `BackupService.restoreBackup`（写数据/图像文件）；通知 `AutoSyncService`；显示 snackbar；调用 [`_handlePostRestoreSync`](#_handlepostrestoresync)。
- **算法：**
  1. 加载 `BackupService.getBackupModules(backup.file)`；为空（捆绑不可读）显示 `backupRestoreFailed` 并返回。
  2. 显示 `_RestoreModuleDialog` 收集所选模块键；用户没挑或关闭则返回。
  3. 显示取消/恢复确认 `AlertDialog`；未确认返回。
  4. 加载当前 `WebDAVService.loadConfig()`。WebDAV 已配置且 `autoSync` 开启时立即用 `autoSync: false` 保存配置——**在任何恢复数据写入前**，使恢复中途崩溃或页面释放绝不能让恢复的旧数据保持自动同步启用（见 [备份、恢复与导出 — 恢复结果与自动同步禁用安全规则](../../../../backup-restore.md#restore-result-and-the-auto-sync-disable-safety-rule)）。
  5. 调用 `BackupService.restoreBackup(backup.file, moduleKeys: selected)`。
  6. 结果非 `ok` 时：只在步骤 4 禁用了它**且** `result.wroteAnything` 为 `false`（即本地数据保证未碰）时重新启用自动同步；显示 `backupRestoreFailed`；返回。
  7. 成功时：调用 `AutoSyncService.instance.notifyLocalDataChangedNow()` 使打开页面立即重载恢复数据；`result.missingImages > 0` 时显示 `backupRestoreMissingImages` 警告；带恢复前配置（WebDAV 未配置则 `null`）调用 [`_handlePostRestoreSync`](#_handlepostrestoresync)。
- **用法：** `build` 中每个备份历史块恢复按钮的 `onPressed: b.corrupt ? null : () => _restoreBackup(b)`（`lib/features/settings/views/backup_page.dart`，第 418 行）——标记 `corrupt` 的捆绑禁用。
- **备注：** 步骤 4 的自动同步禁用刻意无 `mounted` 门：即使页面随后立即释放它也必须运行，因为让自动同步保持开启带恢复的旧本地数据会让下次同步把过期记录/删除传播给远程和每个其他同步设备。

### `Future<void> _handlePostRestoreSync(WebDAVConfig? config)` <a id="_handlepostrestoresync"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 191 行）
- **用途：** 成功恢复后配置了 WebDAV 同步时提供强制上传恢复数据；否则只确认恢复完成。
- **输入：** `config` — 恢复前加载的 `WebDAVConfig`（[`_restoreBackup`](#_restorebackup) 已在其上禁用自动同步），同步未配置时 `null`。
- **返回：** `Future<void>`。
- **副作用：** `config` 非 null 时显示不可关闭对话框；确认时获取 `SyncWakeLock`、调用 `WebDAVService.forceUpload(config)`、释放唤醒锁并经 `AutoSyncService.instance.recordSyncResult` 记录结果；两种方式都显示 snackbar。
- **算法：**
  1. `config == null` 时显示普通 `backupRestored` snackbar 并返回——自动同步从未被碰，因此无可提供。
  2. 否则显示组合"同步已禁用"通知（`backupRestoredSyncDisabled`）和强制上传提示（`backupForceUploadPrompt`）的不可关闭 `AlertDialog`。
  3. 用户拒绝（或组件已卸载）时不重新启用自动同步地返回——它保持关闭直到用户在 WebDAV 页手动重新启用。
  4. 确认时：获取 `SyncWakeLock`、在总是释放唤醒锁的 `try`/`finally` 内调用 `WebDAVService.forceUpload(config)`，然后记录结果并显示 `backupForceUploadDone`/`backupForceUploadFailed`。
- **用法：** [`_restoreBackup`](#_restorebackup) 末尾的 `await _handlePostRestoreSync(webDavConfigured ? config : null);`（`lib/features/settings/views/backup_page.dart`，第 176 行）。
- **备注：** 自动同步本身已更早在 `_restoreBackup` 中、任何文件写入前禁用；此方法只处理面向用户的后续决定（现在强制上传，或保持同步关闭直到用户重访 WebDAV 设置）。`forceUpload` 做什么见 [WebDAV 同步 — 强制上传/强制下载](../../../../sync.md#force-upload--force-download)。

### `Future<void> _deleteBackup(BackupInfo backup)` <a id="_deletebackup"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 249 行）
- **用途：** 确认并接受时永久删除一个备份捆绑并刷新列表。
- **输入：** `backup` — 用户点删除的 `BackupInfo` 条目。
- **返回：** `Future<void>`。
- **副作用：** 显示取消/删除确认对话框；确认时调用 `BackupService.deleteBackup(backup.file)`（删除捆绑文件，受该服务 blob-GC 宽限窗口约束——见 [备份、恢复与导出 — 垃圾收集](../../../../backup-restore.md#garbage-collection)）并重载。
- **算法：** 显示确认 `AlertDialog`；结果不恰好 `true`、或组件未挂载时不删除地返回；否则 await `BackupService.deleteBackup` 然后 [`_load`](#_load)。
- **用法：** `build` 中每个备份历史块删除按钮的 `onPressed: () => _deleteBackup(b)`（`lib/features/settings/views/backup_page.dart`，第 423 行）。
- **备注：** 与恢复不同，删除无 `corrupt` 门控禁用——损坏捆绑仍可删除。

### `Future<void> _toggleAutoBackup(bool value)` <a id="_toggleautobackup"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 279 行）
- **用途：** 启用或禁用自动备份并持久化设置。
- **输入：** `value` — 新开关状态。
- **返回：** `Future<void>`。
- **副作用：** `setState` 更新 `_autoBackup`；设置 `BackupService.autoBackupEnabled`；调用 `BackupService.saveSettings()`（写 `storage_config.json`）。
- **算法：** 经 `setState` 立即更新本地状态、把值镜像到服务静态 `autoBackupEnabled`，然后 await `saveSettings()` 持久化。
- **用法：** `build` 中"Auto Backup"`SwitchListTile` 的 `onChanged: _toggleAutoBackup`（`lib/features/settings/views/backup_page.dart`，第 346 行）。
- **备注：** 无。

### `Future<void> _setRetention(int days)` <a id="_setretention"></a>
- **种类：** `_BackupPageState` 的方法
- **来源：** `lib/features/settings/views/backup_page.dart`（第 290 行）
- **用途：** 更改备份保留期并持久化。
- **输入：** `days` — 固定 `_retentionOptions` 之一（`0, 3, 7, 14, 30, 60, 90`；`0` 意为永久保留）。
- **返回：** `Future<void>`。
- **副作用：** `setState` 更新 `_retentionDays`；设置 `BackupService.retentionDays`；调用 `BackupService.saveSettings()`。
- **算法：** 与 [`_toggleAutoBackup`](#_toggleautobackup) 相同形态：本地 `setState`、镜像到服务静态字段、await 持久化调用。
- **用法：** `build` 中保留 `DropdownButton<int>` 的 `onChanged: (v) { if (v != null) _setRetention(v); }`（`lib/features/settings/views/backup_page.dart`，第 360 行）。
- **备注：** 实际基于天的删除逻辑（`_cleanOldBackups()`）住在 `BackupService`，不在这里——此方法只持久化所选阈值；见 [备份、恢复与导出 — 保留](../../../../backup-restore.md#retention)。
