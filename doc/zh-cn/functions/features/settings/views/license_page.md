# lib/features/settings/views/license_page.dart

`LicensePage` 是显示应用 GNU GPLv3 许可证文本（作为字面 Dart 字符串嵌入）于可滚动、可选择文本视图的静态设置子页。它无状态、无网络或存储访问、无分支逻辑——从 [`settings_page.dart`](settings_page.md) 经"License"列表块压入。

**行数说明：** `grep -c 'Purpose:' license_page.dart` 返回 **2**，与本文件 2 个真实声明精确匹配（都恰好在其文档化声明上方）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `LicensePage`（构造函数） | 构造函数 | B | 创建页面组件（无参数）。 |
| `build` | 方法（组件） | B | 渲染应用栏和可滚动、可选择 GPLv3 许可证文本。 |

## 文档

两个声明都是 Tier B：构造函数是平凡 `const` 转发构造函数，`build` 只在文件嵌入 `_licenseText` 常量周围组合 `Scaffold`/`SingleChildScrollView`/`SelectableText`，无条件逻辑、循环或 IO。
