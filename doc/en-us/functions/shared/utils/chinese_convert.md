# lib/shared/utils/chinese_convert.dart

A static-only `ChineseConvert` utility providing character-by-character Simplified ↔ Traditional
Chinese conversion, backed by two rune→rune maps built lazily from the generated pair strings in
[`chinese_convert_data.md`](chinese_convert_data.md). Added in 1.6.0, copied from MyDay!!!!!
(which copied it unchanged from MyAnime!!!!!). In MyDevice its only caller is `InsightLanguage.finish`
(`lib/features/ai/services/insight_language.dart`), which converts each validated insight-card line
to the Chinese variant of the UI locale — needed because the on-device model may answer in either
variant, and Apple is asked for Simplified Chinese when it rejects Traditional. See
[`../../../on-device-ai.md`](../../../on-device-ai.md).

The class comment notes that the tables are copied from MyAnime and that MyDevice uses them only in
`InsightLanguage.finish`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ChineseConvert._` | constructor (`ChineseConvert`) | B | Prevent direct instantiation and expose only static members. |
| [`ChineseConvert.toTraditional`](#chineseconvert-totraditional) | method (`ChineseConvert`) | A | Convert simplified Chinese characters to their traditional variants. |
| [`ChineseConvert.toSimplified`](#chineseconvert-tosimplified) | method (`ChineseConvert`) | A | Convert traditional Chinese characters to their simplified variants. |
| [`_table`](#chineseconvert-table) | method (`ChineseConvert`) | A | Build a rune→rune map from an interleaved pair string. |
| [`_convert`](#chineseconvert-convert) | method (`ChineseConvert`) | A | Map every rune of a string through a table, passing others through. |

`grep -c 'Purpose:' lib/shared/utils/chinese_convert.dart` reports 5, matching the five rows above.
The two `static Map<int, int>?` cache fields (`_s2t`, `_t2s`) carry no `/// Purpose:` comments and
are not rows; they hold the tables once built.

## Documentation

### `static String toTraditional(String text)` <a id="chineseconvert-totraditional"></a>
- **Kind:** static method of `ChineseConvert`
- **Source:** `lib/shared/utils/chinese_convert.dart` (line 28)
- **Purpose:** Convert every Simplified Chinese character in `text` to a Traditional variant,
  leaving all other characters unchanged.
- **Inputs:** `text` — arbitrary string, here one generated insight line.
- **Returns:** `String` with matched characters replaced.
- **Side effects:** Builds the lookup table on first use.
- **Algorithm:** [`_convert`](#chineseconvert-convert) with the Simplified→Traditional table,
  built on first use by [`_table`](#chineseconvert-table) from `kSimplifiedToTraditionalPairs`.
- **Usage:**
  ```dart
  if (toTraditional) return ChineseConvert.toTraditional(text);
  ```
  (from `InsightLanguage.finish` in `lib/features/ai/services/insight_language.dart`, for a
  Traditional Chinese UI locale)
- **Notes:** This direction is one-to-many, so the result is a *plausible* Traditional form, not a
  guaranteed regional one: one-to-many characters take the legacy table's choice where it had one
  (里→裡, 着→著) and OpenCC's first candidate otherwise (干→幹).

### `static String toSimplified(String text)` <a id="chineseconvert-tosimplified"></a>
- **Kind:** static method of `ChineseConvert`
- **Source:** `lib/shared/utils/chinese_convert.dart` (line 37)
- **Purpose:** Convert every Traditional Chinese character in `text` to its Simplified variant,
  leaving all other characters unchanged.
- **Inputs:** `text`.
- **Returns:** `String` with matched characters replaced.
- **Side effects:** Builds the lookup table on first use.
- **Algorithm:** [`_convert`](#chineseconvert-convert) with the Traditional→Simplified table.
- **Usage:**
  ```dart
  if (toSimplified) return ChineseConvert.toSimplified(text);
  ```
  (from `InsightLanguage.finish`, for the Simplified Chinese UI locale)
- **Notes:** Many-to-one (乾 and 幹 both become 干; 髮 and 發 both become 发). Kanji shared with
  Japanese fold too (滅 → 灭), which is why it is applied only when the UI language is Chinese.

### `static Map<int, int> _table(String pairs)` <a id="chineseconvert-table"></a>
- **Kind:** static method of `ChineseConvert`
- **Source:** `lib/shared/utils/chinese_convert.dart` (line 47)
- **Purpose:** Build a rune→rune map from an interleaved pair string.
- **Inputs:** `pairs` — one of the two generated constants.
- **Returns:** `Map<int, int>`.
- **Side effects:** None.
- **Algorithm:** `pairs.runes.toList()`, then every even index becomes a key and the following rune
  its value; an assertion checks the rune count is even.
- **Usage:** `toTraditional` and `toSimplified`, each once, through `??=` on the cache field.
- **Notes:** Internal helper used within this file only. Iterates `runes`, not code units — OpenCC
  includes CJK Extension B characters, which are surrogate pairs in UTF-16.

### `static String _convert(String text, Map<int, int> table)` <a id="chineseconvert-convert"></a>
- **Kind:** static method of `ChineseConvert`
- **Source:** `lib/shared/utils/chinese_convert.dart` (line 58)
- **Purpose:** Map every rune of `text` through `table`, passing unmapped runes through.
- **Inputs:** `text`, `table`.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** Iterate `text.runes`, `writeCharCode(table[rune] ?? rune)` into a `StringBuffer`.
- **Usage:** `toTraditional` and `toSimplified`.
- **Notes:** Internal helper used within this file only. Punctuation, kana, Latin and characters
  absent from the table pass through unchanged.
