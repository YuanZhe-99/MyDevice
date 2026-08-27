# lib/l10n/ — 生成的本地化代码

`lib/l10n/` 中四个 Dart 文件（`app_localizations.dart`、`app_localizations_en.dart`、`app_localizations_ja.dart`、`app_localizations_zh.dart`）由 Flutter 的 `gen-l10n` 工具从 ARB 模板（`app_en.arb`、`app_ja.arb`、`app_zh.arb`、`app_zh_TW.arb`）生成。像 MyAnime 和 MyDay 一样，它们不带 `/// Purpose:` Function Explanation Layer 注释（确认：`grep -rc 'Purpose:' lib/l10n/*.dart` 四个文件全部报告零匹配，对比 `lib/` 其余 943）。

每个语言区域子类（`AppLocalizationsEn`、`AppLocalizationsJa`、`AppLocalizationsZh`）实现抽象 `AppLocalizations` 基类，ARB 模板定义的每个可翻译键一个平凡字符串/复数 getter。因为它们是生成而非编写的，本文档集不逐一枚举。字符串目录的规范、人工维护真相源是 `lib/l10n/app_en.arb`；按本仓库 `AGENTS.md`，编辑任何 ARB 文件后用 `flutter gen-l10n` 重新生成此代码。

| 源文件 | 种类 | 声明 | Tier |
|---|---|---|---|
| `lib/l10n/app_localizations.dart` | 生成抽象基类 + 委托 | 基类、`LocalizationsDelegate` 查找、`of(context)`、`_lookupAppLocalizations` | B（生成） |
| `lib/l10n/app_localizations_en.dart` | 生成语言区域子类 | 每个 ARB 键一个 getter | B（生成） |
| `lib/l10n/app_localizations_ja.dart` | 生成语言区域子类 | 每个 ARB 键一个 getter | B（生成） |
| `lib/l10n/app_localizations_zh.dart` | 生成语言区域子类 | 每个 ARB 键一个 getter | B（生成） |

此目录中无声明计入 [../INDEX.md](../INDEX.md) 跟踪的 943 个手写声明；仅为函数索引完整性列出。
