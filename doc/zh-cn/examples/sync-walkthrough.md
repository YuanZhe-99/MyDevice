# 同步演练

[WebDAV 同步](../sync.md) 流程的完整示例，覆盖自动解决 case、真实冲突 case 和 `NetworkDevice` 复合键合并。这用具体数据走通 [三方合并](../algorithms/three-way-merge.md) 的概念。

设置：两台设备"Laptop A"和"Desktop B"都配置同步相同 WebDAV 文件夹。两者都已同步过一次，因此各有匹配上次上传内容的本地 `.sync_base/device_data.json`。

## Case 1：自动解决（只有一侧变化）

1. Laptop A 上用户编辑 `Device` 记录（id `dev-1`，名 "ThinkPad X1"）添加 `purchasePrice`。这把 `dev-1.modifiedAt` bump 到 `2026-07-23T10:00:00Z`（UTC——见 [数据格式 — UTC modifiedAt](../data-formats.md#utc-modifiedat)）。
2. Desktop B 自上次同步未碰 `dev-1`——其本地 `dev-1` 的 `modifiedAt` 仍等于基础快照的 `modifiedAt`。
3. Laptop A 打开 WebDAV 设置并同步（或自动同步保存后 30 秒计时器触发）：
   - **步骤 1**（[9 步流程](../sync.md#the-9-step-flow)）：以 60 秒 TTL 获取 `.lock`。
   - **步骤 2：** 从远程下载 `device_data.json`——成功（HTTP 200）。
   - **步骤 3：** 加载本地 `device_data.json` 和 `.sync_base/device_data.json`。
   - **步骤 4：** `mergeRecords<Device>` 把 `dev-1` 的本地 `modifiedAt` 对照基础比较——本地变、远程没变。
   - **步骤 5：** 自动解决为本地 `dev-1` 版本（无冲突，因为只有一侧变化——见 [三方合并 — mergeRecords<T> 通用 ID + 时间戳合并](../algorithms/three-way-merge.md#mergerecordst--generic-id--timestamp-merge) case "只有本地变"）。
   - **步骤 7：** 此合并完全无冲突 → 在仍有效的 `.lock` 下强制上传完整合并 `device_data.json`。
   - **步骤 9：** 保存新基础快照，清除上传锁。
4. Desktop B 下次同步时下载更新 `device_data.json`、合并（其自己 `dev-1` 没变、远程变了 → 取远程版本），其 `.sync_base` 追上。两台设备都不需要用户交互。

## Case 2：真实冲突（两侧改了同一记录）

1. 从相同基础开始，用户在 **Laptop A** 于 `10:00:00Z` 编辑 `dev-1` 的 `notes` 字段。
2. Laptop A 同步前，用户也在 **Desktop B** 于 `10:05:00Z` 编辑 `dev-1` 的 `screenSize` 字段——真正不同的变更，不是同一编辑做两次。
3. Desktop B 先同步：成功上传（自动解决与 Case 1 相同方式应用，因为从 Desktop B 角度同步时只有*它*相对自己的基础改了 `dev-1`）。
4. Laptop A 接着同步：
   - **步骤 4：** `mergeRecords<Device>` 把两侧对照基础比较——`dev-1` 的 `localChanged` 和 `remoteChanged` 都为 true。
   - 相同内容检查（`serialize(local) == serialize(remote)`）失败——`notes` 和 `screenSize` 真实不同。
   - **手动同步和自动同步都用 `autoResolve: false`**（见 [WebDAV 同步 — 手动 vs 自动同步](../sync.md#manual-vs-auto-sync)），因此这不经最后写入者胜出解决。发出带 `localRecord`（Laptop A 版本，`notes` 已编辑）和 `remoteRecord`（Desktop B 版本，`screenSize` 已编辑）的 `RecordConflict<Device>`。
   - **步骤 8：** 冲突返回给用户而非上传。冲突对话框显示两侧 `modifiedAt`（`10:00:00Z` vs `10:05:00Z`——真实 `Device` 有时间戳，不同于 `NetworkDevice`；见下面 Case 3）。
5. 用户选解决（或应用外手动合并再重新输入）。假设保留 Desktop B 版本。应用调用 `finalizePendingSync`：
   - 重新获取 `.lock`。
   - 强制上传完整解决 JSON（`dev-1` = Desktop B 版本，但 `extraJson` 未知字段仍按 [数据格式 — extraJson 未知字段保留](../data-formats.md#extrajson-unknown-field-preservation) 从两侧合并）。
   - 成功时保存 `device_data.json` 新基础快照。
6. 用户反而关闭冲突对话框（如系统返回手势）时，按 [WebDAV 同步 — 手动 vs 自动同步](../sync.md#manual-vs-auto-sync) 整个解决中止：不上传任何东西、冲突在设置/WebDAV 中保持可见为挂起状态，两侧都不被静默选择。

## NetworkDevice 赋值示例

`NetworkDevice` 无 `id` 无 `modifiedAt`——其身份是复合键 `(networkId, deviceId)`，合并比较序列化内容而非时间戳（见 [网络 — 复合键身份及其原因](../features/networks.md#composite-key-identity--and-why) 和 [三方合并 — mergeAssignments 复合键内容比较合并](../algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)）。

1. 基础状态：`dev-1` 以 `NetworkDevice(networkId: 'net-home', deviceId: 'dev-1', addressMode: dhcp, ipAddress: null)` 赋值给网络 `net-home`。两台设备上次同步了这个精确赋值。
2. **Laptop A** 上用户为 `net-home` 上的 `dev-1` 设静态 IP：`addressMode: static_, ipAddress: '192.168.1.50'`。
3. **Desktop B** 未碰此赋值。
4. Laptop A 先同步（成功上传——远程现在有静态 IP 版本）。
5. Desktop B 同步：
   - `mergeAssignments()` 计算 `key = 'net-home:dev-1'`。
   - 把 `content(local)`（仍 DHCP，匹配基础）对照 `baseContent[key]` 比较——未变。
   - 把 `content(remote)`（静态 IP）对照 `baseContent[key]` 比较——变了。
   - 按算法（"远程变且本地没变 → 取远程"），Desktop B 的合并取远程（静态 IP）版本。`NetworkDevice` 绝不抛冲突——算法总是确定性解决（只在*两侧*改了同一赋值时有本地胜出偏向；见 [三方合并 — 算法](../algorithms/three-way-merge.md#algorithm-1)）。
6. 若同一次同步碰巧产生 `Network`（非赋值）冲突且冲突对话框需要引用此赋值，它会显示复合键 ID `net-home:dev-1` 而非两侧各一个 `modifiedAt`，因为不存在——见 [WebDAV 同步 — NetworkDevice 复合键合并](../sync.md#networkdevice-composite-key-merge)。

## 相关

- [WebDAV 同步](../sync.md) — 完整 9 步流程。
- [三方合并](../algorithms/three-way-merge.md) — 底层算法。
- [数据格式](../data-formats.md) — 上面使用的 `Device`/`NetworkDevice` 字段形态。
