# lib/features/ai/widgets/ai_insight_card.dart

共享实现现位于 MyApps-AI v0.4.1，本页描述应用适配器。

`AiInsightCard`，放在 [财务总览](../../devices/views/device_finance_overview_page.md) 页和 [服务总览](../../services/views/service_list_page.md) 上的端侧 AI 洞察卡片，外加 `AiInsightSection`（带标题的一组行）和 `AiInsightRequestBuilder` 回调类型。除非平台可能有端侧模型且用户打开了端侧 AI，否则卡片什么都不渲染；打开时，它从页面已加载的数据构建请求，请 [`AiInsightStore`](../services/insight_service.md) 让自己保持最新，并渲染存储的状态：模型未就绪时的一行提示、生成中的进度条、各行（过时时变暗）、失败提示，以及带时间的「在本设备上生成」标签。它还把计时器重新设到下一个本地午夜，使一直开着的页面在指纹仅因时间变化时也会更新。事实和槽位来自 [`insight_prompts.dart`](../services/insight_prompts.md)，缓存条目形状来自 [`ai_insights_cache.dart`](../services/ai_insights_cache.md)，模型状态来自 [`OnDeviceAiService`](../services/on_device_ai_service.md)。见 [端侧 AI — 洞察卡片](../../../../on-device-ai.md#insight-cards)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`AiInsightSection`（构造函数）](#aiinsightsection-new) | const 构造函数（`AiInsightSection`） | A | 创建一组带标题的槽位 id。 |
| `AiInsightRequestBuilder` | 顶层 `typedef`（函数类型） | B | 为某语言和时间构建卡片请求（或返回 null）的回调。 |
| [`AiInsightCard`（构造函数）](#aiinsightcard-new) | const 构造函数（`AiInsightCard`） | A | 创建洞察卡片。 |
| `createState` | 方法（`AiInsightCard`） | B | 创建状态对象。 |
| `dispose` | 方法（`_AiInsightCardState`） | B | 取消边界计时器并移除服务监听器。 |
| [`_onServiceChanged`](#_onservicechanged) | 方法（`_AiInsightCardState`） | A | 模型变为可用时重建。 |
| [`_listenTo`](#_listento) | 方法（`_AiInsightCardState`） | A | 跟随正确的 `OnDeviceAiService` 实例。 |
| [`_armBoundaryTimer`](#_armboundarytimer) | 方法（`_AiInsightCardState`） | A | 在事实仅因时间变化的下一时刻重建。 |
| [`_scheduleEnsure`](#_scheduleensure) | 方法（`_AiInsightCardState`） | A | 在帧后请存储让此卡片保持最新。 |
| `_statusLabel` | 方法（`_AiInsightCardState`） | B | 用设置行的字符串表述 `GenAiStatus`。 |
| [`build`](#build) | 方法（`_AiInsightCardState`） | A | 构建卡片、一行提示或空盒。 |
| `_notice` | 方法（`_AiInsightCardState`） | B | 构建带可选操作的一行提示卡片。 |
| [`_card`](#_card) | 方法（`_AiInsightCardState`） | A | 构建洞察卡片本体。 |

`grep -c 'Purpose:' lib/features/ai/widgets/ai_insight_card.dart` 报告 12，与上面十二个 `Purpose:` 文档化声明匹配。八个是 Tier A：两个公共构造函数和每个带真实分支或生命周期逻辑的方法。`createState`、`dispose`、`_statusLabel`（一对一 `switch`）和 `_notice`（固定布局）是 Tier B 组件样板。

**对账：** 13 行对 12 个 `Purpose:` 块。额外行是 `AiInsightRequestBuilder`，一个带普通 `///` 描述但无 `Purpose:` 块的真实顶层 `typedef`。类 `AiInsightSection`、`AiInsightCard`、`_AiInsightCardState` 和字段不作为行，与其他页面一致。

## 文档

### `const AiInsightSection(this.title, this.slotIds)` <a id="aiinsightsection-new"></a>
- **种类：** `AiInsightSection` 的 const 构造函数
- **来源：** `lib/features/ai/widgets/ai_insight_card.dart`（第 29 行）
- **用途：** 在卡片内创建一组带标题的洞察行。
- **输入：** `title` — 小节标题；`slotIds` — 行归属于此的槽位 id。
- **返回：** 新 `AiInsightSection`。
- **副作用：** 无。
- **算法：** 普通字段初始化 const 构造函数。
- **用法：**
  ```dart
  AiInsightSection(l10n.aiFinanceRecurring, const {
    'recurringSummary',
  }),
  ```
  （`lib/features/devices/views/device_finance_overview_page.dart`，`build`；同一卡片把 `costSummary`/`costAdvice`/`reviewDevice` 分组在 `aiFinanceCosts` 下。服务卡片不传小节。）
- **备注：** 槽位不属于任何小节的行最先显示，不分组。当前条目中没有行的小节连同标题一起跳过。

### `const AiInsightCard({super.key, required this.module, required this.buildRequest, this.sections = const [], this.compact = false, this.footnote, this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8)})` <a id="aiinsightcard-new"></a>
- **种类：** `AiInsightCard`（一个 `ConsumerStatefulWidget`）的 const 构造函数
- **来源：** `lib/features/ai/widgets/ai_insight_card.dart`（第 72 行）
- **用途：** 为一个模块创建洞察卡片。
- **输入：** `module` — 哪张卡片（`InsightModule`）；`buildRequest` — 把页面已加载数据变成 `AiInsightRequest` 的 `AiInsightRequestBuilder`，无可谈内容时返回 null；`sections` — 可选的按槽位 id 分组；`compact` — 可折叠，默认折叠为一行预览；`footnote` — 行下方可选的弱化说明；`margin` — 外边距。
- **返回：** 新 `AiInsightCard`。
- **副作用：** 无。
- **算法：** 普通字段初始化 const 构造函数。
- **用法：**
  ```dart
  AiInsightCard(
    module: InsightModule.services,
    margin: const EdgeInsets.only(top: 16),
    buildRequest: (language, now) {
      final facts = buildServiceInsightFacts(
        now: now,
        services: _services,
        routes: _routes,
        devices: _devices,
        networks: _networks,
      );
      return facts == null
          ? null
          : AiInsightRequest(facts: facts, language: language, now: now);
    },
  ),
  ```
  （`lib/features/services/views/service_list_page.dart`，`_buildOverview`。）财务总览传 `compact: !sideBySide`、两个 `sections` 以及带 `fallbackFacts` 的请求。MyDevice 中没有调用方传 `footnote`。
- **备注：** 重建开销低：`buildRequest` 每次构建都运行，但存储会先对请求计算指纹并与缓存比较，然后才可能运行任何东西。

### `void _onServiceChanged()` <a id="_onservicechanged"></a>
- **种类：** `_AiInsightCardState` 的私有方法
- **来源：** `lib/features/ai/widgets/ai_insight_card.dart`（第 116 行）
- **用途：** 页面打开后模型变为可用时重建卡片。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 可能调用 `setState`；更新 `_couldGenerate`。
- **算法：** 从所监听服务读取 `canGenerate`；仅在已挂载且出现 `false` → `true` 转变时调用 `setState`；保存新值。
- **用法：** 由 `_listenTo` 注册为 `OnDeviceAiService` 监听器；在 `dispose` 中移除。
- **备注：** 覆盖状态探测在首次构建之后才完成的情况：重建会重新运行 `buildRequest` 和 `_scheduleEnsure`，之前那次构建因存储无法生成而未起作用。其他服务变化只经 `build` 中的 `ListenableBuilder` 重绘。

### `void _listenTo(OnDeviceAiService ai)` <a id="_listento"></a>
- **种类：** `_AiInsightCardState` 的私有方法
- **来源：** `lib/features/ai/widgets/ai_insight_card.dart`（第 127 行）
- **用途：** 让监听器保持在 provider 当前返回的 `OnDeviceAiService` 实例上。
- **输入：** `ai` — 被 watch 的服务。
- **返回：** 无。
- **副作用：** 把 `_onServiceChanged` 从旧实例移到新实例；重置 `_couldGenerate`。
- **算法：** `ai` 就是已监听实例时返回；否则从旧实例移除监听器，加到 `ai` 上，并用 `ai.canGenerate` 初始化 `_couldGenerate`。
- **用法：** 在 `build` 顶部、启用/平台门控之前调用。
- **备注：** 处理 provider 覆盖（测试）或 provider 重建。AI 关闭时监听没有开销：服务此时绝不调用通道。

### `void _armBoundaryTimer(DateTime now)` <a id="_armboundarytimer"></a>
- **种类：** `_AiInsightCardState` 的私有方法
- **来源：** `lib/features/ai/widgets/ai_insight_card.dart`（第 140 行）
- **用途：** 在卡片事实仅因时间变化的下一时刻重建。
- **输入：** `now` — 构建时间。
- **返回：** 无。
- **副作用：** 取消并重新设置一次性的 `_boundaryTimer`。
- **算法：**
  1. 取消之前的计时器。
  2. 取下一个本地午夜。
  3. 为它加一秒设置计时器；触发时若已挂载则 `setState`。
- **用法：** 每次启用状态下的 `build` 都调用。
- **备注：** 一秒余量确保重建运行时指纹中的本地日期已经前进；事实中的服役天数和日均成本随该日期变化。MyDay 还为其 Todo 卡片设置 12:00 和 18:00；MyDevice 没有按时段变化的卡片，因此午夜是唯一边界。关闭开关时计时器不会被取消；它之后的 `setState` 无害。

### `void _scheduleEnsure(AiInsightStore store)` <a id="_scheduleensure"></a>
- **种类：** `_AiInsightCardState` 的私有方法
- **来源：** `lib/features/ai/widgets/ai_insight_card.dart`（第 153 行）
- **用途：** 在帧后请存储让此卡片保持最新。
- **输入：** `store` — `AiInsightStore`。
- **返回：** 无。
- **副作用：** 注册一个调用 `store.ensure(request)`（不 await）的帧后回调。
- **算法：** 已有回调排定时返回；否则设 `_ensureScheduled` 并添加帧后回调，回调清除该标志、读取最新 `_request`，在已挂载且请求非 null 时调用 `ensure`。
- **用法：** 每当构建出请求时从 `build` 调用。
- **备注：** 同一帧内多次构建只产生一次使用最后请求的 `ensure` 调用。放在帧后运行使存储通知不落在构建阶段。不带 `force` 的 `ensure` 在指纹匹配时由缓存应答。

### `Widget build(BuildContext context)` <a id="build"></a>
- **种类：** `_AiInsightCardState` 的方法（override）
- **来源：** `lib/features/ai/widgets/ai_insight_card.dart`（第 188 行）
- **用途：** 构建卡片、一行提示或空盒。
- **输入：** `context`。
- **返回：** `Widget`。
- **副作用：** 重建 `_request`；重新设置边界计时器；排定 `ensure`。
- **算法：**
  1. watch `appSettingsProvider`、`onDeviceAiServiceProvider` 和 `aiInsightStoreProvider`；`_listenTo(ai)`。
  2. `platformMayHaveOnDeviceModel` 为 false 或 `onDeviceAiEnabled` 关闭时，清空 `_request` 并返回 `SizedBox.shrink()`。
  3. `_armBoundaryTimer(now)`；用 `InsightLanguage.forLocale(locale, localeSupported: ai.coreInfo?.localeSupported)` 选择语言；除非语言为 null，否则用 `widget.buildRequest(language, now)` 构建 `_request`；有请求时排定 `ensure`。
  4. 返回监听服务和存储的 `ListenableBuilder`，显示：状态 `unsupported` 时什么都不显示；其他任何非 `available` 状态时显示带状态标签和*设置*按钮（`context.go('/settings')`）的提示；语言为 null 时显示「语言不受支持」提示；请求为 null 时什么都不显示；否则显示 `_card`。
- **用法：** Flutter 框架；在页面重建（其数据变化）、设置或 locale 变化、到达时间边界、模型变为可用时运行。
- **备注：** 即使 `buildRequest` 会返回 null（例如没有任何服务的服务总览），也会显示未就绪提示，因为状态检查在请求检查之前。

### `Widget _card(BuildContext context, AppLocalizations l10n, AiInsightStore store, AiInsightRequest request)` <a id="_card"></a>
- **种类：** `_AiInsightCardState` 的私有方法
- **来源：** `lib/features/ai/widgets/ai_insight_card.dart`（第 271 行）
- **用途：** 从存储中此模块的状态构建洞察卡片本体。
- **输入：** `context`、`l10n`、`store`、`request`。
- **返回：** `Widget` — 一个 `Card`。
- **副作用：** 构建时无；重新生成按钮调用 `store.ensure(request, force: true)`，`compact` 时点击标题栏切换 `_expanded`。
- **算法：**
  1. 读取 `store.stateOf(module)`；`generating` = 阶段为 `generating`；`dim` = 生成中或过时。
  2. 标题栏：图标和标题（无副标题；MyDay 的 Todo 时段副标题没有移植）；生成中禁用的重新生成按钮；`compact` 时的展开箭头。
  3. 正文：*skipped* 条目显示已跳过消息。有行的条目把第 *i* 行与第 *i* 个槽位配对（缺失时为 `''`），`dim` 时以 60 % 透明度变暗，并显示：一行省略的首行（紧凑且折叠时），或先是未分组行的项目符号，再是每个非空小节的标题和项目符号。既无条目又未失败时显示 `aiGenerating`（「正在思考…」）。
  4. 阶段为 `failed` 时：配额提示、前台提示或通用失败文本。
  5. 显示详情（非紧凑或已展开）时：有条目则显示脚注；`ok` 条目显示「在本设备上生成——可能有误」标签和本地生成时间。
  6. 一个 2 像素的占位在生成中放 `LinearProgressIndicator`，使布局不跳动。
- **用法：** 仅在模型可用且存在请求时，从 `build` 的 `ListenableBuilder` 调用。
- **备注：** 生成较新行时较旧行保持可见（变暗）。折叠预览取第一行，不论它属于哪个小节。
