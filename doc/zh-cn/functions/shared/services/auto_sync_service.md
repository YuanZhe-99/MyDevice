# lib/shared/services/auto_sync_service.dart

**共享调度器的门面。** 生命周期观察者、30 秒保存防抖、15 分钟周期计时器、在途守卫和状态记账移到 `myapps_data` 包（`lib/src/sync/auto_sync_scheduler.dart`）。本应用的额外部分作为钩子留在这里。

## 本应用提供的钩子 <a id="hooks-this-app-supplies"></a>

| 钩子 | 值 |
|---|---|
| `isAutoSyncActive` | 配置存在、已配置且启用 `autoSync`。 |
| `runSync` | `WebDAVService.sync(config)`——绝不带 `autoResolve`。 |
| `consumeLocalDataChanged` | `WebDAVService.consumeLocalDataChanged`。 |
| `onPeriodicTick` | `BackupService.runAutoBackupIfNeeded`，使跨午夜持续运行的桌面实例仍取每日备份。 |
| `onResume` | `BackupService.runAutoBackupIfNeeded`（MyDevice 无提醒刷新）。 |

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AutoSyncService` | 类 | B | 启用时自动触发 WebDAV 同步的单例。 |
| `AutoSyncService._` | 构造函数（私有） | B | 阻止直接实例化；唯一实例是 `instance`。 |
| `instance` | 静态 final 字段 | B | 单例。 |
| [`_scheduler`](#_scheduler) | late final 字段（私有） | A | 接好本应用钩子的共享 `AutoSyncScheduler`。 |
| `lastSuccessAt` | getter | B | 上次成功同步的时间，供设置 UI 使用。 |
| `lastFailureAt` | getter | B | 上次失败同步的时间，供设置 UI 使用。 |
| `lastError` | getter | B | 最近一次失败消息；成功同步后为 `null`。 |
| `hasPendingConflicts` | getter | B | 同步是否发现需要手动解决的冲突。 |
| `addOnLocalDataChanged` | 方法 | B | 注册 UI 重载回调。 |
| `removeOnLocalDataChanged` | 方法 | B | 移除 UI 重载回调。 |
| `addOnStatusChanged` | 方法 | B | 注册状态变更回调。 |
| `removeOnStatusChanged` | 方法 | B | 移除状态变更回调；在 `dispose` 中与 `addOnStatusChanged` 配对。 |
| [`recordSyncResult`](#recordsyncresult) | 方法 | A | 把手动触发同步记录进相同状态路径。 |
| `notifyLocalDataChangedIfNeeded` | 方法 | B | **若**引擎的本地数据已变标志已设则触发重载回调（并消费该标志）。 |
| `notifyLocalDataChangedNow` | 方法 | B | 无条件触发重载回调（恢复、ZIP 导入）。 |
| `recordFinalizeResult` | 方法 | B | 记录冲突终定：成功，或失败 "Failed to upload resolved sync conflicts"。 |
| [`start`](#start) | 方法 | A | 开始观察生命周期、同步一次并启动周期计时器。 |
| `stop` | 方法 | B | 取消两个计时器并停止观察生命周期。 |
| [`notifySaved`](#notifysaved) | 方法 | A | 存储钩子：重启 30 秒防抖。 |
| [`requestSyncNow`](#requestsyncnow) | 方法 | A | 取消任何挂起防抖并立即同步。 |

行数（20）比 `grep -c '/// Purpose:' auto_sync_service.dart`（18）多二。18 个 `Purpose:` 块中有一个是第 1 行的库头，不是声明，因此 17 个声明带有它。多出的三行是 `AutoSyncService` 类以及字段 `instance` 和 `_scheduler`，它们带普通 `///` 描述或没有注释，因每个声明都出现在表中而列出。Tier A：5 行。除 `_scheduler` 外每个成员都是委托给调度器的单行代码；下面的 Tier A 条目是调用方必须了解其行为的那些。

## 文档

### `late final shared.AutoSyncScheduler _scheduler` <a id="_scheduler"></a>
- **种类：** `AutoSyncService` 的私有 `late final` 实例字段。
- **来源：** `lib/shared/services/auto_sync_service.dart`（第 30 行）。
- **用途：** 持有唯一的共享调度器，配置了 [本应用提供的钩子](#hooks-this-app-supplies) 中列出的五个钩子。
- **输入：** 无；首次访问时惰性构建。
- **返回：** 每个公开成员都委托给它的 `AutoSyncScheduler`。
- **副作用：** 构建时无。它携带的钩子在调度器调用时读取 `webdav_config.json`、运行 WebDAV 同步并运行每日自动备份。
- **算法：** 1. `isAutoSyncActive` 加载 WebDAV 配置，要求其非 null、`isConfigured` 且 `autoSync`。2. `runSync` 再次加载配置；若自门控后已消失则返回 `AutoSyncResult(success: false)` 而不抛出；否则调用 `WebDAVService.sync(config)` 并把 `success`、`hasConflicts` 和 `error` 复制进 `AutoSyncResult`。3. `consumeLocalDataChanged` 即 `WebDAVService.consumeLocalDataChanged`。4. `onPeriodicTick` 和 `onResume` 都是 `BackupService.runAutoBackupIfNeeded`。
- **用法：** 仅内部；`AutoSyncService` 的每个公开成员都转发给它。
- **备注：** `runSync` 调用 `WebDAVService.sync` 时不带 `autoResolve`，因此它保持默认 `false`，真实冲突以 `hasPendingConflicts` 浮出。调度器吞掉 `onPeriodicTick`/`onResume` 的错误，因此失败的备份绝不会破坏计时器或恢复处理器。

### `void recordSyncResult(SyncResult result)` <a id="recordsyncresult"></a>
- **种类：** `AutoSyncService` 的方法。
- **来源：** `lib/shared/services/auto_sync_service.dart`（第 121 行）。
- **用途：** 把用户手动运行的同步结果送入后台循环维护的同一组状态字段。
- **输入：** `result` — 来自 `WebDAVService` 的应用类型化 `SyncResult`。
- **返回：** 无。
- **副作用：** 更新 `lastSuccessAt`/`lastFailureAt`/`lastError`/`hasPendingConflicts` 并通知状态监听者。
- **算法：** 把 `result` 转换为 `shared.AutoSyncResult(success, hasConflicts, error)` 并传给调度器；调度器把冲突记录为带 `hasPendingConflicts = true` 的失败，把普通失败记录为带 `result.error`（或 "Unknown sync failure"）的失败，其余记录为清除错误和冲突标志的成功。
- **用法：**
  ```dart
  AutoSyncService.instance.recordSyncResult(result);
  AutoSyncService.instance.notifyLocalDataChangedIfNeeded();
  ```
  （来自 `webdav_config_page.dart` 的手动同步、强制上传和强制下载之后，以及
  `backup_page.dart` 的强制上传之后）
- **备注：** 后台同步失败引发的状态横幅正是这样在用户手动同步成功后清除的。

### `void start()` <a id="start"></a>
- **种类：** `AutoSyncService` 的方法。
- **来源：** `lib/shared/services/auto_sync_service.dart`（第 161 行）。
- **用途：** 在进程生命周期内开始自动同步。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 注册 `WidgetsBindingObserver`，启动一次立即的受守卫同步，并启动 15 分钟周期计时器，其每次触发都请求同步并运行 `onPeriodicTick`。
- **算法：** 委托给调度器：已启动则返回；设置已启动标志；添加生命周期观察者；立即请求同步；启动 `Timer.periodic(15 min)`。
- **用法：**
  ```dart
  AutoSyncService.instance.start();
  ```
  （来自 `lib/main.dart`，启动时）
- **备注：** 幂等。每个触发都先经过 `isAutoSyncActive` 门控，因此在 WebDAV 未配置或自动同步关闭时启动没有代价。`start()` 之前 `notifySaved()` 被忽略。

### `void notifySaved()` <a id="notifysaved"></a>
- **种类：** `AutoSyncService` 的方法。
- **来源：** `lib/shared/services/auto_sync_service.dart`（第 175 行）。
- **用途：** 让存储保存调度一次防抖同步。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 取消任何挂起的防抖计时器，并启动一个新的 30 秒计时器来运行受守卫的同步。
- **算法：** 委托给调度器：未启动则返回；否则替换防抖计时器（后沿）。
- **用法：**
  ```dart
  AutoSyncService.instance.notifySaved();
  ```
  （来自 [`device_storage.md`](../../features/devices/services/device_storage.md#save) 中的 `DeviceStorage.save`
  以及其他存储的 `save` 方法；若干编辑页和列表页也直接调用它）
- **备注：** 一连串保存只在最后一次之后 30 秒产生一次同步。[`start`](#start) 之前被忽略，因此早期的存储写入无法调度同步。

### `void requestSyncNow()` <a id="requestsyncnow"></a>
- **种类：** `AutoSyncService` 的方法。
- **来源：** `lib/shared/services/auto_sync_service.dart`（第 182 行）。
- **用途：** 尽快同步，不等待防抖。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 取消挂起的防抖计时器并启动一次受守卫同步，不 await。
- **算法：** 委托给调度器内部的立即请求路径，即启动、周期和恢复触发所用的同一路径。
- **用法：**
  ```dart
  AutoSyncService.instance.requestSyncNow();
  ```
  （来自 `webdav_config_page.dart`，在保存开启自动同步的配置之后，以及打开
  自动同步开关时）
- **备注：** 与 [`notifySaved`](#notifysaved) 不同，它不检查已启动标志。它仍需经过 `isAutoSyncActive` 门控，重叠触发被在途守卫静默跳过。

## 备注

- 状态仅内存且从不持久化。
- 自动同步保持 `autoResolve` 禁用：真实双向冲突被记录为可见挂起状态而非静默应用最后写入者胜出。
- 重叠触发被在途守卫静默跳过。
- `notifySaved()` 在 `start()` 前被忽略。
- **抽取带来的行为变化：** 恢复现在同步前取消挂起保存防抖，而非让它与恢复同步一起排队。在途守卫已使差异不可观察；这只是把三个应用统一到一个规则。

## 调度器文档在哪里

`packages/myapps_data/doc/en-us/functions/src/sync/auto_sync_scheduler.md`。
