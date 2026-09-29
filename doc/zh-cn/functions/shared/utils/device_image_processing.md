# lib/shared/utils/device_image_processing.dart

应用内图片编辑器（[`device_image_editor_page.md`](../../features/devices/views/device_image_editor_page.md)）与缩略图工具共用的设备图片处理流程：`tool/prepare_device_image.dart`（再导出 `applyRoundRectMask`、`fitIntoCircle`、`prepareDeviceImage`、`removeEdgeBackground` 和 `removeSpecks`）、`tool/device_image_check.dart`（再导出 `checkDeviceImage` 和三个常量）以及 `tool/validate_json.dart`（对每张内置缩略图运行 `checkDeviceImage`）。它是基于 `package:image` 的纯 Dart 代码，不含 Flutter import，因此 `processDeviceImage` 能在 `Isolate.run` 中运行，工具也能经 `dart run` 运行。内置缩略图必须满足的规则——正方形、透明、每个可见像素都在头像圆内——也定义在这里，使应用、工具和测试（`test/device_image_test.dart`、`test/device_image_editor_test.dart`）共用同一份定义。`ImageService.loadEditableImage` / `decodeEditableImage`（[`image_service.md`](../services/image_service.md)）构建编辑器起步用的 `DeviceImageEditRequest`。面向用户的行为见 [设备 — 图标与图片](../../../features/devices.md#icon-and-image)，内置缩略图规则见 [在线搜索与预设 — 设备缩略图](../../../features/online-search-and-presets.md#device-thumbnails)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`checkDeviceImage`](#checkdeviceimage) | 顶层函数 | A | 按设备图片规则检查已解码的缩略图。 |
| [`prepareDeviceImage`](#preparedeviceimage) | 顶层函数 | A | 对已解码图片运行完整的缩略图处理流程。 |
| [`applyRoundRectMask`](#applyroundrectmask) | 顶层函数 | A | 只保留填满图片的圆角矩形。 |
| [`removeSpecks`](#removespecks) | 顶层函数 | A | 清除去背景后残留的小块不透明孤岛。 |
| `_edgesTransparent` | 私有顶层函数 | B | 判断图片边框是否已完全透明。 |
| `_borderPixels` | 私有顶层函数（生成器） | B | 枚举图片外边框上的坐标。 |
| [`removeEdgeBackground`](#removeedgebackground) | 顶层函数 | A | 从边缘向内泛洪，把纯色背景变为透明。 |
| [`fitIntoCircle`](#fitintocircle) | 顶层函数 | A | 修剪到可见内容并将其居中放入圆内安全框。 |
| `_premultiply` | 私有顶层函数 | B | 在直通 alpha 与预乘 alpha 之间转换 RGBA 图片。 |
| [`DeviceImageEditRequest`](#deviceimageeditrequest)（构造函数） | const 构造函数 | A | 创建图片编辑请求。 |
| [`copyWith`](#copywith) | 方法（`DeviceImageEditRequest`） | A | 复制此请求并修改部分设置。 |
| [`cropRectOf`](#croprectof) | 顶层函数 | A | 把请求保留的区域换算为源图像素。 |
| [`processDeviceImage`](#processdeviceimage) | 顶层函数 | A | 运行编辑器的处理流程并编码结果。 |

行数（13）与 `grep -c 'Purpose:' device_image_processing.dart`（13）精确匹配。三个常量（`deviceImageSize` = 256、`deviceImageSafeFraction` = 0.64、`deviceImageAlphaThreshold` = 8）、`DeviceImageEditRequest` 类及其字段带的是普通 `///` 文档注释而非 `Purpose:` 块；它们在下方条目中说明，不单独成行。

## 文档

### `List<String> checkDeviceImage(img.Image image)` <a id="checkdeviceimage"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/device_image_processing.dart`（第 35 行）。
- **用途：** 按设备图片规则检查已解码的缩略图。
- **输入：** `image` —— 已解码的 PNG。
- **返回：** 可读问题的 `List<String>`；图片通过时为空。
- **副作用：** 无。
- **算法：**
  1. 非正方形 → 记一个问题并立即返回。
  2. 宽度小于 128 px → 记问题（继续检查）。
  3. 少于 4 个通道 → 「no alpha channel; background was not removed」，返回。
  4. 四个角中任一 alpha ≠ 0 → 记一个「background remains」问题（只记第一个出问题的角）。
  5. 统计 alpha 高于 `deviceImageAlphaThreshold`（8）且中心落在半径 `width / 2 − 1` 的内切圆之外的像素；计数非零时记一个问题。
- **用法：** `tool/validate_json.dart`（`for (final problem in checkDeviceImage(decoded))`）检查每个模板 `image`；`tool/prepare_device_image.dart` 检查其输出（有问题时退出码为 1）；`test/device_image_test.dart`。
- **备注：** 圆形规则之所以存在，是因为每个显示该图片的头像都会把它裁切成那个圆。用户自己编辑过的照片从不检查——它可以合理地超出圆形。

### `img.Image prepareDeviceImage(img.Image source, {int tolerance = 28, double? roundRect, bool removeBackground = true, int maxSource = 1024, int size = deviceImageSize, double safeFraction = deviceImageSafeFraction})` <a id="preparedeviceimage"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/device_image_processing.dart`（第 87 行）。
- **用途：** 对已解码图片运行完整的缩略图处理流程。
- **输入：** `source`；`tolerance` —— 视为背景的颜色距离；`roundRect` —— 设置时为 [`applyRoundRectMask`](#applyroundrectmask) 的圆角比例，替代去背景；`removeBackground` —— 为 false 时保留所有像素；`maxSource` —— 处理的最长边；`size`、`safeFraction` —— 传给 [`fitIntoCircle`](#fitintocircle)。
- **返回：** 边长为 `size` 的新正方形 RGBA 图片。
- **副作用：** 无（在 `source` 转换后的副本上工作）。
- **算法：**
  1. 转为 4 通道 uint8；长边超过 `maxSource` 时缩小到 `maxSource`（平均插值）。
  2. `roundRect != null` 时应用圆角遮罩；否则 `removeBackground` 为真时，除非边框已透明（`_edgesTransparent`），先运行 [`removeEdgeBackground`](#removeedgebackground)，再运行 [`removeSpecks`](#removespecks)。
  3. 返回 `fitIntoCircle(work, size: size, safeFraction: safeFraction)`。
- **用法：** [`processDeviceImage`](#processdeviceimage)（裁切之后）；`tool/prepare_device_image.dart`（`prepareDeviceImage(decoded, tolerance: tolerance, roundRect: roundRect, removeBackground: !keepBackground)`）。
- **备注：** 边框透明时跳过的逻辑，防范的正是 1.6.1 之前弄坏 Switch OLED 和 Steam Deck 抠图的那种故障：对本已透明的渲染图做泛洪填充会损坏它。遮罩适合在杂乱表面（木纹、布料）上正面拍摄的手机或平板，这种情况下泛洪填充分不清背景与设备。

### `void applyRoundRectMask(img.Image image, double radiusFraction)` <a id="applyroundrectmask"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/device_image_processing.dart`（第 122 行）。
- **用途：** 只保留填满图片的圆角矩形。
- **输入：** `image` —— RGBA，原地修改；`radiusFraction` —— 圆角半径占短边的比例。
- **返回：** 无。
- **副作用：** 降低圆角矩形之外像素的 alpha。
- **算法：** `r = min(w, h) × radiusFraction`。只访问四个 `r × r` 角区域内的像素；每个像素按 4×4 采样判断是否落在圆角矩形内，并把 alpha 乘以覆盖比例（`cover / 16`）。
- **用法：** `roundRect` 设置时由 [`prepareDeviceImage`](#preparedeviceimage) 调用——来源是编辑器的 **圆角** 开关（比例 0.12）和 `tool/prepare_device_image.dart --roundrect`。
- **备注：** 边缘抗锯齿而非阶梯状。调用方先紧贴设备裁切。

### `void removeSpecks(img.Image image, {double minFraction = 0.02})` <a id="removespecks"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/device_image_processing.dart`（第 155 行）。
- **用途：** 清除去背景后残留的小块不透明孤岛。
- **输入：** `image` —— RGBA，原地修改；`minFraction` —— 孤岛面积低于最大孤岛面积的这一比例时被清除。
- **返回：** 无。
- **副作用：** 把小孤岛像素的 alpha 设为 0。
- **算法：** 用显式栈为 alpha 高于 `deviceImageAlphaThreshold` 的像素标记 8 连通孤岛；孤岛至少两个时，清除所有小于 `largest × minFraction` 的孤岛。
- **用法：** 去背景之后由 [`prepareDeviceImage`](#preparedeviceimage) 调用。
- **备注：** 否则阴影碎片和噪点会撑大修剪框、让设备变小。8 连通使细线缆保持相连。

### `void removeEdgeBackground(img.Image image, int tolerance)` <a id="removeedgebackground"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/device_image_processing.dart`（第 235 行）。
- **用途：** 从边缘向内泛洪，把纯色背景变为透明。
- **输入：** `image` —— RGBA uint8，原地修改；`tolerance` —— 视为背景的 RGB 欧氏距离。
- **返回：** 无。
- **副作用：** 改写 `image` 中背景像素的 alpha。
- **算法：**
  1. 参考颜色 = 边框像素各通道的中位数。
  2. 以所有与参考颜色距离不超过 `tolerance` 的边框像素为种子做 4 连通广度优先泛洪，经距离不超过 `tolerance` 的邻居扩展。
  3. 被泛洪的像素 alpha 设为 0；未被泛洪但与泛洪区相邻且距离不超过 `2 × tolerance` 的像素 alpha 减半（一像素羽化）。
- **用法：** [`prepareDeviceImage`](#preparedeviceimage)；由 `tool/prepare_device_image.dart` 再导出。
- **备注：** 中位数不受暗角或个别角落干扰。只清除与边框相连的像素，因此设备内的白色屏幕或徽标得以保留。

### `img.Image fitIntoCircle(img.Image image, {int size = deviceImageSize, double safeFraction = deviceImageSafeFraction})` <a id="fitintocircle"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/device_image_processing.dart`（第 298 行）。
- **用途：** 修剪到可见内容并将其居中放入圆内安全框。
- **输入：** 带透明度的 `image`；`size` —— 输出边长；`safeFraction` —— 内容长边占边长的比例。
- **返回：** 边长为 `size` 的新正方形 RGBA 图片（无可见内容时完全透明）。
- **副作用：** 无。
- **算法：**
  1. 找出 alpha 高于 `deviceImageAlphaThreshold` 的像素的包围框；没有则返回空画布。
  2. 裁切到包围框，按保持宽高比缩放使长边为 `floor(size × safeFraction)`。
  3. 在预乘 alpha 下重采样（`_premultiply` 正向、缩放、再反向），并把结果居中合成到透明画布上。
- **用法：** [`prepareDeviceImage`](#preparedeviceimage)；由 `tool/prepare_device_image.dart` 再导出。
- **备注：** 使用默认 `deviceImageSafeFraction`（0.64；0.64 × √2 < 1，与 `TemplateIcon` 用的安全框相同）时，包围框——因而每个可见像素——都在内切圆内。用户自己的照片允许更大的比例（编辑器滑块可到 1.0）。预乘重采样防止被移除背景的颜色渗进边缘形成光晕。

### `const DeviceImageEditRequest({required Uint8List rgba, required int width, required int height, (double, double, double, double)? crop, bool removeBackground = true, int tolerance = 28, double? roundRect, double scale = deviceImageSafeFraction, int outputSize = 512, int maxSource = 1024})` <a id="deviceimageeditrequest"></a>
- **种类：** `DeviceImageEditRequest`（「图片编辑器的一次运行：源像素加用户的设置」）的 const 构造函数。
- **来源：** `lib/shared/utils/device_image_processing.dart`（第 402 行）。
- **用途：** 创建图片编辑请求。
- **输入：** `rgba` —— 直通 alpha 的 RGBA 字节，长度 `width × height × 4`；`crop` —— 保留区域，以源图比例 `(left, top, width, height)` 表示，null 表示全部；`removeBackground`；`tolerance`；`roundRect` —— 遮罩圆角比例，null 表示无；`scale` —— 设备长边占输出边长的比例；`outputSize` —— 输出边长（px）；`maxSource` —— 处理的最长源图边。
- **返回：** 新的 `DeviceImageEditRequest`。
- **副作用：** 无。
- **用法：** `ImageService.decodeEditableImage` 只用 `rgba`/`width`/`height` 构建一个请求，因此编辑器从这些默认值起步；编辑器页面之后的每个请求都经 [`copyWith`](#copywith) 派生。
- **备注：** 纯数据，因此可以发送到 isolate。最终图片为 512 px；编辑器的实时预览把 `maxSource`/`outputSize` 覆盖为 384/256。

### `DeviceImageEditRequest copyWith({(double, double, double, double)? crop, bool clearCrop = false, bool? removeBackground, int? tolerance, double? roundRect, bool clearRoundRect = false, double? scale, int? outputSize, int? maxSource})` <a id="copywith"></a>
- **种类：** `DeviceImageEditRequest` 的方法。
- **来源：** `lib/shared/utils/device_image_processing.dart`（第 421 行）。
- **用途：** 复制此请求并修改部分设置。
- **输入：** 任意要替换的设置；`clearCrop` / `clearRoundRect` 把这两个可空设置重置为 null（仅传 null 参数表示「保留」）。
- **返回：** 新的 `DeviceImageEditRequest`。
- **副作用：** 无。
- **用法：** `DeviceImageEditorPageState` 中的每个控件（如 `_request.copyWith(clearRoundRect: true)`），以及预览的 `_request.copyWith(maxSource: previewMaxSource, outputSize: previewOutputSize)`。
- **备注：** 源像素是共享的，不复制。

### `(int, int, int, int) cropRectOf(DeviceImageEditRequest request)` <a id="croprectof"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/device_image_processing.dart`（第 451 行）。
- **用途：** 把请求保留的区域换算为源图像素。
- **输入：** `request`。
- **返回：** 源图内的 `(x, y, width, height)`，至少 1×1；`crop` 为 null 时是整张图。
- **副作用：** 无。
- **算法：** 把左/上与右/下比例夹到 `[0, 1]`，起点向下取整（上限 `width − 1` / `height − 1`）、终点向上取整，尺寸取 `max(1, end − start)`。
- **用法：** [`processDeviceImage`](#processdeviceimage)；`test/device_image_editor_test.dart`。
- **备注：** 超出图片的裁切区域（用户缩小到图片之外）会被夹紧；留白改由 `scale` 提供。

### `Uint8List processDeviceImage(DeviceImageEditRequest request)` <a id="processdeviceimage"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/device_image_processing.dart`（第 479 行）。
- **用途：** 运行编辑器的处理流程并编码结果。
- **输入：** `request`。
- **返回：** 边长为 `outputSize` 的透明正方形的 PNG 字节（压缩级别 6）。
- **副作用：** 无。
- **算法：** 不复制地把 `rgba` 包装为 4 通道 `img.Image`，按 [`cropRectOf`](#croprectof) 裁切，再以请求的 `tolerance`、`roundRect`、`removeBackground`、`maxSource`、`outputSize`（作为 `size`）和 `scale`（作为 `safeFraction`）调用 [`prepareDeviceImage`](#preparedeviceimage)，并编码结果。
- **用法：** `device_image_editor_page.dart` 中的 `processDeviceImageInIsolate`（`Isolate.run(() => processDeviceImage(request))`）；测试同步调用它。
- **备注：** 定义为顶层函数，以便 `Isolate.run` 调用。顺序：裁切、缩小到 `maxSource`、去背景（或应用圆角遮罩）、修剪、按 `scale` 放入正方形中央。
