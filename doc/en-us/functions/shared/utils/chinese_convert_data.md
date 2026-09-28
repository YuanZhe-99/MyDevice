# lib/shared/utils/chinese_convert_data.dart

A **generated** data file holding the two Simplified ↔ Traditional character tables that
[`chinese_convert.md`](chinese_convert.md) looks up against. Added in 1.6.0, copied byte-for-byte
from MyDay!!!!!, which copied it from MyAnime!!!!!, where it is generated.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `kSimplifiedToTraditionalPairs` | top-level constant (`String`, line 13) | B | Interleaved rune pairs: simplified, traditional, simplified, traditional, … |
| `kTraditionalToSimplifiedPairs` | top-level constant (`String`, line 138) | B | Interleaved rune pairs: traditional, simplified, … |

**Reconciliation:** `grep -c 'Purpose:' lib/shared/utils/chinese_convert_data.dart` reports 0. The
file has no functions, constructors or getters; its two rows are undocumented `const String`
declarations (each carries only a one-line `///` description, no `Purpose:` block), listed as Tier B
because they are data, read only by `ChineseConvert._table`.

## Documentation

No Tier A declarations.

Do not edit the file by hand. Its header records that it was produced by
`tool/gen_chinese_convert.dart` from OpenCC's `data/dictionary/STCharacters.txt` and
`TSCharacters.txt` at commit `178f05dbc5dbcedd09d4ab39d501094f4d9d8820` (first candidate of each
entry), merged with MyAnime's pre-1.5.7 hand-typed table (`tool/data/legacy_st_pairs.txt`). The
generator, its inputs and `test/chinese_convert_test.dart` live in MyAnime only; none of them is in
this repo. To pick up a newer table, regenerate in MyAnime and copy the file here unchanged.

Merge rules (as generated in MyAnime): Simplified→Traditional keeps the legacy pair on a conflict
(the legacy table was Taiwan-flavoured: 里→裡, 着→著) and adds every OpenCC key it lacked;
Traditional→Simplified takes OpenCC's first value (the many-to-one canonical: 乾/幹→干, 髮/發→发)
and falls back to the reversed legacy pairs only for keys OpenCC does not list. Multi-rune entries
and identity pairs are dropped. Non-BMP characters are written as `\u{XXXXX}` escapes so the file
stays safe for tooling that counts UTF-16 units. Pairs are sorted by key.

OpenCC is © Carbo Kuo and contributors, Apache License 2.0; the attribution is in the file header.
The header also says "See the in-app license page for the attribution"; MyDevice's license page
carries that OpenCC notice since 1.6.0 (see
[`../../features/settings/views/license_page.md`](../../features/settings/views/license_page.md)).
