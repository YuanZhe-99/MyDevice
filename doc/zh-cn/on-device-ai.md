# 端侧 AI

Dart 执行及输出工具通过薄适配器使用 MyApps-AI v0.1.0。原生通道及业务提示词
使用 v0.2.0 共享插件，业务提示词留在应用，见 [shared-ai.md](shared-ai.md)。

自 1.6.0 起，MyDevice!!!!! 可以使用设备自带的语言模型——通过 Android AICore 使用 Gemini Nano，或通过 Foundation
Models 框架使用 Apple Intelligence 的模型——在两处写一张简短的**洞察卡片**：**财务总览**页面上是成本概况和一条建议；
**服务**总览上是对自托管配置的总结和建议。本页记录其规则、代码的布局、每张卡片获得的内容、结果如何缓存，以及仍需
在设备上检查的内容。

模型层移植自 MyDay!!!!!（1.5.x），而后者本身移植自 MyAnime!!!!! 和 MyNihongo!!!!!；两张洞察卡片及其事实构建器
是 MyDevice 自己的。

> **最后核实：** 2026-09-28，依据 MyDay 的移植版本和已发布的库。**尚未在设备上验证。** 带 AICore 的 Android
> 设备和带 Apple Intelligence 的 Apple 设备都还没有在 MyDevice 中运行过这段代码；有设备时按
> [设备检查清单](#device-checklist) 操作。提示词只针对一个云端替身检查过（见 [提示词检查](#prompt-check)）。

## 策略 <a id="policy"></a>

第 1–3、7 和 8 条在 `OnDeviceAiService` 中强制执行，并由 `test/on_device_ai_test.dart` 和
`test/ai_settings_tiles_ui_test.dart` 覆盖。第 4–6 和 9 条由洞察层强制执行，并由
`test/insight_service_test.dart`、`test/insight_facts_test.dart`、`test/ai_insights_cache_test.dart` 和
`test/ai_insight_card_ui_test.dart` 覆盖。

1. **默认关闭。** 在用户打开开关之前，`storage_config.json` 中没有 `onDeviceAiEnabled`。
2. **开关就是一道门。** 开关关闭时从不调用方法通道，连状态也不查询，每张卡片都不渲染任何内容。
3. **每次请求前都重新检查状态。** 系统可能在两次请求之间移除模型。
4. **生成的输出带标注**「在本设备上生成——可能有误」。
5. **页面优先。** 卡片只在页面已显示的数据下方添加文字；模型失败时页面保持不变。
6. **生成的内容不同步也不备份。** 结果存放在 `ai_insights.json` 中，该文件没有登记到
   `lib/app/data_modules.dart`。
7. **绝不替用户下载任何东西。** 在 Android 上，模型下载只从设置中的「下载」按钮开始，并由 AICore 执行；在
   Apple 平台上由系统管理模型。
8. **只在端侧。** 绝不使用 Apple 的 Private Cloud Compute，也绝不使用任何其他远程模型。
9. **只有计算出的事实会到达模型。** 卡片由应用计算的汇总数据构建；见
   [每张卡片获得的内容](#what-each-card-is-given)。序列号、备注、位置、主机名、地址和 URL 绝不会到达模型。

两种构建（`FLAVOR=full` 和 `store`）都包含此功能：它自身不发起任何网络调用。在 Windows 和 Linux 上，卡片从不
构建，设置分区只有一行「本平台不可用」。

## 布局 <a id="layout"></a>

| 路径 | 作用 |
|---|---|
| `lib/features/ai/services/genai_backend.dart` | Dart 接缝：`GenAiStatus`、`GenAiFailure`、`GenAiStatusReport`、`GenAiCoreInfo`、`GenAiBackend` 接口和 `MethodChannelGenAiBackend` |
| `lib/features/ai/services/on_device_ai_service.dart` | `OnDeviceAiService`：开关、每次使用前的状态检查、单请求优先级队列、45 秒超时、生命周期、忙碌退避和每日配额停止 |
| `lib/features/ai/services/output_validation.dart` | 去除 Markdown、文字系统检查、清理单句、解析选择应答 |
| `lib/features/ai/services/insight_language.dart` | `InsightLanguage`：根据界面语言区域确定请求语言，以及中文变体转换 |
| `lib/features/ai/services/insight_prompts.dart` | `InsightModule`、`InsightFacts`、带版本的指令与提示词，以及回复解析器 |
| `lib/features/ai/services/ai_insights_cache.dart` | `AiInsightsCache`：`ai_insights.json`，本设备的缓存 |
| `lib/features/ai/services/insight_service.dart` | `AiInsightStore`：指纹、缓存或生成、合并请求、失败处理 |
| `lib/features/ai/widgets/ai_insight_card.dart` | `AiInsightCard`：卡片及其全部状态 |
| `lib/features/ai/widgets/ai_settings_tiles.dart` | `AiSettingsTiles`：开关、状态行、尺寸偏好、说明、技术详情和*清除已生成的洞察* |
| `lib/features/devices/services/finance_insight_facts.dart` | 设备财务事实 |
| `lib/features/services/services/service_insight_facts.dart` | 服务事实 |
| `lib/shared/utils/chinese_convert.dart` | 简体 ↔ 繁体转换，复制自 MyDay |
| `packages/myapps_ai/packages/myapps_ai_platform/android/src/main/kotlin/com/yuanzhe/myapps_ai/GenAiChannel.kt` | 通往 ML Kit GenAI 的 Android 桥接 |
| `packages/myapps_ai/packages/myapps_ai_platform/` | 一个本地 Flutter 插件，iOS 和 macOS 共用一份 Darwin 源码 |

设置中的*端侧 AI*分区位于*数据*和*桌面*之间。开关经 `DeviceStorage` 以 `onDeviceAiEnabled` 和
`onDeviceAiPreferFast` 存放在 `storage_config.json` 中（见 [`data-formats.md`](data-formats.md#storage_configjson)）；
`AppSettingsNotifier` 在启动时把两者推入 `OnDeviceAiService`，`main()` 启动该服务的生命周期监听器。

三个平台上的通道都是 `com.yuanzhe.myapps_ai/genai`。它的方法有 `status`（`force`、`preferFast`）、`info`
（`locale`）、`download`（仅 Android）、`generate`（`instructions`、`prompt`、`maxOutputTokens`、`temperature`、
`topK`）、`choose`（仅 Apple；MyDevice 不使用，但保留以使插件与 MyDay 一致）、`prewarm` 和 `cancel`。
`platformMayHaveOnDeviceModel` 在 Android、iOS 和 macOS 上为 true；在其他所有平台上，后端不触碰通道就回答
`unsupported`。iOS 或 macOS 上的 `MissingPluginException` 报告为 `unreachable`，detail 为「channel not
registered」，绝不报告为 `unsupported`，这样注册失败的插件才会被发现。

### 状态与失败 <a id="statuses-and-failures"></a>

| 状态 | 含义 |
|---|---|
| `unsupported` | 本平台没有端侧模型（Windows、Linux、26 之前的 iOS 或 macOS） |
| `unavailable` | 已询问系统，系统表示不行 |
| `unreachable` | 根本无法询问系统 |
| `notEnabled` | Apple Intelligence 在系统设置中已关闭 |
| `downloadable` | Android：模型可由 AICore 获取 |
| `downloading` | 模型正在获取或准备中（也包括 Apple 的 `modelNotReady`） |
| `available` | 就绪 |
| `unknown` | 本版本没有对应名称的状态 |

失败类型有 `unavailable`、`busy`、`failed`、`cancelled`、`tooLong`、`timeout`、`background`、`quota`、
`guardrail` 和 `unsupportedLanguage`。

### 队列 <a id="the-queue"></a>

一次只运行一个请求。因打开页面而生成的卡片是**后台**请求；卡片的刷新按钮是**交互**请求，排在前面。应用不处于
`AppLifecycleState.resumed` 时什么都不运行。遇到 `busy` 后，后台任务等待 5 秒，逐次翻倍，最长 5 分钟；遇到
`quota` 后，后台任务在当天剩余时间停止；遇到 `background` 后，队列等待下一次 resume。

## 洞察卡片 <a id="insight-cards"></a>

每张卡片是放在其页面上的一个 `AiInsightCard`。开关关闭时或在没有模型的平台上它不渲染任何内容（包括其外边距），
因此那时所有现有布局都不变。模型尚未就绪时（需要下载、Apple Intelligence 已关闭……），它是一行带*设置*按钮的
提示。否则它显示带刷新按钮的标题、生成期间的一条细进度条、各行文字（生成新行期间旧行变暗），以及标注和时间。

| 页面 | 位置 | 槽位 |
|---|---|---|
| 财务总览 | 每日成本趋势卡片之后。在堆叠布局中折叠为一行预览；摘要与分布图并排时完整显示。 | *成本*下的 `costSummary`、`costAdvice`、`reviewDevice`；*周期费用*下的 `recurringSummary`。 |
| 服务（总览） | 警告卡片之后、*访问路径*之前。只在至少有一个服务时显示。 | `setupSummary`、`warningAdvice`、`exposureAdvice`。 |

### 每张卡片获得的内容 <a id="what-each-card-is-given"></a>

事实是由纯函数构建器计算出的英文 `- key: value` 行，经过取整，使指纹不会随浮点噪声变化。模型被要求用界面语言、
以一句不超过 30 个词的话回答每个带编号的问题，只使用给出的事实，金额按事实中给出的货币代码原样书写，不给医疗、
法律或投资建议，也不编造数字。提示词依次是 `Facts:`、事实行、`Questions:`、带编号的问题，最后是精确的回复模板
（`1: <sentence>` ……），因为小模型对刚刚见过的形状的遵循，远好于对散文描述的形状。

回复解析器（`parseInsightReply`）接受以 `:`、`：`、`.`、`)` 或 `、` 为分隔符的 `<number>: <sentence>`、单独
占一行的编号后接其句子的形式，以及——仅在完全没有任何编号时——按顺序取最前面的散文行。它会丢弃只是复述问题的
行、超过 200 个字符的行，以及文字系统不对的行。粗体和代码标记会被去掉；列表标记则保留。

| 卡片 | 发送 | 绝不发送 |
|---|---|---|
| 财务总览 | 日期和默认货币；按状态的设备数量及其中有成本数据的数量；总拥有成本和总日均成本；按类别的成本（前 5 项，只计正值，与分布图相同）；日均成本最高的三台在役设备和在役时间最长的三台，以名称（截断到 30 个字符）和类别表示；在役设备上的周期费用——条目数和设备数、按种类的计数、按月计费的每月合计、按年计费的每年合计，以及年度总额；已退役和已售出的数量以及转售总额。如果模型拒绝这些事实或没有给出任何可用的回答，第二次尝试会发送只写类别的同样事实（`fallbackFacts`）。 | 序列号、备注、位置名称和坐标、品牌和型号、存储序列号、周期费用名称 |
| 服务 | 日期；按状态、种类和运行时的服务数量（各取前 5）；多少台设备托管服务，其中多少台已退役或售出；按协议和范围的端点数量；不同监听端口的数量，以及确定和可能的端口冲突数量；按访问级别和跳点方式的访问路径，以及平均跳点数；端点引用的网络数量；按种类的警告；同一设备上重复的服务名称，以及共用最终 URL 的访问路径 | 服务、访问路径、端点和跳点的名称或标签；绑定地址、主机名、路径和 URL；端口号；标签、备注和 Compose 文件 |

`guardrail` 拒绝会作为*跳过*缓存，在事实变化之前不会重试。

### 语言 <a id="language"></a>

`InsightLanguage.forLocale` 根据界面语言区域选择请求语言：简体中文（转换为简体）、繁体中文（转换为繁体）、日语或
英语。Apple 的 `supportsLocale` 拒绝繁体中文时，改为请求简体再转换；拒绝其他任何界面语言时，卡片会说明模型无法
使用该语言写作。只有文字系统与界面语言匹配的回复行才会保留（中文和日语至少 60 % 为 CJK，其他语言为拉丁字母）。
可以合理地保持拉丁字母的词语作为*引用词*列出，并在检查前被移除：财务卡片上是设备名称和货币代码，服务卡片上是
一份固定的产品与协议名称列表（`serviceInsightTechTerms`——Caddy、Tailscale Funnel、Docker、LAN、URL……）。

### 提示词检查 <a id="prompt-check"></a>

这里没有任何设备能运行端侧模型，因此 1.6.0 用 Claude Haiku 4.5 代替模型，回答了由真实样例数据构建的精确指令和
提示词（两张卡片以及财务后备事实，英语、简体中文和日语），并把每个回复都交给真实的 `parseInsightReply` 处理。
由此产生了两项改动：

- 日语回答把 `CNY` 写成了 `円`。现在指令要求金额保留给出的货币代码。
- 在此之后，含三个金额——或提到 Caddy 和 Tailscale Funnel——的简短中文和日文句子低于 60 % CJK 阈值而被丢弃。
  货币代码和这些技术名称于是成为引用词。

此后两轮共 52 个回答槽位全部保留。云端模型远大于 Gemini Nano 或 Apple 的端侧模型，所以这检查的是提示词的形状
和解析器，而不是端侧回答的质量；事实行都有上限（每行前 3 或前 5 项），以便远低于较小模型的输入预算。

## 缓存与指纹 <a id="cache-and-fingerprint"></a>

结果缓存在应用数据文件夹中的 `ai_insights.json` 里（见
[`data-formats.md`](data-formats.md#ai_insightsjson)）。卡片**只**在其指纹变化时重新生成。指纹是以下内容的
SHA-256：

- 模块，
- `insightPromptVersion`（每当提示词措辞或构建器的输出变化时就要升级它），
- 请求语言标签，
- 本地日期（因此仅凭时间，每张卡片每天至多刷新一次），
- 模型身份（`variant · baseModelName`，或 `apple`），
- 规范化的事实。

因此卡片在以下情况更新：其数据变化（买入或售出设备、添加一项费用、编辑服务或访问路径）、日期变化、模型更新之后，
或界面语言变化——除此之外绝不更新。卡片会为下一个本地午夜设定计时器，因此一直开着的页面也会更新。

`AiInsightStore` 让每张卡片至多有一次生成在运行或等待：期间到达的请求替换等待中的那个，而事实已不再是最新的结果
会被丢弃。`failed`、`timeout` 或无法解析的回复不会缓存，只由刷新按钮或新事实触发重试，因此不会循环；`busy`、
`background`、`cancelled` 和 `unavailable` 在下次构建页面时重试。财务卡片带有 `fallbackFacts`：当模型拒绝主要
事实（`guardrail`）或对它们没有返回任何可用内容时，存储会在同一次运行中把后备事实发送一次，并把它产出的任何结果
缓存在主要指纹之下。设置中的*清除已生成的洞察*会删除该文件。

## Android：基于 AICore 的 ML Kit GenAI <a id="android-ml-kit-genai-over-aicore"></a>

- `com.google.mlkit:genai-prompt:1.0.0-beta4`，与 MyAnime 和 MyDay 版本相同。**没有**使用 Structured Output API。
- 要求 API 26 或以上，因此自 1.6.0 起应用的 `minSdk` 为 26（放弃 Android 7.0 和 7.1）。这些 API 在已解锁
  bootloader 的设备上拒绝运行。输入必须保持在约 4,000 token 以下；两张卡片的提示词都远低于此。
- 只有应用是最前台应用时才允许推理；后台使用会以 `BACKGROUND_USE_BLOCKED`（→ `background`）失败。AICore
  实行按应用的配额：`BUSY`（→ `busy`）和 `PER_APP_BATTERY_USE_QUOTA_EXCEEDED`（→ `quota`）。
- `GenAiChannel.probePrompt` 尝试 `ModelReleaseStage`（STABLE、PREVIEW）与 `ModelPreference`（FULL、FAST）的
  全部四种组合，保留第一个能提供服务的组合。只有两种尺寸都有提供时，设置才提供「使用更快的模型」。
- 模型报告 `isSystemPromptAvailable` 时，instructions 作为 `SystemInstruction` 发送；否则拼接在 prompt 前面。
- 空白文本或 `finishReason` 为 `OTHER` 时作为 `guardrail` 抛出，消息中提到 *safety*、*filter*、*blocked*、
  *guardrail* 或 *harmful* 的处理错误同样如此；`MAX_TOKENS` 会记录日志并返回被截断的文本。
- `android/app/proguard-rules.pro` 带有 R8 为 ML Kit 所需的保留规则，release 构建类型通过 `proguardFiles` 列出它。
- `AndroidManifest.xml` 为 `com.google.android.aicore` 加了 `<queries>` 条目，使 `info` 能读取 AICore 的版本。
- `MainActivity` 在 `configureFlutterEngine` 中挂接 `GenAiChannel`（与现有的分享通道并列），并在 `onDestroy` 中解除。
- 核心库脱糖保持关闭（见 [`platform-notes.md`](platform-notes.md)）；ML Kit GenAI 不需要它。
- 日志标签：`MyDeviceGenAi`。记录异常，从不记录 prompt。

## Apple：Foundation Models 框架 <a id="apple-the-foundation-models-framework"></a>

- iOS、iPadOS 和 macOS 26.0 或以上。`SystemLanguageModel.default.availability` 为 `.available` 或
  `.unavailable(reason)`，原因是 `deviceNotEligible`、`appleIntelligenceNotEnabled` 或 `modelNotReady`；可用性
  还取决于地区。
- 每个请求新建一个 `LanguageModelSession(instructions:)`，使前面的对话轮次不会泄漏到后面的回答中。
- 列出的语言包括 en-US、ja-JP 和 zh-CN；繁体中文不在列表中，见 [语言](#language)。
- 上下文窗口为 4,096 token。后台调用会被限速。
- 错误：`rateLimited` → `quota`，`concurrentRequests` → `busy`，`guardrailViolation` 和 `refusal` →
  `guardrail`，`unsupportedLanguageOrLocale` → `unsupportedLanguage`，`exceededContextWindowSize` →
  `tooLong`，`assetsUnavailable` → `unavailable`，其他一律 → `failed`。
- CI 使用 `macos-latest` 镜像默认的 Xcode（26.x）构建。
- 不需要任何 entitlement、`Info.plist` 键或使用说明，并且刻意没有 Private Cloud Compute 的 entitlement。

### 弱链接 <a id="weak-linking"></a>

部署目标保持为 iOS 13.0 和 macOS 13.0。每处 FoundationModels 引用都位于 `#if canImport(FoundationModels)` 和
`@available(iOS 26.0, macOS 26.0, *)` 之后，podspec 声明了 `s.weak_frameworks = 'FoundationModels'`。强链接该
框架的应用无法在 iOS 18 或 macOS 15 及更早版本上启动，因此这一点**经过检查，而不是假设**：只要有任何链接
FoundationModels 的二进制没有使用 `LC_LOAD_WEAK_DYLIB`，`tool/check_weak_link.sh` 就让 CI 构建失败；没有任何
二进制链接它时（插件没有进入构建）也会失败。见 [`ci-cd.md`](ci-cd.md)。

## 商店政策 <a id="store-policy"></a>

Google Play 的 AI 生成内容政策把使用 AI 改进现有功能的效率类应用列为不在适用范围内；输出仍然带标注。两张卡片
只发送中性的统计数据。

## 设备检查清单 <a id="device-checklist"></a>

有设备时执行以下步骤，并更新上文的**最后核实**。

1. 开关关闭时，确认没有任何东西触碰模型（logcat 标签 `MyDeviceGenAi` 保持安静），也没有出现任何卡片。
2. 打开开关；检查状态行、技术详情，以及 Android 上的 AICore 版本和已提供与被拒绝的变体。
3. Android：点「下载」，进度以 MB 显示；状态变为可用。
4. 打开财务总览和服务总览；每张卡片生成一次，之后重新打开页面时显示缓存的文字，不出现进度条。
5. 添加一项周期费用或把一台设备标记为已售出；财务卡片重新生成。编辑一条访问路径；服务卡片重新生成。
6. 检查全部四种界面语言；各行以正确的文字系统到达，金额保留货币代码，模型用简体回答时繁体中文会被转换。
7. 请求进行中把应用切到后台；恢复后正常继续。
8. 在 **release** 构建（R8）上重复第 2–7 步。
9. Apple：在系统设置中关闭 Apple Intelligence；卡片和状态行都如实说明。
10. Apple：在 iOS 18 或 macOS 15 设备上安装，或在模拟器中启动一台，确认应用能启动。

## 如何刷新本页 <a id="how-to-refresh-this-page"></a>

1. 对照 Google Maven 分组索引（`https://dl.google.com/android/maven2/com/google/mlkit/group-index.xml`）和
   ML Kit 发布说明检查 `genai-prompt`，并对照 MyDay 的 `doc/en-us/on-device-ai.md`。
2. 针对当前 SDK 重读 Foundation Models 文档，并确认 runner 镜像的默认 Xcode。
3. 修改任何提示词措辞或事实构建器之后，升级 `insightPromptVersion`。
4. 在两种语言中更新**最后核实**和上面的事实。
