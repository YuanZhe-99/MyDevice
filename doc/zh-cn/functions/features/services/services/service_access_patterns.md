# lib/features/services/services/service_access_patterns.dart

[服务与拓扑](../../../../features/services-topology.md#access-patterns) 描述的引导式**添加访问路径**流程背后的纯 Dart 模型。它把常见的自托管方案命名为 `ServiceAccessPattern`，把表单状态保存在不可变的 `ServiceAccessDraft` 中，把草稿转换为恰好一个 `ServiceRoute`（其跳 [service_analysis.md](service_analysis.md) 的 `buildServiceTopology` 已能渲染），并且只在往返无损时才把保存的路由读回草稿。验证（阻塞问题）和建议性警告也住在这里，因此页面保持为薄表单，一切都无需组件（widget）即可测试（`test/service_access_patterns_test.dart`）。

这里没有任何东西作为新字段持久化：每次打开路由时都从跳重新检测模式。1.5.6 唯一新增的持久化内容是路由的 `extraJson['accessLane']`，经 `serviceRouteExtraJsonWithAccessLane` 写入（见 [数据格式](../../../../data-formats.md#extrajson-unknown-field-preservation)）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `fixedMethod` | getter（`ServiceAccessPattern`） | B | 模式的访问跳记录的路由方法；反向代理为 null，其方法来自代理服务。 |
| [`allowsProxyPrefix`](#allowsproxyprefix) | getter（`ServiceAccessPattern`） | A | 是否提供"先经反向代理"跳。 |
| `requiresTargets` | getter（`ServiceAccessPattern`） | B | 保存的路由是否至少需要一个 URL 或域名（反向代理和三种隧道）。 |
| `requiresPublicPort` | getter（`ServiceAccessPattern`） | B | 模式是否记录必填的公网入口端口（FRP、路由器端口转发）。 |
| `usesRelayService` | getter（`ServiceAccessPattern`） | B | 访问跳能否引用中继服务。 |
| `requiresRelayService` | getter（`ServiceAccessPattern`） | B | 中继服务是否必填（仅 FRP）。 |
| `defaultReachability` | getter（`ServiceAccessPattern`） | B | 直连为局域网，其余一律为公网。 |
| [`accessLevel`](#accesslevel) | getter（`ServiceReachability`） | A | 可达范围保存的路由访问级别。 |
| [`lane`](#lane) | getter（`ServiceReachability`） | A | 可达范围固定的拓扑车道。 |
| [`ServiceAccessDraft` 构造函数](#serviceaccessdraft-new) | 构造函数 | A | 创建草稿；默认为直连局域网路径。 |
| `usesProxyPrefix` | getter（`ServiceAccessDraft`） | B | 模式允许前缀时取 `viaProxy`。 |
| `needsProxy` | getter（`ServiceAccessDraft`） | B | 草稿是否需要代理服务（反向代理模式或前缀）。 |
| [`copyWith`](#copywith) | 方法（`ServiceAccessDraft`） | A | 替换或清除字段；身份元数据原样带过。 |
| [`toRoute`](#toroute) | 方法（`ServiceAccessDraft`） | A | 构建草稿描述的那一个 `ServiceRoute`。 |
| [`_proxyHop`](#proxyhop) | 方法（`ServiceAccessDraft`） | A | 构建反向代理跳。 |
| [`_accessHop`](#accesshop) | 方法（`ServiceAccessDraft`） | A | 构建模式自身的跳。 |
| [`fromRoute`](#fromroute) | 静态方法（`ServiceAccessDraft`） | A | 往返无损时把保存的路由读回草稿。 |
| [`operator ==`](#equals) | 运算符（`ServiceAccessDraft`） | A | 按表单内容比较草稿。 |
| `hashCode` | getter（`ServiceAccessDraft`） | B | 所比较字段的哈希；`extraJson` 只贡献其键数量。 |
| `toString` | 方法（`ServiceAccessDraft`） | B | 测试失败时使用的诊断文本。 |
| [`detectServiceAccessPattern`](#detectserviceaccesspattern) | 顶层函数 | A | 指出保存的路由遵循的模式，或 null。 |
| [`serviceReachabilityForRoute`](#servicereachabilityforroute) | 顶层函数 | A | 从访问级别和车道覆盖读取路由的可达范围。 |
| [`serviceAccessDraftIssues`](#serviceaccessdraftissues) | 顶层函数 | A | 列出草稿的阻塞问题。 |
| `present`（嵌套于 `serviceAccessDraftIssues`） | 本地函数 | B | 某个 id 是否指向现存服务。 |
| [`serviceAccessDraftWarnings`](#serviceaccessdraftwarnings) | 顶层函数 | A | 列出草稿的建议性 FRP 发现。 |
| [`serviceProxyMethodFor`](#serviceproxymethodfor) | 顶层函数 | A | 为代理服务取 Caddy / Nginx / Traefik / custom。 |
| `isReverseProxyLikeService` | 顶层函数 | B | kind 为 `reverseProxy`，或是已知代理模板或名称。 |
| [`isFrpLikeService`](#isfrplikeservice) | 顶层函数 | A | FRP 中继启发式，从已移除的快速访问对话框移到这里。 |
| [`serviceAccessProxySuggestions`](#serviceaccessproxysuggestions) | 顶层函数 | A | 要推荐的类代理服务，源所在机器上的排在最前。 |
| [`serviceAccessRelaySuggestions`](#serviceaccessrelaysuggestions) | 顶层函数 | A | 为某种模式推荐的中继服务，VPS 设备上的排在最前。 |
| `named`（嵌套于 `serviceAccessRelaySuggestions`） | 本地函数 | B | 服务的名称、模板或图标是否指明该产品。 |
| `serviceAccessRelayTemplateId` | 顶层函数 | B | 「新建中继服务…」起步所用的模板：`frp`、`pangolin`、`cloudflare-tunnel`、`tailscale`。 |
| `serviceAccessRouterCandidates` | 顶层函数 | B | 路由器选择器中的设备，路由器在前，然后按名称排序。 |
| [`suggestedDirectTarget`](#suggesteddirecttarget) | 顶层函数 | A | 直连访问路径打开的地址，取自设备的网络分配。 |
| `hasAddress`（嵌套于 `suggestedDirectTarget`） | 本地函数 | B | 网络分配是否记录了 IP 地址或主机名。 |
| `matches`（嵌套于 `suggestedDirectTarget`） | 本地函数 | B | 网络分配所在的网络是否适合该可达范围。 |
| [`suggestedPublicHost`](#suggestedpublichost) | 顶层函数 | A | 取自中继设备唯一网络分配的 FRP 公网主机。 |
| `_isProxyHop` | 顶层函数 | B | 跳能否作为反向代理前缀。 |
| [`_patternForHop`](#patternforhop) | 顶层函数 | A | 把路由最后一跳归类为某种模式。 |
| [`_sameAccessShape`](#sameaccessshape) | 顶层函数 | A | 检查重建的路由是否复现保存路由的内容。 |
| `_cleanTargets` | 顶层函数 | B | 修剪目标，丢弃空值和不区分大小写的重复项。 |
| `_trimmedOrNull` | 顶层函数 | B | 修剪字符串；为空则变 null。 |
| `_jsonEquals` | 顶层函数 | B | JSON 形态的映射、列表和标量的深相等比较。 |

枚举 `ServiceAccessPattern`（`direct`、`reverseProxy`、`cloudflareTunnel`、`pangolin`、`frp`、`routerPortForward`、`tailscaleFunnel`）、`ServiceReachability`（`lan`、`vpn`、`public`、`publicAuthenticated`）、`ServiceAccessDraftIssue`（`missingSource`、`missingProxy`、`missingRelay`、`invalidPublicPort`、`missingTargets`）和 `ServiceAccessDraftWarning`（`relayWithoutIngress`、`relayOnSourceDevice`）不带其他声明。

## 文档

### `bool get allowsProxyPrefix` <a id="allowsproxyprefix"></a>
- **种类：** `ServiceAccessPattern` 的 getter。**来源：** 第 45 行。
- **用途：** 报告是否提供"先经反向代理"前缀跳。
- **输入：** 无。**返回：** `bool`。**副作用：** 无。
- **算法：** `direct` 和 `reverseProxy` 为 `false`，其他五种为 `true`。
- **用法：** 引导式页面只在此为 true 时显示前缀开关；`fromRoute` 拒绝最后一跳所指模式不允许前缀的两跳路由。
- **备注：** 前缀正是用来构建旧快速对话框无法创建的两跳链 *应用 → 反向代理 → 隧道或端口映射*。

### `ServiceAccessLevel get accessLevel` <a id="accesslevel"></a>
- **种类：** `ServiceReachability` 的 getter。**来源：** 第 126 行。
- **用途：** 返回可达范围保存的路由访问级别。
- **输入：** 无。**返回：** `ServiceAccessLevel`。**副作用：** 无。
- **算法：** `lan`→`lan`、`vpn`→`vpn`、`public`→`public`、`publicAuthenticated`→`authenticated`。
- **用法：** `toRoute` 把它写入 `ServiceRoute.accessLevel`。
- **备注：** `ServiceAccessLevel.custom` 没有对应的可达范围，因此使用它的路由留给高级编辑器处理。

### `ServiceAccessLane get lane` <a id="lane"></a>
- **种类：** `ServiceReachability` 的 getter。**来源：** 第 138 行。
- **用途：** 返回可达范围固定的拓扑车道。
- **输入：** 无。**返回：** `ServiceAccessLane`。**副作用：** 无。
- **算法：** `lan`→`local`、`vpn`→`vpn`，两种公网变体→`public`。
- **用法：** `toRoute` 把它写为 `extraJson['accessLane']`，使仅限局域网的反向代理画在本地车道，而不是方法推断会选的公网车道。
- **备注：** 无。

### `const ServiceAccessDraft({...})` <a id="serviceaccessdraft-new"></a>
- **种类：** 构造函数。**来源：** 第 206 行。
- **用途：** 创建访问路径草稿。
- **输入：** 全部可选：`routeId`（被编辑的路由）、`sourceServiceId`、`sourceEndpointId`、`pattern`（默认 `direct`）、`reachability`（默认 `lan`）、`viaProxy`（默认 `false`）、`proxyServiceId`、`proxyEndpointId`、`proxyMethod`（null = 从代理服务推导）、`relayServiceId`、`relayEndpointId`（FRP 时即入口）、`remoteDeviceId`（路由器端口转发的路由器）、`publicHost`、`publicPort`、`targets`、`notes`、`extraJson`（被编辑路由的未知键，不含 `publicTargets` 和 `accessLane`）、`baseHops`（被编辑路由的跳）。
- **返回：** 新 `ServiceAccessDraft`。**副作用：** 无。
- **算法：** 普通字段赋值。
- **用法：** `const ServiceAccessDraft(sourceServiceId: service.id)` 从某个服务开始新路径；`ServiceAccessDraft.fromRoute` 开始一次编辑。
- **备注：** 不可变；每次变化时页面都经 `copyWith` 替换整个值。

### `ServiceAccessDraft copyWith({...})` <a id="copywith"></a>
- **种类：** `ServiceAccessDraft` 的方法。**来源：** 第 249 行。
- **用途：** 创建替换或清除所选字段的副本。
- **输入：** 任一内容字段；`clearX` 标志把可空字段 `X` 设为 null。
- **返回：** `ServiceAccessDraft`。**副作用：** 无。
- **算法：** 逐字段 `clear ? null : (value ?? this.value)`，即本仓库惯用的 `copyWith` 约定。
- **用法：** 用户改选另一个中继时调用 `draft.copyWith(relayServiceId: id, clearRelayEndpointId: true)`。
- **备注：** `routeId`、`extraJson` 和 `baseHops` 总是原样带过，因此无论用户改了什么，编辑都保持其身份。

### `ServiceRoute toRoute({required List<ServiceNode> services})` <a id="toroute"></a>
- **种类：** `ServiceAccessDraft` 的方法。**来源：** 第 326 行。
- **用途：** 构建草稿描述的那一个 `ServiceRoute`。
- **输入：** `services` — 用于源名称、推导出的代理方法，以及 FRP 中继的设备和默认入口。
- **返回：** `ServiceRoute`。**副作用：** 无。
- **算法：**
  1. 跳：反向代理模式是一个 `_proxyHop`；其他每种模式是可选的 `_proxyHop`（`usesProxyPrefix` 时）后接 `_accessHop`。被编辑路由的跳按位置复用——最后一个基础跳用于访问跳，第一个用于前缀——使 id 和跳的 `extraJson` 得以保留。
  2. 目标经修剪和去重；`finalUrl` 取第一个，其余经 `serviceRouteExtraJsonWithTargets` 写入。
  3. `accessLevel` 来自可达范围，`serviceRouteExtraJsonWithAccessLane` 把 `accessLane` 固定为可达范围的车道。
  4. 名称为 `serviceRouteGeneratedName`（与每个持久化名称一样不本地化）；空备注变为 null。
- **用法：** 保存时在 `serviceAccessDraftIssues` 返回空之后调用；实时预览和重复目标警告在用户输入时对未完成的草稿调用它。
- **备注：** 路由保留被编辑路由的 id，因此同步看到的是一次更新，而不是一次删除加一次添加。

### `ServiceRouteHop _proxyHop(Map<String, ServiceNode> byId, ServiceRouteHop? base)` <a id="proxyhop"></a>
- **种类：** `ServiceAccessDraft` 的方法。**来源：** 第 368 行。
- **用途：** 构建反向代理跳，可以是整个反向代理模式，也可以是前缀。
- **输入：** `byId` — 按 id 索引的服务；`base` — 该位置上被编辑的跳。
- **返回：** `ServiceRouteHop`。**副作用：** 无。
- **算法：** 类型 `reverseProxy`；方法取 `proxyMethod`，否则 `serviceProxyMethodFor(proxy)`，未选代理时为 `custom`；`serviceId`/`endpointId` 取自草稿；id 和 `extraJson` 取自 `base`。
- **用法：** 由 `toRoute` 和 `_accessHop` 的反向代理分支调用。
- **备注：** 不写标签：拓扑按其服务为该跳加标签。

### `ServiceRouteHop _accessHop(Map<String, ServiceNode> byId, ServiceRouteHop? base)` <a id="accesshop"></a>
- **种类：** `ServiceAccessDraft` 的方法。**来源：** 第 395 行。
- **用途：** 构建模式自身的跳。
- **输入：** `byId` — 按 id 索引的服务；`base` — 该位置上被编辑的跳。
- **返回：** `ServiceRouteHop`。**副作用：** 无。
- **算法：**

  | 模式 | 跳 |
  |---|---|
  | direct | `manual`，方法 `direct`，标签 `Direct` |
  | cloudflareTunnel / pangolin / tailscaleFunnel | `tunnel`，该模式的方法，选了中继时取其 `serviceId`/`endpointId`，否则用方法标签 |
  | frp | `portForward`，方法 `frp`，中继的 `serviceId` 和 `deviceId`，所选入口（否则 `serviceDefaultIngressEndpoint`）作为 `endpointId`，公网入口的 `host`/`port` |
  | routerPortForward | `portForward`，方法 `routerPortForward`，路由器作为 `deviceId`，标签 `Router Port Forward`，公网入口的 `host`/`port` |

- **用法：** 由 `toRoute` 调用。
- **备注：** FRP 入口总是显式写入；未改动的默认值与拓扑构建器为未指定入口的跳推断出的值相同，因此图不会改变。

### `static ServiceAccessDraft? fromRoute(ServiceRoute route, List<ServiceNode> services)` <a id="fromroute"></a>
- **种类：** `ServiceAccessDraft` 的静态方法。**来源：** 第 476 行。
- **用途：** 为引导式页面把保存的路由读回草稿。
- **输入：** `route`；`services` — 当前的服务。
- **返回：** 草稿；引导式页面无法在不改变或丢失内容的前提下编辑该路由时为 null。
- **副作用：** 无。
- **算法：**
  1. `serviceReachabilityForRoute` 必须成功。
  2. 一或两跳；两跳时第一跳必须是反向代理跳（`_isProxyHop`）；最后一跳必须能归类（`_patternForHop`），有前缀时需要 `allowsProxyPrefix`。
  3. 从跳构建草稿。与代理服务所隐含方法相同的代理方法读回为 null（"推导"）；没有端点的 FRP 跳读回其默认入口。
  4. 用 `toRoute` 重建路由并要求 `_sameAccessShape` 成立；要求 `serviceAccessDraftIssues` 为空。
- **用法：** 打开路由时用它决定进入引导式页面还是高级编辑器。
- **备注：** 以下情况保持 null：三跳、跳备注、路径或 scheme、自定义访问级别、与访问级别不一致的车道覆盖、没有服务的自由形式 FRP 跳，或没有目标的隧道——高级编辑器会原样保留所有这些内容。

### `bool operator ==(Object other)` <a id="equals"></a>
- **种类：** `ServiceAccessDraft` 的运算符。**来源：** 第 552 行。
- **用途：** 按表单内容比较草稿。
- **输入：** `other`。**返回：** `bool`。**副作用：** 无。
- **算法：** 比较每个内容字段；`targets` 和 `extraJson` 经 `_jsonEquals` 深比较。
- **用法：** 往返测试把 `fromRoute(draft.toRoute(...))` 与原草稿比较。
- **备注：** `routeId` 和 `baseHops` 是身份元数据，不参与比较。

### `ServiceAccessPattern? detectServiceAccessPattern(ServiceRoute route, List<ServiceNode> services)` <a id="detectserviceaccesspattern"></a>
- **种类：** 顶层函数。**来源：** 第 625 行。
- **用途：** 指出保存的路由遵循的访问模式。
- **输入：** `route`、`services`。**返回：** 该模式，或 null。**副作用：** 无。
- **算法：** `ServiceAccessDraft.fromRoute(route, services)?.pattern`。由最后一跳决定：方法 `direct` ⇒ 直连；反向代理跳（按类型，或方法为 Caddy / Nginx / Traefik）作为唯一一跳 ⇒ 反向代理；方法 Cloudflare Tunnel、Pangolin 或 Tailscale Funnel ⇒ 相应模式；方法 FRP，或带服务的 `portForward` 跳 ⇒ FRP；方法路由器端口转发，或不带服务的 `portForward` 跳 ⇒ 路由器端口转发。
- **用法：** 路由打开规则，以及高级编辑器的"引导式编辑器"操作。
- **备注：** 检测的定义是"引导式页面能无损编辑它"，而不是宽松的分类。

### `ServiceReachability? serviceReachabilityForRoute(ServiceRoute route)` <a id="servicereachabilityforroute"></a>
- **种类：** 顶层函数。**来源：** 第 638 行。
- **用途：** 读取保存的路由所表达的可达范围。
- **输入：** `route`。**返回：** `ServiceReachability?`。**副作用：** 无。
- **算法：** 映射访问级别（`authenticated` ⇒ `publicAuthenticated`，`custom` ⇒ null）。存在有效的 `accessLane` 覆盖时，覆盖必须等于该可达范围的车道，否则为 null。未知的覆盖值被忽略。
- **用法：** 由 `fromRoute` 调用。
- **备注：** 刻意比"车道优先"更严格：打开一条覆盖与访问级别不一致的路由时，绝不能静默改写其中任何一个。

### `List<ServiceAccessDraftIssue> serviceAccessDraftIssues(ServiceAccessDraft draft, List<ServiceNode> services)` <a id="serviceaccessdraftissues"></a>
- **种类：** 顶层函数。**来源：** 第 659 行。
- **用途：** 列出使草稿无法保存的问题。
- **输入：** `draft`、`services`。**返回：** 问题列表，可保存时为空。
- **副作用：** 无。
- **算法：** 没有现存的源时 `missingSource`；`needsProxy` 且缺少代理时 `missingProxy`；FRP 没有中继、或任何所选中继已不存在时 `missingRelay`；FRP 和路由器端口转发的端口不在 1–65535 内时 `invalidPublicPort`；`requiresTargets` 且没有剩下非空白目标时 `missingTargets`。
- **用法：** 引导式页面据此禁用保存并显示内联错误；`fromRoute` 要求它为空。
- **备注：** 不检查源端点——没有端点的服务也是合法的源。

### `List<ServiceAccessDraftWarning> serviceAccessDraftWarnings(ServiceAccessDraft draft, List<ServiceNode> services)` <a id="serviceaccessdraftwarnings"></a>
- **种类：** 顶层函数。**来源：** 第 696 行。
- **用途：** 列出引导式页面在预览旁显示的建议性发现。
- **输入：** `draft`、`services`。**返回：** 警告列表。**副作用：** 无。
- **算法：** 仅限 FRP：中继没有可充当入口的端点时 `relayWithoutIngress`；中继运行在源自身的设备上时 `relayOnSourceDevice`。
- **用法：** 与引用警告一起显示在预览卡片中。
- **备注：** 与端口冲突一样仅为建议：绝不阻塞保存。

### `ServiceRouteMethod serviceProxyMethodFor(ServiceNode proxy)` <a id="serviceproxymethodfor"></a>
- **种类：** 顶层函数。**来源：** 第 723 行。
- **用途：** 挑选经某服务的反向代理跳所记录的路由方法。
- **输入：** `proxy`。**返回：** `ServiceRouteMethod`。**副作用：** 无。
- **算法：** 把模板 id、名称和图标转为小写；依次以 `caddy`、`nginx`、`traefik` 子串优先；否则 `custom`。
- **用法：** 草稿没有显式 `proxyMethod` 时供 `_proxyHop` 使用；`fromRoute` 用它判断保存的方法是否就是推导出的那个。
- **备注：** 无。

### `bool isFrpLikeService(ServiceNode service)` <a id="isfrplikeservice"></a>
- **种类：** 顶层函数。**来源：** 第 752 行。
- **用途：** 报告服务是否像 FRP 服务端或其他隧道端点。
- **输入：** `service`。**返回：** `bool`。**副作用：** 无。
- **算法：** 小写的名称、模板 id、图标或 kind 名中含 "frp"，或 kind 为 `tunnel`。
- **用法：** 为端口映射跳排序中继候选。
- **备注：** 从已移除的快速访问对话框的私有 `_isFrpLikeService` 原样移来。没有以 FRP 命名的服务时，`serviceAccessRelaySuggestions` 用它作为 FRP 回退。

### `List<String> serviceAccessProxySuggestions(List<ServiceNode> services, {String? sourceServiceId})` <a id="serviceaccessproxysuggestions"></a>
- **种类：** 顶层函数。**来源：** 第 769 行。
- **用途：** 列出值得推荐为反向代理的服务。
- **输入：** `services`；`sourceServiceId` — 被排除，且其设备上的代理排在最前。
- **返回：** 服务 id。**副作用：** 无。
- **算法：** 保留源以外的 `isReverseProxyLikeService` 服务；排序时源所在设备上的在前，然后按名称。
- **用法：** 引导式页面的代理选择器（推荐分组）及其「恰好一个时预选」规则。
- **备注：** 选择器仍会在推荐项下方列出其他所有服务。

### `List<String> serviceAccessRelaySuggestions(ServiceAccessPattern pattern, List<ServiceNode> services, List<Device> devices, {String? sourceServiceId})` <a id="serviceaccessrelaysuggestions"></a>
- **种类：** 顶层函数。**来源：** 第 799 行。
- **用途：** 列出值得推荐为某种模式中继的服务。
- **输入：** `pattern`、`services`、`devices`；`sourceServiceId` — 被排除。
- **返回：** 服务 id；没有中继的模式返回空。**副作用：** 无。
- **算法：** 保留小写名称、模板 id 或图标包含该模式关键字的服务——`frp`、`pangolin`、`cloudflare`（也匹配 `cloudflared`）或 `tailscale`。没有以 FRP 命名的服务时，FRP 回退到 `isFrpLikeService`。排序时 VPS 设备上的服务在前，然后按名称。
- **用法：** 引导式页面的中继选择器（推荐分组），以及恰好推荐一个服务时的预选。
- **备注：** 与清单的其余部分一样，这只是基于名称的启发式：不会检查任何真实服务器。

### `String? suggestedDirectTarget({required ServiceNode source, ServiceEndpoint? endpoint, required List<NetworkDevice> assignments, required List<Network> networks, required ServiceReachability reachability})` <a id="suggesteddirecttarget"></a>
- **种类：** 顶层函数。**来源：** 第 893 行。
- **用途：** 推荐直连访问路径打开的地址。
- **输入：** `source`；`endpoint` — 所选的源端点；`assignments`、`networks` — 源设备所在的网络；`reachability`。
- **返回：** 由已知信息拼出的 `scheme://host:port/path`，或 null。
- **副作用：** 无。
- **算法：** 只有局域网和 VPN 可达范围才会得到推荐。在源设备带地址的网络分配中，局域网优先选局域网网络上的，VPN 优先选叠加网络——Tailscale、ZeroTier、EasyTier、WireGuard——上的，否则取第一个。VPN 优先用主机名（MagicDNS），局域网优先用 IP 地址。scheme 来自 http/https 端点，其他协议不带 scheme；端点取所选的那个，或唯一的那个。最后追加端点的路径。
- **用法：** 引导式页面用它预填直连访问路径的目标，并把它作为 chip 提供。
- **备注：** 有多个端点且均未选择时，不猜测端口。

### `String? suggestedPublicHost(ServiceNode relay, List<NetworkDevice> assignments)` <a id="suggestedpublichost"></a>
- **种类：** 顶层函数。**来源：** 第 960 行。
- **用途：** 推荐 FRP 中继的公网主机。
- **输入：** `relay`、`assignments`。**返回：** `String?`。**副作用：** 无。
- **算法：** 中继的设备恰好有一个网络分配时，取其主机名，否则取其 IP 地址；其他情况为 null。
- **用法：** 引导式页面用它预填空的 FRP 公网主机。
- **备注：** 多个网络分配会使推测含糊，因此不做推测。

### `ServiceAccessPattern? _patternForHop(ServiceRouteHop hop)` <a id="patternforhop"></a>
- **种类：** 顶层函数。**来源：** 第 991 行。
- **用途：** 把路由最后一跳归类为某种模式。
- **输入：** `hop`。**返回：** `ServiceAccessPattern?`。**副作用：** 无。
- **算法：** 按方法分支（见 `detectServiceAccessPattern`）；方法为 `custom` 或缺失时回退到跳类型：`reverseProxy` ⇒ 反向代理，`portForward` ⇒ 带服务时为 FRP、不带服务时为路由器端口转发；其他 ⇒ null。
- **用法：** 由 `fromRoute` 调用。
- **备注：** 无。

### `bool _sameAccessShape(ServiceRoute saved, ServiceRoute rebuilt, Map<String, ServiceNode> byId)` <a id="sameaccessshape"></a>
- **种类：** 顶层函数。**来源：** 第 1031 行。
- **用途：** 检查重建的路由是否复现保存路由的内容。
- **输入：** `saved`、`rebuilt`、`byId`。**返回：** `bool`。**副作用：** 无。
- **算法：** 比较源服务和端点、访问级别、修剪后的备注、访问目标列表，并逐跳比较类型、方法、服务、端点、设备、标签、scheme、主机、端口、路径和备注。没有端点的已保存 FRP 跳按其默认入口比较。
- **用法：** `fromRoute` 的最后一道关卡。
- **备注：** 不比较 id、生成的名称、时间戳和 `extraJson`：`toRoute` 保留第一项和最后一项，像高级编辑器一样重新生成名称，并写入 `accessLane`。
