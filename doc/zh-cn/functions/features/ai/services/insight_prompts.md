# lib/features/ai/services/insight_prompts.dart

洞察卡片的词汇与措辞：哪张卡片（`InsightModule`）、纯事实构建器产出的 `InsightFacts`、带版本的系统指令与提示、把模型的 `<number>: <sentence>` 回复转为已校验行的解析器，以及事实构建器使用的小型格式化函数（使指纹不随浮点噪声变化）。事实构建器为 [`finance_insight_facts.md`](../../devices/services/finance_insight_facts.md) 和 [`service_insight_facts.md`](../../services/services/service_insight_facts.md)；消费方为 [`insight_service.md`](insight_service.md)；行校验来自 [`output_validation.md`](output_validation.md)。见 [端侧 AI — 每张卡片获得什么](../../../../on-device-ai.md#what-each-card-is-given) 和 [缓存与指纹](../../../../on-device-ai.md#cache-and-fingerprint)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `insightPromptVersion` | 顶层常量（`int`） | B | 提示版本 `1`（MyDevice 1.6.0），属于每个指纹；措辞或构建器输出改变时递增。 |
| `insightLineMaxLength` | 顶层常量（`int`） | B | `200`：保留行的最大长度（字符）；更长的行被丢弃（与 MyDay v1.5.1 的上限相同）。 |
| `insightMaxOutputTokens` | 顶层常量（`int`） | B | `400`：一张卡片的输出预算。 |
| `InsightModule`（枚举） | 枚举 | B | `deviceFinance` / `services`；名称即 `ai_insights.json` 中的键。 |
| [`InsightSlot`（构造函数）](#insightslot-new) | const 构造函数（`InsightSlot`） | A | 创建一个编号请求。 |
| [`InsightFacts`（构造函数）](#insightfacts-new) | const 构造函数（`InsightFacts`） | A | 创建卡片的事实与所请求的答案。 |
| [`canonical`](#canonical) | 方法（`InsightFacts`） | A | 为计算指纹序列化事实。 |
| [`insightInstructions`](#insightinstructions) | 顶层函数 | A | 构建一张卡片的系统指令。 |
| [`insightPrompt`](#insightprompt) | 顶层函数 | A | 构建提示：先事实，后编号请求。 |
| `_answerLine` | 私有顶层变量（`RegExp`） | B | 匹配 `<number><sep><sentence>`，分隔符为 `:` `：` `.` `)` `、`。 |
| `_bareNumber` | 私有顶层变量（`RegExp`） | B | 匹配单独占一行的数字，可带可选分隔符（`^\s*(\d+)\s*[:：.)、]?\s*$`）。 |
| `_heading` | 私有顶层变量（`RegExp`） | B | 匹配以冒号结尾的短行（`^\s*.{0,60}[:：]\s*$`），在无编号回退中被跳过。 |
| `_inlineMarks` | 私有顶层变量（`RegExp`） | B | 代码围栏、`**`、`__` 和反引号，解析前移除。 |
| [`parseInsightReply`](#parseinsightreply) | 顶层函数 | A | 读取并校验模型的编号行。 |
| [`_normalize`](#_normalize) | 私有顶层函数 | A | 折叠一行以便与回显的问题比较。 |
| [`clipTitle`](#cliptitle) | 顶层函数 | A | 为事实行缩短用户输入的名称。 |
| [`factNumber`](#factnumber) | 顶层函数 | A | 格式化数字并去掉末尾零。 |
| [`factDate`](#factdate) | 顶层函数 | A | 把日期格式化为 `yyyy-MM-dd`。 |

`grep -c 'Purpose:' lib/features/ai/services/insight_prompts.dart` 报告 10，与上面十个 Tier A 行匹配。

**对账：** 表格有 18 行，对应 10 个 `Purpose:` 块。多出的八行是不带 `Purpose:` 块的真实顶层声明：三个常量 `insightPromptVersion`、`insightLineMaxLength` 和 `insightMaxOutputTokens` 与枚举 `InsightModule`（各自只带普通文档注释），以及四个私有正则表达式 `_answerLine`、`_bareNumber`、`_heading` 和 `_inlineMarks`（完全没有文档注释）。八个均为 Tier B。`InsightSlot` 和 `InsightFacts` 的字段不列为行。MyDay 中仅供 Todo 使用的 `InsightTimeBucket`、`todoBucketFor`、`bucket` 字段和 `factWeekday` 没有移植。

## 文档

### `const InsightSlot(this.id, this.ask)` <a id="insightslot-new"></a>
- **种类：** `InsightSlot` 的 const 构造函数
- **来源：** `lib/features/ai/services/insight_prompts.dart`（第 34 行）
- **用途：** 创建向模型请求的一个编号答案。
- **输入：** `id`——稳定标识符（如 `costSummary`、`setupSummary`），属于规范形式，并按行存入缓存；`ask`——展示给模型的英文请求。
- **返回：** 新 `InsightSlot`。
- **副作用：** 无。
- **算法：** 普通字段初始化 const 构造函数。
- **用法：** `InsightSlot('setupSummary', 'Sum up this self-hosting setup.'),`（`lib/features/services/services/service_insight_facts.dart`，`serviceInsightSlots`）。
- **备注：** 只有 `id` 进入指纹，`ask` 文本不进入；修改 `ask` 措辞必须递增 `insightPromptVersion` 才能替换已缓存的卡片。

### `const InsightFacts({required this.module, required this.lines, required this.slots, this.quotedTerms = const []})` <a id="insightfacts-new"></a>
- **种类：** `InsightFacts` 的 const 构造函数
- **来源：** `lib/features/ai/services/insight_prompts.dart`（第 61 行）
- **用途：** 创建一张卡片由应用计算的事实与所请求的答案。
- **输入：** `module`；`lines`——英文 `- key: value` 事实行，已取整并限量；`slots`——按顺序的编号请求；`quotedTerms`——可能以拉丁字母出现在答案中的词（设备名称、货币代码、产品与协议名称），默认为空。
- **返回：** 新 `InsightFacts`。
- **副作用：** 无。
- **算法：** 普通字段初始化 const 构造函数。
- **用法：** 每个构建器末尾的 `return InsightFacts(`，如 `lib/features/devices/services/finance_insight_facts.dart`（`buildDeviceFinanceInsightFacts`）。
- **备注：** 只由纯 `*_insight_facts.dart` 构建器构建，它们从不把自由文本备注或识别性细节放入 `lines`。`quotedTerms` 不属于规范形式。

### `String canonical()` <a id="canonical"></a>
- **种类：** `InsightFacts` 的方法
- **来源：** `lib/features/ai/services/insight_prompts.dart`（第 73 行）
- **用途：** 为计算指纹序列化事实。
- **输入：** 无。
- **返回：** `String`——相同事实得到相同结果。
- **副作用：** 无。
- **算法：** 以 `\n` 连接：`module.name`、每条事实行，然后是以 `|` 连接的槽位 id。
- **用法：** `request.facts.canonical(),`（`lib/features/ai/services/insight_service.dart`，`insightFingerprint`）。
- **备注：** 改变任一行或槽位列表都会改变指纹；`ask` 文本和 `quotedTerms` 不会。

### `String insightInstructions(InsightLanguage language)` <a id="insightinstructions"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/insight_prompts.dart`（第 87 行）
- **用途：** 构建一张卡片的系统指令。
- **输入：** `language`——见 [`insight_language.md`](insight_language.md)。
- **返回：** `String`——一段英文。
- **副作用：** 无。
- **算法：** 固定模板：声明 "The person's locale is `<localeTag>`"，把模型设定为个人设备清单应用中的私人助手，要求只用给定事实、以 `<name>` 用一句 30 词以内的短句回答每个编号问题，格式为 `"<number>: <sentence>"`，告诉它不要重复事实或问题，要具体、平和、友善，每个金额都按事实给出的原样写货币代码（绝不用货币符号或翻译后的货币名称），并禁止医疗、法律或投资建议、诊断和捏造数字。
- **用法：** `instructions: insightInstructions(language),`（`lib/features/ai/services/insight_service.dart`，`AiInsightStore._generateParsed`）。
- **备注：** 所有模块共用一个模板。区域设置句采用 Apple 文档中的形式；回复语言也被显式点名。刻意保持简短：回复形状在 [`insightPrompt`](#insightprompt) 末尾再次写明。货币代码一句为 MyDevice 独有；它与财务构建器把货币代码列为引用词配合，使文字系统检查不会因拉丁字母丢弃中文或日文句子。任何措辞修改都需要递增 `insightPromptVersion`。

### `String insightPrompt(InsightFacts facts)` <a id="insightprompt"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/insight_prompts.dart`（第 106 行）
- **用途：** 构建一张卡片的用户提示。
- **输入：** `facts`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 第一行为 `Facts:` 及每条事实行；一个空行；`Questions:` 及每个槽位一行 `"<i+1>. <ask>"`；一个空行；`Reply with exactly N line(s), one per question, in this form:`（N 为 1 时用 `line`，否则用 `lines`）；然后每个槽位一行模板 `"<i+1>: <sentence>"`。每行以 `\n` 结尾。
- **用法：** `prompt: insightPrompt(facts),`（`lib/features/ai/services/insight_service.dart`，`AiInsightStore._generateParsed`）。
- **备注：** 问题编号从 1 开始，与 [`parseInsightReply`](#parseinsightreply) 期望收到的编号一致。末尾的模板是让小模型保持 `<number>: <sentence>` 形式的关键，问题以 `Questions:` 而不是 `Answer:` 为标题，使它们不会被当作要回显的答案。

### `Map<int, String> parseInsightReply(String reply, int slotCount, String languageCode, {List<String> quotedTerms = const [], List<String> asks = const []})` <a id="parseinsightreply"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/insight_prompts.dart`（第 147 行）
- **用途：** 把模型的 `<number>: <sentence>` 行读为已校验的句子。
- **输入：** `reply`——模型原始输出；`slotCount`；`languageCode`——`en`、`ja` 或 `zh`；`quotedTerms`——文字系统检查前移除的词；`asks`——各槽位的问题，使回显的问题不被当作答案。
- **返回：** `Map<int, String>`——从 1 开始的槽位编号到清理后句子的映射；未找到有效内容时为空。
- **副作用：** 无。
- **算法：**
  1. 用 [`_normalize`](#_normalize) 把每个 ask 规范化为一个集合。定义 `accept(raw)`：`cleanSentence(raw, maxLength: insightLineMaxLength)`，其为 `null`（空或超过 200 字符）或规范化后的句子等于某个规范化后的 ask 时返回 `null`；然后在副本中把每个至少 2 个码点的引用词替换为空格，除非 `matchesScript(copy, languageCode)` 成立，否则返回 `null`；否则返回清理后（未替换）的句子。
  2. 只从回复中移除内联标记 `_inlineMarks`（代码围栏、`**`、`__`、反引号），按 `\n` 拆分。刻意**不**使用 `stripMarkdown`：它还会删除 `1. ` 列表标记，而那正是要找的编号（这就是 MyDay v1.5.0 中编号为 `1. …` 的回复解析为空的原因）。
  3. 对每行：匹配 `_answerLine`（`^\s*(\d+)\s*[:：.)、]\s*(.+?)\s*$`）时直接得到正文。否则匹配 `_bareNumber`（单独的数字，可选分隔符）时取下一非空行为正文，除非没有下一行或它本身就是 `_answerLine`；循环索引跳到该行。其他行忽略。任一匹配都设置 `numbered`。
  4. 跳过 `1..slotCount` 以外的编号和已出现过的编号（首次出现者胜出）；`accept(body)` 非 null 时以编号存储。
  5. 若有任一行带编号（或 `slotCount` 为 0），返回。否则按顺序遍历各行，跳过空行和匹配 `_heading` 的行（最多 60 个字符且以冒号结尾），把 `accept(line)` 依次赋给槽位 1、2、……直到达到 `slotCount`；被 `accept` 拒绝的行仍占用其槽位编号。
- **用法：**
  ```dart
  return parseInsightReply(
    reply,
    facts.slots.length,
    language.code,
    quotedTerms: facts.quotedTerms,
    asks: [for (final s in facts.slots) s.ask],
  );
  ```
  （`lib/features/ai/services/insight_service.dart`，`AiInsightStore._generateParsed`。）
- **备注：** 按优先顺序接受三种回复形状：`<number>: <sentence>`；数字单独占一行、句子在下一行；以及仅当没有任何行带编号时，按顺序取前 `slotCount` 个正文行。过长的行被丢弃，从不截断。只由引用词和数字组成的句子在文字系统检查时没有剩余正文，会被丢弃；短于两个码点的引用词不会被移除，因为那会掏空它所在的正文。允许缺少槽位；调用方把空映射视为失败。`cleanSentence` 和 `matchesScript` 见 [`output_validation.md`](output_validation.md)。

### `String _normalize(String s)` <a id="_normalize"></a>
- **种类：** 私有顶层函数
- **来源：** `lib/features/ai/services/insight_prompts.dart`（第 216 行）
- **用途：** 折叠一行以便与回显的问题比较。
- **输入：** `s`。
- **返回：** `String`——小写，并移除每段连续的空白和 Unicode 标点。
- **副作用：** 无。
- **算法：** `toLowerCase()`，然后 `replaceAll(RegExp(r'[\s\p{P}]+', unicode: true), '')`。
- **用法：** 在 [`parseInsightReply`](#parseinsightreply) 中：每个 ask 调用一次以构建集合，`accept` 内每个清理后的句子调用一次。
- **备注：** 把 `Sum up this self-hosting setup.` 回显为第 1 行的模型不会把该回显当作答案显示出来。只丢弃（折叠后）完全相同的匹配；改写过的问题仍会通过。

### `String clipTitle(String title, int maxRunes)` <a id="cliptitle"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/insight_prompts.dart`（第 225 行）
- **用途：** 为事实行缩短用户输入的名称。
- **输入：** `title`；`maxRunes`——省略号前结果的最大长度，以 Unicode 码点计。
- **返回：** `String`——单行且已去除首尾空白；超过 `maxRunes` 时为前 `maxRunes` 个码点加 `…`。
- **副作用：** 无。
- **算法：** 把每段连续空白折叠为一个空格并去除首尾空白；比较码点数；需要时按码点截断并追加 `…`。
- **用法：** `final name = clipTitle(d.name, 30);`（`lib/features/devices/services/finance_insight_facts.dart`，`buildDeviceFinanceInsightFacts` 内的局部函数 `label`）。
- **备注：** 截断后的结果长 `maxRunes + 1` 个码点。按码点截断能保持代理对完整，但仍可能拆开由多个码点组成的表情序列。服务构建器不发送任何名称，也不调用它。

### `String factNumber(double value, [int digits = 1])` <a id="factnumber"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/insight_prompts.dart`（第 237 行）
- **用途：** 为事实行格式化数字。
- **输入：** `value`；`digits`——小数位数，默认 1。
- **返回：** 不带末尾零（也不带末尾 `.`）的 `String`。
- **副作用：** 无。
- **算法：** `value.toStringAsFixed(digits)`；若含 `.`，移除正则 `\.?0+$` 的匹配。
- **用法：** `'- Total daily cost: ${factNumber(dailyCost, 2)} $cur per day',`（`lib/features/devices/services/finance_insight_facts.dart`，`buildDeviceFinanceInsightFacts`）；也用于服务构建器的平均跳数。
- **备注：** 取整到固定精度使指纹不随浮点噪声变化。极小的负值可能被格式化为 `-0`。

### `String factDate(DateTime d)` <a id="factdate"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/insight_prompts.dart`（第 248 行）
- **用途：** 为事实行或指纹把日期格式化为 `yyyy-MM-dd`。
- **输入：** `d`。
- **返回：** `String`——补零的年（4 位）、月（2 位）、日（2 位）。
- **副作用：** 无。
- **算法：** 用 `padLeft` 的字符串插值。
- **用法：** `'date:${factDate(request.now)}',`（`lib/features/ai/services/insight_service.dart`，`insightFingerprint`）；也用于两个事实构建器的 `- Today:` 行和财务构建器的购买日期。
- **备注：** 按原样使用 `d` 的日历字段，因此本地 `DateTime` 得到本地日期。
