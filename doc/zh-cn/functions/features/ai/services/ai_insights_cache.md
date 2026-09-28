# lib/features/ai/services/ai_insights_cache.dart

已生成洞察卡片的设备本地缓存，即应用数据文件夹中的 `ai_insights.json`：`AiInsightEntry` 模型（一张卡片）、`AiInsights` 容器（每个 `InsightModule` 一个条目），以及读取、写入和删除该文件的静态 `AiInsightsCache`。它刻意**不是**已注册的数据模块：从不同步，从不进入备份包或 ZIP 导出，也没有保留 schema。与数据文件不同，无法读取的缓存按空处理，因为它可重建，丢失它只需每张卡片重新生成一次。与 MyAnime!!!!! 的同名文件不同，它按模块而非按记录建键，且没有清理逻辑。唯一的消费方是 [`AiInsightStore`](insight_service.md)。见 [端侧 AI — 缓存与指纹](../../../../on-device-ai.md#cache-and-fingerprint) 和 [数据格式 — `ai_insights.json`](../../../../data-formats.md#ai_insightsjson)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AiInsightStatus`（枚举） | 枚举 | B | `ok`（文本）/ `skipped`（拒绝或不支持的语言，保留以免重试）。 |
| [`AiInsightEntry`（构造函数）](#aiinsightentry-new) | 构造函数（`AiInsightEntry`） | A | 创建缓存条目。 |
| [`AiInsightEntry.toJson`](#aiinsightentry-tojson) | 方法（`AiInsightEntry`） | A | 序列化条目。 |
| [`AiInsightEntry.fromJson`](#aiinsightentry-fromjson) | 静态方法（`AiInsightEntry`） | A | 容错地解析条目；格式错误时为 null。 |
| [`AiInsights`（构造函数）](#aiinsights-new) | 构造函数（`AiInsights`） | A | 创建缓存值并复制映射。 |
| [`AiInsights.toJson`](#aiinsights-tojson) | 方法（`AiInsights`） | A | 以排序的模块键序列化缓存文件。 |
| [`AiInsights.fromJson`](#aiinsights-fromjson) | 工厂构造函数（`AiInsights`） | A | 解析缓存文件；格式错误时为空。 |
| `AiInsightsCache._` | 私有构造函数（`AiInsightsCache`） | B | 阻止实例化；缓存是静态的。 |
| [`file`](#file) | 静态方法（`AiInsightsCache`） | A | 解析应用目录下的 `ai_insights.json`。 |
| [`load`](#load) | 静态方法（`AiInsightsCache`） | A | 读取缓存；不存在或无法读取时为空。 |
| [`save`](#save) | 静态方法（`AiInsightsCache`） | A | 经串行队列原子写入缓存。 |
| [`clear`](#clear) | 静态方法（`AiInsightsCache`） | A | 删除缓存文件。 |

`grep -c 'Purpose:' lib/features/ai/services/ai_insights_cache.dart` 报告 11，与上面十一个非枚举行匹配。

**对账：** 表格有 12 行，对应 11 个 `Purpose:` 块。多出的一行是 `AiInsightStatus` 枚举，一个只带普通文档注释的真实顶层声明。静态字段 `AiInsightsCache.fileName`（`'ai_insights.json'`）和私有的 `AiInsightsCache._queue`（一个 `AtomicWriteQueue`），以及条目与容器的字段，不列为行。

## 文档

### `AiInsightEntry({required this.fingerprint, required this.lines, List<String>? slots, required this.status, required this.generatedAt, this.model, required this.language, required this.promptVersion})` <a id="aiinsightentry-new"></a>
- **种类：** `AiInsightEntry` 的构造函数
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（第 53 行）
- **用途：** 创建一张已缓存的卡片。
- **输入：** `fingerprint`——卡片所依赖一切内容的十六进制 SHA-256；`lines`——按槽位顺序的已校验句子（`skipped` 时为空）；`slots`——每行的槽位 id；`status`；`generatedAt`——UTC；`model`——模型标识，供诊断；`language`——请求标签，如 `zh_CN`；`promptVersion`——生成时的 `insightPromptVersion`。
- **返回：** 新 `AiInsightEntry`。
- **副作用：** 无。
- **算法：** 字段初始化；`slots` 为 `null` 时默认为 `const []`。
- **用法：** `AiInsightStore._run`（`lib/features/ai/services/insight_service.dart`）用解析后的回复构建 `ok` 条目，在 guardrail 或不支持语言的失败时构建 `skipped` 条目。
- **备注：** `slots` 让卡片在前面某个槽位被丢弃时仍能把行放到正确的分区下；空 `slots` 表示不分组。构造函数不检查 `slots` 与 `lines` 长度是否一致（`fromJson` 会检查）。

### `Map<String, dynamic> toJson()` <a id="aiinsightentry-tojson"></a>
- **种类：** `AiInsightEntry` 的方法
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（第 69 行）
- **用途：** 序列化条目。
- **输入：** 无。
- **返回：** 依次含键 `fingerprint`、`generatedAt`、`language`、`lines`、`model`（仅非空时）、`promptVersion`、`slots`、`status` 的 JSON 映射。
- **副作用：** 无。
- **算法：** 映射字面量；`generatedAt.toUtc().toIso8601String()`；`status.name`。
- **用法：** [`AiInsights.toJson`](#aiinsights-tojson) 中的 `entries[k]!.toJson()`。
- **备注：** `generatedAt` 总以 UTC 写入。

### `static AiInsightEntry? fromJson(Object? json)` <a id="aiinsightentry-fromjson"></a>
- **种类：** `AiInsightEntry` 的静态方法
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（第 85 行）
- **用途：** 容忍损坏地解析一个条目。
- **输入：** `json`——任意已解码的 JSON 值。
- **返回：** `AiInsightEntry?`——当 `json` 不是映射，或 `fingerprint` 不是字符串、`lines` 不是列表、`status` 不是已知的 `AiInsightStatus` 名称、`generatedAt` 无法解析时为 `null`。
- **副作用：** 无。
- **算法：**
  1. 如上校验四个必需字段。
  2. 把 `lines` 的每个元素转为字符串。
  3. `slots` 为列表时转为字符串，且仅在其长度等于行数时保留；否则传 `null`（不分组）。
  4. 把 `generatedAt` 转为 UTC；`model` 仅为字符串时保留；`language` 默认为 `''`；`promptVersion` 不是 `int` 时默认为 `0`。
- **用法：** [`AiInsights.fromJson`](#aiinsights-fromjson) 中的 `final entry = AiInsightEntry.fromJson(map[module.name]);`。
- **备注：** 坏条目被丢弃，而非致命错误。不含 `slots` 的旧文件仍可加载。

### `AiInsights([Map<InsightModule, AiInsightEntry>? entries])` <a id="aiinsights-new"></a>
- **种类：** `AiInsights` 的构造函数
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（第 129 行）
- **用途：** 创建缓存值。
- **输入：** `entries`——可选；`null` 表示空。
- **返回：** 新 `AiInsights`，其 `entries` 是一份新的可变副本（`{...?entries}`）。
- **副作用：** 无。
- **算法：** 展开复制到新映射。
- **用法：** 文件缺失或无法读取时 [`load`](#load) 中的 `return AiInsights();`；`AiInsightStore.clearAll` 中的 `_cache = AiInsights();`。
- **备注：** `entries` 可变；`AiInsightStore._store` 在保存前原地写入它。

### `Map<String, dynamic> toJson()` <a id="aiinsights-tojson"></a>
- **种类：** `AiInsights` 的方法
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（第 137 行）
- **用途：** 序列化整个缓存文件。
- **输入：** 无。
- **返回：** `{"version": 1, "insights": {<module name>: <entry>, ...}}`，模块键按名称排序。
- **副作用：** 无。
- **算法：** 按 `name` 排序键，再用每个条目的 `toJson()` 构建映射。
- **用法：** [`save`](#save) 中的 `insights.toJson()`。
- **备注：** 排序的键使内容相同的文件逐字节一致。

### `factory AiInsights.fromJson(Object? json)` <a id="aiinsights-fromjson"></a>
- **种类：** `AiInsights` 的工厂构造函数
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（第 150 行）
- **用途：** 解析缓存文件。
- **输入：** `json`——已解码的文件。
- **返回：** `AiInsights`——`json` 不是映射或没有 `insights` 映射时为空。
- **副作用：** 无。
- **算法：** 对每个 `InsightModule` 值，用 `AiInsightEntry.fromJson` 解析 `insights[module.name]`，保留非空结果。
- **用法：** [`load`](#load) 中的 `return AiInsights.fromJson(jsonDecode(await f.readAsString()));`。
- **备注：** 未知模块键和格式错误的条目被丢弃。不检查 `version` 字段。

### `static Future<File> file()` <a id="file"></a>
- **种类：** `AiInsightsCache` 的静态方法
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（第 187 行）
- **用途：** 解析缓存文件。
- **输入：** 无。
- **返回：** `Future<File>`——`<app dir>/ai_insights.json`。
- **副作用：** 可能创建应用目录（经 [`DeviceStorage.getAppDir`](../../devices/services/device_storage.md#getappdir)）。
- **算法：** `File(p.join((await DeviceStorage.getAppDir()).path, fileName))`。
- **用法：** 在 [`load`](#load)、[`save`](#save) 和 [`clear`](#clear) 内部；测试用 `await AiInsightsCache.file()` 读取它（`test/ai_insights_cache_test.dart`）。
- **备注：** 经存储中枢解析，因此自定义存储路径可用。

### `static Future<AiInsights> load()` <a id="load"></a>
- **种类：** `AiInsightsCache` 的静态方法
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（第 195 行）
- **用途：** 读取缓存。
- **输入：** 无。
- **返回：** `Future<AiInsights>`——文件不存在或无法读取、解码时为空。
- **副作用：** 读取本地存储。
- **算法：** 在 `try` 内：解析文件；不存在则返回空；否则 `AiInsights.fromJson(jsonDecode(...))`。任何异常都返回空 `AiInsights`。
- **用法：** `AiInsightStore` 的默认 `load`（`_load = load ?? AiInsightsCache.load`，`lib/features/ai/services/insight_service.dart`）。
- **备注：** 从不抛出。这是对「损坏的数据文件抛出类型化异常」规则的刻意例外：该文件不含用户数据，可按需重建。

### `static Future<void> save(AiInsights insights)` <a id="save"></a>
- **种类：** `AiInsightsCache` 的静态方法
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（第 210 行）
- **用途：** 原子写入缓存。
- **输入：** `insights`。
- **返回：** `Future<void>`——本次写入执行后完成。
- **副作用：** 替换 `ai_insights.json`。
- **算法：** 加入类的 `AtomicWriteQueue`；在其中用两空格缩进编码 `insights.toJson()`，并用 `package:myapps_data` 的 `atomicWriteString` 写入（见 `packages/myapps_data/doc/zh-cn/functions/src/storage/atomic_io.md`）。MyDay 经其 `DataFileSafety.atomicWriteString` 写入；MyDevice 没有这层包装，直接调用包。
- **用法：** `AiInsightStore` 的默认 `save`，从 `AiInsightStore._store` 调用。
- **备注：** 从不通知自动同步。错误传给调用方；`_store` 会吞掉它们。

### `static Future<void> clear()` <a id="clear"></a>
- **种类：** `AiInsightsCache` 的静态方法
- **来源：** `lib/features/ai/services/ai_insights_cache.dart`（第 222 行）
- **用途：** 删除缓存。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 若存在则删除 `ai_insights.json`。
- **算法：** 加入与 [`save`](#save) 相同的队列；文件存在时删除。
- **用法：** `AiInsightStore` 的默认 `clear`，从 `AiInsightStore.clearAll`（设置中的 *Clear generated insights* 操作）调用。
- **备注：** 与写入串行执行，因此已排队的保存不会在删除后重新创建文件。
