# lib/shared/services/tray_service.dart

`TrayService` 是 [平台说明](../../../platform-notes.md) 描述的桌面系统托盘单例：显示/退出菜单、最小化到托盘、关闭到托盘，和经方法通道的 macOS Dock 图标可见性。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`TrayService._`](#trayservice-new) | 私有构造函数 | A | 支撑 `TrayService.instance` 单例。 |
| `minimizeToTray` | getter | B | 当前最小化到托盘偏好。 |
| `closeToTray` | getter | B | 当前关闭到托盘偏好。 |
| [`init`](#init) | 方法 | A | 从持久化设置初始化窗口/托盘管理器。 |
| [`_setupTray`](#setuptray) | 方法 | A | 设置托盘图标/工具提示并构建上下文菜单。 |
| [`_rebuildMenu`](#rebuildmenu) | 方法 | A | 重建本地化托盘上下文菜单。 |
| [`setMinimizeToTray`](#setminimizetotray) | 方法 | A | 更新并持久化最小化到托盘偏好。 |
| [`setCloseToTray`](#setclosetotray) | 方法 | A | 更新并持久化关闭到托盘偏好。 |
| [`updateLocale`](#updatelocale) | 方法 | A | 更新菜单标签使用的语言区域并重建菜单。 |
| `onTrayIconMouseDown` | 方法（`TrayListener`） | B | 托盘图标左键点击时显示窗口。 |
| `onTrayIconRightMouseDown` | 方法（`TrayListener`） | B | 弹出托盘上下文菜单。 |
| [`onTrayMenuItemClick`](#ontraymenuitemclick) | 方法（`TrayListener`） | A | 处理显示/退出菜单选择。 |
| [`onWindowClose`](#onwindowclose) | 方法（`WindowListener`） | A | 关闭时隐藏到托盘或销毁窗口。 |
| [`onWindowMinimize`](#onwindowminimize) | 方法（`WindowListener`） | A | 启用时最小化隐藏到托盘。 |
| [`_showWindow`](#showwindow) | 方法 | A | 恢复 Dock 可见性并显示/聚焦窗口。 |
| [`_setDockIconVisible`](#setdockiconvisible) | 静态方法 | A | 经方法通道切换 macOS Dock 图标可见性。 |

## 文档

### `TrayService._()` <a id="trayservice-new"></a>
- **种类：** `TrayService` 的私有未命名构造函数（带 `TrayListener, WindowListener`）。
- **来源：** `lib/shared/services/tray_service.dart`（第 17 行）。
- **用途：** 支撑模块级单例 `TrayService.instance`。
- **输入：** 无。
- **返回：** 新 `TrayService`。
- **副作用：** 无（状态稍后在 `init` 设置，不在构造函数）。
- **算法：** 空体；`static final TrayService instance = TrayService._()` 在类加载时急切构造单例。
- **用法：** 从不直接调用；经 `TrayService.instance` 访问。
- **备注：** 与 `AppFlavor._`/`AppTheme._`（纯仅静态持有者）不同，`TrayService` 混入 `TrayListener`/`WindowListener`，因此这里的私有构造函数也存在为使单例成为能注册为那些监听器的唯一实例。

### `Future<void> init()` <a id="init"></a>
- **种类：** `TrayService` 的方法。
- **来源：** `lib/shared/services/tray_service.dart`（第 45 行）。
- **用途：** 窗口管理器、托盘图标和持久化最小化/关闭到托盘偏好的一次性初始化。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `DeviceStorage.readConfig()` 读取 `storage_config.json`；初始化 `window_manager`/`tray_manager`；把 `this` 注册为 `WindowListener` 和 `TrayListener` 两者。
- **算法：** 已初始化或非 Windows/macOS/Linux 时空操作。从配置读 `minimizeToTray`/`closeToTray`（默认 `false`）；`windowManager.ensureInitialized()`、添加自己为窗口监听器、`setPreventClose(_closeToTray)`；`_setupTray()`；添加自己为托盘监听器；标记已初始化。
- **用法：** 桌面平台从 `main()` 调用一次（见 [main.md](../../main.md)）。
- **备注：** 由 `_initialized` 守卫，第二次调用空操作。

### `Future<void> _setupTray()` <a id="setuptray"></a>
- **种类：** `TrayService` 的方法。
- **来源：** `lib/shared/services/tray_service.dart`（第 68 行）。
- **用途：** 设置托盘图标和工具提示，然后构建初始上下文菜单。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** `trayManager.setIcon`/`setToolTip`；调用 `_rebuildMenu`。
- **算法：** Windows 挑 `.ico`，否则 `.png`；工具提示设为 `'MyDevice!!!!!'`；`_rebuildMenu()`。
- **用法：** 从 `init` 调用一次。
- **备注：** 无。

### `Future<void> _rebuildMenu()` <a id="rebuildmenu"></a>
- **种类：** `TrayService` 的方法。
- **来源：** `lib/shared/services/tray_service.dart`（第 82 行）。
- **用途：** 为当前 `_locale` 用本地化"显示"/"退出"标签（重新）构建托盘上下文菜单。
- **输入：** 无（读取 `_locale`）。
- **返回：** `Future<void>`。
- **副作用：** `trayManager.setContextMenu`。
- **算法：** `lookupAppLocalizations(_locale)`，构建带本地化标签的两项菜单（`show`、分隔符、`quit`）并经 `trayManager.setContextMenu` 安装。
- **用法：** 从 `_setupTray` 和已初始化时语言区域变化的 `updateLocale` 调用。
- **备注：** 直接 `lookupAppLocalizations`（非 `AppLocalizations.of(context)`），因为托盘无 `BuildContext`。

### `Future<void> setMinimizeToTray(bool value)` <a id="setminimizetotray"></a>
- **种类：** `TrayService` 的方法。
- **来源：** `lib/shared/services/tray_service.dart`（第 99 行）。
- **用途：** 更新并持久化最小化到托盘偏好。
- **输入：** `value`。
- **返回：** `Future<void>`。
- **副作用：** 更新 `_minimizeToTray`；读/写 `storage_config.json`。
- **算法：** 设字段；读配置、设 `config['minimizeToTray'] = value`、写回。
- **用法：** 从设置页托盘行为切换调用。
- **备注：** 对完整配置映射读-改-写，与 `setCloseToTray` 相同模式。

### `Future<void> setCloseToTray(bool value)` <a id="setclosetotray"></a>
- **种类：** `TrayService` 的方法。
- **来源：** `lib/shared/services/tray_service.dart`（第 111 行）。
- **用途：** 更新并持久化关闭到托盘偏好，并立即应用到窗口管理器。
- **输入：** `value`。
- **返回：** `Future<void>`。
- **副作用：** 更新 `_closeToTray`；读/写 `storage_config.json`；`windowManager.setPreventClose(value)`。
- **算法：** 设字段；经读-改-写持久化；立即调用 `windowManager.setPreventClose(value)`，使新行为无需重启生效。
- **用法：** 从设置页托盘行为切换调用。
- **备注：** 与 `setMinimizeToTray` 不同，这个除持久化偏好外也有立即运行时效果（`setPreventClose`）。

### `Future<void> updateLocale(Locale locale)` <a id="updatelocale"></a>
- **种类：** `TrayService` 的方法。
- **来源：** `lib/shared/services/tray_service.dart`（第 124 行）。
- **用途：** 更新托盘菜单标签使用的语言区域，已初始化时重建菜单。
- **输入：** `locale`。
- **返回：** `Future<void>`。
- **副作用：** 更新 `_locale`；条件调用 `_rebuildMenu`。
- **算法：** 设 `_locale`；`if (_initialized) await _rebuildMenu()`。
- **用法：** 应用语言区域变化时（如从 `AppSettingsNotifier.setLocale`）调用，使托盘菜单语言与 UI 其余部分保持同步。
- **备注：** 托盘尚未初始化时（安全地）空操作。

### `void onTrayMenuItemClick(MenuItem menuItem)` <a id="ontraymenuitemclick"></a>
- **种类：** `TrayService` 的方法（`TrayListener` 覆盖）。
- **来源：** `lib/shared/services/tray_service.dart`（第 157 行）。
- **用途：** 处理托盘上下文菜单点击。
- **输入：** `menuItem`。
- **返回：** 无。
- **副作用：** `'show'` 调用 `_showWindow()`；`'quit'` 禁用 prevent-close 并调用 `windowManager.close()`。
- **算法：** `switch (menuItem.key)`：`'show'` → `_showWindow()`；`'quit'` → `windowManager.setPreventClose(false)` 然后 `windowManager.close()`。
- **用法：** 用户点击菜单项时由 `tray_manager` 调用。
- **备注：** 退出显式先禁用 prevent-close，使配置 `closeToTray` 的窗口实际关闭而非再次隐藏。

### `void onWindowClose()` <a id="onwindowclose"></a>
- **种类：** `TrayService` 的方法（`WindowListener` 覆盖）。
- **来源：** `lib/shared/services/tray_service.dart`（第 177 行）。
- **用途：** 实现关闭到托盘行为：启用时隐藏而非退出。
- **输入：** 无（读取 `_closeToTray`）。
- **返回：** 无。
- **副作用：** `windowManager.hide()` + `_setDockIconVisible(false)`，或 `windowManager.destroy()`。
- **算法：** `_closeToTray` 时隐藏窗口并隐藏 macOS Dock 图标；否则销毁窗口（真实退出）。
- **用法：** 按下窗口关闭按钮时由 `window_manager` 调用（只在 `setPreventClose(true)` 生效时可达，即 `closeToTray` 开启）。
- **备注：** 无。

### `void onWindowMinimize()` <a id="onwindowminimize"></a>
- **种类：** `TrayService` 的方法（`WindowListener` 覆盖）。
- **来源：** `lib/shared/services/tray_service.dart`（第 192 行）。
- **用途：** 实现最小化到托盘：启用时隐藏窗口（而非正常操作系统最小化）。
- **输入：** 无（读取 `_minimizeToTray`）。
- **返回：** 无。
- **副作用：** 启用时 `windowManager.hide()` + `_setDockIconVisible(false)`。
- **算法：** `if (_minimizeToTray) { hide(); _setDockIconVisible(false); }`——否则正常操作系统最小化不受打扰进行。
- **用法：** 最小化事件时由 `window_manager` 调用。
- **备注：** 无。

### `void _showWindow()` <a id="showwindow"></a>
- **种类：** `TrayService` 的方法。
- **来源：** `lib/shared/services/tray_service.dart`（第 206 行）。
- **用途：** 从托盘隐藏状态恢复窗口：显示 Dock 图标（macOS）、显示窗口并聚焦。
- **输入：** 无。
- **返回：** `void`。
- **副作用：** `_setDockIconVisible(true)`；`windowManager.show()`/`.focus()`。
- **算法：** 三个顺序调用，自己无分支（平台检查住在 `_setDockIconVisible` 内）。
- **用法：** 从 `onTrayIconMouseDown`（左键点击）和 `onTrayMenuItemClick` 的 `'show'` case 调用。
- **备注：** 无。

### `static void _setDockIconVisible(bool visible)` <a id="setdockiconvisible"></a>
- **种类：** `TrayService` 的静态方法。
- **来源：** `lib/shared/services/tray_service.dart`（第 217 行）。
- **用途：** 经原生方法通道切换 macOS Dock 图标可见性；其他平台空操作。
- **输入：** `visible`。
- **返回：** `void`。
- **副作用：** 调用 `com.yuanzhe.my_device/dock` 方法通道的 `setDockIconVisible` 方法（仅 macOS）。
- **算法：** `!Platform.isMacOS` 提前返回；否则 `_dockChannel.invokeMethod('setDockIconVisible', {'visible': visible})`。
- **用法：** 从 `onWindowClose`、`onWindowMinimize` 和 `_showWindow` 调用。
- **备注：** Dart 侧不 await 方法通道调用结果——即发即忘。
