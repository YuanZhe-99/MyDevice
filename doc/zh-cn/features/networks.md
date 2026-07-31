# 网络

模型来源：`lib/features/network/models/network.dart`。精确字段列表见 [数据格式 — 网络 / NetworkDevice](../data-formats.md#network--networkdevice-libfeaturesnetworkmodelsnetworkdart)。

## Network

`Network` 表示局域网、VPN 叠加网或类似物：`id`、`name`、`type`、`subnet`、`gateway`、`dnsServers`（`List<String>`）、`notes`、`modifiedAt`、`extraJson`。

`NetworkType` 值（确认枚举）：`lan`、`tailscale`、`zerotier`、`easytier`、`wireguard`、`other`。

## NetworkDevice

`NetworkDevice` 是设备在网络中的成员/赋值：`networkId`、`deviceId`、`addressMode`（`AddressMode`：`dhcp` 或 `static_`，序列化为 `"dhcp"` / `"static"`）、`ipAddress`、`hostname`、`isExitNode`、`extraJson`。

## 复合键身份——及其原因

直接在 `NetworkDevice` 类体确认：其构造函数**无 `id` 参数、完全无 `modifiedAt` 字段**——只有 `networkId`、`deviceId`、`addressMode`、`ipAddress`、`hostname`、`isExitNode`、`extraJson`。这是刻意的：

- `NetworkDevice` 本质上是单个 `Network` 与单个 `Device` 之间的*关系*——对 `(networkId, deviceId)` 已是自然唯一键，因此多对多连接行再要单独合成 `id` 只是冗余记账。
- 无 `modifiedAt`，三方同步合并无法用"谁更近修改"检测哪侧变了。而是 `lib/shared/services/sync_merge.dart` 的 `mergeAssignments()` 把每侧**序列化 JSON 内容**对照同一复合键的上次同步基础快照比较。精确算法见 [三方合并 — mergeAssignments 复合键内容比较合并](../algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)，完整示例见 [同步演练 — NetworkDevice 赋值示例](../examples/sync-walkthrough.md#networkdevice-assignment-example)。
- 因为无时间戳，同步冲突对话框专门为 `NetworkDevice` 赋值回退显示记录复合键 ID 而非 `modifiedAt`（每个其他记录类型显示真实时间戳）。见 [WebDAV 同步 — NetworkDevice 复合键合并](../sync.md#networkdevice-composite-key-merge)。

## 相关

- [WebDAV 同步](../sync.md) 了解 `Network` 和 `NetworkDevice` 如何不同同步。
- [数据格式](../data-formats.md) 了解完整持久化数据清单。
- 退役/出售设备从网络赋值和选择器移除——见 [设备 — 退役/出售/删除的级联规则](devices.md#cascade-rules-on-retiresell-delete)。
