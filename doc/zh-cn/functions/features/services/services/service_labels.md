# lib/features/services/services/service_labels.dart

服务模块的纯 UI 标签辅助。每个都接收 `AppLocalizations`，把模型枚举转换为当前语言显示的字符串：路由跳类型、路由方法、访问级别和可达范围、拓扑车道和节点角色，以及引导流程的访问模式（见 [service_access_patterns.md](service_access_patterns.md)）。

持久化的一侧刻意保持英语：路由名（`serviceRouteGeneratedName`）、Markdown 导出和本地 API 继续使用 [service_analysis.md](service_analysis.md) 中未本地化的 `serviceRouteMethodLabel`，因此路由存储的名称绝不会随保存它的设备的语言而变化。产品名——Caddy、Nginx、Traefik、FRP、Cloudflare Tunnel、Pangolin、Tailscale Funnel——从不翻译；只有通用的 Direct、Custom 和 Router port forward 会被翻译。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`serviceWarningLabel`](#servicewarninglabel) | 顶层函数 | A | 引用警告的本地化文本（从服务总览移来）。 |
| `serviceAccessDraftWarningLabel` | 顶层函数 | B | 引导式草稿警告的本地化文本。 |
| [`serviceHopFallbackLabel`](#servicehopfallbacklabel) | 顶层函数 | A | 为没有服务或标签的跳命名：取其方法，否则取其类型。 |
| `serviceHopTypeLabel` | 顶层函数 | B | `ServiceRouteHopType` 的本地化标签。 |
| [`serviceRouteMethodUiLabel`](#serviceroutemethoduilabel) | 顶层函数 | A | 路由方法的 UI 标签：产品名原样，通用方法本地化。 |
| [`serviceAccessLevelLabel`](#serviceaccesslevellabel) | 顶层函数 | A | `ServiceAccessLevel` 的本地化标签。 |
| `serviceReachabilityLabel` | 顶层函数 | B | `ServiceReachability` 的本地化标签，经其访问级别取得。 |
| `serviceAccessLaneLabel` | 顶层函数 | B | `ServiceAccessLane` 的本地化标签（局域网 / WiFi、VPN / Tailscale、公网 / VPS）。 |
| `serviceTopologyRoleLabel` | 顶层函数 | B | `ServiceTopologyNodeRole` 的本地化标签。 |
| [`serviceAccessPatternLabel`](#serviceaccesspatternlabel) | 顶层函数 | A | 访问模式的显示名。 |
| `serviceAccessPatternDescription` | 顶层函数 | B | 显示在模式名下方的一行描述。 |

## 文档

### `String serviceWarningLabel(AppLocalizations l10n, ServiceWarning warning)` <a id="servicewarninglabel"></a>
- **种类：** 顶层函数。**来源：** 第 17 行。
- **用途：** 返回引用警告的本地化文本。
- **输入：** `l10n`、`warning`。**返回：** `String`。**副作用：** 无。
- **算法：** 每个 `ServiceWarningKind` 一条 ARB 消息，各自接收警告的名称。
- **用法：** 服务总览的警告卡片和引导式访问路径页的预览。
- **备注：** 1.5.6 中从总览的私有 `_warningText` 移来，使两处使用相同的措辞。

### `String serviceHopFallbackLabel(AppLocalizations l10n, ServiceRouteHop hop)` <a id="servicehopfallbacklabel"></a>
- **种类：** 顶层函数。**来源：** 第 69 行。
- **用途：** 为既没有服务也没有自身标签的跳命名。
- **输入：** `l10n`、`hop`。**返回：** `String`。**副作用：** 无。
- **算法：** 跳带方法时取本地化方法（`serviceRouteMethodUiLabel`），否则取本地化跳类型。
- **用法：** 两种路由编辑器传给 `serviceRouteChainPreview` 的 `hopFallback`。
- **备注：** 优先取方法，使直连跳在预览中显示为「直连」，而不是其跳类型「手动」。

### `String serviceRouteMethodUiLabel(AppLocalizations l10n, ServiceRouteMethod method)` <a id="serviceroutemethoduilabel"></a>
- **种类：** 顶层函数。**来源：** 第 103 行。
- **用途：** 返回路由方法在 UI 中显示的标签。
- **输入：** `l10n`、`method`。**返回：** `String`。**副作用：** 无。
- **算法：** `direct`、`custom` 和 `routerPortForward` 映射到各自的 ARB 键；其他每个方法原样返回 `serviceRouteMethodLabel(method)`。
- **用法：** 高级路由编辑器的方法下拉框和跳行；拓扑的中继副标题。
- **备注：** 从不用于任何持久化内容。

### `String serviceAccessLevelLabel(AppLocalizations l10n, ServiceAccessLevel level)` <a id="serviceaccesslevellabel"></a>
- **种类：** 顶层函数。**来源：** 第 119 行。
- **用途：** 返回路由访问级别的本地化标签。
- **输入：** `l10n`、`level`。**返回：** `String`。**副作用：** 无。
- **算法：** 每个级别一个 ARB 键（`serviceAccessLevelLan`、`…Vpn`、`…Authenticated`、`…Public`、`…Custom`）。
- **用法：** 高级编辑器的访问级别下拉框，以及列表页和拓扑节点详情中的路由摘要。
- **备注：** `serviceReachabilityLabel` 复用这些键，因此引导式页面的可达范围 chip 读起来与高级编辑器的访问级别完全一致。

### `String serviceAccessPatternLabel(AppLocalizations l10n, ServiceAccessPattern pattern)` <a id="serviceaccesspatternlabel"></a>
- **种类：** 顶层函数。**来源：** 第 182 行。
- **用途：** 返回访问模式的显示名。
- **输入：** `l10n`、`pattern`。**返回：** `String`。**副作用：** 无。
- **算法：** `direct` ⇒ `servicePatternDirect`（"直连（局域网 / VPN）"）；`reverseProxy` ⇒ 反向代理跳类型标签；`routerPortForward` ⇒ 路由器端口转发方法标签；产品类模式 ⇒ 其固定方法的 `serviceRouteMethodLabel`。
- **用法：** 引导式页面的模式卡片。
- **备注：** 无。
