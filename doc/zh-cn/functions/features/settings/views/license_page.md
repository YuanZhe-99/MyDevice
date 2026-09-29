# lib/features/settings/views/license_page.dart

`LicensePage` 是显示应用 GNU GPLv3 许可证文本（作为字面 Dart 字符串嵌入）于可滚动、可选择文本视图的静态设置子页。自 1.6.0 起，该字符串末尾附有一段说明：可选的端侧 AI 洞察卡片所用的简繁中文转换表（[`chinese_convert_data.md`](../../../shared/utils/chinese_convert_data.md)）派生自 OpenCC，版权归 Carbo Kuo 与贡献者所有，采用 Apache License 2.0。自 1.6.1 起，末尾还附有一段声明：内置图片不属于 GPL-3.0 源代码（指向三个 `SOURCES.md` 文件），部分设备缩略图是厂商的产品图，所有产品名称、标志和品牌都是其所有者的商标。它无状态、无网络或存储访问、无分支逻辑——从 [`settings_page.dart`](settings_page.md) 经"License"列表块压入。

**行数说明：** `grep -c 'Purpose:' license_page.dart` 返回 **2**，与本文件 2 个真实声明精确匹配（都恰好在其文档化声明上方）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `LicensePage`（构造函数） | 构造函数 | B | 创建页面组件（无参数）。 |
| `build` | 方法（组件） | B | 渲染应用栏和可滚动、可选择 GPLv3 许可证文本（外加 OpenCC 说明），封顶 `readingMaxWidth` 并居中。 |

## 文档

两个声明都是 Tier B：构造函数是平凡 `const` 转发构造函数，`build` 只在文件嵌入 `_licenseText` 常量周围组合 `Scaffold`/`SingleChildScrollView`/`SelectableText`，无条件逻辑、循环或 IO。
