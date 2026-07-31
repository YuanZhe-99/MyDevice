# lib/app/app.dart

定义 `MyDeviceApp`，根组件：把主题、语言区域和路由接进 `MaterialApp.router`。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `MyDeviceApp` 构造函数 | 构造函数 | B | 创建根应用组件。 |
| `build` | 方法（`MyDeviceApp`） | B | 构建带主题/语言区域/路由接线的 `MaterialApp.router`。 |

## 文档

两个声明都是 Tier B：构造函数是平凡 `const` 组件构造函数，`build` 是纯组件组合（读取 `appSettingsProvider` 获取主题模式和语言区域，把 `AppTheme.light`/`AppTheme.dark`、`AppLocalizations.supportedLocales`/`localizationsDelegates` 和来自 [router.md](router.md) 的 `appRouter` 接进 `MaterialApp.router`），自身无分支或 IO。应用壳总览见 [架构](../../architecture.md)。
