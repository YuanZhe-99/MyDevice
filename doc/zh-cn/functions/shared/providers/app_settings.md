# lib/shared/providers/app_settings.dart

设备本地 UI 偏好（主题模式、语言区域）的 Riverpod 状态。由 `DeviceStorage` 在 `storage_config.json` 中的主题/语言区域键支撑（见 [数据格式](../../../data-formats.md)）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`AppSettingsNotifier` 构造函数](#appsettingsnotifier-new) | 构造函数 | A | 创建通知器并启动加载持久化设置。 |
| [`_loadPersisted`](#loadpersisted) | 方法（`AppSettingsNotifier`） | A | 从 `DeviceStorage` 加载主题模式和语言区域。 |
| [`setThemeMode`](#setthememode) | 方法（`AppSettingsNotifier`） | A | 更新状态并持久化新主题模式。 |
| [`setLocale`](#setlocale) | 方法（`AppSettingsNotifier`） | A | 更新状态并持久化新语言区域。 |
| [`AppSettings` 构造函数](#appsettings-new) | 构造函数 | A | 创建不可变设置值。 |
| [`copyWith`](#copywith) | 方法（`AppSettings`） | A | 创建设置值的修改副本。 |

`appSettingsProvider`（`StateNotifierProvider<AppSettingsNotifier, AppSettings>` 顶层值）无自己的 `/// Purpose:` 注释，是普通提供者声明，非函数/方法/构造函数——不单独计数。

## 文档

### `AppSettingsNotifier() : super(const AppSettings())` <a id="appsettingsnotifier-new"></a>
- **种类：** `AppSettingsNotifier` 的构造函数（扩展 `StateNotifier<AppSettings>`）。
- **来源：** `lib/shared/providers/app_settings.dart`（第 12 行）。
- **用途：** 用默认设置初始化通知器，然后异步加载真实持久化值。
- **输入：** 无。
- **返回：** 新 `AppSettingsNotifier`。
- **副作用：** 调用 `_loadPersisted()`（即发即忘；构造函数不 await）。
- **算法：** 用 `const AppSettings()`（系统主题、无语言区域覆盖）播种 `state`，然后不 await 地调用 `_loadPersisted()`。
- **用法：** 由 `appSettingsProvider` 的 Riverpod 工厂构造一次。
- **备注：** 因为加载不 await，首帧短暂用默认设置渲染，直到 `_loadPersisted` 解析并更新 `state`。

### `Future<void> _loadPersisted()` <a id="loadpersisted"></a>
- **种类：** `AppSettingsNotifier` 的方法。
- **来源：** `lib/shared/providers/app_settings.dart`（第 21 行）。
- **用途：** 从 `DeviceStorage` 读取持久化主题模式和语言区域标签并相应更新 `state`。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 读取 `DeviceStorage.getThemeMode()`/`getLocaleTag()`；覆盖 `state`。
- **算法：** 把存储字符串（`'light'`/`'dark'`/其他任何）映射到 `ThemeMode.light`/`.dark`/`.system`；把 `languageCode` 或 `languageCode_countryCode` 形态存储语言区域标签解析为 `Locale`；分配新 `AppSettings(themeMode, locale)`。
- **用法：** 从构造函数调用一次。
- **备注：** `null` 语言区域标签让 `locale` 保持 `null`，`MyDeviceApp` 解释为"跟随系统语言区域"（见 [app.md](../../app/app.md)）。

### `void setThemeMode(ThemeMode mode)` <a id="setthememode"></a>
- **种类：** `AppSettingsNotifier` 的方法。
- **来源：** `lib/shared/providers/app_settings.dart`（第 45 行）。
- **用途：** 更新内存主题模式并持久化。
- **输入：** `mode` — 新 `ThemeMode`。
- **返回：** 无。
- **副作用：** 更新 `state`；调用 `DeviceStorage.setThemeMode(str)`。
- **算法：** `state = state.copyWith(themeMode: mode)`；持久化前把 `light`/`dark` 映射到字符串形态、`system` 映射到 `null`。
- **用法：** 从设置页主题选择器调用。
- **备注：** `system` 存 `null` 意为"无记录覆盖"，匹配 `_loadPersisted` 对无法识别/缺席值的默认系统回退。

### `void setLocale(Locale? locale)` <a id="setlocale"></a>
- **种类：** `AppSettingsNotifier` 的方法。
- **来源：** `lib/shared/providers/app_settings.dart`（第 60 行）。
- **用途：** 更新内存语言区域覆盖并持久化。
- **输入：** `locale` — 新语言区域，或 `null` 跟随系统语言区域。
- **返回：** 无。
- **副作用：** 更新 `state`；调用 `DeviceStorage.setLocaleTag(...)`。
- **算法：** `state = state.copyWith(locale: locale, clearLocale: locale == null)`；清除时持久化 `null`，否则 `languageCode` 或 `languageCode_countryCode` 标签字符串。
- **用法：** 从设置页语言选择器调用。
- **备注：** `copyWith` 的 `clearLocale` 标志存在正因可空字段无法经单独 `??` 与"保持不变"区分——见下面 `copyWith`。

### `const AppSettings({this.themeMode = ThemeMode.system, this.locale})` <a id="appsettings-new"></a>
- **种类：** `AppSettings` 的构造函数。
- **来源：** `lib/shared/providers/app_settings.dart`（第 82 行）。
- **用途：** 创建不可变设置快照。
- **输入：** `themeMode`（默认 `ThemeMode.system`）、`locale`（默认 `null`）。
- **返回：** 新 `AppSettings`。
- **副作用：** 无。
- **算法：** 普通字段赋值。
- **用法：** 用作通知器默认状态并在每次更新经 `copyWith` 重建。
- **备注：** 无。

### `AppSettings copyWith({ThemeMode? themeMode, Locale? locale, bool clearLocale = false})` <a id="copywith"></a>
- **种类：** `AppSettings` 的方法。
- **来源：** `lib/shared/providers/app_settings.dart`（第 89 行）。
- **用途：** 创建 `AppSettings` 值的修改副本。
- **输入：** `themeMode`（可选替换）、`locale`（可选替换）、`clearLocale`（无论 `locale` 参数如何强制 `locale` 为 `null`）。
- **返回：** 新 `AppSettings`。
- **副作用：** 无。
- **算法：** `themeMode: themeMode ?? this.themeMode`；`locale: clearLocale ? null : (locale ?? this.locale)`——`clearLocale` 优先于任何传入 `locale` 值。
- **用法：** 从 `setThemeMode` 和 `setLocale` 两者调用。
- **备注：** `clearLocale` 标志正是让"显式把语言区域设为 null"在 `copyWith` 模式中可与"不碰语言区域"区分的东西，因为传 `locale: null` 否则与省略参数无法区分。
