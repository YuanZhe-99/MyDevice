# lib/features/settings/views/privacy_policy_page.dart

`PrivacyPolicyPage` 是以活动语言区域语言（英语、简体中文、繁体中文或日语，每个变体作为字面 Dart 字符串嵌入）显示应用隐私政策的静态设置子页。它无网络或存储访问；唯一逻辑是挑显示哪个嵌入字符串。从 [`settings_page.dart`](settings_page.md) 经"Privacy Policy"列表块压入。此政策文本描述的底层事实（仅本地存储、WebDAV 同步、芯片搜索/地图块/汇率的第三方网络访问）见 [平台说明](../../../../platform-notes.md) 和 [数据格式](../../../../data-formats.md)。

**行数说明：** `grep -c 'Purpose:' privacy_policy_page.dart` 返回 **3**，与本文件 3 个真实声明精确匹配（三个都恰好坐在其文档化声明上方）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `PrivacyPolicyPage`（构造函数） | 构造函数 | B | 创建页面组件（无参数）。 |
| `build` | 方法（组件） | B | 解析活动语言区域政策文本并在可滚动、可选择视图渲染。 |
| `_getText` | 方法（`PrivacyPolicyPage`） | B | 选择显示哪个语言区域特定政策字符串。 |

## 文档

三个声明都是 Tier B。`build` 是纯组件组合。`_getText` 是在四个嵌入字符串常量（`_en`、`_zh`、`_zhTW`、`_ja`）间选择的语言区域 switch——它无副作用无 IO，因此尽管有分支仍被当作与本文档集别处归为 Tier B 的标签/文本查找辅助（如 `device_list_page.dart` 的 `_categoryLabel`/`_sortModeLabel`）相同：对返回静态内容的枚举类输入固定 switch，非业务逻辑。其唯一值得注意行为（源码第 41-53 行）是在落入普通 `switch (locale.languageCode)` *前*检查 `languageCode == 'zh' && countryCode == 'TW'`，因此繁体中文必须两个字段一起匹配——否则裸 `'zh'` 匹配会也为台湾语言区域选择简体中文文本。
