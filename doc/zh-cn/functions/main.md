# lib/main.dart

应用入口点：运行组件树前初始化仅桌面启动服务（启动时启动、本地 API 服务器、系统托盘），并启动即发即忘后台任务（自动备份、汇率刷新、自动同步生命周期观察者）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`main`](#main) | 顶层函数 | A | 应用入口点：桌面启动接线，然后 `runApp`。 |

## 文档

### `void main() async` <a id="main"></a>
- **种类：** 顶层函数。
- **来源：** `lib/main.dart`（第 22 行）。
- **用途：** 执行仅桌面启动接线并启动 Flutter 应用。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 调用 `WidgetsFlutterBinding.ensureInitialized()`；Windows/macOS/Linux 上配置 `launch_at_startup` 并启动 `LocalApiServer` 和 `TrayService`；调用 `BackupService.runAutoBackupIfNeeded()`、`DeviceExchangeRateService.refreshIfNeeded()` 和 `AutoSyncService.instance.start()`；经 `runApp` 运行组件树。
- **算法：**
  1. 确保 Flutter 绑定初始化。
  2. 桌面平台（`!kIsWeb` 且 Windows/macOS/Linux）上读取 `PackageInfo` 并用应用名和解析可执行路径配置 `launch_at_startup`。
  3. 相同桌面平台上 `await LocalApiServer.start()`（API 服务器在设置中禁用时空操作——见 [shared/services/local_api_server.md](shared/services/local_api_server.md)）。
  4. 相同桌面平台上经 `TrayService.instance.init()` 初始化系统托盘。
  5. 即发即忘 `BackupService.runAutoBackupIfNeeded()` 和 `DeviceExchangeRateService.refreshIfNeeded()`（`runApp` 前都不 await）。
  6. 启动自动同步生命周期观察者 `AutoSyncService.instance.start()`。
  7. `runApp` 把 `MyDeviceApp` 包在 `ProviderScope` 和 `DevicePreview`（只在调试模式启用）中。
- **用法：** 进程启动时由 Flutter 引擎调用一次；应用代码任何地方不调用。
- **备注：** 三个仅桌面步骤刻意门控于相同平台检查（`!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)`），使移动构建完全跳过启动时启动、本地 API 服务器和托盘。
