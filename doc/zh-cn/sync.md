# WebDAV 同步

MyDevice 的 WebDAV 同步是**逐记录三方合并，非整文件替换**。引擎住在 `lib/shared/services/webdav_service.dart`（`WebDAVService`）和 `lib/shared/services/sync_merge.dart`（合并算法——见 [三方合并](algorithms/three-way-merge.md)）。本页描述流程、重试/心跳策略、图像同步，以及本应用流程与姊妹 MyAnime 应用不同的一个地方。完整示例见 [同步演练](examples/sync-walkthrough.md)。

## 9 步流程

1. **任何数据下载前获取远程 `.lock`**，用稳定本地客户端 id、一个上传令牌、UTC 时间戳和 60 秒 TTL（`webdav_service.dart` 的 `_lockTtlSeconds = 60`）。其他客户端持有的活动锁阻塞上传；过期锁当作失败上传且可替换。本地 `.sync_base/upload_lock.json` 文件让*下次*应用启动检测中断上传并在再次上传前重新下载/重新合并。
2. **用判别结果下载远程 JSON。** 只有 HTTP 404 算"远程缺失"。**任何其他失败（认证/服务器/网络）记录逐文件错误并跳过该文件**——该文件本地数据绝不在不可读远程文件上上传。这是 MyDevice 流程刻意不同于 MyAnime 的唯一一点：MyAnime 非 404 下载失败时中止*整个*同步，而 MyDevice 为该单文件记录失败并独立继续同步其他数据文件（设备/网络/数据集/服务）。
3. **加载本地 JSON 和 `.sync_base/` 基础快照**（每个文件上次成功同步版本）。
4. **可用处按 `modifiedAt` 逐记录合并**（见 [三方合并](algorithms/three-way-merge.md)）。两侧*序列化内容*相同的记录即使两侧 `modifiedAt` 都动也无冲突合并（如更早失败上传留下过期基础后）。
5. **只有一侧相对基础变化时自动解决。**
6. **相同记录自上次同步起两侧都变时检测真实冲突。**
7. **无记录冲突时**在 `.lock` 仍有效时强制上传完整合并 JSON。数据 JSON `PUT` **不**用数据文件 `If-Match` / `If-None-Match` 前置条件——`.lock` 是数据写入唯一并发守卫。
8. **有记录冲突时**返回给用户而非自动解决。用户解决后 `finalizePendingSync` 重新获取 `.lock` 并强制上传每个完整解决 JSON。
9. **上传成功后保存新基础快照**，然后清除匹配远程/本地上传锁。

## 手动 vs 自动同步

- **手动同步**（从 WebDAV 设置页）用 `autoResolve: false` 并显示冲突对话框。
- **自动同步**也保持 `autoResolve` 禁用——绝不静默应用最后写入者胜出。而是把失败和真实双向冲突记录为设置/WebDAV 中可见状态；用户必须打开 WebDAV 页手动解决冲突。
- **关闭任何冲突对话框**（如系统返回手势）中止整个解决：不上传任何东西、冲突在可见同步状态保持挂起、无记录被静默解决为本地版本。
- `finalizePendingSync` 重新获取 `.lock` 并无数据文件前置条件地强制上传解决完整 JSON；任何文件远程读取或上传失败时返回 `false`，失败文件基础快照保持不动（因此下次同步重试）。

## 唤醒锁

WebDAV 页前台同步操作——手动同步、冲突终定上传、强制上传、强制下载——经 `lib/shared/services/sync_wake_lock.dart`（`wakelock_plus`）持有屏幕唤醒锁：

- 引用计数；只在无其他功能已持有时启用。
- 只在强制操作确认*后*获取（不在确认前 UI 期间持有）。
- 完成、失败、取消或异常时在 `finally` 释放。
- 绝不被后台自动同步使用（只有前台、用户发起操作持有）。

## 重试策略

瞬时网络失败——套接字/超时/客户端错误和 HTTP 5xx——最多**重试 2 次额外尝试，带 1s 然后 2s 退避**，由 `webdav_service.dart` 内部 `_withRetry<T>` 辅助实现（源码确认：`retries = 2` 默认、`Duration(seconds: attemptIndex)` 退避，即第一次重试前 1s、第二次前 2s）。这应用于数据 GET/PUT、字节（图像）GET/PUT 和 PROPFIND 列表。两件事绝不重试：

- **`.lock` 写**——绝不重试，使重试的仅创建 PUT 不误报锁争用。
- **HTTP 4xx 响应**——绝不重试（只有 `statusCode >= 500` 经传给 `_withRetry` 的 `shouldRetry` 谓词触发重试）。

## 心跳

数据或图像 `PUT` 在途时，持有 `.lock` 每 **20 秒**心跳刷新（`_lockHeartbeatInterval = Duration(seconds: 20)`，经 `webdav_service.dart` 的 `_withLockHeartbeat`）——确认远低于 60 秒锁 TTL，使比 TTL 慢的传输绝不让其他客户端把锁当作过期并并发上传。心跳失败被吞掉且绝不中止在途传输。

## 同步进度

`WebDAVService.progress` 是 `ValueNotifier<SyncProgress>`（`lib/shared/services/sync_progress.dart`），发布带逐文件和逐图像计数的连接/下载/合并/上传阶段。服务只发原始阶段和文件名；WebDAV 页把阶段映射为本地化文本并渲染 `LinearProgressIndicator`。

## 图像同步

图像**增量和仅引用**同步：同步引擎计算本地和远程 `Device` 记录引用的 `imagePath` 基名并集，只传输那些文件。孤儿图像（无设备再引用）不重复上传或下载。远程图像目录列表任何 PROPFIND 失败时返回 `null`；`_syncImages` 然后带可见警告跳过图像阶段，而非把未知远程状态当作空——这先前导致瞬时 PROPFIND 失败后每个引用图像被重新上传。下载图像设本地数据变更标志，使即使数据 JSON 本身未变 UI 页也重载。

## 逐文件数据合并规则

| 文件 | 合并策略 |
| --- | --- |
| `device_data.json` | `Device` 记录按 `id` 和 `modifiedAt` 合并 |
| `network_data.json` | `Network` 记录按 `id`/`modifiedAt`；`NetworkDevice` 赋值按复合键和内容比较 |
| `dataset_data.json` | `DataSet` 记录按 `id` 和 `modifiedAt` |
| `service_data.json` | `ServiceNode` 和 `ServiceRoute` 记录按 `id` 和 `modifiedAt`；端点和路由跳跟随其父记录 |

每个数据文件合并有**逐文件错误处理**——一个格式错误文件不阻塞其他文件同步。网络 IO 后重新读取本地文件检测*同步期间*发生的并发用户编辑。`_atomicWrite()` 用 tmp-然后-重命名避免损坏本地文件。`_syncing` 防止并发同步运行。

## NetworkDevice 复合键合并

`NetworkDevice` 无 `id` 无 `modifiedAt`（见 [数据格式](data-formats.md#network--networkdevice-libfeaturesnetworkmodelsnetworkdart)），因此其合并（`sync_merge.dart` 的 `mergeAssignments`）用复合键 `(networkId, deviceId)` 并对照基础快照比较*序列化 JSON 内容*检测哪侧（些）变了，因为无可比较时间戳。精确算法见 [三方合并 — mergeAssignments 复合键内容比较合并](algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)，完整示例见 [同步演练 — NetworkDevice 赋值示例](examples/sync-walkthrough.md#networkdevice-assignment-example)。

因为 `NetworkDevice` 无可显示冲突时间戳，**冲突对话框为 `NetworkDevice` 赋值回退显示记录 ID** 而非两侧裸 `modifiedAt`（每个其他记录类型显示的）。

## 强制上传 / 强制下载

- `WebDAVService.forceUpload()` 无任何合并或冲突检查地覆盖远程数据文件并上传引用图像，在远程 `.lock` 下，然后保存基础快照。
- `WebDAVService.forceDownload()` 替换本地数据文件（先 JSON 验证、原子写）并无合并地下载引用图像、保存基础快照并设本地数据变更标志。它仅下载且不取远程锁。

两者共享 `_syncing` 守卫并要求 WebDAV 页破坏性操作确认对话框。

## 自动同步触发器

自动同步在以下触发：

- 应用启动。
- 应用恢复。
- 存储保存后 30 秒防抖。
- 应用进程存活时 15 分钟周期计时器。
- 保存/启用完整配置的自动同步 WebDAV 设置（经 `requestSyncNow()` 立即同步）。

`_trySync` 持有实例级 `_syncing` 守卫，重叠触发器被静默跳过而非浮出虚假"同步已在进行"失败横幅。移动操作系统挂起可能延迟计时器直到恢复。存储层 `save()` 方法通知自动同步，使非 UI 写被覆盖。自动同步在内存记录最新成功、失败和挂起冲突状态，使设置和 WebDAV 页能浮出同步健康。

手动同步或强制操作后，WebDAV 页调用 `AutoSyncService.notifyLocalDataChangedIfNeeded()`，使打开页面无需等待下次后台同步即重载。

## 已知限制

同步合并当前合并后不运行完整交叉引用验证（如它不会在合并遍本身中主动清理设备在另一侧被删的 `NetworkDevice` 赋值）。见 [数据格式 — 交叉引用规则](data-formats.md#cross-reference-rules)。
