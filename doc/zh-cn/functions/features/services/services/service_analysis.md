# lib/features/services/services/service_analysis.dart

[服务与拓扑](../../../../features/services-topology.md) 描述的服务功能的纯计算伴生和 [service_topology_layout.md](service_topology_layout.md) 的布局引擎：从保存的服务/路由构建 `ServiceTopologyGraph`（节点/边）、检测端口冲突和悬空引用，并提供 UI 和 `import_export_service.dart` 的 Markdown 导出共享的访问目标/路由命名辅助。

**行数说明：** `grep -c 'Purpose:' service_analysis.dart` 返回 **27**，但其中 2 个块被编写它们的文档注释工具错附到非声明——一个坐在 `listServicePortUses` 内调用 `uses.sort(...)` 上方（非声明），一个坐在 `serviceRouteAccessTargets` 内调用 `addTarget(route.finalUrl);` 上方（`addTarget` 的真实声明在几行上方，已带自己正确块）。因此只有 **25** 个块文档化真实声明。本文件共 **52** 个真实声明（10 个类成员 + 42 个顶层/嵌套函数），因此 **27** 个未文档化——27-vs-52 算术也对账（25 文档化 + 27 未文档化 = 52；25 文档化 + 2 错附 = 27 原始 grep 匹配）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`ServiceTopologyNode` 构造函数](#servicetopologynode-new) | 构造函数 | A | 创建不可变拓扑节点。 |
| [`mergeRoute`](#mergeroute) | 方法（`ServiceTopologyNode`） | A | 把路由 id 附加到节点，已存在则合并。 |
| [`merge`](#merge) | 方法（`ServiceTopologyNode`） | A | 组合共享 id 的两个节点实例。 |
| [`ServiceTopologyEdge` 构造函数](#servicetopologyedge-new) | 构造函数 | A | 创建不可变拓扑边。 |
| [`ServiceTopologyGraph` 构造函数](#servicetopologygraph-new) | 构造函数 | A | 创建图结果值。 |
| `isEmpty` | getter（`ServiceTopologyGraph`） | B | 图是否无节点。 |
| [`ServicePortUse` 构造函数](#serviceportuse-new) | 构造函数 | A | 创建一个端点/端口/传输使用记录。 |
| `usesAnyAddress` | getter（`ServicePortUse`） | B | 绑定地址是否为通配符 `'*'`。 |
| [`ServicePortConflict` 构造函数](#serviceportconflict-new) | 构造函数 | A | 创建检测到端口冲突记录。 |
| [`ServiceWarning` 构造函数](#servicewarning-new) | 构造函数 | A | 创建引用完整性警告记录。 |
| [`listServicePortUses`](#listserviceportuses) | 顶层函数 | A | 把每个服务端点展开为具体逐端口使用记录。 |
| [`findServicePortConflicts`](#findserviceportconflicts) | 顶层函数 | A | 分组端口使用并标记同设备/传输/端口上重叠绑定地址。 |
| [`buildServiceTopology`](#buildservicetopology) | 顶层函数 | A | 从服务、路由和设备构建完整拓扑图。 |
| [`addNode`](#addnode)（嵌套于 `buildServiceTopology`） | 本地函数 | A | 按 id 插入或合并节点。 |
| [`addEdge`](#addedge)（嵌套于 `buildServiceTopology`） | 本地函数 | A | 插入去重边。 |
| `deviceNodeId`（嵌套） | 本地函数 | B | 格式化设备节点 id。 |
| `serviceNodeId`（嵌套） | 本地函数 | B | 格式化服务节点 id。 |
| `endpointNodeId`（嵌套） | 本地函数 | B | 格式化端点节点 id。 |
| [`addDeviceNode`](#adddevicenode)（嵌套） | 本地函数 | A | 添加/合并本地设备节点。 |
| [`addRemoteDeviceNode`](#addremotedevicenode)（嵌套） | 本地函数 | A | 在路由下添加/合并远程设备节点。 |
| [`addServiceNode`](#addservicenode)（嵌套） | 本地函数 | A | 添加/合并服务节点及其设备边。 |
| [`addEndpointNode`](#addendpointnode)（嵌套） | 本地函数 | A | 添加/合并端点节点及其服务边。 |
| [`findServiceReferenceWarnings`](#findservicereferencewarnings) | 顶层函数 | A | 找出损坏/含糊服务和路由引用。 |
| [`normalizedBindAddress`](#normalizedbindaddress) | 顶层函数 | A | 把任何通配符形态绑定地址规范化为 `'*'`。 |
| `_bindsOverlap` | 顶层函数 | A | 两个绑定地址是否可能碰撞。 |
| [`_conflictingPublicTargetRoutes`](#conflictingpublictargetroutes) | 顶层函数 | A | 把路由过滤到重复目标冲突中的那些。 |
| [`_publicTargetRoutesConflict`](#publictargetroutesconflict) | 顶层函数 | A | 决定共享目标的两条路由是否应警告。 |
| [`_sourceEndpointForDuplicateTargetCheck`](#sourceendpointforduplicatetargetcheck) | 顶层函数 | A | 解析目标冲突比较使用的源端点。 |
| [`_endpointPortsOverlap`](#endpointportsoverlap) | 顶层函数 | A | 两个端点端口范围是否重叠。 |
| [`_preferTopologyRole`](#prefertopologyrole) | 顶层函数 | A | 合并节点时挑更具体的两个角色。 |
| `_isRemoteRole` | 顶层函数 | B | 角色是否为"远程"角色之一。 |
| [`_isRemoteHopService`](#isremotehopservice) | 顶层函数 | A | 跳的服务是否应渲染为远程。 |
| [`serviceAccessLaneForRoute`](#serviceaccesslaneforroute) | 顶层函数 | A | 分类路由访问车道（本地/VPN/公共）。 |
| `_roleForRelay` | 顶层函数 | B | 把路由车道映射到中继节点角色。 |
| `_endpointForRoute` | 顶层函数 | B | 在服务上按 id 查找端点。 |
| [`_portMappingIngressEndpoint`](#portmappingingressendpoint) | 顶层函数 | A | 解析 FRP/端口转发跳的入口端点。 |
| `_isPortMappingHop` | 顶层函数 | B | 跳是否是 FRP/端口转发风格跳。 |
| `_hasRemoteEntry` | 顶层函数 | B | 跳是否有值得渲染的远程主机/端口。 |
| `_relayNodeId` | 顶层函数 | B | 格式化中继节点稳定 id。 |
| `_remoteEntryNodeId` | 顶层函数 | B | 格式化远程入口节点稳定 id。 |
| [`_relayLabel`](#relaylabel) | 顶层函数 | A | 计算中继节点显示标签。 |
| `_remoteEntryLabel` | 顶层函数 | B | 格式化远程入口节点显示标签。 |
| `serviceRouteMethodLabel` | 顶层函数 | B | `ServiceRouteMethod` 枚举 → 显示标签。 |
| [`serviceRouteAccessTargets`](#servicerouteaccesstargets) | 顶层函数 | A | 收集路由去重公共访问目标。 |
| [`addTarget`](#addtarget)（嵌套于 `serviceRouteAccessTargets`） | 本地函数 | A | 非空且非重复时添加一个目标。 |
| [`serviceRouteExtraJsonWithTargets`](#servicerouteextrajsonwithtargets) | 顶层函数 | A | 把分组目标写回路由 `extraJson`。 |
| [`serviceRouteDisplayTarget`](#serviceroutedisplaytarget) | 顶层函数 | A | 挑路由主显示字符串。 |
| [`serviceRouteGeneratedName`](#serviceroutegeneratedname) | 顶层函数 | A | 生成路由内部显示名。 |
| `serviceRouteTargetsSummary` | 顶层函数 | B | 对路由的 `_targetsSummary` 薄包装。 |
| [`_targetsSummary`](#targetssummary) | 顶层函数 | A | 用"+N more"截断连接目标标签。 |
| [`compactAccessTargetLabel`](#compactaccesstargetlabel) | 顶层函数 | A | 缩短 URL/目标为紧凑 `host[:port][path]` 标签。 |
| `_canonicalAccessTarget` | 顶层函数 | B | 目标的小写/紧凑形态，供去重比较。 |

## 文档

### `const ServiceTopologyNode({...})` <a id="servicetopologynode-new"></a>
- **种类：** 构造函数。**来源：** 第 51 行。
- **用途：** 为渲染图创建不可变拓扑节点（设备/服务/端点/中继/远程入口/域）。
- **输入：** `id`、`kind`、`role`、`label` 必填；`detail`/`deviceId`/`serviceId`/`endpointId`/`lane`/`method`/`layoutColumn` 可选；`compact`（默认 `false`）；`routeIds`（默认 `[]`）。
- **返回：** 新 `ServiceTopologyNode`。**副作用：** 无。
- **算法：** 普通字段赋值。
- **用法：** 贯穿 `buildServiceTopology` 嵌套 `add*Node` 辅助构造。
- **备注：** `routeIds` 跟踪触碰此节点的每条路由，因为一个节点（如共享设备）可跨多条路由复用。

### `ServiceTopologyNode mergeRoute(String routeId)` <a id="mergeroute"></a>
- **种类：** `ServiceTopologyNode` 的方法。**来源：** 第 72 行。
- **用途：** 尚未存在时把路由 id 附加到此节点。
- **输入：** `routeId`。**返回：** `ServiceTopologyNode`。
- **副作用：** 无（返回新/相同实例；不修改）。
- **算法：** `routeIds` 已含 `routeId` 时原样返回 `this`；否则委托 `merge(this, routeId: routeId)`。
- **用法：** 节点在特定路由下新建时被 `addNode` 调用。
- **备注：** 无。

### `ServiceTopologyNode merge(ServiceTopologyNode other, {String? routeId})` <a id="merge"></a>
- **种类：** `ServiceTopologyNode` 的方法。**来源：** 第 82 行。
- **用途：** 组合共享 id（经不同路由到达的相同设备/服务/端点）的两个节点值。
- **输入：** `other`；可选 `routeId` 添加。
- **返回：** 新合并 `ServiceTopologyNode`。
- **副作用：** 无。
- **算法：** 并集 `routeIds`；经 `_preferTopologyRole` 挑更具体角色；只在其角色胜出**且**其 detail 非空时偏好 `other.detail`，否则保留此节点自己非空 detail 或回退 `other.detail`；取第一个非 null `lane`/`method`/`layoutColumn`；OR `compact` 标志。
- **用法：** 节点 id 被重访时被 `addNode` 的 `nodes.update` 合并路径调用。
- **备注：** detail 偏好逻辑存在，使先以泛型 detail（如服务 kind）看到的节点在带"更远程"角色的路由触碰它时升级为更具体 detail（如其端点摘要），同时否则不丢失既有良好 detail。

### `const ServiceTopologyEdge({...})` <a id="servicetopologyedge-new"></a>
- **种类：** 构造函数。**来源：** 第 125 行。
- **用途：** 创建两个节点 id 间不可变有向边。
- **输入：** `from`、`to` 必填；`label`/`routeId`/`lane`/`method` 可选。
- **返回：** 新 `ServiceTopologyEdge`。**副作用：** 无。
- **算法：** 普通字段赋值。
- **用法：** 由 `addEdge` 构造。
- **备注：** 无。

### `const ServiceTopologyGraph({required this.nodes, required this.edges})` <a id="servicetopologygraph-new"></a>
- **种类：** 构造函数。**来源：** 第 144 行。
- **用途：** 把最终排序节点/边列表包装为 `buildServiceTopology` 结果。
- **输入：** `nodes`、`edges`。**返回：** 新 `ServiceTopologyGraph`。**副作用：** 无。
- **算法：** 普通字段赋值。
- **用法：** 由 `buildServiceTopology` 返回；被 [service_topology_layout.md](service_topology_layout.md) 布局引擎消费。
- **备注：** 无。

### `const ServicePortUse({...})` <a id="serviceportuse-new"></a>
- **种类：** 构造函数。**来源：** 第 166 行。
- **用途：** 记录一个具体 `(service, endpoint, transport, port, bindAddress)` 使用，从可能范围的端点展开。
- **输入：** 全部五个字段必填。**返回：** 新 `ServicePortUse`。**副作用：** 无。
- **算法：** 普通字段赋值。
- **用法：** 由 `listServicePortUses` 构造。
- **备注：** 无。

### `const ServicePortConflict({...})` <a id="serviceportconflict-new"></a>
- **种类：** 构造函数。**来源：** 第 194 行。
- **用途：** 记录两个或多个服务使用间检测到（或潜在）的端口碰撞。
- **输入：** `deviceId`、`port`、`transport`、`uses` 必填；`potential`（默认 `false`）。
- **返回：** 新 `ServicePortConflict`。**副作用：** 无。
- **算法：** 普通字段赋值。
- **用法：** 由 `findServicePortConflicts` 构造。
- **备注：** `potential` 区分软/建议冲突（所有使用绑定具体、非通配符地址，因此运行时可能实际不碰撞）与更硬的冲突——匹配本仓库文档化"端口冲突检测仅建议"规则。

### `const ServiceWarning(this.kind, this.name, {this.detail})` <a id="servicewarning-new"></a>
- **种类：** 构造函数。**来源：** 第 227 行。
- **用途：** 为服务总览记录一个引用完整性警告。
- **输入：** `kind`（`ServiceWarningKind`）、`name`、可选 `detail`。
- **返回：** 新 `ServiceWarning`。**副作用：** 无。
- **算法：** 普通字段赋值（位置构造函数）。
- **用法：** 贯穿 `findServiceReferenceWarnings` 构造。
- **备注：** 无。

### `List<ServicePortUse> listServicePortUses(List<ServiceNode> services)` <a id="listserviceportuses"></a>
- **种类：** 顶层函数。**来源：** 第 230 行。
- **用途：** 把每个服务端点的（可能范围）端口展开为单个具体 `ServicePortUse` 记录，端点声明 `tcpUdp` 时每传输一个。
- **输入：** `services`。**返回：** `List<ServicePortUse>`，按设备 id、然后传输、然后端口、然后服务名（不区分大小写）排序。
- **副作用：** 无。
- **算法：** 对每个带非 null `port` 的端点，跨每个适用传输（端点 `tcpUdp` 时 `tcp`+`udp`，否则只其自己传输）展开 `[port, portEnd ?? port]`，经 `normalizedBindAddress` 规范化绑定地址；排序结果。
- **用法：** 被 `findServicePortConflicts` 调用。
- **备注：** 无。

### `List<ServicePortConflict> findServicePortConflicts(List<ServiceNode> services)` <a id="findserviceportconflicts"></a>
- **种类：** 顶层函数。**来源：** 第 275 行。
- **用途：** 按 `(deviceId, transport, port)` 分组端口使用并标记至少两个条目绑定地址重叠的组。
- **输入：** `services`。**返回：** `List<ServicePortConflict>`。
- **副作用：** 无。
- **算法：** 把 `listServicePortUses` 结果按键分桶；对 2+ 条目桶做成对 `_bindsOverlap` 检查收集重叠子集（经 `toSet` 去重）；为每个幸存桶构建 `ServicePortConflict`，只在每个重叠使用都有具体（非通配符）绑定地址时标记 `potential: true`。
- **用法：** 被服务总览调用渲染端口冲突警告。
- **备注：** 仅建议，按本仓库文档化规则——冲突绝不阻塞保存。

### `ServiceTopologyGraph buildServiceTopology({required List<ServiceNode> services, required List<ServiceRoute> routes, required List<Device> devices})` <a id="buildservicetopology"></a>
- **种类：** 顶层函数。**来源：** 第 313 行。
- **用途：** 核心拓扑图构建器：把保存服务和访问路由变成布局引擎渲染的节点/边图。
- **输入：** `services`、`routes`、`devices`。**返回：** `ServiceTopologyGraph`（节点按 kind 然后 label 排序）。
- **副作用：** 无（对输入纯）。
- **算法：** 构建设备/服务查找映射。定义本地辅助 `addNode`/`addEdge`（按 id/键去重）和 id 格式化器 `deviceNodeId`/`serviceNodeId`/`endpointNodeId`，加 `addDeviceNode`/`addRemoteDeviceNode`/`addServiceNode`/`addEndpointNode`（各构建节点并把其边接到父级）。首先把每个服务（及其设备）作为普通本地节点添加。然后对每条路由：添加源服务/端点链；走每个跳——FRP/端口转发风格跳（`_isPortMappingHop`）渲染为远程服务+入口端口对（跳服务无法解析时中继+远程设备对），随后跳有主机/端口时远程入口节点（`_hasRemoteEntry`）；引用可解析服务的跳渲染为（可能远程）服务+端点节点对；其他一切经 `_relayLabel`/`_roleForRelay` 渲染为泛型中继节点。最后链末每个访问目标（`serviceRouteAccessTargets`）添加一个域节点。返回前按 kind 然后 label 排序节点。
- **用法：** 被服务总览页调用构建交给布局引擎（[service_topology_layout.md](service_topology_layout.md)）的图。
- **备注：** 这是编码 [服务与拓扑](../../../../features/services-topology.md) 描述每个拓扑建模规则的唯一函数——FRP 入口/公共端口区分、同设备反向代理 `layoutColumn` 提示和本地/远程角色分配都住在这里，不在布局或渲染代码。

### `void addNode(ServiceTopologyNode node, {String? routeId})`（嵌套） <a id="addnode"></a>
- **种类：** `buildServiceTopology` 内本地函数。**来源：** 第 328 行。
- **用途：** 按 id 插入节点，与任何同 id 既有节点合并。
- **输入：** `node`、可选 `routeId`。**返回：** `void`。
- **副作用：** 修改外层 `nodes` 映射。
- **算法：** `nodes.update(node.id, (existing) => existing.merge(node, routeId: routeId), ifAbsent: () => routeId == null ? node : node.mergeRoute(routeId))`。
- **用法：** 被下面每个 `add*Node` 辅助调用。
- **备注：** 无。

### `void addEdge(String from, String to, {String? label, String? routeId})`（嵌套） <a id="addedge"></a>
- **种类：** `buildServiceTopology` 内本地函数。**来源：** 第 341 行。
- **用途：** 在两个已添加节点间插入去重边。
- **输入：** `from`、`to`；可选 `label`/`routeId`。**返回：** `void`。
- **副作用：** 修改外层 `edges` 映射。
- **算法：** `from == to` 或任一端点尚不在 `nodes` 时空操作。解析路由访问车道和首跳方法（如有）；从 `from/to/label/lane/method` 构建复合去重键；`putIfAbsent` 新 `ServiceTopologyEdge`。
- **用法：** 贯穿 `buildServiceTopology` 路由走循环调用。
- **备注：** 复合键（不只 `from->to`）正是让相同两节点间在车道或方法不同时允许多条不同边（如同一两服务间一条经公共 FRP、另一条经 VPN 的路由）。

### `String addDeviceNode(String deviceId)`（嵌套） <a id="adddevicenode"></a>
- **种类：** `buildServiceTopology` 内本地函数。**来源：** 第 395 行。
- **用途：** 添加（或复用）本地设备节点。
- **输入：** `deviceId`。**返回：** 节点 id。
- **副作用：** 调用 `addNode`。
- **算法：** 查找设备（无法解析时回退原始 id 作标签）；构建 `localDevice` 角色、以 `deviceNodeId(deviceId)` 键控的节点。
- **用法：** 被 `addServiceNode` 为服务自己设备调用。
- **备注：** 无。

### `String addRemoteDeviceNode(String deviceId, {String? routeId})`（嵌套） <a id="addremotedevicenode"></a>
- **种类：** `buildServiceTopology` 内本地函数。**来源：** 第 416 行。
- **用途：** 添加（或复用）带路由 id 标记的远程设备节点。
- **输入：** `deviceId`；可选 `routeId`。**返回：** 节点 id。
- **副作用：** 调用 `addNode`。
- **算法：** 与 `addDeviceNode` 相同但角色 `remoteDevice` 并传 `routeId`，使 `merge` 的角色偏好逻辑能在设备稍后经另一路由远程到达时升级先前本地设备节点。
- **用法：** 为与路由源不同物理设备上的跳引用设备调用。
- **备注：** 无。

### `String addServiceNode(ServiceNode service, {bool remote = false, String? routeId, String? detailOverride, int? layoutColumn})`（嵌套） <a id="addservicenode"></a>
- **种类：** `buildServiceTopology` 内本地函数。**来源：** 第 438 行。
- **用途：** 添加（或复用）服务节点、其拥有设备节点和它们之间的边。
- **输入：** `service`；`remote`（默认 `false`）；可选 `routeId`/`detailOverride`/`layoutColumn`。**返回：** 节点 id。
- **副作用：** 调用 `addDeviceNode`/`addRemoteDeviceNode`、`addNode`、`addEdge`。
- **算法：** 解析设备节点（按 `remote` 远程或本地）；用 `detailOverride` 或默认（服务 kind，或至多 3 个端点端口文本连接）构建服务节点；接设备→服务边（只在远程时带 `routeId` 标记）。
- **用法：** 先每个服务一次（作为普通本地节点），再每个引用服务的路由跳一次。
- **备注：** 无。

### `String addEndpointNode(ServiceNode service, ServiceEndpoint endpoint, {bool remote = false, String? routeId, int? layoutColumn})`（嵌套） <a id="addendpointnode"></a>
- **种类：** `buildServiceTopology` 内本地函数。**来源：** 第 485 行。
- **用途：** 添加（或复用）端点节点并把它接到父服务节点。
- **输入：** `service`、`endpoint`；`remote`；可选 `routeId`/`layoutColumn`。**返回：** 节点 id。
- **副作用：** 调用 `addNode`、`addEdge`。
- **算法：** 构建 `compact: true` 节点，其标签是端点修剪标签或其协议名，detail 连接绑定地址/端口文本/路径（跳过空/`'-'` 部分）；接服务→端点边。
- **用法：** 为路由源端点和 FRP 风格跳的解析入口端点调用。
- **备注：** 总是标记 `compact: true`，在布局中视觉区分端点节点与完整设备/服务节点（见 [service_topology_layout.md](service_topology_layout.md)）。

### `List<ServiceWarning> findServiceReferenceWarnings({required List<ServiceNode> services, required List<ServiceRoute> routes, required List<Device> devices, required List<Network> networks})` <a id="findservicereferencewarnings"></a>
- **种类：** 顶层函数。**来源：** 第 717 行。
- **用途：** 扫描保存服务和路由找损坏或含糊引用，供服务总览显示。
- **输入：** `services`、`routes`、`devices`、`networks`。**返回：** `List<ServiceWarning>`。
- **副作用：** 无。
- **算法：** 逐服务：缺失设备（`missingDevice`）或退役/出售设备（`inactiveDevice`）警告；逐端点其 `networkId` 不解析（`missingEndpointNetwork`）警告。逐路由：缺失源服务/端点、空跳列表（`emptyRoute`）、或 `public` 访问路由无可解析访问目标（`publicRouteMissingUrl`）警告；逐跳缺失跳服务/端点/设备警告。最后按规范访问目标分组路由，对每个超过一条*冲突*路由（按 `_conflictingPublicTargetRoutes`）的组发出一个列出冲突路由名的 `duplicateFinalUrl` 警告。
- **用法：** 被服务总览页调用渲染其警告列表。
- **备注：** 重复目标警告收窄到真正含糊 case——同设备、源端口明显不同的路由不警告，按 `_publicTargetRoutesConflict`/`_endpointPortsOverlap`。

### `String normalizedBindAddress(String? bindAddress)` <a id="normalizedbindaddress"></a>
- **种类：** 顶层函数。**来源：** 第 829 行。
- **用途：** 把任何通配符含义绑定地址形态规范化为单个哨兵 `'*'`。
- **输入：** `bindAddress`（可空）。**返回：** `String`。
- **副作用：** 无。
- **算法：** 修剪；把 `null`/空/`'0.0.0.0'`/`'::'` 当作 `'*'`；否则原样返回修剪值。
- **用法：** 跨服务比较绑定地址前被 `listServicePortUses` 调用。
- **备注：** 无此规范化，`0.0.0.0` 和未设绑定地址不会被识别为冲突检测的相同"监听一切" case。

### `List<ServiceRoute> _conflictingPublicTargetRoutes(List<ServiceRoute> routes, Map<String, ServiceNode> serviceMap)` <a id="conflictingpublictargetroutes"></a>
- **种类：** 顶层函数。**来源：** 第 844 行。
- **用途：** 给定共享一个规范访问目标的路由集合，只返回实际互相冲突的子集。
- **输入：** `routes`、`serviceMap`。**返回：** 冲突子集，原始顺序。
- **副作用：** 无。
- **算法：** 成对 `_publicTargetRoutesConflict` 检查；把出现在至少一个冲突对的任何路由收集进集合，然后按该集合过滤原始列表（保留顺序）。
- **用法：** 被 `findServiceReferenceWarnings` 调用。
- **备注：** 无。

### `bool _publicTargetRoutesConflict(ServiceRoute a, ServiceRoute b, Map<String, ServiceNode> serviceMap)` <a id="publictargetroutesconflict"></a>
- **种类：** 顶层函数。**来源：** 第 868 行。
- **用途：** 决定共享公共目标的两条路由是否含糊到值得警告。
- **输入：** `a`、`b`、`serviceMap`。**返回：** `bool`。
- **副作用：** 无。
- **算法：** 任一侧源服务未知、或源在不同设备 → 当作冲突（`true`，保守）。否则解析每侧有效源端点（`_sourceEndpointForDuplicateTargetCheck`）——任一侧端点未知 → 冲突。否则当且仅当两端点端口范围重叠（`_endpointPortsOverlap`）时冲突。
- **用法：** 被 `_conflictingPublicTargetRoutes` 调用。
- **备注：** "同设备、源端口明显不同"是不*警告*的唯一 case——匹配 `findServiceReferenceWarnings` 文档块注释。

### `ServiceEndpoint? _sourceEndpointForDuplicateTargetCheck(ServiceNode service, ServiceRoute route)` <a id="sourceendpointforduplicatetargetcheck"></a>
- **种类：** 顶层函数。**来源：** 第 889 行。
- **用途：** 解析重复目标检查比较两条路由源端口时使用的端点。
- **输入：** `service`、`route`。**返回：** `ServiceEndpoint?`。
- **副作用：** 无。
- **算法：** 路由显式 `sourceEndpointId` 可解析则用它；否则未指定端点**且**服务恰好一个端点时推断那个单端点；否则 `null`（含糊）。
- **用法：** 被 `_publicTargetRoutesConflict` 调用。
- **备注：** 多端点且无显式源端点的服务被当作含糊而非猜测。

### `bool _endpointPortsOverlap(ServiceEndpoint a, ServiceEndpoint b)` <a id="endpointportsoverlap"></a>
- **种类：** 顶层函数。**来源：** 第 906 行。
- **用途：** 测试两个端点（可能范围）端口间隔是否重叠。
- **输入：** `a`、`b`。**返回：** `bool` — 任一侧完全无端口时 `true`（保守）。
- **副作用：** 无。
- **算法：** 任一侧 `port` 缺失 → `true`。否则计算每侧 `[start, end]` 间隔（`portEnd` 已设且 `>= start` 则用，否则只 `start`）并测试 `max(aStart,bStart) <= min(aEnd,bEnd)`。
- **用法：** 被 `_publicTargetRoutesConflict` 调用。
- **备注：** 无。

### `ServiceTopologyNodeRole _preferTopologyRole(ServiceTopologyNodeRole current, ServiceTopologyNodeRole incoming)` <a id="prefertopologyrole"></a>
- **种类：** 顶层函数。**来源：** 第 917 行。
- **用途：** 合并同 id 两个节点观察时挑更有信息的两个角色。
- **输入：** `current`、`incoming`。**返回：** `ServiceTopologyNodeRole`。
- **副作用：** 无。
- **算法：** 角色相等 → 保留任一；`incoming` 是"远程"角色（`_isRemoteRole`）则它胜出；否则保留 `current`。
- **用法：** 被 `ServiceTopologyNode.merge` 调用。
- **备注：** 编码规则"一旦共享节点经任何路由已知远程到达，处处当作远程"，而非首见角色任意胜出。

### `bool _isRemoteHopService({required ServiceNode source, required ServiceNode hopService, required Map<String, Device> deviceMap})` <a id="isremotehopservice"></a>
- **种类：** 顶层函数。**来源：** 第 932 行。
- **用途：** 决定跳的引用服务是否应渲染为远程。
- **输入：** `source`（路由源服务）、`hopService`、`deviceMap`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 与源同设备 → 非远程。否则当且仅当跳设备类别为 `vps` 时远程——匹配本仓库对 FRP 风格路径的文档化 VPS/远程设备共享分支建模规则。
- **用法：** 被 `buildServiceTopology` 的跳走循环调用。
- **备注：** 无。

### `ServiceAccessLane serviceAccessLaneForRoute(ServiceRoute route)` <a id="serviceaccesslaneforroute"></a>
- **种类：** 顶层函数。**来源：** 第 941 行。
- **用途：** 为拓扑渲染和边分组把路由分类为三个访问车道（本地/VPN/公共）之一。
- **输入：** `route`。**返回：** `ServiceAccessLane`。
- **副作用：** 无。
- **算法：** 任何跳用"公共风格"方法（FRP、路由器端口转发、Caddy、Nginx、Traefik、Cloudflare Tunnel、Pangolin）→ `public`。否则任何跳用 Tailscale Funnel、或路由 `accessLevel` 为 `vpn` → `vpn`。否则 `accessLevel` 为 `public` 或 `authenticated` → `public`。否则 → `local`。
- **用法：** `buildServiceTopology` 通篇和 `_roleForRelay` 调用确定渲染拓扑中边/节点着色和分组。
- **备注：** 方法基础分类优先于路由自己 `accessLevel` 字段——显式标记 `local` 但经 FRP 跳路由的路由仍分类为 `public`。

### `ServiceEndpoint? _portMappingIngressEndpoint(ServiceNode service, ServiceRouteHop hop)` <a id="portmappingingressendpoint"></a>
- **种类：** 顶层函数。**来源：** 第 982 行。
- **用途：** 解析跳服务上哪个端点代表 FRP/端口转发入口端口。
- **输入：** `service`、`hop`。**返回：** `ServiceEndpoint?`。
- **副作用：** 无。
- **算法：** 跳显式 `endpointId` 可解析则用它（`_endpointForRoute`）；否则回退服务主端点，或未标记主时其第一端点。
- **用法：** 被 `buildServiceTopology` 的 FRP/端口转发跳分支调用。
- **备注：** 实现 [服务与拓扑](../../../../features/services-topology.md) 的 FRP 入口-vs-公共端口建模规则：入口端点是源连接的东西，区别于经 `_hasRemoteEntry`/`addRemoteDeviceNode` 渲染的单独公共远程入口端口。

### `String _relayLabel(ServiceRouteHop hop, Map<String, ServiceNode> services)` <a id="relaylabel"></a>
- **种类：** 顶层函数。**来源：** 第 1017 行。
- **用途：** 计算泛型（非服务、非端口映射）中继节点显示标签。
- **输入：** `hop`、`services`。**返回：** `String`。
- **副作用：** 无。
- **算法：** 偏好跳引用服务名；否则其自己修剪标签；否则已知 `method` 时 `serviceRouteMethodLabel(method)`；否则按 `hop.type` 切换到每类型固定英语标签（Reverse Proxy/Tunnel/Port Forward/Public Endpoint/Internal Endpoint/DNS/Origin），`manual` case 有主机时回退 `_remoteEntryLabel`，否则 `'Manual'`。
- **用法：** 被 `buildServiceTopology` 泛型中继分支调用。
- **备注：** 无。

### `List<String> serviceRouteAccessTargets(ServiceRoute route)` <a id="servicerouteaccesstargets"></a>
- **种类：** 顶层函数。**来源：** 第 1057 行。
- **用途：** 收集路由去重公共访问目标：其 `finalUrl` 加 `extraJson.publicTargets` 中任何分组目标。
- **输入：** `route`。**返回：** `List<String>`，原始遇到顺序，重复按规范形态先到先得。
- **副作用：** 无。
- **算法：** 定义本地 `addTarget` 修剪、拒绝空字符串、跳过按规范形态（`_canonicalAccessTarget`）已存在的值；添加 `route.finalUrl`，然后 `extraJson[serviceRoutePublicTargetsKey]` 是 `Iterable` 时每个条目、否则原始值本身。
- **用法：** 被 `buildServiceTopology`（域节点）、`findServiceReferenceWarnings`、`serviceRouteDisplayTarget`、`serviceRouteTargetsSummary`、`serviceRouteGeneratedName` 和 `import_export_service.dart` 的 Markdown 导出调用。
- **备注：** `finalUrl` 总是最先（或单独）出现在结果中，匹配本仓库文档化兼容规则 `finalUrl` 保持"兼容性第一目标"。

### `void addTarget(Object? value)`（嵌套） <a id="addtarget"></a>
- **种类：** `serviceRouteAccessTargets` 内本地函数。**来源：** 第 1065 行。
- **用途：** 是字符串且非空、非重复时把候选目标添加到外层 `targets` 列表。
- **输入：** `value`（无类型——容忍非字符串 JSON 值）。**返回：** `void`。
- **副作用：** 修改外层 `targets` 列表。
- **算法：** 拒绝非 `String`/修剪后空值；计算规范形态并拒绝任何既有目标已规范化为相同的；否则追加（修剪）目标。
- **用法：** 为 `route.finalUrl` 和 `extraJson.publicTargets` 每个条目调用。
- **备注：** 第二个 `/// Purpose:` 注释出现在此声明下方几行*调用* `addTarget(route.finalUrl);` 上方——那个文档化调用点，非第二个声明，不计数在本页声明表（见本页顶部行数说明）。

### `Map<String, dynamic> serviceRouteExtraJsonWithTargets(Map<String, dynamic> extraJson, List<String> targets)` <a id="servicerouteextrajsonwithtargets"></a>
- **种类：** 顶层函数。**来源：** 第 1093 行。
- **用途：** 把路由分组额外访问目标写回其 `extraJson`，准备好持久化。
- **输入：** `extraJson`（既有映射）、`targets`。**返回：** 新 `Map<String, dynamic>`。
- **副作用：** 无（返回副本）。
- **算法：** 复制 `extraJson`、移除任何既有 `publicTargets` 键、只在 `targets.length > 1` 时重新添加（单目标完全由 `finalUrl` 单独表示，无需分组目标条目）。
- **用法：** 保存分组公共目标时从路由编辑器调用。
- **备注：** 无。

### `String serviceRouteDisplayTarget(ServiceRoute route)` <a id="serviceroutedisplaytarget"></a>
- **种类：** 顶层函数。**来源：** 第 1105 行。
- **用途：** 挑用于显示路由主目标的单个字符串（如作为 Markdown 小节标题，按 `import_export_service.md`）。
- **输入：** `route`。**返回：** `String`。
- **副作用：** 无。
- **算法：** 无目标 → `route.name`。单目标 → 逐字那个目标。多个 → 第一目标加剩余 `'+N'` 后缀。
- **用法：** 被 `import_export_service.dart` 的 Markdown 导出（见 [import_export_service.md](../../../shared/services/import_export_service.md)）和路由列表 UI 调用。
- **备注：** 无。

### `String serviceRouteGeneratedName({required String sourceName, required List<ServiceRouteHop> hops, required List<String> targets})` <a id="serviceroutegeneratedname"></a>
- **种类：** 顶层函数。**来源：** 第 1112 行。
- **用途：** 生成路由内部显示名（`"<source> via <method> - <target>"`），用户未写自定义描述时使用。
- **输入：** `sourceName`、`hops`、`targets`。**返回：** `String`。
- **副作用：** 无。
- **算法：** 从首跳方法标签、否则其自己标签、否则其类型名确定"via"短语，无跳默认 `'Access'`。从 `_targetsSummary(targets, maxItems: 1)` 确定目标摘要，无目标但有远程入口时首跳远程入口标签。用空格连接 `sourceName`、`'via <phrase>'` 和 `'- <target>'`（只在存在时）。
- **用法：** 被路由编辑器自动生成路由名调用。
- **备注：** 按本仓库文档化约定，路由名内部生成——面向用户的路由描述属于 `notes`，非此生成名。

### `String _targetsSummary(List<String> targets, {int maxItems = 3})` <a id="targetssummary"></a>
- **种类：** 顶层函数。**来源：** 第 1142 行。
- **用途：** 把访问目标列表连接为紧凑、截断摘要字符串。
- **输入：** `targets`；`maxItems`（默认 3）。**返回：** `String` — `targets` 为空时空。
- **副作用：** 无。
- **算法：** 把每个目标经 `compactAccessTargetLabel` 映射；用 `', '` 连接前 `maxItems`；剩余更多时追加 `' +<remaining count>'`。
- **用法：** 被 `serviceRouteTargetsSummary` 和 `serviceRouteGeneratedName` 调用。
- **备注：** 无。

### `String compactAccessTargetLabel(String target)` <a id="compactaccesstargetlabel"></a>
- **种类：** 顶层函数。**来源：** 第 1150 行。
- **用途：** 把 URL 类访问目标缩短为紧凑 `host[:port][path]` 标签供显示，或非可解析绝对 URL 时原样返回。
- **输入：** `target`。**返回：** `String`。
- **副作用：** 无。
- **算法：** `Uri.tryParse`；有 scheme 和非空 host 时渲染 `host[:port][path]`（path 为空或只 `'/'` 时省略）；否则逐字返回修剪输入。
- **用法：** 被 `buildServiceTopology`（域节点标签）、`_targetsSummary` 和 `import_export_service.dart` 的路由目标渲染调用。
- **备注：** 无。
