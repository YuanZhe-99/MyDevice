# 架构

本页覆盖 MyDevice!!!!! 的应用壳、导航、状态管理、主题、本地化和整体仓库布局。数据级细节见 [数据格式](data-formats.md)；同步引擎见 [WebDAV 同步](sync.md)。

## 入口点：`lib/main.dart`

`main()` 在 `runApp()` 前执行启动工作：

1. `WidgetsFlutterBinding.ensureInitialized()`。
2. 桌面（`Platform.isWindows || Platform.isMacOS || Platform.isLinux`，Web 上绝不）：用解析包名/可执行路径设置 `launch_at_startup`。
3. 相同桌面平台：启动本地 API 服务器（`LocalApiServer.start()`）。
4. 相同桌面平台：初始化系统托盘（`TrayService.instance.init()`）。
5. 触发 `BackupService.runAutoBackupIfNeeded()`（即发即忘，每日一次自动备份）。
6. 触发 `DeviceExchangeRateService.refreshIfNeeded()` 自动更新汇率。
7. 启动 `AutoSyncService.instance.start()`，驱动自动同步触发器的生命周期观察者（见 [WebDAV 同步](sync.md)）。
8. 调用 `runApp()`，把 `MyDeviceApp` 包在 `DevicePreview`（仅调试构建启用）和 Riverpod `ProviderScope` 中。

## 应用壳：`lib/app/`

- **`app.dart`** — `MyDeviceApp`，监视 `appSettingsProvider` 并构建 `MaterialApp.router` 的 `ConsumerWidget`。它把主题模式、语言区域、支持语言区域和 `routerConfig: appRouter` 接在一起。应用标题字面为 `'MyDevice!!!!!'`。
- **`router.dart`** — `appRouter` 是 `initialLocation: '/devices'` 的 `GoRouter`，带包裹 `ShellScaffold` 的单个 `ShellRoute`。五个标签路由住在那个壳内，在窄于 600 逻辑像素的窗口上由底部 `NavigationBar` 到达，更宽的窗口上由侧边 `NavigationRail` 到达——这是 `lib/shared/utils/adaptive_layout.dart` 里 `useNavigationRail` 的仅宽度决策（见[自适应布局](adaptive-layout.md)）。其他每一页都推到壳之上的根导航器：

  | 路径 | 页面 |
  | --- | --- |
  | `/devices` | `DeviceListPage` |
  | `/services` | `ServiceListPage` |
  | `/network` | `NetworkListPage` |
  | `/datasets` | `DataSetListPage` |
  | `/settings` | `SettingsPage` |

- **`theme.dart`** — `AppTheme.light` / `AppTheme.dark` 用 `flex_color_scheme` 的 `FlexThemeData` 构建，两者都用 `FlexScheme.blue`、`FlexSurfaceMode.levelSurfacesLowScaffold`、Material 3 和底部导航栏的 `NavigationDestinationLabelBehavior.onlyShowSelected`。浅色用 `blendLevel: 7` / `blendOnLevel: 10`；深色用 `blendLevel: 13` / `blendOnLevel: 20`。
- **`flavor.dart`** — `AppFlavor` 读取编译期 `FLAVOR` dart-define（`String.fromEnvironment('FLAVOR', defaultValue: 'full')`）。`AppFlavor.isStore` 只在 define 恰好是 `'store'` 时为 true；`AppFlavor.isFull` 是其否定。这如何门控在线搜索见 [在线搜索与预设](features/online-search-and-presets.md)。

## 状态管理

状态管理通篇用 `flutter_riverpod`（根部 `ProviderScope`、页面 `ConsumerWidget`/`ConsumerStatefulWidget`、`lib/shared/providers/app_settings.dart` 中 `appSettingsProvider` 等提供者）。新代码不应引入 `Provider` 或 `Bloc`。

## 本地化（l10n）

应用支持四种语言：英语、日语、简体中文和繁体中文，由 `lib/l10n/` 下 ARB 文件确认：

- `app_en.arb`（模板）
- `app_ja.arb`
- `app_zh.arb`（简体）
- `app_zh_TW.arb`（繁体）

生成的本地化类（`AppLocalizations` 和逐语言区域子类）与它们在 `lib/l10n/` 下并列。编辑模板 ARB 后用 `flutter gen-l10n` 重新生成。

## 仓库结构

```text
lib/
  main.dart
  app/
    app.dart
    flavor.dart
    router.dart
    theme.dart
  features/
    devices/
      models/device.dart
      services/chip_search_service.dart
      services/device_search_service.dart
      services/device_storage.dart
      services/exchange_rate_service.dart
      services/preset_service.dart
      views/
      widgets/device_category_icon.dart
    network/
      models/network.dart
      services/network_storage.dart
      views/
    datasets/
      models/dataset.dart
      services/dataset_storage.dart
      views/
    services/
      models/service.dart
      services/service_storage.dart
      services/service_template_service.dart
      views/
    settings/views/
  shared/
    providers/app_settings.dart
    services/
      auto_sync_service.dart
      backup_service.dart
      image_service.dart
      import_export_service.dart
      local_api_server.dart
      sync_merge.dart
      sync_progress.dart
      sync_wake_lock.dart
      tray_service.dart
      webdav_service.dart
    utils/json_preservation.dart
    views/device_map_page.dart
    views/webdav_config_page.dart
    widgets/
  l10n/
```

（改编自 `AGENTS.md`；`lib/shared/widgets/map_picker_page.dart` 和 `lib/features/devices/widgets/device_avatar.dart` 也住在那些目录下——见 [地图](features/map.md) 和 [设备](features/devices.md)。）

## 共享包（`myapps_data`）

WebDAV 同步引擎、备份引擎、ZIP 传输引擎和自动同步调度器**不在此仓库**。它们住在共享 `myapps_data` 包，作为 git 子模块嵌入 `packages/myapps_data` 并作为 pub 路径依赖消费。MyAnime、MyDay 和 MyDevice 都用它，这正是让它们的线格式、备份格式和锁语义保持互操作的东西。

- **留在这里的东西：** 所有模型、逐功能存储枢纽、逐模块合并包装、`mergeAssignments`、Markdown 导出和每个页面。
- **移走的东西：** 传输、锁生命周期、合并管线、`.sync_base` 快照、图像同步、备份捆绑和 blob 存储、ZIP 允许列表和同步调度。
- **接缝：** [`functions/app/data_modules.md`](functions/app/data_modules.md) 声明 `DeviceStorage` 上的 `StorageAdapter` 加每个数据文件一个 `DataModule`。它是数据文件名和备份模块键的单一真相源。
- **门面：** `WebDAVService`、`BackupService`、`ImportExportService` 和 `AutoSyncService` 保留先前公共 API 并委托给包。其形态刻意冻结，使调用点和测试继续工作；行为变更属于包。
- **MyDevice 特有旋钮：** 备份引擎以 `syntheticImagesModule: true` 构建，这正是让 `images` 在这里成为可选恢复模块而其他两个应用没有的东西。

`.gitmodules` 用相对 URL `../MyApps-DATA.git`，因此它对照克隆跟踪的任何远程解析——Gitea 克隆从 Gitea 拉取、GitHub 克隆从 GitHub 拉取，且绝不提交主机名。全新克隆需要 `git clone --recurse-submodules` 或 `git submodule update --init`。

## 核心架构规则

- 导航用带上面列出的五个标签 `ShellRoute` 的 `go_router`。
- 视觉系统经 `flex_color_scheme` 用 Material 3。
- 每个宽度或高度决策——布局能否分栏、导航放在哪里、能容纳多少列、对话框能多高——都经过 `lib/shared/utils/adaptive_layout.dart`。组件文件里把尺寸和数字比较就是 bug。见[自适应布局](adaptive-layout.md)。
- 文件 IO 经 `DeviceStorage.getAppDir()`，使用户配置的自定义存储路径（`storage_config.json`）总是被尊重。
- JSON 输出用 `JsonEncoder.withIndent('  ')` 美化打印。
- 可选 null/空字段经条件映射条目从 JSON 省略（如 `if (notes != null) 'notes': notes`），不写显式 `null`。
- 每个模型的 `modifiedAt` 写为 `DateTime.now().toUtc()`。本地时间 `modifiedAt` 值破坏跨时区同步冲突检测；本地时间写的旧数据仍解析，但新写必须 UTC。见 [数据格式](data-formats.md)。
- 未知/向前兼容 JSON 字段经 `extraJson` 模式（`lib/shared/utils/json_preservation.dart`）保留，使旧应用构建绝不静默丢弃新构建写的字段。见 [数据格式 — extraJson 未知字段保留](data-formats.md#extrajson-unknown-field-preservation)。

## 下一步去哪里

- [数据格式](data-formats.md) 了解每个模型精确字段和持久化数据清单。
- [WebDAV 同步](sync.md) 了解记录如何跨设备合并。
- [备份与恢复](backup-restore.md) 了解本地备份/恢复和 ZIP/Markdown 导出。
- [平台说明](platform-notes.md) 了解 Windows/macOS/iOS/Android 特有行为和桌面 API/托盘/启动集成。
