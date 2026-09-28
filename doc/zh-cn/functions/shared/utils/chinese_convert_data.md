# lib/shared/utils/chinese_convert_data.dart

一个**生成**的数据文件，保存 [`chinese_convert.md`](chinese_convert.md) 查表所用的两张简繁字符表。1.6.0 新增，
逐字节复制自 MyDay!!!!!，而 MyDay 复制自生成它的 MyAnime!!!!!。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `kSimplifiedToTraditionalPairs` | 顶层常量（`String`，第 13 行） | B | 交错的码点对：简体、繁体、简体、繁体、…… |
| `kTraditionalToSimplifiedPairs` | 顶层常量（`String`，第 138 行） | B | 交错的码点对：繁体、简体、…… |

**对账：** `grep -c 'Purpose:' lib/shared/utils/chinese_convert_data.dart` 报告 0。该文件没有函数、构造函数或
getter；两行都是未文档化的 `const String` 声明（各自只有一行 `///` 描述，没有 `Purpose:` 块），因为它们是数据、
只被 `ChineseConvert._table` 读取，所以列为 Tier B。

## 文档

没有 Tier A 声明。

不要手工编辑该文件。它的头部记录了它由 `tool/gen_chinese_convert.dart` 生成，输入为 OpenCC 在 commit
`178f05dbc5dbcedd09d4ab39d501094f4d9d8820` 时的 `data/dictionary/STCharacters.txt` 与 `TSCharacters.txt`（每个
条目取第一个候选），并与 MyAnime 1.5.7 之前的手打表（`tool/data/legacy_st_pairs.txt`）合并。生成器、它的输入以及
`test/chinese_convert_test.dart` 只存在于 MyAnime；本仓库里都没有。要换用更新的表，在 MyAnime 中重新生成，再把
文件原样复制过来。

合并规则（在 MyAnime 中生成时）：简转繁在冲突时保留旧表的选择（旧表偏台湾用法：里→裡、着→著），并补上 OpenCC
有而旧表没有的每个字；繁转简取 OpenCC 的第一个候选（多对一的规范方向：乾/幹→干、髮/發→发），只在 OpenCC 未列出
的字上回退到旧表的反向对。多码点条目与恒等对被丢弃。非 BMP 字符写成 `\u{XXXXX}` 转义，使文件对按 UTF-16 单元
计数的工具保持安全。各对按键排序。

OpenCC 版权归 Carbo Kuo 与贡献者所有，采用 Apache License 2.0；署名在文件头部。头部还写着
“See the in-app license page for the attribution”；MyDevice 的许可证页面自 1.6.0 起带有该 OpenCC 署名（见
[`../../features/settings/views/license_page.md`](../../features/settings/views/license_page.md)）。
