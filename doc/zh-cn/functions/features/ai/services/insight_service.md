# lib/features/ai/services/insight_service.dart

`AiInsightStore`，洞察卡片的所有者：它计算每个请求的指纹，指纹匹配时显示已缓存的条目，否则经 [`OnDeviceAiService`](on_device_ai_service.md) 运行端侧模型，解析回复并存入 [`ai_insights.json`](ai_insights_cache.md)，并告诉卡片（[`ai_insight_card.md`](../widgets/ai_insight_card.md)）显示什么。每个模块至多一个生成在运行或等待：期间到达的请求替换待处理的请求，指纹已不再是最新的结果会被丢弃。请求可携带更朴素的 `fallbackFacts`（源自 MyDay v1.5.1），当模型拒绝主事实或对其返回无法解析的内容时，存储会把它发送一次。提示与解析来自 [`insight_prompts.md`](insight_prompts.md)；失败代码与状态报告来自 [`genai_backend.md`](genai_backend.md)。见 [端侧 AI — 缓存与指纹](../../../../on-device-ai.md#cache-and-fingerprint)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AiInsightPhase`（枚举） | 枚举 | B | `idle` / `generating` / `ready` / `failed`：卡片所处的生命周期阶段。 |
| [`AiInsightState`（构造函数）](#aiinsightstate-new) | const 构造函数（`AiInsightState`） | A | 创建卡片显示的内容。 |
| [`AiInsightRequest`（构造函数）](#aiinsightrequest-new) | const 构造函数（`AiInsightRequest`） | A | 创建一张卡片的请求：事实、语言、时间、可选的回退事实。 |
| [`modelIdentityOf`](#modelidentityof) | 顶层函数 | A | 命名状态报告描述的模型。 |
| [`insightFingerprint`](#insightfingerprint) | 顶层函数 | A | 计算一张卡片请求的指纹（十六进制 SHA-256）。 |
| [`AiInsightStore`（构造函数）](#aiinsightstore-new) | 构造函数（`AiInsightStore`） | A | 以可注入的服务、缓存 I/O 和时钟创建存储。 |
| `setInstanceForTest` | 静态方法（`AiInsightStore`） | B | 替换应用级 `instance`；仅测试使用。 |
| `_ai` | 私有 getter（`AiInsightStore`） | B | 注入的服务，否则为当前的 `OnDeviceAiService.instance`。 |
| [`stateOf`](#stateof) | 方法（`AiInsightStore`） | A | 读取卡片状态。 |
| [`_cached`](#_cached) | 私有方法（`AiInsightStore`） | A | 只加载一次缓存并共享。 |
| [`ensure`](#ensure) | 方法（`AiInsightStore`） | A | 使卡片保持最新：已缓存条目或一次生成。 |
| [`_run`](#_run) | 私有方法（`AiInsightStore`） | A | 生成一张卡片，然后处理替换它的请求。 |
| [`_generateParsed`](#_generateparsed) | 私有方法（`AiInsightStore`） | A | 为一个事实值运行模型一次并解析回复。 |
| [`_answer`](#_answer) | 私有方法（`AiInsightStore`） | A | 回答一个请求，需要时尝试一次其回退事实。 |
| [`_store`](#_store) | 私有方法（`AiInsightStore`） | A | 把条目放入缓存并持久化。 |
| [`clearAll`](#clearall) | 方法（`AiInsightStore`） | A | 忘记所有已生成的洞察。 |
| `_set` | 私有方法（`AiInsightStore`） | B | 更新一张卡片的状态并通知监听者。 |
| `aiInsightStoreProvider` | 顶层变量（`Provider`） | B | 基于 `AiInsightStore.instance` 的普通 `Provider`，可在测试中覆盖。 |

`grep -c 'Purpose:' lib/features/ai/services/insight_service.dart` 报告 16，与上面除 `AiInsightPhase` 和 `aiInsightStoreProvider` 之外的十六行匹配。

**对账：** 表格有 18 行，对应 16 个 `Purpose:` 块。多出的两行是只带普通文档注释的真实顶层声明：`AiInsightPhase` 枚举和 `aiInsightStoreProvider` provider。静态字段 `AiInsightStore.instance`、私有状态映射（`_states`、`_running`、`_pending`、`_latest`）以及值类的字段不列为行。

## 文档

### `const AiInsightState({this.phase = AiInsightPhase.idle, this.entry, this.failure, this.stale = false})` <a id="aiinsightstate-new"></a>
- **种类：** `AiInsightState` 的 const 构造函数（`@immutable`）
- **来源：** `lib/features/ai/services/insight_service.dart`（第 49 行）
- **用途：** 创建卡片渲染的值。
- **输入：** `phase`（默认 `idle`）；`entry`——要显示的条目；`failure`——上次尝试失败的原因，或对 `ready` 的 skipped 条目而言被跳过的原因；`stale`——`entry` 是否属于较旧的事实（默认 `false`）。
- **返回：** 新 `AiInsightState`。
- **副作用：** 无。
- **算法：** 普通字段初始化 const 构造函数。
- **用法：** `_set(module, AiInsightState(phase: AiInsightPhase.ready, entry: entry));`（`ensure`，同文件）；`const AiInsightState()` 是 [`stateOf`](#stateof) 的默认值。
- **备注：** 无。

### `const AiInsightRequest({required this.facts, required this.language, required this.now, this.fallbackFacts})` <a id="aiinsightrequest-new"></a>
- **种类：** `AiInsightRequest` 的 const 构造函数
- **来源：** `lib/features/ai/services/insight_service.dart`（第 79 行）
- **用途：** 创建一张卡片的请求。
- **输入：** `facts`——来自某个 `*_insight_facts.dart` 构建器；`language`——回复语言；`now`——计算事实时的本地时间；`fallbackFacts`——更朴素的第二次尝试，或 null：当模型以 `guardrail` 拒绝 `facts` 或对其返回无法解析的内容时，由 [`_answer`](#_answer) 发送一次。
- **返回：** 新 `AiInsightRequest`。
- **副作用：** 无。
- **算法：** 普通字段初始化 const 构造函数。
- **用法：**
  ```dart
  AiInsightRequest(
    facts: full,
    language: language,
    now: now,
    fallbackFacts: facts(names: false),
  )
  ```
  （`lib/features/devices/views/device_finance_overview_page.dart`，财务卡片的 `buildRequest`，其中 `facts(names: …)` 包装 `buildDeviceFinanceInsightFacts(..., includeNames: names)`；`lib/features/services/views/service_list_page.dart` 中的服务总览只传 `facts`、`language` 和 `now`，不带回退。）
- **备注：** 只有 `now` 的日期进入指纹。`fallbackFacts` 完全不属于指纹，且必须与 `facts` 携带相同的模块和顺序相同的相同槽位 id，使卡片的各节仍适用于实际被回答的那组事实。

### `String modelIdentityOf(GenAiStatusReport report)` <a id="modelidentityof"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/insight_service.dart`（第 92 行）
- **用途：** 命名状态报告描述的模型。
- **输入：** `report`——服务当前的状态报告。
- **返回：** `String`——以 `' · '` 连接的非空 `variant` 和 `baseModelName`（如 `stable/full · nano-v3`），两者都为 null 时为 `apple`。
- **副作用：** 无。
- **算法：** 用空感知元素构建 `[?report.variant, ?report.baseModelName]`；连接，为空时返回 `apple`。
- **用法：** [`ensure`](#ensure) 和 [`_run`](#_run) 中的 `modelIdentityOf(_ai.report)`。
- **备注：** 与 MyAnime!!!!! 规则相同。由于标识进入指纹，模型更新会重新生成每张卡片；在 Apple 平台上标识恒定。

### `String insightFingerprint(AiInsightRequest request, String model)` <a id="insightfingerprint"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/insight_service.dart`（第 104 行）
- **用途：** 计算一张卡片请求的指纹。
- **输入：** `request`；`model`——来自 [`modelIdentityOf`](#modelidentityof)。
- **返回：** `String`——小写十六进制 SHA-256。
- **副作用：** 无。
- **算法：** 以 `\n` 连接：模块名、`prompt:<insightPromptVersion>`、`language:<localeTag>`、`date:<factDate(now)>`、`model:<model>` 和 `request.facts.canonical()`；用 `sha256` 对 UTF-8 字节求哈希。
- **用法：** `final fingerprint = insightFingerprint(request, modelIdentityOf(_ai.report));`（[`ensure`](#ensure)）；也在 [`_run`](#_run) 中用于待处理请求。
- **备注：** 覆盖模块、提示版本、语言、本地日期、模型和事实。其中任一改变都会重新生成卡片；其他任何因素都不会。

### `AiInsightStore({OnDeviceAiService? ai, Future<AiInsights> Function()? load, Future<void> Function(AiInsights insights)? save, Future<void> Function()? clear, DateTime Function()? clock})` <a id="aiinsightstore-new"></a>
- **种类：** `AiInsightStore` 的构造函数（扩展 `ChangeNotifier`）
- **来源：** `lib/features/ai/services/insight_service.dart`（第 129 行）
- **用途：** 创建存储。
- **输入：** `ai`——模型服务（默认：`OnDeviceAiService.instance`，每次使用时解析）；`load` / `save` / `clear`——缓存 I/O（默认：`AiInsightsCache.load` / `.save` / `.clear`）；`clock`——`generatedAt` 的时钟（默认 `DateTime.now`，使用时转为 UTC）。
- **返回：** 新 `AiInsightStore`。
- **副作用：** 首次使用前无；缓存惰性加载。
- **算法：** 把每个覆盖值或其默认值存入 final 字段。
- **用法：** `static AiInsightStore instance = AiInsightStore();`（同文件）；`test/insight_service_test.dart` 传入基于假后端的 `OnDeviceAiService`、内存缓存 I/O 和固定 UTC 时钟。
- **备注：** 让 `ai` 保持 null（而非捕获单例）使 `OnDeviceAiService.setInstanceForTest` 无需重建存储即可生效。

### `AiInsightState stateOf(InsightModule module)` <a id="stateof"></a>
- **种类：** `AiInsightStore` 的方法
- **来源：** `lib/features/ai/services/insight_service.dart`（第 178 行）
- **用途：** 读取卡片的当前状态。
- **输入：** `module`。
- **返回：** 已存的 `AiInsightState`，或 `const AiInsightState()`（idle，无条目）。
- **副作用：** 无。
- **算法：** 带默认值的映射查找。
- **用法：** `final state = store.stateOf(widget.module);`（`lib/features/ai/widgets/ai_insight_card.dart`，卡片正文构建器）。
- **备注：** 在该模块运行 [`ensure`](#ensure) 之前为 idle，[`clearAll`](#clearall) 之后亦然。

### `Future<AiInsights> _cached()` <a id="_cached"></a>
- **种类：** `AiInsightStore` 的私有方法
- **来源：** `lib/features/ai/services/insight_service.dart`（第 186 行）
- **用途：** 只加载一次缓存并共享。
- **输入：** 无。
- **返回：** `Future<AiInsights>`——内存中的缓存。
- **副作用：** 首次使用时调用注入的 `load`。
- **算法：** `_cache` 已设置时返回它。否则启动（或复用）`_loading = _load().catchError(=> AiInsights()).then(...)`，其中设置 `_cache ??= value`、清空 `_loading` 并返回 `_cache`。
- **用法：** [`ensure`](#ensure)、[`_run`](#_run) 和 [`_store`](#_store) 的第一行。
- **备注：** 并发的首次调用共享一次加载。`_cache ??=` 保留加载期间 [`clearAll`](#clearall) 安装的空缓存。若注入的 `load` 抛出，缓存以空开始，而不是让之后每次调用都失败；默认的 `AiInsightsCache.load` 从不抛出。

### `Future<void> ensure(AiInsightRequest request, {bool force = false})` <a id="ensure"></a>
- **种类：** `AiInsightStore` 的方法
- **来源：** `lib/features/ai/services/insight_service.dart`（第 204 行）
- **用途：** 使卡片保持最新：匹配时显示已缓存条目，否则生成。
- **输入：** `request`；`force`——即使缓存匹配也重新生成（卡片的刷新按钮）。
- **返回：** `Future<void>`——本次调用的工作完成后完成（包括它启动的生成，但不包括它仅排队的生成）。
- **副作用：** 可能运行模型、写入 `ai_insights.json` 并通知监听者。
- **算法：**
  1. 加载缓存；用当前模型标识计算指纹。
  2. 非强制且已缓存条目的指纹匹配 → 记为最新，丢弃任何待处理请求，以该条目设为 `ready`，返回。
  3. `!_ai.canGenerate` → 以已缓存条目设为 `idle`（有条目时标为 `stale`），返回。
  4. 非强制且 `_latest` 已等于此指纹 → 返回（这组事实已在运行、排队或已失败）。
  5. 把指纹记为最新。若该模块已有生成在运行，把 `(request, force)` 存为待处理请求（替换任何更早的请求），以标为 stale 的当前显示条目设为 `generating`，返回。
  6. 否则 `await _run(request, fingerprint, force)`。
- **用法：** `unawaited(store.ensure(request));`（每次卡片构建后的帧回调中）和 `unawaited(store.ensure(request, force: true))`（刷新按钮），均在 `lib/features/ai/widgets/ai_insight_card.dart`。
- **备注：** 模型无法运行时只显示已缓存文本。强制刷新以 `AiPriority.interactive` 运行；页面打开以 `background` 运行。已缓存的 `skipped` 条目也算匹配，因此拒绝在事实改变或用户刷新前不会重试。

### `Future<void> _run(AiInsightRequest request, String fingerprint, bool force)` <a id="_run"></a>
- **种类：** `AiInsightStore` 的私有方法
- **来源：** `lib/features/ai/services/insight_service.dart`（第 252 行）
- **用途：** 生成一张卡片，然后处理期间替换它的请求。
- **输入：** `request`；`fingerprint`——调用方已计算；`force`——决定优先级。
- **返回：** `Future<void>`。
- **副作用：** 运行模型（一次或两次）；可能写入缓存；通知监听者。
- **算法：**
  1. 把模块标为运行中；以先前缓存的条目（存在时标为 stale）设为 `generating`。
  2. `final (facts, parsed) = await _answer(request, force)`（[`_answer`](#_answer)）：模型为主事实运行，当它拒绝主事实或返回无法解析的内容且请求带有 `fallbackFacts` 时，再为回退事实运行一次；`facts` 是实际被回答的那个值。
  3. `parsed` 为空 → 以 `GenAiFailure.failed` 设为 `failed`（不缓存）。否则构建 `ok` 条目：按槽位编号顺序、经 `language.finish` 处理的行，取自 `facts.slots[n - 1].id` 的对应槽位 id，UTC `generatedAt`，模型、语言标签和提示版本；状态 `ready`；用 [`_store`](#_store) 存储。
  4. `GenAiException` 为 `guardrail` 或 `unsupportedLanguage` → 构建 `skipped` 条目（无行），状态 `ready` 并携带该失败，并存储。其他 `GenAiException` → 以其失败设为 `failed`。其他任何异常 → 以 `GenAiFailure.failed` 设为 `failed`。
  5. 清除运行标记。若存在待处理请求：重新计算其指纹并记为最新；若非强制且缓存已与之匹配，以该条目设为 `ready`；否则若模型可运行，以它递归进入 `_run`；否则忘记最新指纹，以可用的最佳条目（stale）设为 `idle`。
  6. 无待处理请求：仅当此指纹仍为最新时发布新状态；若为带 `busy`、`background`、`cancelled` 或 `unavailable` 的 `failed` 状态，则忘记最新指纹，使下次页面构建重试。
- **用法：** 只从 [`ensure`](#ensure) 调用，并递归调用自身。
- **备注：** 指纹已不再是最新的结果既不存储也不显示。`failed`、`timeout`、`tooLong`、`quota` 或无法解析的结果保留其指纹为最新，因此只由刷新按钮或新事实重试，不会循环。当待处理请求替换本次运行时，本次运行自己的状态从不发布。即使实际被回答的是回退事实，条目仍按主事实计算指纹并缓存。

### `Future<Map<int, String>> _generateParsed(InsightFacts facts, InsightLanguage language, bool force)` <a id="_generateparsed"></a>
- **种类：** `AiInsightStore` 的私有方法
- **来源：** `lib/features/ai/services/insight_service.dart`（第 377 行）
- **用途：** 为一个事实值运行模型一次并解析回复。
- **输入：** `facts`；`language`；`force`——为 true 时用交互优先级，否则用后台优先级。
- **返回：** `Future<Map<int, String>>`——槽位编号到句子的映射，来自 [`parseInsightReply`](insight_prompts.md#parseinsightreply)；回复中没有可用内容时为空。
- **副作用：** 运行模型。
- **算法：** `_ai.generate(instructions: insightInstructions(language), prompt: insightPrompt(facts), maxOutputTokens: insightMaxOutputTokens, priority: interactive|background)`，然后 `parseInsightReply(reply, facts.slots.length, language.code, quotedTerms: facts.quotedTerms, asks: [for (final s in facts.slots) s.ask])`。
- **用法：** 每次生成由 [`_answer`](#_answer) 调用一次或两次。
- **备注：** 从 [`_run`](#_run) 拆出（MyDay v1.5.1），使其可为任一事实值运行。像服务一样抛出 `GenAiException`；这里不捕获任何异常。

### `Future<(InsightFacts, Map<int, String>)> _answer(AiInsightRequest request, bool force)` <a id="_answer"></a>
- **种类：** `AiInsightStore` 的私有方法
- **来源：** `lib/features/ai/services/insight_service.dart`（第 406 行）
- **用途：** 回答一个请求，需要时尝试一次其回退事实。
- **输入：** `request`；`force`——透传给 [`_generateParsed`](#_generateparsed)。
- **返回：** `Future<(InsightFacts, Map<int, String>)>`——实际被回答的事实和解析后的回复，后者可能为空。
- **副作用：** 运行模型一次或两次。
- **算法：**
  1. `_generateParsed(request.facts, ...)`。若结果非空，或请求没有 `fallbackFacts`，返回 `(request.facts, parsed)`。
  2. 若该调用抛出 `GenAiException`，除非其失败为 `guardrail` 且存在回退，否则重新抛出。
  3. 否则（解析为空或 guardrail，且存在回退）返回 `(fallback, await _generateParsed(fallback, ...))`。
- **用法：** [`_run`](#_run) 中的 `final (facts, parsed) = await _answer(request, force);`。
- **备注：** MyDay v1.5.1 为其 Todo 卡片新增：端侧模型拒绝了 Todo 带标题的事实或回答了没有可用内容。在 MyDevice 中只有财务卡片传入回退：相同事实，只是用分类代替设备名称。回退至多尝试一次，且只针对 `guardrail` 拒绝或解析为空——`unsupportedLanguage`、`busy`、`timeout` 及其余失败原样传播。回退本身的 guardrail 也会传播，因此 `_run` 像其他拒绝一样把它缓存为 `skipped`。

### `Future<void> _store(InsightModule module, AiInsightEntry entry, String fingerprint)` <a id="_store"></a>
- **种类：** `AiInsightStore` 的私有方法
- **来源：** `lib/features/ai/services/insight_service.dart`（第 427 行）
- **用途：** 把条目放入缓存并持久化。
- **输入：** `module`、`entry`、`fingerprint`。
- **返回：** `Future<void>`。
- **副作用：** 修改内存缓存；经注入的 `save` 写入 `ai_insights.json`。
- **算法：** `_latest[module] != fingerprint` 时返回；否则设 `cache.entries[module] = entry` 并 `await _save(cache)`，吞掉任何错误。
- **用法：** [`_run`](#_run) 中对 `ok` 和 `skipped` 条目调用 `await _store(module, entry, fingerprint);`。
- **备注：** 期间已有更新事实到达时跳过。写入失败被忽略：卡片仍显示文本，只是在下次应用启动时重新生成。

### `Future<void> clearAll()` <a id="clearall"></a>
- **种类：** `AiInsightStore` 的方法
- **来源：** `lib/features/ai/services/insight_service.dart`（第 446 行）
- **用途：** 忘记所有已生成的洞察。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 把内存缓存替换为空；清空每张卡片的状态、最新指纹和待处理请求；经注入的 `clear` 删除 `ai_insights.json`（错误被吞掉）；通知监听者。
- **算法：** 重置字段，在 `try` 中 `await _clear()`，`notifyListeners()`。
- **用法：** `await ref.read(aiInsightStoreProvider).clearAll();`（`lib/features/ai/widgets/ai_settings_tiles.dart`，*Clear generated insights*）。
- **备注：** 不清空 `_running`：进行中的生成会完成，但因其指纹已不再是最新，结果既不存储也不显示。卡片在其页面下次构建时重新生成。
