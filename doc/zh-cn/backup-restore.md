# 备份、恢复与导出

本页覆盖 `lib/shared/services/backup_service.dart`（本地备份/恢复）和 `lib/shared/services/import_export_service.dart`（ZIP 和 Markdown 导出/导入）。用于验证恢复数据的模型 `fromJson` 解析器见 [数据格式](data-formats.md)，恢复为何与自动同步交互见 [WebDAV 同步](sync.md)。

## 备份格式 v2

每个 `backups/backup_*.json` 捆绑（`_backupFormat: 2`）存储：

- 每个存在数据模块文件的原始 JSON 字符串内容（`device_data.json`、`network_data.json`、`dataset_data.json`、`service_data.json`——[持久化数据清单](data-formats.md#persisted-data-inventory) 的相同四个文件）。
- 从 `images/<filename>` 到存储在 `backups/blobs/` 下的内容寻址 blob 名 `<sha256><ext>` 的 `_imageRefs` 映射。

```dart
static const modules = <String, String>{
  'device_data.json': 'devices',
  'network_data.json': 'networks',
  'dataset_data.json': 'datasets',
  'service_data.json': 'services',
};
```

### 去重

`createBackup()` 用 SHA-256 哈希 `images/` 下每个文件，且只在 `backups/blobs/<hash><ext>` 尚不存在时写它。**相同图像存储一次并被每个引用它们的备份共享**——未变图像库的重复备份保持小，因为每次备份只增长 `_imageRefs` 映射（非图像字节）。

### 垃圾收集

`_collectUnreferencedBlobs()` 在每次创建/删除/保留遍后运行：

- 它遍历每个剩余 `backup_*.json`，**任何**捆绑解析失败时整个 GC 遍**中止**——引用集合未知，因此不确定下不删除任何东西。
- blob 只在**没有剩余备份引用它**时被物理删除。
- blob 比 **10 分钟宽限窗口**更年轻则绝不删除（源码确认：`_blobGcGrace = Duration(minutes: 10)`），保护与 GC 遍并发写入的备份。

### 遗留 v1 恢复

带内联 base64 `_images`（裸基名，无 `images/` 前缀）的捆绑仍可恢复：`restoreBackup()` 先检查 `_imageRefs`，存在时改回退用 `base64Decode()` 解码 `_images` 条目。

## 保留

`BackupService.retentionDays`（0 = 永久保留）经 `storage_config.json`（`autoBackupEnabled`、`backupRetentionDays`）加载/保存。`_cleanOldBackups()` 在 `retentionDays > 0` 时删除任何早于 `DateTime.now().subtract(Duration(days: retentionDays))` 的备份。

## 原子写与损坏捆绑处理

捆绑 JSON 和每个 blob/图像文件都经 tmp-然后-重命名（`_atomicWriteString` / `_atomicWriteBytes`）写入，因此写中崩溃不能留下最终路径的截断文件。

`listBackups()` 解析 4 MiB 探测大小（`_probeMaxBytes = 4 * 1024 * 1024`）或以下的任何捆绑检测损坏；更大遗留内联图像捆绑只按文件大小列出，无损坏检查。解析失败的捆绑被标记 `corrupt: true`——备份历史以禁用恢复显示它，（重要的是）它**不算**"今天已备份"，因此同一天更早被中断的自动备份被下次 `runAutoBackupIfNeeded()` 调用重试。`runAutoBackupIfNeeded()` 有重入守卫（`_autoBackupRunning`）；其触发器是应用启动、应用恢复和 15 分钟自动同步周期计时器（最后一个专门覆盖跨午夜持续运行的桌面实例）。

## 恢复验证

`restoreBackup()` 在**写任何东西前**用其模型解析器验证**每个所选模块的 JSON 负载**：

```dart
static void _validateModuleJson(String fileName, String content) {
  final json = jsonDecode(content) as Map<String, dynamic>;
  switch (fileName) {
    case 'device_data.json': DeviceData.fromJson(json);
    case 'network_data.json': NetworkData.fromJson(json);
    case 'dataset_data.json': DataSetData.fromJson(json);
    case 'service_data.json': ServiceData.fromJson(json);
    default: throw FormatException('unsupported data file: $fileName');
  }
}
```

任何所选模块解析失败时，整个恢复在任何文件写入前抛。只有每个所选负载都验证后函数才迭代并原子写每个文件。

图像名由 `_safeImageBasename()` 净化：它接受裸基名（遗留）和 `images/<name>` 键（v2），并拒绝剥离 `images/` 前缀后含 `/`、`..` 或绝对路径的任何东西——因此精心构造的捆绑不能写到 `images/` 目录外。

## 图像模块门控

捆绑含 `_images`（遗留）或 `_imageRefs`（v2）时 `getBackupModules()` 报告**合成 `images` 模块**。这让恢复 UI 在设备/网络/数据集/服务旁提供"图像"作为自己的可选复选框。只在 `moduleKeys` 含 `images` 模块（或 `moduleKeys` 为 `null`，意为"恢复一切"）时恢复图像。

## 恢复结果与自动同步禁用安全规则

`restoreBackup()` 返回 `RestoreResult`：

```dart
class RestoreResult {
  final bool ok;
  final bool wroteAnything;
  final int missingImages;
}
```

- `wroteAnything` 只在恢复*在写任何数据或图像文件前*失败时为 `false`——调用方用此知道本地数据保证未碰。
- `missingImages` 统计 v2 `_imageRefs` 条目中 blob 文件缺席于 blob 存储的（如未带其 `backups/blobs/` 目录复制的捆绑）——调用方把它浮出为本地化 `backupRestoreMissingImages` 警告而非静默丢弃那些图像。

**安全规则：** WebDAV 自动同步启用时，恢复备份**在首个文件写入前于 `webdav_config.json` 中禁用自动同步**（UI 侧无 `mounted` 门），使恢复中途崩溃或页面释放绝不能让恢复的旧数据保持自动同步开启。只在恢复以 `wroteAnything == false` 失败时重新启用自动同步——即只在本地数据保证未碰时。不先禁用自动同步，下次同步会把恢复的旧数据当作新鲜本地编辑/删除并传播给远程和每个其他同步设备。

成功恢复后：

1. 备份页经 `AutoSyncService.notifyLocalDataChangedNow()` 重载打开页面。
2. 任何 v2 图像 blob 缺失时警告（`backupRestoreMissingImages`）。
3. 只在 WebDAV 同步配置时，询问是否强制上传恢复数据（持有同步唤醒锁；结果记录进同步状态）。见 [WebDAV 同步 — 强制上传/强制下载](sync.md#force-upload--force-download)。

## ZIP 导出/导入

`import_export_service.dart` 把四个数据 JSON 文件加 `images/` 下每个文件导出进 ZIP 存档，导入则反之。导入时每个存档条目名被规范化且必须是已知数据文件名之一或匹配 `images/<扁平名>`（源码确认：`normalizedName.startsWith('images/') && normalizedName.split('/').length == 2`，即 `images/` 后恰好一个路径段）——任何其他、或含 `..` 的任何名字被拒绝。解析输出路径写入前也用 `path.isWithin(appDir, outFile)` 双重检查。

**文档化 v1.2.2 修复：** 此检查的早期版本只测试 `normalizedName.startsWith('images/')`——它对 `images/` 下*任何*嵌套路径（如某些规范化后的 `images/../../evil.txt`，或简单 `images/sub/dir/file`）都为 `true`，因此总是通过并放行允许列表本应拒绝的嵌套条目。当前检查额外要求 `images/` 前缀后恰好一个路径段（`split('/').length == 2`），封住那个缺口。这是 `AGENTS.md` "ZIP import must keep path traversal protection" 规则引用的路径遍历保护。

## Markdown 导出

`import_export_service.dart` 也产生覆盖设备、网络、数据集和服务的 LLM 友好 Markdown 导出——含服务端点、路由、跳、Docker Compose 备注和分组公共目标（`extraJson.publicTargets`，见 [服务与拓扑](features/services-topology.md)）。设备导出相关时含生命周期和财务信息（`v0.4.0` 随设备生命周期/财务添加；服务数据 `v0.5.6` 添加）。

## `image_service.dart`

处理文件挑选、URL 下载、`images/` 下 UUID 文件名、相对路径解析和删除——`Device.imagePath` 和同步/备份图像逻辑构建于其上的原语。
