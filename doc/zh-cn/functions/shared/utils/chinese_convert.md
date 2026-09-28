# lib/shared/utils/chinese_convert.dart

仅含静态成员的 `ChineseConvert` 工具，提供逐字符的简体 ↔ 繁体中文转换，背后是两张按需从
[`chinese_convert_data.md`](chinese_convert_data.md) 中生成的配对字符串构建的码点→码点映射。1.6.0 新增，复制自 MyDay!!!!!
（MyDay 原样复制自 MyAnime!!!!!）。在 MyDevice 中它唯一的调用方是 `InsightLanguage.finish`
（`lib/features/ai/services/insight_language.dart`），它把每一行通过校验的洞察卡片文字转换为界面语言区域对应的
中文变体——之所以需要，是因为端侧模型可能用任一变体回答，而且 Apple 拒绝繁体中文时会改为请求简体中文。见
[`../../../on-device-ai.md`](../../../on-device-ai.md)。

类注释说明这些表是从 MyAnime 复制而来，MyDevice 只在 `InsightLanguage.finish` 中使用它们。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ChineseConvert._` | 构造函数（`ChineseConvert`） | B | 阻止直接实例化，只暴露静态成员。 |
| [`ChineseConvert.toTraditional`](#chineseconvert-totraditional) | 方法（`ChineseConvert`） | A | 把简体中文字符转换为其繁体变体。 |
| [`ChineseConvert.toSimplified`](#chineseconvert-tosimplified) | 方法（`ChineseConvert`） | A | 把繁体中文字符转换为其简体变体。 |
| [`_table`](#chineseconvert-table) | 方法（`ChineseConvert`） | A | 从交错的配对字符串构建码点→码点映射。 |
| [`_convert`](#chineseconvert-convert) | 方法（`ChineseConvert`） | A | 把字符串的每个码点经表映射，其余原样透传。 |

`grep -c 'Purpose:' lib/shared/utils/chinese_convert.dart` 报告 5，与上面五行一致。两个 `static Map<int, int>?`
缓存字段（`_s2t`、`_t2s`）没有 `/// Purpose:` 注释，不作为行；它们保存构建好的表。

## 文档

### `static String toTraditional(String text)` <a id="chineseconvert-totraditional"></a>
- **种类：** `ChineseConvert` 的静态方法
- **来源：** `lib/shared/utils/chinese_convert.dart`（第 28 行）
- **用途：** 把 `text` 中的每个简体中文字符转换为一个繁体变体，其余字符保持不变。
- **输入：** `text`——任意字符串，在这里是一行生成的洞察文字。
- **返回：** 替换了匹配字符的 `String`。
- **副作用：** 首次使用时构建查找表。
- **算法：** 用简转繁表调用 [`_convert`](#chineseconvert-convert)，该表由 [`_table`](#chineseconvert-table) 首次
  使用时从 `kSimplifiedToTraditionalPairs` 构建。
- **用法：**
  ```dart
  if (toTraditional) return ChineseConvert.toTraditional(text);
  ```
  （来自 `lib/features/ai/services/insight_language.dart` 中的 `InsightLanguage.finish`，用于繁体中文界面
  语言区域）
- **备注：** 这个方向是一对多，因此结果是一个*合理的*繁体形式，而非有保证的地区写法：一对多的字在旧表有选择时
  沿用旧表（里→裡、着→著），否则取 OpenCC 的第一个候选（干→幹）。

### `static String toSimplified(String text)` <a id="chineseconvert-tosimplified"></a>
- **种类：** `ChineseConvert` 的静态方法
- **来源：** `lib/shared/utils/chinese_convert.dart`（第 37 行）
- **用途：** 把 `text` 中的每个繁体中文字符转换为其简体变体，其余字符保持不变。
- **输入：** `text`。
- **返回：** 替换了匹配字符的 `String`。
- **副作用：** 首次使用时构建查找表。
- **算法：** 用繁转简表调用 [`_convert`](#chineseconvert-convert)。
- **用法：**
  ```dart
  if (toSimplified) return ChineseConvert.toSimplified(text);
  ```
  （来自 `InsightLanguage.finish`，用于简体中文界面语言区域）
- **备注：** 多对一（乾与幹都变成干；髮与發都变成发）。与日文共用的汉字同样会被折叠（滅 → 灭），因此只在界面
  语言为中文时才应用。

### `static Map<int, int> _table(String pairs)` <a id="chineseconvert-table"></a>
- **种类：** `ChineseConvert` 的静态方法
- **来源：** `lib/shared/utils/chinese_convert.dart`（第 47 行）
- **用途：** 从交错的配对字符串构建码点→码点映射。
- **输入：** `pairs`——两个生成常量之一。
- **返回：** `Map<int, int>`。
- **副作用：** 无。
- **算法：** `pairs.runes.toList()`，然后每个偶数下标成为键、其后一个码点成为值；断言检查码点数为偶数。
- **用法：** `toTraditional` 和 `toSimplified`，各通过缓存字段上的 `??=` 调用一次。
- **备注：** 仅在本文件内部使用的辅助函数。遍历的是 `runes` 而不是码元——OpenCC 包含 CJK 扩展 B 的字符，它们在
  UTF-16 中是代理对。

### `static String _convert(String text, Map<int, int> table)` <a id="chineseconvert-convert"></a>
- **种类：** `ChineseConvert` 的静态方法
- **来源：** `lib/shared/utils/chinese_convert.dart`（第 58 行）
- **用途：** 把 `text` 的每个码点经 `table` 映射，未映射的码点原样透传。
- **输入：** `text`、`table`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 遍历 `text.runes`，把 `table[rune] ?? rune` `writeCharCode` 进 `StringBuffer`。
- **用法：** `toTraditional` 和 `toSimplified`。
- **备注：** 仅在本文件内部使用的辅助函数。标点、假名、拉丁字母与不在表中的字符原样透传。
