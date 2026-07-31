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
- `dev-vps` — 租的 VPS（`DeviceCategory.vps`）。

**服务**（`ServiceNode`，见 [数据格式](../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)）：

- `dev-home` 上的 `svc-jellyfin`：`kind: media`、引用捆绑 Jellyfin 模板的 `templateId`、一个 `ServiceEndpoint` `ep-jellyfin`（`protocol: http`、`port: 8096`、`scope: localhost`）。
- `dev-home` 上的 `svc-caddy`：`kind: reverseProxy`、一个 `ServiceEndpoint` `ep-caddy`（`protocol: https`、`port: 443`、`scope: lan`——与 Jellyfin 同设备，因此按 [服务与拓扑 — 拓扑图布局（高层）](../features/services-topology.md#topology-graph-layout-high-level) 即使它把流量转发下去也保持本地节点）。
- `dev-home` 上的 `svc-frp`（FRP 客户端）和 `dev-vps` 上对应的 FRP 服务器存在。VPS 侧两个兄弟端点，按 FRP 建模规则：
  - `dev-vps` 上的 `ep-frp-ingress`：FRP **入口/监听**端点，如端口 `57000`。
  - `dev-vps` 上的 `ep-frp-public`：FRP **公共远程入口**端口，如端口 `443`。

## 路由与跳

单个 `ServiceRoute` 表示整个访问路径：

```text
ServiceRoute(
  name: <generated, hidden from user>,
  sourceServiceId: 'svc-jellyfin',
  sourceEndpointId: 'ep-jellyfin',
  hops: [
    ServiceRouteHop(type: reverseProxy, serviceId: 'svc-caddy', endpointId: 'ep-caddy',
                     method: caddy),
    ServiceRouteHop(type: tunnel, serviceId: 'svc-frp', endpointId: 'ep-frp-ingress',
                     method: frp),
    ServiceRouteHop(type: publicEndpoint, endpointId: 'ep-frp-public'),
    ServiceRouteHop(type: dns, host: 'media.example.com'),
  ],
  finalUrl: 'https://media.example.com',
  accessLevel: public,
)
```

（字段名对照 `lib/features/services/models/service.dart` 的 `ServiceRoute`/`ServiceRouteHop` 确认——见 [数据格式](../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)。精确跳顺序/数量是概念的示意；应用"FRP"访问类型的快速访问路由创建流程会为用户自动生成等价跳——见 [服务与拓扑 — 快速访问路由创建 vs 高级编辑器](../features/services-topology.md#quick-access-route-creation-vs-the-advanced-editor)。）

若 `media.example.com` 是共享此精确访问路径的几个域之一（如通配符或多个子域都按相同方式路由），额外域/URL 进入路由上的 `extraJson['publicTargets']` 而非逐域重复整个路由（见 [数据格式](../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)）。

## FRP 入口/公共拆分如何建模

按 FRP 建模规则（`AGENTS.md` 和 [服务与拓扑 — FRP 风格入口/公共端口建模](../features/services-topology.md#frp-style-ingresspublic-port-modeling)）：

- 路径**不**建模为单链 `source → FRP ingress port → FRP public port → domain`。
- 而是 `ep-frp-ingress`（57000）和 `ep-frp-public`（443）是 `dev-vps` 上同一 FRP 服务下的**兄弟端口 chip**。
- **源端点的路由跳连接到 FRP 入口端口**（`ep-frp-ingress`）——这是隧道的监听侧，家用服务器 FRP 客户端实际连接的地方。
- **FRP 公共端口继续连接到域**（`ep-frp-public` → `media.example.com`）——这是 DNS 实际解析到的面向互联网侧。

此区分重要，因为从网络流量角度看入口端口（57000）和公共端口（443）从不在链条上彼此连接——客户端绝不连接到 57000 并被转发到 443 作为进一步跳；而是 FRP 内部把隧道桥接到公共监听器。把它们建模为兄弟而非链条让图示准确反映 FRP 实际工作方式，并避免暗示不存在的、经入口端口的面向客户端跳。

## 拓扑图如何渲染这个

按 [服务拓扑布局](../algorithms/service-topology-layout.md)：

1. `svc-jellyfin` 和 `svc-caddy` 坐在与 `dev-home`（本地服务）相同的等级列组上，`svc-caddy` 按语义分层布局移到比 `svc-jellyfin` 更晚的等级，使箭头流向即使两者都在同一物理设备上仍读作从左到右。
2. `dev-vps` 及其 FRP 端口坐在更晚等级（远程/公共侧）。`_alignSiblingPortRanks` 把 `ep-frp-ingress` 和 `ep-frp-public` 拉到彼此相同等级，使两个 FRP 端口 chip 并排出现而非一个拖后。
3. 边正交路由：`ep-jellyfin → ep-caddy`（同设备，短本地边）、`ep-caddy → ep-frp-ingress`（跨到 VPS 等级）、`ep-frp-public → media.example.com`（域/URL 叶节点）——每条边由带转弯/拥塞代价的 `_fastRouteBetween`/`_routeBetween` 计算，使这三条边即使都流经画布相同一般区域也不视觉重叠。
4. 两个 FRP 端口 chip 按端口 chip 渲染规则渲染为小圆角方块 chip（端口图标 + 数字）而非完整节点卡片。

## 相关

- [服务与拓扑](../features/services-topology.md) — 完整功能描述，含快速访问路由创建和模板。
- [服务拓扑布局](../algorithms/service-topology-layout.md) — 上面引用的布局/路由算法。
- [数据格式](../data-formats.md) — 精确 `ServiceRoute`/`ServiceRouteHop` 字段形态。
