# Platform Notes

Platform-specific caveats for Windows, macOS, iOS, and Android, plus the desktop-only
local API server, system tray, and launch-at-startup integration. See
[Architecture](architecture.md) for the cross-platform app shell.

## Windows

- The Inno Setup installer is defined in `installer.iss`; output goes to
  `build/installer/`.
- The installer creates Start Menu shortcuts — do not create shortcuts programmatically
  elsewhere.
- App icon: `windows/runner/resources/app_icon.ico`.
- MSIX configuration lives in `pubspec.yaml` under `msix_config` with `internetClient`.
- CI's Windows x64 and ARM64 jobs set
  `CL=/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` as a temporary VS/MSVC 18
  compatibility workaround for dependency chains that still reach deprecated WinRT
  `<experimental/coroutine>` headers.
- No on-device AI: the insight cards never render and Settings shows one "not available on this
  platform" line (see [On-device AI](on-device-ai.md)).

## macOS

- App name is `MyDevice!!!!!` in `macos/Runner/Configs/AppInfo.xcconfig`.
- Deployment target is `13.0`, required for **LaunchAtLogin-Modern**, added via Swift
  Package Manager in `project.pbxproj`.
- `MainFlutterWindow.swift` exposes a `launch_at_startup` method channel for startup
  enablement.
- `AppDelegate.swift` keeps the app alive when the last window closes and exposes the
  **dock visibility** method channel (`com.yuanzhe.my_device/dock` — confirmed in
  `tray_service.dart`, method `setDockIconVisible`).
- Both `DebugProfile.entitlements` and `Release.entitlements` must include
  `com.apple.security.network.client` and `com.apple.security.network.server`; without
  them, sandboxed network requests and the local API server break.
- App icons are generated with `flutter_launcher_icons`; keep the macOS section in
  `flutter_launcher_icons.yaml` in sync.
- On-device AI (v1.6.0) uses the local `packages/on_device_ai_apple` plugin, shared with iOS; the
  FoundationModels framework is weak-linked and CI checks it with `tool/check_weak_link.sh`. No
  entitlement is added. See [On-device AI](on-device-ai.md#apple-the-foundation-models-framework).

## iOS

- `CFBundleDisplayName` is `MyDevice!!!!!` in `Info.plist`.
- HTTPS network access needs no special entitlement.
- iOS `AppIcon` assets are generated from `assets/icon/app_icon_ios.png`,
  `assets/icon/app_icon_ios_dark.png`, and `assets/icon/app_icon_ios_tinted.png` via
  `dart run tool/generate_ios_icons.dart`, then `dart run flutter_launcher_icons`, then
  `dart run tool/validate_ios_icons.dart --clean`.
- The default icon source uses an opaque white background; dark and tinted sources use
  transparent backgrounds. The tinted source must stay grayscale so iOS can apply the
  user's selected tint.
- Do not add native Icon Composer or Liquid Glass Clear-specific assets; rely on the
  default/dark/tinted fallback set.
- App Store IPA requires signing/provisioning and is not built by CI.
- On-device AI (v1.6.0) needs iOS 26 with Apple Intelligence; the deployment target stays 13.0
  because FoundationModels is weak-linked (checked in CI). See
  [On-device AI](on-device-ai.md#weak-linking).

## Android

- `android/app/build.gradle.kts` uses `import java.util.Properties`.
- Kotlin migration state (app side migrated): Gradle wrapper `9.3.1`, AGP `9.1.1`, no
  app-level `kotlin-android` plugin. The Kotlin `jvmTarget` is set via a top-level
  `kotlin { compilerOptions { jvmTarget = JvmTarget.JVM_17 } }` block (not
  `jvmToolchain`, which needs a real JDK 17 install; not `kotlinOptions`, which is
  removed). `android/gradle.properties` keeps `android.builtInKotlin=false` and
  `android.newDsl=false` because several plugins still apply KGP directly — flipping
  `builtInKotlin=true` breaks every KGP-applying plugin. `org.jetbrains.kotlin.android`
  stays declared (`apply false`) in `settings.gradle.kts` for those plugins to resolve.
- `file_picker` is **pinned to exactly `10.3.7`** (no caret): it's the last release that
  both applies KGP itself (required while `builtInKotlin=false`) and compiles against
  `flutter.compileSdkVersion` (required by AGP 9 AAR metadata checks). `10.3.9+`/`11.x`
  need AGP built-in Kotlin; `10.3.2` and older pin `compileSdk 34` and fail the metadata
  check.
- Keystore properties use nullable casts (`as String?`).
- Core library desugaring is **not** enabled — MyDevice schedules no notifications and
  has no dependency that requires it (ML Kit GenAI does not).
- `minSdk` is **26** since 1.6.0 (was `flutter.minSdkVersion`, 24): the on-device AI library
  `com.google.mlkit:genai-prompt:1.0.0-beta4` requires it, so Android 7.0 and 7.1 are dropped.
  `GenAiChannel.kt` sits next to `MainActivity.kt`, `proguard-rules.pro` keeps ML Kit and
  kotlinx.coroutines for R8 in release builds, and the manifest `<queries>` lists
  `com.google.android.aicore`. See [On-device AI](on-device-ai.md#android-ml-kit-genai-over-aicore).
- Signing is optional locally via `key.properties`; CI uses GitHub Secrets.
- Topology PNG export uses `share_plus` on iOS, a
  `com.yuanzhe.my_device/share` Android method channel plus `FileProvider`, and a
  desktop preview with copy/save actions (see
  [Services and Topology](features/services-topology.md)).

## Desktop local API server

`lib/shared/services/local_api_server.dart` (`LocalApiServer`) runs a Shelf-based HTTP
server on desktop platforms only (Windows/macOS/Linux, started from `main()` — see
[Architecture](architecture.md#entry-point-libmaindart)).

- **Default port:** `7789` (confirmed: `static int _port = 7789;`, overridable via
  `storage_config.json`'s `apiPort`).
- **Endpoints:**
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
- Device API JSON includes current lifecycle, location, image, screen resolution,
  purchase/sold price, recurring cost, and computed finance summary fields. `POST
  /device/add` accepts these optional fields on top of the minimal name/category flow.
- Network, dataset, and service endpoints are **read-only** — they expose manually
  saved inventory data (enriched with linked device/network names) and must not
  perform discovery, scanning, or operations, in keeping with the
  [Services](features/services-topology.md) module's manual-inventory-only design.
- **CORS is permissive** (`Access-Control-Allow-Origin: *`, confirmed in source). When
  credentials are configured, **Basic Auth is required for every request, including
  loopback** — permissive CORS would otherwise let any local web page read the API by
  proxying through the browser. Without credentials configured, loopback requests are
  allowed and the server refuses to start unsafely bound to a non-localhost address.

## `tray_service.dart`

`TrayService` manages the system tray: Show/Hide, Quit, minimize-to-tray, close-to-tray
(`windowManager.setPreventClose(_closeToTray)`), and the macOS dock icon visibility
method channel `com.yuanzhe.my_device/dock`. Tray preferences (`minimizeToTray`,
`closeToTray`) persist in `storage_config.json`.

## `launch_at_startup`

Desktop auto-start is handled by the `launch_at_startup` package, set up in `main()`
with the platform-resolved app name and executable path. macOS specifically uses
**LaunchAtLogin-Modern** (see the macOS section above) rather than a hand-rolled login
item.
