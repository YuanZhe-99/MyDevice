# 平台说明

Windows、macOS、iOS 和 Android 的平台特定注意，加仅桌面本地 API 服务器、系统托盘和启动时启动集成。跨平台应用壳见 [架构](architecture.md)。

## Windows

- Inno Setup 安装器定义在 `installer.iss`；输出到 `build/installer/`。
- 安装器创建开始菜单快捷方式——不要在其他地方程序化创建快捷方式。
- 应用图标：`windows/runner/resources/app_icon.ico`。
- MSIX 配置住在 `pubspec.yaml` 的 `msix_config` 下，带 `internetClient`。
- CI 的 Windows x64 和 ARM64 作业设 `CL=/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`，作为仍触及弃用 WinRT `<experimental/coroutine>` 页头依赖链的临时 VS/MSVC 18 兼容变通。

## macOS

- 应用名是 `macos/Runner/Configs/AppInfo.xcconfig` 中的 `MyDevice!!!!!`。
- 部署目标是 `13.0`，为 **LaunchAtLogin-Modern** 所需，经 `project.pbxproj` 中 Swift Package Manager 添加。
- `MainFlutterWindow.swift` 暴露用于启动启用的 `launch_at_startup` 方法通道。
- `AppDelegate.swift` 在最后一个窗口关闭时保持应用存活，并暴露 **dock 可见性**方法通道（`com.yuanzhe.my_device/dock`——在 `tray_service.dart` 方法 `setDockIconVisible` 确认）。
- `DebugProfile.entitlements` 和 `Release.entitlements` 都必须含 `com.apple.security.network.client` 和 `com.apple.security.network.server`；没有它们，沙盒网络请求和本地 API 服务器会坏。
- 应用图标用 `flutter_launcher_icons` 生成；保持 `flutter_launcher_icons.yaml` 中 macOS 小节同步。

## iOS

- `CFBundleDisplayName` 是 `Info.plist` 中的 `MyDevice!!!!!`。
- HTTPS 网络访问无需特殊权利。
- iOS `AppIcon` 资产从 `assets/icon/app_icon_ios.png`、`assets/icon/app_icon_ios_dark.png` 和 `assets/icon/app_icon_ios_tinted.png` 经 `dart run tool/generate_ios_icons.dart` 生成，然后 `dart run flutter_launcher_icons`，然后 `dart run tool/validate_ios_icons.dart --clean`。
- 默认图标源用不透明白背景；深色和着色源用透明背景。着色源必须保持灰度，使 iOS 能应用用户所选着色。
- 不要添加原生 Icon Composer 或 Liquid Glass Clear 特定资产；依赖默认/深色/着色回退集合。
- App Store IPA 需要签名/预置且不由 CI 构建。

## Android

- `android/app/build.gradle.kts` 用 `import java.util.Properties`。
- Kotlin 迁移状态（应用侧已迁移）：Gradle 包装 `9.3.1`、AGP `9.1.1`、无应用级 `kotlin-android` 插件。Kotlin `jvmTarget` 经顶层 `kotlin { compilerOptions { jvmTarget = JvmTarget.JVM_17 } }` 块设置（非需要真实 JDK 17 安装的 `jvmToolchain`；非已移除的 `kotlinOptions`）。`android/gradle.properties` 保持 `android.builtInKotlin=false` 和 `android.newDsl=false`，因为几个插件仍直接应用 KGP——翻转 `builtInKotlin=true` 破坏每个 KGP 应用插件。`org.jetbrains.kotlin.android` 保持声明（`apply false`）在 `settings.gradle.kts` 供那些插件解析。
- `file_picker` **精确钉在 `10.3.7`**（无脱字符）：它是既自己应用 KGP（`builtInKotlin=false` 时需要）又对照 `flutter.compileSdkVersion` 编译（AGP 9 AAR 元数据检查所需）的最后发布。`10.3.9+`/`11.x` 需要 AGP 内置 Kotlin；`10.3.2` 和更早钉 `compileSdk 34` 并失败元数据检查。
- Keystore 属性用可空转换（`as String?`）。
- 核心库脱糖**未**启用——MyDevice 不调度通知且无需要它的依赖。
- 本地经 `key.properties` 签名可选；CI 用 GitHub Secrets。
- 拓扑 PNG 导出 iOS 用 `share_plus`、Android 用 `com.yuanzhe.my_device/share` 方法通道加 `FileProvider`、桌面用带复制/保存操作的预览（见 [服务与拓扑](features/services-topology.md)）。

## 桌面本地 API 服务器

`lib/shared/services/local_api_server.dart`（`LocalApiServer`）只在桌面平台（Windows/macOS/Linux，从 `main()` 启动——见 [架构 — 入口点](architecture.md#entry-point-libmaindart)）运行基于 Shelf 的 HTTP 服务器。

- **默认端口：** `7789`（确认：`static int _port = 7789;`，经 `storage_config.json` 的 `apiPort` 可覆盖）。
- **端点：**
  - `GET /ping`
  - `GET /device/list(?category=)`
  - `GET /device/search?q=`
  - `POST /device/add`
  - `GET /device/stats`
  - `GET /network/list`
  - `GET /network/search?q=`
  - `GET /dataset/list`
  - `GET /dataset/search?q=`
  - `GET /service/list(?deviceId=&kind=&state=)`
  - `GET /service/search?q=`
  - `GET /service/routes`
  - `GET /service/stats`
- 设备 API JSON 含当前生命周期、位置、图像、屏幕分辨率、购买/出售价格、循环成本和计算财务摘要字段。`POST /device/add` 在最小 name/category 流程之上接受这些可选字段。
- 网络、数据集和服务端点**只读**——它们暴露手动保存清单数据（富化链接设备/网络名），且必须不执行发现、扫描或操作，与 [服务](features/services-topology.md) 模块仅手动清单设计一致。
- **CORS 宽松**（`Access-Control-Allow-Origin: *`，源码确认）。配置凭据时，**每个请求都要求 Basic Auth，含回环**——否则宽松 CORS 会让任何本地网页经浏览器代理读取 API。未配置凭据时允许回环请求，服务器拒绝不安全绑定到非 localhost 地址地启动。

## `tray_service.dart`

`TrayService` 管理系统托盘：显示/隐藏、退出、最小化到托盘、关闭到托盘（`windowManager.setPreventClose(_closeToTray)`）和 macOS Dock 图标可见性方法通道 `com.yuanzhe.my_device/dock`。托盘偏好（`minimizeToTray`、`closeToTray`）持久化在 `storage_config.json`。

## `launch_at_startup`

桌面自动启动由 `launch_at_startup` 包处理，在 `main()` 中用平台解析应用名和可执行路径设置。macOS 特别用 **LaunchAtLogin-Modern**（见上面 macOS 小节）而非手工登录项。
