# lib/features/devices/views/device_image_editor_page.dart

用于用户自己设备照片的全屏图片编辑器：带圆形参考线的平移/缩放裁切、去背景（带容差滑块）或应用圆角遮罩，以及设定设备的圆内占比。每次修改后会在 isolate 中运行实时预览，并以大尺寸和列表尺寸同时显示。所有像素处理都是 [`device_image_processing.md`](../../../shared/utils/device_image_processing.md) 中的 `processDeviceImage` 和 `DeviceImageEditRequest`；文件由 `ImageService.loadEditableImage`（[`image_service.md`](../../../shared/services/image_service.md)）解码。它从 [`device_edit_page.dart`](device_edit_page.md) 的 `_pickImage`（带 **使用原图**）和 `_editImage` 打开，二者把返回的 PNG 作为新文件保存在 `images/` 下。面向用户的行为见 [设备 — 图标与图片](../../../../features/devices.md#icon-and-image)。组件测试位于 `test/device_image_editor_test.dart`。按本文档集分层规则，`build()` 方法和私有组件组合辅助方法为 Tier B。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`processDeviceImageInIsolate`](#processdeviceimageinisolate) | 顶层函数 | A | 在 UI isolate 之外运行 `processDeviceImage`。 |
| `DeviceImageEditorResult`（构造函数） | const 构造函数 | B | 创建图片编辑器结果实例；`png` 为 null 表示「使用原图」。 |
| `keepOriginal` | getter（`DeviceImageEditorResult`） | B | 判断用户是否选择保留原文件。 |
| [`showDeviceImageEditor`](#showdeviceimageeditor) | 顶层函数 | A | 在文件上打开图片编辑器并等待用户操作。 |
| `DeviceImageEditorPage`（构造函数） | const 构造函数 | B | 创建设备图片编辑器页面实例；以 `DeviceImageEditorResult` 弹出，取消时为 null。 |
| `createState` | 方法（`DeviceImageEditorPage`） | B | 为此组件创建可变状态对象。 |
| `request` | getter（`DeviceImageEditorPageState`） | B | 暴露编辑器此刻会应用的设置；供组件测试读取。 |
| `initState` | 方法（组件生命周期） | B | 从源图默认值起步并渲染第一张预览。 |
| `dispose` | 方法（组件生命周期） | B | 释放防抖计时器和变换控制器。 |
| `_update` | 方法（`DeviceImageEditorPageState`） | B | 修改设置并刷新预览。 |
| [`_schedulePreview`](#_schedulepreview) | 方法（`DeviceImageEditorPageState`） | A | 防抖后以当前设置运行一次小预览。 |
| [`_onCropChanged`](#_oncropchanged) | 方法（`DeviceImageEditorPageState`） | A | 把裁切区域的平移和缩放换算为源图区域。 |
| [`_reset`](#_reset) | 方法（`DeviceImageEditorPageState`） | A | 把所有设置和裁切恢复为默认值。 |
| [`_use`](#_use) | 方法（`DeviceImageEditorPageState`） | A | 生成全尺寸图片并带着它关闭编辑器。 |
| `build` | 方法（组件） | B | 构建编辑器；宽度 720 px 及以上时裁切区域位于预览和控件旁边，更窄的窗口则上下堆叠。 |
| `_buildCropArea` | 方法（组件辅助） | B | 构建带圆形参考线的平移/缩放裁切区域；记录边长供裁切计算。 |
| `_buildPreview` | 方法（组件辅助） | B | 以设备列表的显示方式展示结果：在头像底色上显示 160 px 和 48 px 两个圆。 |
| `_buildControls` | 方法（组件辅助） | B | 构建设置控件；圆角遮罩开启时去背景开关被禁用。 |
| `_labeledSlider` | 方法（组件辅助） | B | 构建带标签和当前值的滑块行。 |
| `_CircleGuidePainter`（构造函数） | 构造函数 | B | 创建圆形参考线绘制器实例。 |
| `paint` | 方法（`_CircleGuidePainter`） | B | 调暗四角并描出头像圆。 |
| `shouldRepaint` | 方法（`_CircleGuidePainter`） | B | 仅在描边颜色变化时重绘。 |

行数（22）与 `grep -c 'Purpose:' device_image_editor_page.dart`（22）精确匹配。`DeviceImageProcessor` typedef、`DeviceImageEditorResult`、`DeviceImageEditorPage` 和 `DeviceImageEditorPageState` 类，以及静态常量 `previewMaxSource`（384）、`previewOutputSize`（256）和 `roundRectFraction`（0.12）带的是普通 `///` 文档注释而非 `Purpose:` 块，不单独成行。

## 文档

### `Future<Uint8List> processDeviceImageInIsolate(DeviceImageEditRequest request)` <a id="processdeviceimageinisolate"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/devices/views/device_image_editor_page.dart`（第 22 行）。
- **用途：** 在 UI isolate 之外运行 [`processDeviceImage`](../../../shared/utils/device_image_processing.md#processdeviceimage)。
- **输入：** `request`。
- **返回：** `Future<Uint8List>` —— PNG 字节。
- **副作用：** 启动一个短暂的 isolate（`Isolate.run`）。
- **用法：** `showDeviceImageEditor` 和 `DeviceImageEditorPage` 的默认 `processor`。
- **备注：** 它是默认的 `DeviceImageProcessor`（`Future<Uint8List> Function(DeviceImageEditRequest)`）；测试传入一个同步版本，包装 `processDeviceImage` 并记录每个请求。

### `Future<DeviceImageEditorResult?> showDeviceImageEditor(BuildContext context, File file, {bool allowOriginal = false, DeviceImageProcessor processor = processDeviceImageInIsolate})` <a id="showdeviceimageeditor"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/devices/views/device_image_editor_page.dart`（第 55 行）。
- **用途：** 在文件上打开图片编辑器并等待用户操作。
- **输入：** `context`；`file` —— 要编辑的图片；`allowOriginal` —— 提供 **使用原图**（添加新选的照片时为 true）；`processor` —— 处理流程执行器。
- **返回：** `Future<DeviceImageEditorResult?>` —— 编辑后的图片为 `DeviceImageEditorResult(png)`，「使用原图」为 `DeviceImageEditorResult(null)`（`keepOriginal`）；取消、context 已卸载，或文件无法解码且 `allowOriginal` 为 false 时为 null。
- **副作用：** 解码并读取文件；可能显示 `imageEditorDecodeFailed` 提示条；在根导航器上推入全屏 `MaterialPageRoute`。
- **算法：**
  1. `ImageService.loadEditableImage(file)`（先用平台解码器，回退到 `package:image`，解码时缩小到 1024 px）。
  2. 解码失败 → 显示提示条，允许时返回「保留原图」，否则返回 null。
  3. 读取原始字节用于显示，然后以 `fullscreenDialog` 推入 `DeviceImageEditorPage(source, displayBytes, allowOriginal, processor)` 并返回其弹出的值。
- **用法：**
  ```dart
  final result = await showDeviceImageEditor(context, file, allowOriginal: true);
  ```
  （来自 `lib/features/devices/views/device_edit_page.dart` 中的 `_pickImage`，第 1071 行——那里缺少 `png` 即走 `ImageService.saveImageFile(file)`），以及 `_editImage`（第 1097 行）中的 `showDeviceImageEditor(context, file)`，它只保存非 null 的 `png`。
- **备注：** 解码器拒绝的文件在允许时作为「保留原图」返回，因此编辑器读不了的格式永远不会阻止添加照片。

### `void _schedulePreview({bool immediate = false})` <a id="_schedulepreview"></a>
- **种类：** `DeviceImageEditorPageState` 的方法。
- **来源：** `lib/features/devices/views/device_image_editor_page.dart`（第 182 行）。
- **用途：** 防抖后以当前设置运行一次小预览。
- **输入：** `immediate` —— 跳过防抖（`initState` 使用）。
- **返回：** 无。
- **副作用：** 取消任何待执行计时器；运行 `widget.processor`；对 `_processing` 和 `_preview` 调用 `setState`。
- **算法：**
  1. 取消 `_debounce`。执行步骤递增 `_generation`、设置 `_processing`，并处理 `_request.copyWith(maxSource: previewMaxSource, outputSize: previewOutputSize)`（384 / 256）。
  2. 仅在仍挂载且代数未变时应用 PNG；出错时在同样的检查下只清除 `_processing`。
  3. `immediate` 时立即运行，否则在 150 ms 的 `Timer` 之后运行。
- **用法：** `initState`（`immediate: true`）以及每次设置变化后的 `_update`。
- **备注：** 代数计数器会丢弃已被更新的修改取代的结果，因此慢的预览永远不会覆盖更新的预览。

### `void _onCropChanged()` <a id="_oncropchanged"></a>
- **种类：** `DeviceImageEditorPageState` 的方法。
- **来源：** `lib/features/devices/views/device_image_editor_page.dart`（第 221 行）。
- **用途：** 把裁切区域的平移和缩放换算为源图区域。
- **输入：** 无（读取 `_transform.value` 和 `_cropSide`）。
- **返回：** 无。
- **副作用：** 经 `_update` 更新请求。
- **算法：**
  1. 裁切区域尚未布局（`_cropSide <= 0`）时返回。
  2. 单位变换 → `copyWith(clearCrop: true)`（整张图）。
  3. 否则，设缩放为 `k`、平移为 `t`，图片以 `contain` 方式放入正方形（`f = side / max(w, h)`，偏移 `ox`、`oy`）；可见正方形 `(-t.x / k, -t.y / k, side / k)` 被换算为所绘图片的比例并存为 `crop`。
- **用法：** `_buildCropArea` 中的 `InteractiveViewer.onInteractionEnd`。
- **备注：** `InteractiveViewer` 允许 `side / 2` 的边界余量，因此裁切区域可以超出图片；`cropRectOf` 会将其夹紧，留白则由 **圆内占比** 提供。

### `void _reset()` <a id="_reset"></a>
- **种类：** `DeviceImageEditorPageState` 的方法。
- **来源：** `lib/features/devices/views/device_image_editor_page.dart`（第 248 行）。
- **用途：** 把所有设置和裁切恢复为默认值。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 把 `_transform` 重置为单位矩阵、`_request` 重置为 `widget.source`；安排一次预览。
- **用法：** `_buildControls` 末尾的 **重置** 按钮。
- **备注：** `widget.source` 是带默认设置的已解码请求，因此这也会恢复容差 28、开启去背景、无遮罩和比例 0.64。

### `Future<void> _use()` <a id="_use"></a>
- **种类：** `DeviceImageEditorPageState` 的方法。
- **来源：** `lib/features/devices/views/device_image_editor_page.dart`（第 258 行）。
- **用途：** 生成全尺寸图片并带着它关闭编辑器。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 设置 `_saving`（禁用两个应用栏操作并显示转圈）；按请求自身的尺寸（512 px 输出）运行 `widget.processor(_request)`；以 `DeviceImageEditorResult(png)` 弹出路由。
- **用法：** 应用栏的 **使用** 操作（`ValueKey('imageEditorUse')`）。
- **备注：** 处理出错时编辑器保持打开并清除 `_saving`；不向用户报告任何内容。
