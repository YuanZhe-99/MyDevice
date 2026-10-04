# 网络

## 配置与 CSV 导入（1.9.0）

自动匹配依次使用节点 ID、不区分大小写的精确名称、忽略空格/连字符/下划线/点的
名称。预览显示依据和歧义候选。每个目标可调整，新设备可编辑名称/分类/系统。
逐列显示前后值并可勾选，未勾选保留原值。移动已有节点明确提示并保留原设备。
网络分配并发修改会拒绝保存。

EasyTier 菜单可编辑 TOML/YAML 原文，支持读取、复制、导出和保存。每项网络分配独立
保存文本；切换标签不转换或执行配置。Tailscale CSV 导入逐行预览已有/新建/跳过选项，
先按节点 ID 匹配，再建议无歧义精确名称匹配。保留全部原始列和地址，菜单可查看详情。
不删除缺失节点或覆盖已有设备规格。不能选择退役/出售设备，多行不得关联同一设备。
先保存新设备，再排队一次保存网络；失败保留预览及生成 ID 供重试。此操作不是跨文件
事务：网络保存失败时新设备记录可能保留。相同内容导入跳过网络写入。

模型来源：`lib/features/network/models/network.dart`。精确字段列表见 [数据格式 — 网络 / NetworkDevice](../data-formats.md#network--networkdevice-libfeaturesnetworkmodelsnetworkdart)。

## Network

`Network` 表示局域网、VPN 叠加网络或类似物：`id`、`name`、`type`、`subnet`、`gateway`、`dnsServers`（`List<String>`）、`notes`、`modifiedAt`、`extraJson`。

`NetworkType` 值（确认枚举）：`lan`、`tailscale`、`zerotier`、`easytier`、`wireguard`、`other`。

## NetworkDevice

`NetworkDevice` 是设备在网络中的成员/赋值：`networkId`、`deviceId`、`addressMode`（`AddressMode`：`dhcp` 或 `static_`，序列化为 `"dhcp"` / `"static"`）、`ipAddress`、`hostname`、`isExitNode`、`extraJson`。

## 复合键身份——及其原因 <a id="composite-key-identity--and-why"></a>

直接在 `NetworkDevice` 类体确认：其构造函数**无 `id` 参数、完全无 `modifiedAt` 字段**——只有 `networkId`、`deviceId`、`addressMode`、`ipAddress`、`hostname`、`isExitNode`、`extraJson`。这是刻意的：

- `NetworkDevice` 本质上是单个 `Network` 与单个 `Device` 之间的*关系*——对 `(networkId, deviceId)` 已是自然唯一键，因此多对多连接行再要单独合成 `id` 只是冗余记账。
- 无 `modifiedAt`，三方同步合并无法用"谁更近修改"检测哪侧变了。而是 `lib/shared/services/sync_merge.dart` 的 `mergeAssignments()` 把每侧**序列化 JSON 内容**对照同一复合键的上次同步基础快照比较。精确算法见 [三方合并 — mergeAssignments 复合键内容比较合并](../algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)，完整示例见 [同步演练 — NetworkDevice 赋值示例](../examples/sync-walkthrough.md#networkdevice-assignment-example)。
- 因为无时间戳，同步冲突对话框专门为 `NetworkDevice` 赋值回退显示记录复合键 ID 而非 `modifiedAt`（每个其他记录类型显示真实时间戳）。见 [WebDAV 同步 — NetworkDevice 复合键合并](../sync.md#networkdevice-composite-key-merge)。

## 相关

- [WebDAV 同步](../sync.md) 了解 `Network` 和 `NetworkDevice` 如何不同同步。
- [数据格式](../data-formats.md) 了解完整持久化数据清单。
- 退役/出售设备从网络分配和选择器移除——见 [设备 — 退役/出售/删除的级联规则](devices.md#cascade-rules-on-retiresell-delete)。
