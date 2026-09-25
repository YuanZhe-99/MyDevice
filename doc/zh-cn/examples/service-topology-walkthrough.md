# 服务拓扑演练

把服务放在反向代理后面、FRP 隧道后面、公网域后面的完整示例，以及 [服务与拓扑](../features/services-topology.md) 路由/跳模型和拓扑渲染如何表示它。这遵循 `AGENTS.md` 的 FRP 建模规则和 [服务拓扑布局](../algorithms/service-topology-layout.md)。

## 场景

用户在家用服务器上自托管 Jellyfin，经以下暴露到公共互联网：

1. **Caddy**，同一家用服务器上运行、终止 TLS 并按主机名路由的反向代理。
2. **FRP**，从家用服务器隧道到用户租的 VPS，使家用连接不需要家用路由器端口转发。
3. 指向 VPS 的**公共域** `media.example.com`。

## 清单条目

遵循仅手动清单约束（见 [服务与拓扑 — 仅手动清单约束](../features/services-topology.md#manual-inventory-only-constraint)），用户手输这一切——这里没有自动发现。

**设备**（见 [设备](../features/devices.md)）：
- `dev-home` — 家用服务器。
- `dev-vps` — 租的 VPS（`DeviceCategory.vps`），有一条网络分配，其主机名是 `vps.example.com`。

**服务**（`ServiceNode`，见 [数据格式](../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)）：

- `dev-home` 上的 `svc-jellyfin`：`kind: media`、一个 `ServiceEndpoint` `ep-jellyfin`（`protocol: http`、`port: 8096`）。
- `dev-home` 上的 `svc-caddy`：`kind: reverseProxy`、模板 `caddy`、一个 `ServiceEndpoint` `ep-caddy`（`protocol: https`、`port: 443`）——与 Jellyfin 同设备，因此即使它把流量转发下去也保持本地节点。
- `dev-vps` 上的 `svc-frp`：FRP 服务端，模板 `frp`、一个 `ServiceEndpoint` `ep-frp-ingress`（端口 `57000`）——家用服务器的 FRP 客户端所连接的**入口/监听**端口。

VPS 的公网端口 `443` **不是**独立的端点。它是路由 FRP 跳的公网入口（`host`/`port`），拓扑把它渲染为入口 chip 旁的远程入口 chip。

## 用户如何录入这些

在引导式**添加访问路径**页面上（见 [服务与拓扑 — 添加访问路径](../features/services-topology.md#adding-an-access-path)），一屏完成：

1. **服务与端口：** Jellyfin；它唯一的端点 `Web · 8096` 已预选。
2. **通过什么方式访问？** 选 **FRP** 卡片。可达范围切换为**公网**。
3. **详细设置：**
   - **先经过反向代理：** 开启。Caddy 是唯一的代理类服务，因此它连同主端点 `HTTPS · 443` 一起被预选。
   - **FRP 服务端：** `svc-frp` 是唯一名称含 FRP 的服务，因此被预选，其主端点——**入口** chip `57000`——也随之预选。
   - **公网主机：** 由 `dev-vps` 唯一的网络分配预填为 `vps.example.com`。**公网端口：** `443`。
   - **域名：** `media.example.com`。

随后预览卡片显示 `Jellyfin 8096 -> Caddy 443 -> FRP 57000 (dev-vps) -> vps.example.com:443 -> media.example.com`，位于公网 / VPS 车道；保存即写入一条路由。

## 路由与跳

单个 `ServiceRoute` 表示整个访问路径：

```text
ServiceRoute(
  name: 'Jellyfin via Caddy - media.example.com',   // generated, hidden from the user
  sourceServiceId: 'svc-jellyfin',
  sourceEndpointId: 'ep-jellyfin',
  hops: [
    ServiceRouteHop(type: reverseProxy, method: caddy,
                    serviceId: 'svc-caddy', endpointId: 'ep-caddy'),
    ServiceRouteHop(type: portForward, method: frp,
                    serviceId: 'svc-frp', endpointId: 'ep-frp-ingress',
                    deviceId: 'dev-vps', host: 'vps.example.com', port: 443),
  ],
  finalUrl: 'https://media.example.com',
  accessLevel: public,
  extraJson: {'accessLane': 'public'},
)
```

（字段名对照 `lib/features/services/models/service.dart` 的 `ServiceRoute`/`ServiceRouteHop` 确认——见 [数据格式](../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)。对「FRP，先经过反向代理」，引导式页面恰好写入这两跳；FRP 跳总是显式指明其入口端点，`accessLane` 固定所选可达范围对应的车道——见 [服务与拓扑 — 访问模式](../features/services-topology.md#access-patterns)。）

若 `media.example.com` 是共享此精确访问路径的几个域之一（如通配符或多个子域都按相同方式路由），额外域/URL 进入路由上的 `extraJson['publicTargets']` 而非逐域重复整个路由（见 [数据格式](../data-formats.md#app-written-extrajson-keys)）。

## FRP 入口/公共拆分如何建模

按 FRP 建模规则（`AGENTS.md` 和 [服务与拓扑 — FRP 风格入口/公共端口建模](../features/services-topology.md#frp-style-ingresspublic-port-modeling)）：

- 路径**不**建模为单链 `source → FRP ingress port → FRP public port → domain`。
- 而是入口端点 chip（`ep-frp-ingress`，57000）和公共远程入口 chip（443，来自跳的 `host`/`port`）是 `dev-vps` 上同一 FRP 服务下的**兄弟端口 chip**。
- **路由的上一步连接到 FRP 入口端口**——这里是 Caddy 的端点 `ep-caddy`，因为 Caddy 是 FRP 之前的那一跳。这是隧道的监听侧，家用服务器 FRP 客户端实际连接的地方。
- **FRP 公共端口继续连接到域**（`:443` → `media.example.com`）——这是 DNS 实际解析到的面向互联网侧。

此区分重要，因为从网络流量角度看入口端口（57000）和公共端口（443）从不在链条上彼此连接——客户端绝不连接到 57000 并被转发到 443 作为进一步跳；而是 FRP 内部把隧道桥接到公共监听器。把它们建模为兄弟而非链条让图示准确反映 FRP 实际工作方式，并避免暗示不存在的、经入口端口的面向客户端跳。

## 拓扑图如何渲染这个

按 [服务拓扑布局](../algorithms/service-topology-layout.md)：

1. `svc-jellyfin` 和 `svc-caddy` 是 `dev-home` 下的本地服务节点；因为路由经过 Jellyfin → Caddy，Caddy 位于比 Jellyfin 端点 chip 更晚的等级，所以即使两者运行在同一台机器上，箭头仍保持从左到右读。
2. `dev-vps`、`svc-frp` 及其端口 chip 位于更晚的等级（远程/公共侧）。`_alignSiblingPortRanks` 把入口 chip 和公网入口 chip 拉到同一等级，使两个 FRP 端口 chip 并排出现而非一个拖在另一个后面。
3. 边正交路由：`ep-jellyfin → svc-caddy → ep-caddy`（短本地边）、`ep-caddy → ep-frp-ingress`（跨到 VPS 侧）、`svc-frp → :443` 和 `:443 → media.example.com`（域/URL 叶节点）——每条都由带转弯/拥塞代价的 `_fastRouteBetween`/`_routeBetween` 计算，使它们即使都流经画布相同一般区域也不视觉重叠。
4. 两个 FRP 端口 chip 按端口 chip 渲染规则渲染为小圆角方块 chip（端口图标 + 数字）而非完整节点卡片。

## 相关

- [服务与拓扑](../features/services-topology.md) — 完整功能描述，含引导式访问路径页、访问模式和模板。
- [服务拓扑布局](../algorithms/service-topology-layout.md) — 上面引用的布局/路由算法。
- [数据格式](../data-formats.md) — 精确 `ServiceRoute`/`ServiceRouteHop` 字段形态。
