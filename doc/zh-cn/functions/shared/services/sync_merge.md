# lib/shared/services/sync_merge.dart

**拆分文件。** 通用三方记录合并——`mergeRecords<T>`、`RecordConflict<T>` 和 `RecordMergeResult<T>`——移到 `myapps_data` 包（`lib/src/merge/sync_merge.dart`）并在此重新导出。MyDevice 自己的合并逻辑留下。

MyDevice 的签名是**包采用的超集**：它携带用于模型级 `extraJson` 保留的可选 `mergeUnknownFields` 回调。共享实现因此这里行为相同，设备合并仍传该回调。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`mergeAssignments(...)`](#mergeassignments) | 函数 | A | MyDevice 独有网络设备赋值复合键合并。 |
| `DeviceMergeResult` / `mergeDeviceData(...)` | 类 + 函数 | A | 设备，带未知字段保留。 |
| `NetworkMergeResult` / `mergeNetworkData(...)` | 类 + 函数 | A | 网络及其赋值。 |
| `DataSetMergeResult` / `mergeDataSetData(...)` | 类 + 函数 | A | 数据集。 |
| `ServiceMergeResult` / `mergeServiceData(...)` | 类 + 函数 | A | 服务节点和路由（两个容器）。 |
| `RecordConflict<T>` / `RecordMergeResult<T>` / `mergeRecords<T>` | 重新导出 | A | 通用引擎，来自包。 |

## 文档

### `mergeAssignments(local, remote, base)` <a id="mergeassignments"></a>
- **用途：** `NetworkDevice` 赋值记录的三方合并。
- **备注：** 刻意**不**抽取。赋值无 `modifiedAt`，因此变更经对照基础比较序列化内容检测，键是复合（`networkId:deviceId`）。都变时解析为本地，因为无时间戳挑胜者。未知字段从输侧合并。

### 逐模块合并包装
- **备注：** 各返回携带其合并列表、冲突列表和保留顶层 `extraJson` 的应用类型化结果。同步引擎把它们作为不透明 `state` 携带，这正是冲突对话框仍收到真实模型对象的方式。`ServiceMergeResult.buildResolved` 按运行时类型消歧共享记录 ID，这正是单个扁平解析映射能服务每个模块的原因。

## 通用引擎文档在哪里

`packages/myapps_data/doc/en-us/functions/src/merge/sync_merge.md`。
