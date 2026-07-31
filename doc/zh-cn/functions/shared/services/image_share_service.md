# lib/shared/services/image_share_service.dart

`ImageShareService` 经平台适当分享路径分享内存 PNG 字节（如 [服务与拓扑](../../../features/services-topology.md) 的服务拓扑导出）：Android 方法通道、iOS `share_plus`，或带复制/保存操作的桌面预览对话框。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`sharePngBytes`](#sharepngbytes) | 静态方法 | A | 经平台适当路径分享 PNG 字节。 |
| [`_showDesktopPreview`](#showdesktoppreview) | 静态方法 | A | 显示带复制/另存为操作的桌面预览对话框。 |
| [`_copyImageToClipboard`](#copyimagetoclipboard) | 静态方法 | A | 桌面把图像文件复制到操作系统剪贴板。 |

## 文档

### `static Future<void> sharePngBytes(BuildContext context, Uint8List imageBytes, {required String fileName})` <a id="sharepngbytes"></a>
- **种类：** `ImageShareService` 的静态方法。
- **来源：** `lib/shared/services/image_share_service.dart`（第 18 行）。
- **用途：** 把 PNG 字节写入临时文件并交给平台原生分享机制，或桌面预览对话框。
- **输入：** `context`；`imageBytes`；`fileName`（临时文件和任何另存为对话框都用）。
- **返回：** `Future<void>`。
- **副作用：** 写临时文件（`path_provider` 的临时目录）；Android 上调用 `com.yuanzhe.my_device/share` 方法通道；iOS 上调用 `Share.shareXFiles`；桌面打开对话框。
- **算法：** 把 `imageBytes` 写到 `<tempDir>/<fileName>`；await 后重新检查 `context.mounted`；按 `Platform.isAndroid`（带 `path`/`mimeType` 的方法通道 `shareFile`）、`Platform.isIOS`（`Share.shareXFiles`）、否则（桌面）`_showDesktopPreview` 分支。
- **用法：** 应用分享生成 PNG 的任何地方调用，如服务拓扑 PNG 导出。
- **备注：** 镜像姊妹应用其他导出流程使用的相同三平台分支分享模式（Android 方法通道 / iOS `share_plus` / 桌面预览对话框）。

### `static Future<void> _showDesktopPreview(BuildContext context, Uint8List imageBytes, String tempPath, AppLocalizations l10n, {required String fileName})` <a id="showdesktoppreview"></a>
- **种类：** `ImageShareService` 的静态方法。
- **来源：** `lib/shared/services/image_share_service.dart`（第 54 行）。
- **用途：** 为无原生分享面板的桌面平台显示带"复制"和"另存为"操作的模态预览对话框。
- **输入：** `context`、`imageBytes`、`tempPath`（已写临时文件）、`l10n`、`fileName`。
- **返回：** `Future<void>`。
- **副作用：** 打开 `showDialog`；"复制"调用 `_copyImageToClipboard`；"另存为"打开 `FilePicker.platform.saveFile` 并把 `imageBytes` 写到所选路径。
- **算法：** 在受限 `Dialog` 内经 `Image.memory` 渲染图像，带底部操作行。复制按钮：复制到剪贴板、弹出对话框、显示"已复制"snackbar。保存按钮：打开预填 `fileName` 的原生保存对话框；选了路径则把字节写那里、弹出对话框、显示"已保存"snackbar。两个操作 await 后碰导航器/scaffold messenger 前守卫 `ctx.mounted`。
- **用法：** 只从 `sharePngBytes` 桌面分支调用。
- **备注：** "另存为"在用户选择位置写第二份文件——`sharePngBytes` 的原始临时文件不删除不移动。

### `static Future<void> _copyImageToClipboard(String imagePath)` <a id="copyimagetoclipboard"></a>
- **种类：** `ImageShareService` 的静态方法。
- **来源：** `lib/shared/services/image_share_service.dart`（第 129 行）。
- **用途：** 用平台特定外部进程把图像文件内容作为图像复制到操作系统剪贴板，因为 Flutter 无内置跨平台图像剪贴板 API。
- **输入：** `imagePath` — 图像文件绝对路径。
- **返回：** `Future<void>`。
- **副作用：** 生成外部进程：PowerShell（Windows，经 `System.Drawing` + `System.Windows.Forms.Clipboard`）、`osascript`（macOS，AppleScript 剪贴板设置）或 `xclip`（Linux，`image/png` 目标）。
- **算法：** 按 `Platform.isWindows`/`isMacOS`/`isLinux` 分支并用 `Process.run` 运行对应外部命令，图像路径嵌入命令字符串/参数。
- **用法：** 只从 `_showDesktopPreview` 的"复制"按钮调用。
- **备注：** Windows 分支把 `imagePath` 直接插入 PowerShell 命令字符串；因为此路径总是来自本应用自己临时文件写（非用户输入），当前实现不当作注入风险，但任何未来传不可信路径的调用方需要重新考虑。
