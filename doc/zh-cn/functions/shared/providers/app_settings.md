# lib/shared/providers/app_settings.dart

设备本地 UI 偏好（主题模式、语言区域）以及自 1.6.0 起两个端侧 AI 开关（使用端侧 AI、偏好更快的模型）的 Riverpod 状态。由 `DeviceStorage` 在 `storage_config.json` 中的主题/语言区域键和 `onDeviceAi*` 键支撑（见 [数据格式](../../../data-formats.md)）。AI 开关还会推送给负责策略的 [`OnDeviceAiService`](../../features/ai/services/on_device_ai_service.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`AppSettingsNotifier` 构造函数](#appsettingsnotifier-new) | 构造函数 | A | 创建通知器并启动加载持久化设置。 |
| [`AppSettingsNotifier.fixed`](#appsettingsnotifier-fixed) | 命名构造函数 | A | 创建从固定设置开始的通知器（测试用）。 |
| [`_loadPersisted`](#loadpersisted) | 方法（`AppSettingsNotifier`） | A | 从 `DeviceStorage` 加载主题模式、语言区域和 AI 开关，然后把 AI 开关推送给服务。 |
| [`setThemeMode`](#setthememode) | 方法（`AppSettingsNotifier`） | A | 更新状态并持久化新主题模式。 |
| [`setLocale`](#setlocale) | 方法（`AppSettingsNotifier`） | A | 更新状态并持久化新语言区域。 |
| [`setOnDeviceAiEnabled`](#setondeviceaienabled) | 方法（`AppSettingsNotifier`） | A | 打开或关闭端侧 AI。 |
| [`setOnDeviceAiPreferFast`](#setondeviceaipreferfast) | 方法（`AppSettingsNotifier`） | A | 在两种尺寸都提供时偏好更快的端侧模型。 |
| [`AppSettings` 构造函数](#appsettings-new) | 构造函数 | A | 创建不可变设置值。 |
| [`copyWith`](#copywith) | 方法（`AppSettings`） | A | 创建设置值的修改副本。 |

`appSettingsProvider`（`StateNotifierProvider<AppSettingsNotifier, AppSettings>` 顶层值）无自己的 `/// Purpose:` 注释，是普通提供者声明，非函数/方法/构造函数——不单独计数。字段 `onDeviceAiEnabled` 和 `onDeviceAiPreferFast` 只带普通 `///` 描述，也不列为行。行数（9）与 `grep -c '/// Purpose:' lib/shared/providers/app_settings.dart`（9）一致。

## 文档

### `AppSettingsNotifier() : super(const AppSettings())` <a id="appsettingsnotifier-new"></a>
- **种类：** `AppSettingsNotifier` 的构造函数（扩展 `StateNotifier<AppSettings>`）。
- **来源：** `lib/shared/providers/app_settings.dart`（第 13 行）。
- **用途：** 用默认设置初始化通知器，然后异步加载真实持久化值。
- **输入：** 无。
- **返回：** 新 `AppSettingsNotifier`。
- **副作用：** 调用 `_loadPersisted()`（即发即忘；构造函数不 await）。
- **算法：** 用 `const AppSettings()`（系统主题、无语言区域覆盖、两个 AI 开关均关闭）播种 `state`，然后不 await 地调用 `_loadPersisted()`。
- **用法：** 由 `appSettingsProvider` 的 Riverpod 工厂构造一次。
- **备注：** 因为加载不 await，首帧短暂用默认设置渲染，直到 `_loadPersisted` 解析并更新 `state`。

### `AppSettingsNotifier.fixed(super.settings)` <a id="appsettingsnotifier-fixed"></a>
- **种类：** `AppSettingsNotifier` 的命名构造函数（v1.6.0）。
- **来源：** `lib/shared/providers/app_settings.dart`（第 23 行）。
- **用途：** 创建从给定设置开始的通知器。
- **输入：** `settings`——初始 `AppSettings`，转交给 `StateNotifier`。
- **返回：** 新 `AppSettingsNotifier`。
- **副作用：** 无；不从磁盘读取任何内容，也不向 `OnDeviceAiService` 推送任何内容。
- **算法：** 只做超参数转交；不调用 `_loadPersisted`。
- **用法：** `test/ai_insight_card_ui_test.dart` 和 `test/ai_settings_tiles_ui_test.dart` 中的 `AppSettingsNotifier.fixed(AppSettings(onDeviceAiEnabled: enabled))`，用于覆盖 `appSettingsProvider`。
- **备注：** 供测试使用。各 setter 仍经 `DeviceStorage` 持久化。

### `Future<void> _loadPersisted()` <a id="loadpersisted"></a>
- **种类：** `AppSettingsNotifier` 的方法。
- **来源：** `lib/shared/providers/app_settings.dart`（第 31 行）。
- **用途：** 从 `DeviceStorage` 读取持久化主题模式、语言区域标签和 AI 开关，相应更新 `state`，并把 AI 开关交给 `OnDeviceAiService`。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 读取 `DeviceStorage.getThemeMode()`/`getLocaleTag()`/`getOnDeviceAiEnabled()`/`getOnDeviceAiPreferFast()`（均来自 `storage_config.json`）；覆盖 `state`；先 await `OnDeviceAiService.instance.setPreferFast(...)`，再 await `setEnabled(...)`。
- **算法：** 把存储字符串（`'light'`/`'dark'`/其他任何）映射到 `ThemeMode.light`/`.dark`/`.system`；把 `languageCode` 或 `languageCode_countryCode` 形态存储语言区域标签解析为 `Locale`；分配新 `AppSettings(themeMode, locale, onDeviceAiEnabled, onDeviceAiPreferFast)`；然后先推送尺寸偏好，再推送开关。
- **用法：** 从无名构造函数调用一次。
- **备注：** `null` 语言区域标签让 `locale` 保持 `null`，`MyDeviceApp` 解释为"跟随系统语言区域"（见 [app.md](../../app/app.md)）。先推送偏好再推送开关，使 `setEnabled(true)` 触发的启动状态探测已使用持久化的尺寸偏好。开关关闭时，`setEnabled(false)` 不做任何后端调用（[`on_device_ai_service.md`](../../features/ai/services/on_device_ai_service.md)）。

### `void setThemeMode(ThemeMode mode)` <a id="setthememode"></a>
- **种类：** `AppSettingsNotifier` 的方法。
- **来源：** `lib/shared/providers/app_settings.dart`（第 65 行）。
- **用途：** 更新内存主题模式并持久化。
- **输入：** `mode` — 新 `ThemeMode`。
- **返回：** 无。
- **副作用：** 更新 `state`；调用 `DeviceStorage.setThemeMode(str)`。
- **算法：** `state = state.copyWith(themeMode: mode)`；持久化前把 `light`/`dark` 映射到字符串形态、`system` 映射到 `null`。
- **用法：** 从设置页主题选择器调用。
- **备注：** `system` 存 `null` 意为"无记录覆盖"，匹配 `_loadPersisted` 对无法识别/缺席值的默认系统回退。

### `void setLocale(Locale? locale)` <a id="setlocale"></a>
- **种类：** `AppSettingsNotifier` 的方法。
- **来源：** `lib/shared/providers/app_settings.dart`（第 80 行）。
- **用途：** 更新内存语言区域覆盖并持久化。
- **输入：** `locale` — 新语言区域，或 `null` 跟随系统语言区域。
- **返回：** 无。
- **副作用：** 更新 `state`；调用 `DeviceStorage.setLocaleTag(...)`。
- **算法：** `state = state.copyWith(locale: locale, clearLocale: locale == null)`；清除时持久化 `null`，否则 `languageCode` 或 `languageCode_countryCode` 标签字符串。
- **用法：** 从设置页语言选择器调用。
- **备注：** `copyWith` 的 `clearLocale` 标志存在正因可空字段无法经单独 `??` 与"保持不变"区分——见下面 `copyWith`。

### `void setOnDeviceAiEnabled(bool enabled)` <a id="setondeviceaienabled"></a>
- **种类：** `AppSettingsNotifier` 的方法（v1.6.0）。
- **来源：** `lib/shared/providers/app_settings.dart`（第 98 行）。
- **用途：** 打开或关闭端侧 AI。
- **输入：** `enabled`。
- **返回：** 无。
- **副作用：** 更新 `state`；调用 `DeviceStorage.setOnDeviceAiEnabled(enabled)` 和 `OnDeviceAiService.instance.setEnabled(enabled)`，均不 await。
- **算法：** `state = state.copyWith(onDeviceAiEnabled: enabled)`，持久化，切换服务。
- **用法：** [`AiSettingsTiles`](../../features/ai/widgets/ai_settings_tiles.md) 中「使用端侧 AI」开关的 `onChanged: notifier.setOnDeviceAiEnabled`。
- **备注：** 默认关闭。关闭会取消正在运行的任何内容，之后洞察卡片什么都不渲染。该值仅限本设备（`storage_config.json` 从不同步）。

### `void setOnDeviceAiPreferFast(bool enabled)` <a id="setondeviceaipreferfast"></a>
- **种类：** `AppSettingsNotifier` 的方法（v1.6.0）。
- **来源：** `lib/shared/providers/app_settings.dart`（第 109 行）。
- **用途：** 在两种尺寸都提供时偏好更快的端侧模型。
- **输入：** `enabled`。
- **返回：** 无。
- **副作用：** 更新 `state`；调用 `DeviceStorage.setOnDeviceAiPreferFast(enabled)` 和 `OnDeviceAiService.instance.setPreferFast(enabled)`（开启时会重新探测状态），均不 await。
- **算法：** `state = state.copyWith(onDeviceAiPreferFast: enabled)`，持久化，告知服务。
- **用法：** [`AiSettingsTiles`](../../features/ai/widgets/ai_settings_tiles.md) 中「偏好更快的模型」一行的 `onChanged: notifier.setOnDeviceAiPreferFast`，仅在 Android 上两种模型尺寸都提供时显示。
- **备注：** 仅 Android；Apple 平台只有一个系统模型。

### `const AppSettings({this.themeMode = ThemeMode.system, this.locale, this.onDeviceAiEnabled = false, this.onDeviceAiPreferFast = false})` <a id="appsettings-new"></a>
- **种类：** `AppSettings` 的构造函数。
- **来源：** `lib/shared/providers/app_settings.dart`（第 132 行）。
- **用途：** 创建不可变设置快照。
- **输入：** `themeMode`（默认 `ThemeMode.system`）、`locale`（默认 `null`）、`onDeviceAiEnabled`（默认 `false`）、`onDeviceAiPreferFast`（默认 `false`）。
- **返回：** 新 `AppSettings`。
- **副作用：** 无。
- **算法：** 普通字段赋值。
- **用法：** 用作通知器默认状态并在每次更新经 `copyWith` 重建。
- **备注：** 无。

### `AppSettings copyWith({ThemeMode? themeMode, Locale? locale, bool? onDeviceAiEnabled, bool? onDeviceAiPreferFast, bool clearLocale = false})` <a id="copywith"></a>
- **种类：** `AppSettings` 的方法。
- **来源：** `lib/shared/providers/app_settings.dart`（第 144 行）。
- **用途：** 创建 `AppSettings` 值的修改副本。
- **输入：** `themeMode`、`locale`、`onDeviceAiEnabled`、`onDeviceAiPreferFast`（各为可选替换）、`clearLocale`（无论 `locale` 参数如何强制 `locale` 为 `null`）。
- **返回：** 新 `AppSettings`。
- **副作用：** 无。
- **算法：** 每个字段为 `参数 ?? this.字段`，唯独 `locale: clearLocale ? null : (locale ?? this.locale)`——`clearLocale` 优先于任何传入 `locale` 值。
- **用法：** 从 `setThemeMode`、`setLocale`、`setOnDeviceAiEnabled` 和 `setOnDeviceAiPreferFast` 调用。
- **备注：** `clearLocale` 标志正是让"显式把语言区域设为 null"在 `copyWith` 模式中可与"不碰语言区域"区分的东西，因为传 `locale: null` 否则与省略参数无法区分。

## 界面风格（自 1.7.0 起）

`AppSettings` 新增 `uiStyle`（`AppUiStyle`，默认 `AppUiStyle.expressive`），出现在构造函数、`copyWith` 和 `_loadPersisted` 中（后者把 `DeviceStorage.getUiStyle()`——`'material3'` 或 null——映射为枚举）。新方法 `AppSettingsNotifier.setUiStyle(AppUiStyle style)`（Tier B）更新 `state`，并经 `DeviceStorage.setUiStyle('material3' 或 null)` 持久化，因此只有非默认的 Material 3 风格会存储，即 `storage_config.json` 中的 `uiStyle: "material3"`。`MyDeviceApp.build` 把 `settings.uiStyle` 传给 `AppTheme.light`/`dark`，主题因此立即重建；`ShellScaffold` 监视 `appSettingsProvider.select((s) => s.uiStyle == AppUiStyle.expressive)`，Expressive 时构建 `_FloatingNavBar`。该设置是本地的，从不同步。
