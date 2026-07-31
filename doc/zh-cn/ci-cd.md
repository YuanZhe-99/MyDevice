# CI/CD 与构建命令

## 工作流

`.github/workflows/build.yml` 在 `v*` 标签推送和 `workflow_dispatch` 上运行。

每个检出步骤传 `submodules: recursive`。没有它 `flutter pub get` 会因缺失 `packages/myapps_data` 路径依赖失败。相对子模块 URL 在 CI 中解析到公共 GitHub 副本，因此默认 `GITHUB_TOKEN` 足够。

## 作业

| 作业 | 运行器 | 输出 | 备注 |
| --- | --- | --- | --- |
| `android` | `ubuntu-latest` | APK（full）+ AAB（store） | Java 17，可选签名机密 |
| `windows-x64` | `windows-latest` | Inno x64 安装器 | 稳定 Flutter `3.44.2`，`iscc installer.iss` |
| `windows-arm64` | `windows-11-arm` | Inno ARM64 安装器 | ARM64 引擎的 Flutter master，`iscc /DARM64 installer.iss` |
| `ios` | `macos-latest` | 侧载 IPA | Release，无 codesign |
| `macos` | `macos-latest` | DMG | 用 `create-dmg` |

GitHub Release 工件在标签推送时上传。

## 工作流注意事项

- 保持工作流 Flutter 版本与 Dart SDK 约束对齐。
- GitHub `secrets` 不能直接在步骤 `if` 表达式中使用；经作业级 `env` 路由它们。
- Windows ARM64 Inno 输出由 `iscc /DARM64 installer.iss` 控制。
- 操作版本：`actions/checkout@v7`、`actions/setup-java@v5`、`actions/upload-artifact@v7`、`actions/download-artifact@v8`、`softprops/action-gh-release@v3`（从 GitHub 弃用的 Node 20 基础大版本升上来）。下次标签发布前用 `workflow_dispatch` 运行验证工作流变更。
- 已知剩余警告：Android 作业仍为 `package_info_plus`、`share_plus`、`shared_preferences_android`、`wakelock_plus` 和 `file_picker` 打印 Flutter 的 "plugins that apply KGP" 警告。应用侧已迁移（AGP 9.1.1，无应用级 `kotlin-android`）；剩余警告仅插件侧，截至 2026-07 那些插件的最新发布仍应用 KGP。完全消除需要每个插件发布 Built-in Kotlin 支持后翻转 `android.builtInKotlin=true`；尝试时用真实 APK/AAB 构建验证。

## 命令

```powershell
flutter pub get
flutter analyze
flutter test
flutter gen-l10n
dart run tool/generate_ios_icons.dart
dart run flutter_launcher_icons
dart run tool/validate_ios_icons.dart --clean
flutter build apk --release --no-tree-shake-icons --dart-define=FLAVOR=full
flutter build appbundle --release --no-tree-shake-icons --dart-define=FLAVOR=store
flutter build windows --release --dart-define=FLAVOR=full
iscc installer.iss
iscc /DARM64 installer.iss
```

用最窄相关命令集验证。模型或同步变更时包含针对性测试，如 `flutter test test/sync_unknown_fields_test.dart` 或 `flutter test test/device_finance_test.dart`。

## 全新克隆

共享引擎包是 git 子模块，因此普通 `git clone` 让 `packages/myapps_data` 为空且 `flutter pub get` 失败：

```bash
git clone --recurse-submodules <app-url>
# or, after a plain clone:
git submodule update --init
```
