# lib/features/ai/services/insight_language.dart

`InsightLanguage`：洞察卡片请求端侧模型使用哪种语言书写，以及每条通过校验的回复行如何后处理。移植自 MyAnime!!!!! 的 `ReasonLanguage`。卡片（[`ai_insight_card.md`](../widgets/ai_insight_card.md)）根据 UI 区域设置选择语言；存储（[`insight_service.md`](insight_service.md)）把区域标签写入指纹，并对每条保留的行运行 [`finish`](#finish)。中文转换委托给 [`ChineseConvert`](../../../shared/utils/chinese_convert.md)。见 [端侧 AI — 语言](../../../../on-device-ai.md#language)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`InsightLanguage`（构造函数）](#insightlanguage-new) | const 构造函数（`InsightLanguage`） | A | 创建洞察语言。 |
| [`forLocale`](#forlocale) | 静态方法（`InsightLanguage`） | A | 为 UI 区域设置选择请求语言；模型无法书写时返回 null。 |
| [`finish`](#finish) | 方法（`InsightLanguage`） | A | 把通过校验的行转换为 UI 所用的中文变体。 |

`grep -c 'Purpose:' lib/features/ai/services/insight_language.dart` 报告 3，与上面三行精确匹配。五个字段（`localeTag`、`name`、`code`、`toTraditional`、`toSimplified`）只带不含 `Purpose:` 的单行文档注释，不列为行。三个声明均为公共声明，均为 Tier A。

## 文档

### `const InsightLanguage(this.localeTag, this.name, this.code, {this.toTraditional = false, this.toSimplified = false})` <a id="insightlanguage-new"></a>
- **种类：** `InsightLanguage` 的 const 构造函数
- **来源：** `lib/features/ai/services/insight_language.dart`（第 28 行）
- **用途：** 创建不可变的请求语言。
- **输入：** `localeTag`——指令中声明的标签（`zh_CN`、`zh_TW`、`ja_JP`、`en_US`）；`name`——指令中使用的英文语言名；`code`——`en`、`ja` 或 `zh`，供文字系统检查使用；`toTraditional` / `toSimplified`——[`finish`](#finish) 应用哪种中文转换（均默认 `false`）。
- **返回：** 新 `InsightLanguage`。
- **副作用：** 无。
- **算法：** 普通字段初始化 const 构造函数。
- **用法：** 仅 [`forLocale`](#forlocale) 内的五个 `const InsightLanguage(...)` 值；测试自行构造。
- **备注：** 没有任何机制阻止两个转换标志同时为真；此时 `finish` 只应用 `toTraditional`。

### `static InsightLanguage? forLocale(Locale locale, {bool? localeSupported})` <a id="forlocale"></a>
- **种类：** `InsightLanguage` 的静态方法
- **来源：** `lib/features/ai/services/insight_language.dart`（第 46 行）
- **用途：** 为当前 UI 区域设置选择卡片的请求语言。
- **输入：** `locale`——UI 区域设置；`localeSupported`——Apple 对该区域设置的 `supportsLocale` 答复（来自 `GenAiCoreInfo.localeSupported`），未知时为 `null`（Android，或 `info` 尚未答复）。
- **返回：** `InsightLanguage?`——模型无法用 UI 语言书写时为 `null`，卡片据此说明原因而不生成。
- **副作用：** 无。
- **算法：**
  1. 当语言为 `zh` 且国家为 `TW` 或 `HK`，或文字系统为 `Hant` 时，`traditional` 为真。
  2. 若 `localeSupported == false` 且区域设置不是繁体中文，返回 `null`。
  3. 否则按语言代码分支：
     - 繁体中文且 `localeSupported == false` → `zh_CN` / "Simplified Chinese" / `zh`，`toTraditional: true`（请求简体，转换为繁体）；
     - 其他繁体中文 → `zh_TW` / "Traditional Chinese" / `zh`，`toTraditional: true`；
     - 其他 `zh` → `zh_CN` / "Simplified Chinese" / `zh`，`toSimplified: true`；
     - `ja` → `ja_JP` / "Japanese" / `ja`；
     - 其余 → `en_US` / "English" / `en`。
- **用法：**
  ```dart
  final language = InsightLanguage.forLocale(
    Localizations.localeOf(context),
    localeSupported: ai.coreInfo?.localeSupported,
  );
  ```
  （`lib/features/ai/widgets/ai_insight_card.dart`，`build`；结果为 `null` 时不构建请求。）
- **备注：** 中文输出总是转换为 UI 所用的变体，因此另一变体的回复会被修正而不是丢弃。香港区域设置按 `zh_TW` 请求。任何未识别的语言回退为英语，因为应用本身只提供 en、ja、zh 和 zh_TW。

### `String finish(String text)` <a id="finish"></a>
- **种类：** `InsightLanguage` 的方法
- **来源：** `lib/features/ai/services/insight_language.dart`（第 84 行）
- **用途：** 后处理一条通过校验的回复行。
- **输入：** `text`——已被 `parseInsightReply` 接受的行。
- **返回：** `String`——设置了对应标志时转换为繁体或简体中文，否则原样返回 `text`。
- **副作用：** 无。
- **算法：** `toTraditional` → `ChineseConvert.toTraditional(text)`；否则 `toSimplified` → `ChineseConvert.toSimplified(text)`；否则返回 `text`。
- **用法：** `for (final n in numbers) request.language.finish(parsed[n]!)`（`lib/features/ai/services/insight_service.dart`，`AiInsightStore._run`）。
- **备注：** 在文字系统检查之后运行，因此转换从不决定某行是否保留。日语和英语行原样通过。
