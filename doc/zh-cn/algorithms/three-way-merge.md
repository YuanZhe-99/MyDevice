# 三方合并

来源：`lib/shared/services/sync_merge.dart`（约 22 KB）。这是 [WebDAV 同步](../sync.md) 背后的通用合并引擎；它如何插入完整 9 步同步流程见该页，被合并的模型见 [数据格式](../data-formats.md)。

本文件有两个合并算法：每个有 `id` 和 `modifiedAt` 的模型使用的通用基于 ID/时间戳的 `mergeRecords<T>`，以及专门用于两者都没有的 `NetworkDevice` 的复合键/内容比较 `mergeAssignments`。

## `mergeRecords<T>` — 通用 ID + 时间戳合并

确认签名：

```dart
RecordMergeResult<T> mergeRecords<T>({
  required List<T> local,
  required List<T> remote,
  required List<T>? base,
  required String Function(T) getId,
  required DateTime Function(T) getModifiedAt,
  required String Function(T) getDisplayName,
  T Function(T primary, T secondary, T? base)? mergeUnknownFields,
  bool autoResolve = false,
  String Function(T)? serialize,
})
```

用于 `Device`、`Network`、`DataSet`、`ServiceNode` 和 `ServiceRoute`——每个有 `id` 和 `modifiedAt` 的模型（见同文件 `mergeDeviceData`、`mergeNetworkData`、`mergeDataSetData`、`mergeServiceData`，各解码 JSON、用模型自己的 `id`/`modifiedAt`/显示名访问器调用 `mergeRecords<T>`，并重组类型化 `*MergeResult`）。

### 算法

构建三个 ID 键控映射（`localMap`、`remoteMap`、`baseMap`）并遍历任何地方见过的所有 ID 的并集：

1. **两侧都有记录，且基础存在（真实三方 case）：**
   - 把每侧 `modifiedAt` 与基础的 `modifiedAt` 比较（`isAfter`）确定 `localChanged` / `remoteChanged`。
   - **都变了：**
     - 提供 `serialize` 且 `serialize(local) == serialize(remote)`——两侧内容相同——无冲突合并（这正是让记录从更早失败上传的过期基础中存活而不误报冲突的东西；见 [WebDAV 同步](../sync.md#the-9-step-flow) 步骤 4）。
     - 否则 `autoResolve` 为 true 时把 `modifiedAt` 较晚一侧作为 primary（最后写入者胜出），另一侧作为未知字段合并的 secondary。
     - 否则为调用方发出带两侧的 `RecordConflict<T>` 解决（手动同步和自动同步都一样使用，因为两者都用 `autoResolve: false`——见 [WebDAV 同步](../sync.md#manual-vs-auto-sync)）。
   - **只有本地变：** 保留本地（经 `preserveUnknown` 合并远程未知字段）。
   - **只有远程变：** 保留远程。
   - **都没变：** 保留本地（任意——两者从基础等价）。
2. **两侧都有记录，无基础（首次同步，或两侧独立创建相同 ID）：** primary = `modifiedAt` 较晚一侧；secondary = 另一侧。
3. **只有本地有记录：**
   - 有基础：本地自基础变化，它经受住了远程删除——保留它（删除-vs-修改冲突以修改胜出解决）。本地未变化，它被远程删除且本地未碰——丢弃它。
   - 无基础：本地新的——包含它。
4. **只有远程有记录：** 与 case 3 对称。
5. **两侧都没有（都 null），但在基础中：** 两侧都删——从结果排除。

`preserveUnknown(primary, secondary, base)` 调用调用方提供 `mergeUnknownFields` 回调（典型为模型自己的 `mergeUnknownFieldsFrom`，见 [数据格式 — extraJson 未知字段保留](../data-formats.md#extrajson-unknown-field-preservation)）或未给回调时原样返回 `primary`。

### 结果形态

```dart
class RecordConflict<T> {
  final String id;
  final T localRecord;
  final T remoteRecord;
  final String displayName;
}

class RecordMergeResult<T> {
  final List<T> merged;
  final List<RecordConflict<T>> conflicts;
}
```

每个逐模型包装（`DeviceMergeResult`、`NetworkMergeResult`、`DataSetMergeResult`、`ServiceMergeResult`）暴露 `hasConflicts` 和取调用方逐冲突 ID 解决选择、产生准备好上传的最终类型化数据容器（`DeviceData`、`NetworkData` 等）的 `buildResolved(resolutions)` 方法。

## `mergeAssignments` — 复合键内容比较合并

`NetworkDevice` 无 `id` 无 `modifiedAt`（见 [网络 — 复合键身份及其原因](../features/networks.md#composite-key-identity--and-why)），因此需要不同算法。确认签名：

```dart
List<NetworkDevice> mergeAssignments(
  List<NetworkDevice> local,
  List<NetworkDevice> remote,
  List<NetworkDevice>? base,
)
```

键函数是 `'${networkId}:${deviceId}'`；变更检测函数是 `jsonEncode(assignment.toJson())`——即**对照基础的内容相等**，非时间戳比较。

### 算法

对跨 local/remote/base 的每个复合键：

1. **两侧都有，带基础：** 把每侧序列化内容与基础该键序列化内容比较。
   - 远程变且本地没变 → 取远程（合并进本地未知字段）。
   - 否则（本地变，或都变，或都没变）→ **取本地**。注意这是对 `mergeRecords<T>` 的刻意简化：两侧都变时无时间戳选胜者，此函数总是偏好本地而非向用户浮出冲突。`mergeUnknownFieldsFrom` 仍双向调用，使无论哪侧已知字段胜出，两侧未知字段都保留。
2. **两侧都有，无基础：** 都新——合并未知字段，保留本地已知字段为 primary。
3. **只有本地有：**
   - 带基础：本地内容对照基础变了，远程删了它但本地修改了它——保留本地。本地内容匹配基础，远程删了它且本地没碰——丢弃它。
   - 无基础：本地新的——保留它。
4. **只有远程有：** 与 case 3 对称。

与 `mergeRecords<T>` 不同，`mergeAssignments` **绝不产生 `RecordConflict`**——每个 case 确定性解决（两侧改了同一赋值时带本地胜出偏向）。这正是冲突对话框对 `NetworkDevice` 无物可显示、在*确实*需要显示一个时（如同时碰赋值的 `Network` 冲突内）回退记录复合键 ID 的原因——见 [WebDAV 同步 — NetworkDevice 复合键合并](../sync.md#networkdevice-composite-key-merge)。

`mergeNetworkData()` 对 `Network` 列表运行 `mergeRecords<Network>`（带真实 `RecordConflict<Network>` 支持）并对赋值列表单独运行 `mergeAssignments()`，然后组合进一个 `NetworkMergeResult`。

## 相关

- [WebDAV 同步](../sync.md) — 此合并引擎插入的完整 9 步流程。
- [同步演练](../examples/sync-walkthrough.md) — 两条合并路径的完整示例，含 `NetworkDevice` 赋值场景。
- [数据格式 — extraJson 未知字段保留](../data-formats.md#extrajson-unknown-field-preservation) — 上面两个算法都使用的 `mergeUnknownJsonFields`/`jsonValueEquals` 辅助。
