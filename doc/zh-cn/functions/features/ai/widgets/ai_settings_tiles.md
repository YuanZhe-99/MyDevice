# lib/features/ai/widgets/ai_settings_tiles.dart

共享实现现位于 MyApps-AI v0.4.1，本页描述应用适配器。

`AiSettingsTiles` 于 1.6.0 新增（移植自 MyDay!!!!!，MyDay 取自 MyAnime!!!!!），构建「端侧 AI」设置分区的各行：「使用端侧 AI」开关、
带操作的模型状态行、「使用更快的模型」（Android，仅当两种尺寸都有提供时）、关于模型归属的说明、一个折叠的
「技术详情」，以及「清除已生成的洞察」。在 Windows、Linux 和 Web 上它什么也不渲染；`settings_page.dart` 在这些
平台上根本不构建它，而是显示一行 `aiNotSupportedHere` 说明。与 MyAnime 不同，这个开关没有功能门槛：总能打开或
关闭。见 [`../services/on_device_ai_service.md`](../services/on_device_ai_service.md)、
[`../services/insight_service.md`](../services/insight_service.md) 和
[`../../../../on-device-ai.md`](../../../../on-device-ai.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AiSettingsTiles.new` | 构造函数（`AiSettingsTiles`） | B | 创建 AI 设置行；除 `key` 外不接受参数。 |
| `AiSettingsTiles.createState` | 方法（`AiSettingsTiles`） | B | 创建状态对象。 |
| [`_AiSettingsTilesState.initState`](#_aisettingstilesstate-initstate) | 方法（`_AiSettingsTilesState`） | A | 打开设置时刷新模型状态。 |
| `_AiSettingsTilesState._localeTag` | 方法（`_AiSettingsTilesState`） | B | 以 `zh_TW` 这样的标签返回应用当前的语言区域。 |
| `_AiSettingsTilesState._statusLabel` | 方法（`_AiSettingsTilesState`） | B | 用 `aiStatus*` 字符串表述模型状态。 |
| [`_AiSettingsTilesState.build`](#_aisettingstilesstate-build) | 方法（`_AiSettingsTilesState`） | A | 构建这些行。 |

`grep -c 'Purpose:' lib/features/ai/widgets/ai_settings_tiles.dart` 报告 6，与上面六行一致。`AiSettingsTiles`
的类级注释没有 `/// Purpose:`，不作为行。

## 文档

### `void initState()` <a id="_aisettingstilesstate-initstate"></a>
- **种类：** `_AiSettingsTilesState` 的方法（Flutter 生命周期覆写）
- **来源：** `lib/features/ai/widgets/ai_settings_tiles.dart`（第 45 行）
- **用途：** 打开设置时刷新模型状态。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 第一帧之后进行一次强制状态探测——仅在开关开启时。
- **算法：** 在帧后回调中，若仍 mounted，读取 `onDeviceAiServiceProvider`；若 `enabled`，调用
  `refreshStatus(localeTag: _localeTag())`。
- **用法：** 这些行首次插入时由 Flutter 调用。
- **备注：** 需要帧后回调，因为 `_localeTag` 读取 `Localizations`。

### `Widget build(BuildContext context)` <a id="_aisettingstilesstate-build"></a>
- **种类：** `_AiSettingsTilesState` 的方法
- **来源：** `lib/features/ai/widgets/ai_settings_tiles.dart`（第 89 行）
- **用途：** 构建这些行。
- **输入：** `context`。
- **返回：** 一个由各行组成的 `Column`；`platformMayHaveOnDeviceModel` 为 false 时返回 `SizedBox.shrink()`。
- **副作用：** 构建时无；各行被点击时调用 `OnDeviceAiService`、`AppSettingsNotifier` 和 `AiInsightStore`。
- **算法：** 监听 `appSettingsProvider` 和 `onDeviceAiServiceProvider`；在监听该服务的 `ListenableBuilder` 内：
  1. 开关，绑定到 `AppSettings.onDeviceAiEnabled` 和 `setOnDeviceAiEnabled`，始终可用，副标题为
     `aiUseOnDeviceDesc`。
  2. 仅在开启时：状态行。`notEnabled` 追加「开启 Apple Intelligence」一行；下载进行中时显示已下载的 MB。
     它的操作在 Android 上的 `downloadable` 时为「下载」（下载中禁用），在 `unavailable`、`unreachable`、
     `notEnabled`、`unknown` 和 `downloading` 时为「重新检查」。
  3. 「使用更快的模型」（`setOnDeviceAiPreferFast`），仅在 Android 上且 `report.hasSizeChoice` 时显示。
  4. 说明：在 Android 上说明谁下载模型、为何不能在这里删除；在 Apple 上说明由系统管理。
  5. 一个折叠的「技术详情」，内容为可选中的文本：状态名和代码、detail、变体、已提供和被拒绝的变体、模型名、
     token 上限、AICore 版本（或 Android 上的「未安装」）、SDK、设备、兼容性、系统版本和语言区域支持，各项只在
     已知时显示。
  6. 「清除已生成的洞察」：点击时 await `ref.read(aiInsightStoreProvider).clearAll()`（删除 `ai_insights.json`
     并重置每张洞察卡片），然后通过在 await 之前取得的 `ScaffoldMessenger` 显示 `aiClearInsightsDone` 提示条。
- **用法：** `lib/features/settings/views/settings_page.dart` 的「端侧 AI」分区
  （`if (platformMayHaveOnDeviceModel) const AiSettingsTiles() else ListTile(...aiNotSupportedHere)`；
  见 [`../../settings/views/settings_page.md`](../../settings/views/settings_page.md)）；
  `test/ai_settings_tiles_ui_test.dart`（用 `debugDefaultTargetPlatformOverride` 按平台测试，包括
  "Clear generated insights empties the insight cache"）。
- **备注：** 开关之后的每一行，包括「清除已生成的洞察」，都只在开关开启时显示。`unsupported` 表述为需要支持
  Apple Intelligence 的 iOS 26 或 macOS 26；这正是 Apple 插件在 26 之前的 iOS 和 macOS 上报告的状态。


当前接入 MyApps-AI v0.5.2，显式注入平台后端，使用应用所属来源路由与统一设置骨架。WebDAV 入口在任何网络请求前要求设备本地提醒确认；具体见同步概念文档。
