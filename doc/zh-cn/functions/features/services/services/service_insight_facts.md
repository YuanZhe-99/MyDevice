# lib/features/services/services/service_insight_facts.dart

服务总览端侧 AI 洞察卡片背后的纯事实构建器，1.6.0 新增。`buildServiceInsightFacts` 把 [服务页](../views/service_list_page.md) 已持有的服务、访问路径、设备和网络转为 [`InsightFacts`](../../ai/services/insight_prompts.md)：按状态、种类和运行时统计的服务数、宿主设备（以及其中已退役或已售出的数量）、按协议和范围统计的端点、不同的监听端口数与端口冲突、按访问级别和跳转方式统计的访问路径、端点引用的网络、按种类统计的警告，以及重复名称与最终 URL。它**只发送计数和枚举名**。端口冲突和警告来自总览所显示的同一组 [`service_analysis`](service_analysis.md) 函数，因此卡片与列表一致。卡片本身是 [`AiInsightCard`](../../ai/widgets/ai_insight_card.md)，事实由 [`AiInsightStore`](../../ai/services/insight_service.md) 计算指纹。见 [端侧 AI — 每张卡片获得什么](../../../../on-device-ai.md#what-each-card-is-given)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `serviceInsightMaxBreakdown` | 顶层 `const int` | B | 一条分项行最多列出多少个值，从大到小（5）。 |
| `serviceInsightSlots` | 顶层 `const List<InsightSlot>` | B | 卡片的三个槽位：`setupSummary`、`warningAdvice`、`exposureAdvice`。 |
| `serviceInsightTechTerms` | 顶层 `const List<String>` | B | 回复中可保留拉丁字母的产品与协议名称；作为引用词传入。 |
| [`_breakdown`](#_breakdown) | 顶层函数（私有） | A | 把计数分项渲染为 `a 3, b 1` 形式的事实行片段。 |
| `_countBy` | 顶层函数（私有） | B | 按字符串键统计条目。 |
| [`buildServiceInsightFacts`](#buildserviceinsightfacts) | 顶层函数 | A | 构建服务卡片的事实。 |

`grep -c 'Purpose:' lib/features/services/services/service_insight_facts.dart` 报告 3，与 `_breakdown`、`_countBy` 和 `buildServiceInsightFacts` 匹配。

**对账：** 6 行对应 3 个 `Purpose:` 块。多出的三行是真实的顶层常量——`serviceInsightMaxBreakdown`、`serviceInsightSlots` 和 `serviceInsightTechTerms`——各自带普通 `///` 描述但没有 `Purpose:` 块。`serviceInsightTechTerms` 把较长的名称排在它所包含的较短名称之前（`Cloudflare Tunnel` 在 `Cloudflare` 之前，`HTTPS` 在 `HTTP` 之前），因为引用词在文字系统检查前按顺序移除。

## 文档

### `String _breakdown(Map<String, int> counts)` <a id="_breakdown"></a>
- **种类：** 顶层函数（私有）
- **来源：** `lib/features/services/services/service_insight_facts.dart`（第 66 行）
- **用途：** 把计数分项渲染为 `a 3, b 1` 形式的事实行片段。
- **输入：** `counts`——值名称到计数的映射。
- **返回：** `String`——`counts` 为空时为 `none`；否则为以 `, ` 连接的 `<name> <count>` 条目，从大到小，至多 `serviceInsightMaxBreakdown` 个，有条目被省略时后接 `<n> more`。
- **副作用：** 无。
- **算法：** 按计数降序、再按名称升序排序条目；取前 `serviceInsightMaxBreakdown` 个；有剩余时追加 `'$rest more'`；连接。
- **用法：** `'${_breakdown(_countBy(services, (s) => s.kind.name))}'` 以及 [`buildServiceInsightFacts`](#buildserviceinsightfacts) 中的其他每个分项；跳转方式用 `_breakdown(methods)`。
- **备注：** 按名称打破平局，使该行——因而使指纹——与映射的遍历顺序无关。

### `InsightFacts? buildServiceInsightFacts({required DateTime now, required List<ServiceNode> services, required List<ServiceRoute> routes, required List<Device> devices, required List<Network> networks})` <a id="buildserviceinsightfacts"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/services/services/service_insight_facts.dart`（第 105 行）
- **用途：** 构建服务卡片的事实。
- **输入：** `now`——本地时间；页面的 `services`、`routes`（访问路径）、`devices` 和 `networks`。
- **返回：** `InsightFacts?`，带 `module: services`、三个 `serviceInsightSlots` 和 `quotedTerms: serviceInsightTechTerms`——没有任何服务时为 null。
- **副作用：** 无。
- **算法：**
  1. `services` 为空时返回 null。收集每个服务的端点和宿主设备 id 集合；统计设备存在且不在服役中的宿主数。
  2. 端口事实：`listServicePortUses(services)` 按不同的 `deviceId|transport|port` 三元组计数；`findServicePortConflicts(services)` 拆分为确定与潜在冲突（见 [`service_analysis.md`](service_analysis.md#findserviceportconflicts)）。
  3. `findServiceReferenceWarnings(services:, routes:, devices:, networks:)`（[`service_analysis.md`](service_analysis.md#findservicereferencewarnings)）。
  4. 遍历访问路径：总跳数与跳转方式（`h.method?.name`）计数。收集端点引用的不同网络 id。统计去除首尾空白并转小写后在同一设备上重复的服务名（按 `deviceId|name`），以及种类为 `duplicateFinalUrl` 的警告数。
  5. 各行：`- Today:`；带按 `state` 分项的 `- Services:`；`- Services by kind:`；`- Runtimes:`（无运行时为 `unspecified`）；`- Hosts:`；按 `protocol` 和 `scope` 的 `- Endpoints:`；带确定与潜在冲突的 `- Distinct listening ports:`；`- Access paths:`——`none`，或按 `accessLevel` 的数量、按方式的分项和平均跳数（[`factNumber`](../../ai/services/insight_prompts.md#factnumber)）；`- Networks referenced by endpoints:`；按种类的 `- Warnings:`；`- Duplicates:`。
  6. 返回 `InsightFacts(module: InsightModule.services, lines, slots: serviceInsightSlots, quotedTerms: serviceInsightTechTerms)`。
- **用法：**
  ```dart
  final facts = buildServiceInsightFacts(
    now: now,
    services: _services,
    routes: _routes,
    devices: _devices,
    networks: _networks,
  );
  ```
  （`lib/features/services/views/service_list_page.dart`，`_buildOverview`，第 454 行；不带 `fallbackFacts`。由 `test/insight_facts_test.dart` 的 `service facts` 组覆盖。）
- **备注：** 构建器从不发送服务或访问路径名称、绑定地址、路径、URL、跳转主机、端口号、标签、备注或 compose 文件；名称只用于统计重复。每个分项都经过 [`_breakdown`](#_breakdown)，因此相同输入得到相同的规范形式。由于不发送任何用户输入的词，引用词只有固定的技术名称，使中文或日文句子可以保留 `Caddy` 或 `Tailscale Funnel` 之类的名称而不会通不过文字系统检查。
