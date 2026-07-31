# lib/app/theme.dart

定义 `AppTheme`，经 `flex_color_scheme`（`FlexScheme.blue`）的应用 Material 3 浅/深主题，匹配 [架构](../../architecture.md) 描述的视觉系统。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`AppTheme._`](#apptheme-new) | 私有构造函数 | A | 阻止实例化；`AppTheme` 仅静态。 |
| [`light`](#light) | 静态 getter | A | 构建浅色 `ThemeData`。 |
| [`dark`](#dark) | 静态 getter | A | 构建深色 `ThemeData`。 |

## 文档

### `AppTheme._()` <a id="apptheme-new"></a>
- **种类：** `AppTheme` 的私有未命名构造函数。
- **来源：** `lib/app/theme.dart`（第 10 行）。
- **用途：** 让 `AppTheme` 成为两个主题 getter 的不可实例化、仅静态持有者。
- **输入：** 无。
- **返回：** 不适用。
- **副作用：** 无。
- **算法：** 空私有构造函数体。
- **用法：** 从不直接调用。
- **备注：** 与 [flavor.md](flavor.md) 的 `AppFlavor._()` 相同模式。

### `static ThemeData get light` <a id="light"></a>
- **种类：** `AppTheme` 的静态 getter。
- **来源：** `lib/app/theme.dart`（第 17 行）。
- **用途：** 构建应用浅色模式 `ThemeData`。
- **输入：** 无。
- **返回：** 由 `FlexThemeData.light(...)` 构建的 `ThemeData`。
- **副作用：** 无（每次访问构造新 `ThemeData`；不缓存）。
- **算法：** 调用 `FlexThemeData.light`，`scheme: FlexScheme.blue`、`surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold`、`blendLevel: 7` 和 `FlexSubThemesData(blendOnLevel: 10, useMaterial3Typography: true, useM2StyleDividerInM3: true, inputDecoratorBorderType: FlexInputBorderType.outline, navigationBarLabelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected)`，`useMaterial3: true`。
- **用法：** 在 `MyDeviceApp.build()` 中以 `theme: AppTheme.light` 读取（见 [app.md](../app.md)）。
- **备注：** 无。

### `static ThemeData get dark` <a id="dark"></a>
- **种类：** `AppTheme` 的静态 getter。
- **来源：** `lib/app/theme.dart`（第 37 行）。
- **用途：** 构建应用深色模式 `ThemeData`。
- **输入：** 无。
- **返回：** 由 `FlexThemeData.dark(...)` 构建的 `ThemeData`。
- **副作用：** 无。
- **算法：** 与 `light` 相同形态，但经 `FlexThemeData.dark` 带 `blendLevel: 13` 和 `blendOnLevel: 20`（比浅色模式更高混合级别，按 `flex_color_scheme` 深色表面约定）。
- **用法：** 在 `MyDeviceApp.build()` 中以 `darkTheme: AppTheme.dark` 读取。
- **备注：** 无。
