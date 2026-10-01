# lib/app/app.dart

定义 `MyDeviceApp`，根组件：把主题、语言区域和路由接进 `MaterialApp.router`。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `MyDeviceApp` 构造函数 | 构造函数 | B | 创建根应用组件。 |
| `build` | 方法（`MyDeviceApp`） | B | 构建带主题/语言区域/路由接线的 `MaterialApp.router`。 |

## 文档

两个声明都是 Tier B：构造函数是平凡 `const` 组件构造函数，`build` 是纯组件组合（读取 `appSettingsProvider` 获取主题模式和语言区域，把 `AppTheme.light`/`AppTheme.dark`、`AppLocalizations.supportedLocales`/`localizationsDelegates` 和来自 [router.md](router.md) 的 `appRouter` 接进 `MaterialApp.router`），自身无分支或 IO。应用壳总览见 [架构](../../architecture.md)。

## 动态取色（自 1.7.0 起）

`MyDeviceApp.build` 把 `MaterialApp.router` 包在 `DynamicColorBuilder`（`dynamic_color` 包）中。构建器给出的壁纸派生（Material You）配色方案**仅**在 `!kIsWeb && defaultTargetPlatform == TargetPlatform.android` 时传给 `AppTheme.light(...)` / `AppTheme.dark(...)`。设这道门是因为在 Windows 和 macOS 上插件会返回系统强调色，那会替换应用自己的蓝色种子；因此这些平台（以及 iOS 和插件不返回方案的 Android 11 及更低版本）使用 `ColorScheme.fromSeed(AppTheme.seedColor)`。`build` 还读取 `settings.uiStyle`（`AppSettings.uiStyle`），并把它作为 `AppTheme.light(...)` 和 `AppTheme.dark(...)` 的第二个参数传入，因此更改界面风格会立即重建主题。`MaterialApp.router` 的其余参数（语言区域、委托、`DevicePreview.appBuilder`、路由）不变。见 [theme.md](theme.md) 和 [../../platform-notes.md](../../platform-notes.md)。
