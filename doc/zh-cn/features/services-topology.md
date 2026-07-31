# 服务与拓扑

模型来源：`lib/features/services/models/service.dart`。布局算法来源：`lib/features/services/services/service_topology_layout.dart`。精确模型字段见 [数据格式 — ServiceNode / ServiceEndpoint / ServiceRoute / ServiceRouteHop](../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)，布局/路由算法深潜见 [服务拓扑布局](../algorithms/service-topology-layout.md)。完整示例见 [服务拓扑演练](../examples/service-topology-walkthrough.md)。

## 仅手动清单约束

这是整个功能最重要的约束，直接陈述于 `AGENTS.md`：**服务管理是手动清单/备注模块，不是运维或监控系统。** 它必须不连接服务器、不扫描端口、不检查 Docker、不启动/停止服务、不存储机密。用户为个人参考手输服务、端口、路由和 Docker Compose 备注——这里没有任何发现。

服务数据存储在 `service_data.json` 并像其他主模块一样同步/备份/导入（见 [数据格式 — 持久化数据清单](../data-formats.md#persisted-data-inventory)）。

## 模型回顾

- **`ServiceNode`** — 设备上的服务实例：`deviceId`、`name`、`templateId`/`icon`/`kind`/`runtime`/`state`、`endpoints`（`List<ServiceEndpoint>`）、`tags`、`notes`、可选 `dockerCompose`（纯文本，可从编辑器复制——此字段不添加凭据/令牌管理）、`modifiedAt`、`extraJson`。
- **`ServiceEndpoint`** — 手动记录的本地/监听端点：协议、传输、绑定地址、端口或端口范围（`port`/`portEnd`）、可选路径/`networkId`、`scope`、`isPrimary` 标志、备注、`extraJson`。
- **`ServiceRoute`** — 从源服务端点经有序 `hops` 到最终 URL/地址的手动记录访问路径。`finalUrl` 为向后兼容存储第一目标；*同一*访问路径的额外分组 URL/域存储在 `extraJson['publicTargets']`。
- **`ServiceRouteHop`** — 一跳：源、反向代理、隧道、端口转发、公共端点、内部端点、DNS 或手动备注。跳可引用既有服务/端点（`serviceId`/`endpointId`/`deviceId`）或完全自由形式（`label`/`scheme`/`host`/`port`/`path`）。

完整字段列表：[数据格式](../data-formats.md)。

## 视图

服务标签有四个视图：**总览**、**按设备**、**路由**和**端口**。

总览从保存的服务/路由生成手动服务拓扑图，按本地设备分组，同时允许共享远程设备/VPS 节点跨多个本地设备。图区分：

- 本地服务端点。
- 局域网/WiFi 访问。
- VPN/Tailscale 访问。
- 中继/代理/隧道跳。
- FRP/路由器风格远程端口条目。
- 最终域/URL。

总览卡片页头/操作布局响应式，使"service topology"等标题在窄屏不垂直坍缩，它用**打开拓扑按钮**而非缩小嵌入式预览，因为真实图太密在预览尺寸不可读。全屏拓扑添加可选择节点详情、单独移动/缩放模式、内部 90 度旋转（不改变系统方向）和 PNG 导出/分享（平台特定机制——见 [平台说明 — Android](../platform-notes.md#android)）。

## 拓扑图布局（高层）

拓扑布局**语义紧凑而非固定列**：动态图等级从实际边派生并按图压缩，使未用角色列不浪费画布空间。全屏拓扑把昂贵布局推迟到首帧后，并按图、路由、宽度和旋转派生视口缓存布局，因此模式变化（如进入移动/缩放模式）不重跑路由。

边由**带 A* 回退的快速净空路径正交路由器**预计算，带膨胀节点障碍、转弯代价、拥塞代价、显式退出/进入桩和障碍外路由轨道——因此箭头避开元素内部并垂直进入/离开卡片。算法细节（类/函数名、障碍模型、代价函数）见 [服务拓扑布局](../algorithms/service-topology-layout.md)。

直接/局域网/VPN 访问节点和远程 VPS 设备在源端点后作为**平行分支**出现而非单链，同设备公共反向代理服务（如 Caddy）保持本地但可放在路由路径更后位置，使箭头保持从左到右移动。

## 快速访问路由创建 vs 高级编辑器

**快速访问路由创建**是添加直接、反向代理、隧道、FRP 和路由器端口转发访问路径的默认、简单流程——它覆盖常见 case，无需用户手工构建多跳链。**高级路由编辑器**对手工多跳链仍可用，用于不适合那些模板的。路由*名称*内部生成（对用户隐藏）；面向用户的路由描述属于 `notes`。

## FRP 风格入口/公共端口建模

对 FRP 风格访问，路径建模为：VPS/远程设备 → 该 VPS/远程设备上的 FRP 服务，带**兄弟 FRP 端口 chip**：

- **入口/监听端点**，如端口 `57000`。
- 单独**公共远程入口端口**，如端口 `443`。

**源端点连接到 FRP 入口端口**，而 **FRP 公共端口连接到一个或多个域**——入口和公共 FRP 端口*不*建模为链（即不是入口 → 公共端口 → 域三个顺序跳；源直接连接入口，公共直接连接域，作为同一 FRP 服务下兄弟）。此精确模式的完整示例见 [服务拓扑演练](../examples/service-topology-walkthrough.md)。

拓扑端点和远程公共入口端口渲染为带图标和端口号的小圆角方块**端口 chip**，使端口保持可见而不与主设备/服务/域节点视觉竞争。

## 服务模板

`service_template_service.dart` 为常见自托管工具提供模板：Caddy、Gitea、Jellyfin、Pangolin、FRP、Cloudflare Tunnel、File Browser、Vaultwarden、Nextcloud、WordPress、Code Server、OpenCode、AdGuard Home、LuCI、Minecraft Server 和相关 homelab 服务。模板只**预填**名称/图标/类型/默认端口/Compose 示例——不执行发现，匹配上面仅手动清单约束。

## 端口冲突检测

端口冲突检测**仅建议**：它警告多个手动输入服务使用相同设备/传输/端口，但绝不阻塞保存，因为绑定地址和用户意图可能合法不同（如两个服务正确绑定同一端口的不同接口）。

## 相关

- [服务拓扑布局](../algorithms/service-topology-layout.md) — 布局和路由算法。
- [服务拓扑演练](../examples/service-topology-walkthrough.md) — 完整 FRP 示例。
- [数据格式](../data-formats.md) — 完整模型字段。
- [备份与恢复 — Markdown 导出](../backup-restore.md#markdown-export) — Markdown 导出含服务端点、路由、跳、Compose 备注和分组公共目标。
- [平台说明 — 桌面本地 API 服务器](../platform-notes.md#desktop-local-api-server) — 只读 `/service/*` API 端点。
