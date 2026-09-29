# lib/shared/services/image_service.dart

`ImageService` 处理设备/服务图像的图像文件挑选、为图片编辑器解码、存储、URL 下载和删除，把它们以 UUID 命名文件存到应用目录内 `images/` 下（见 [数据格式](../../../data-formats.md)）。解码辅助把来自 [device_image_processing.md](../utils/device_image_processing.md) 的 `DeviceImageEditRequest` 交给图片编辑器（[device_image_editor_page.md](../../features/devices/views/device_image_editor_page.md)）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`_getImageDir`](#getimagedir) | 静态方法 | A | 解析（缺失时创建）应用 `images/` 目录。 |
| [`pickAndSaveImage`](#pickandsaveimage) | 静态方法 | A | 让用户挑选图像文件并原样复制进应用存储。 |
| [`pickImageFile`](#pickimagefile) | 静态方法 | A | 让用户挑选图像文件而不复制。 |
| [`saveImageFile`](#saveimagefile) | 静态方法 | A | 把图像文件原样复制进应用存储。 |
| [`saveImageBytes`](#saveimagebytes) | 静态方法 | A | 把编码图像字节（如图片编辑器的 PNG）存为新文件。 |
| [`loadEditableImage`](#loadeditableimage) | 静态方法 | A | 读取并解码图像文件为可编辑 RGBA 请求。 |
| [`decodeEditableImage`](#decodeeditableimage) | 静态方法 | A | 把编码图像字节解码为缩小后的可编辑 RGBA 请求。 |
| [`resolve`](#resolve) | 静态方法 | A | 把相对 `images/...` 路径解析为绝对 `File`。 |
| [`delete`](#delete) | 静态方法 | A | 按相对路径删除先前保存的图像。 |
| [`saveImageFromUrl`](#saveimagefromurl) | 静态方法 | A | 从 URL 下载图像进应用存储。 |

行数说明：对此文件 `grep -c 'Purpose:'` 返回 10，与上面 10 行精确匹配。

## 文档

### `static Future<Directory> _getImageDir()` <a id="getimagedir"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 21 行）。
- **用途：** 解析应用 `images/` 子目录，不存在时创建。
- **输入：** 无。
- **返回：** `Future<Directory>`。
- **副作用：** 文件系统：缺席时创建目录（递归）。
- **算法：** 经 `DeviceStorage.getAppDir()` `p.join(appDir.path, 'images')`；`!await imgDir.exists()` 时递归创建。
- **用法：** 被 `saveImageFile`、`saveImageBytes` 和 `saveImageFromUrl` 调用。
- **备注：** 遵循全应用规则，所有文件 IO 经存储枢纽 `getAppDir()`，使自定义存储路径工作（见本仓库 `AGENTS.md`）。

### `static Future<String?> pickAndSaveImage()` <a id="pickandsaveimage"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 38 行）。
- **用途：** 让用户经系统文件选择器挑选图像文件并以新 UUID 文件名原样复制进应用存储。
- **输入：** 无。
- **返回：** `Future<String?>` — 如 `"images/<uuid>.png"` 的相对路径，用户取消或所选路径不可用时 `null`。
- **副作用：** 打开原生文件选择器；把所选文件复制进 `images/`。
- **算法：** 委托：[`pickImageFile`](#pickimagefile)；它返回 `null` 时返回 `null`，否则对所选文件调用 [`saveImageFile`](#saveimagefile)。
- **用法：** 目前 `lib/` 中无调用方——设备编辑器改经 `pickImageFile` 和图片编辑器。为需要原样文件的调用方保留。
- **备注：** 原始文件被复制而非移动——用户挑的源文件在磁盘上保持不动。

### `static Future<File?> pickImageFile()` <a id="pickimagefile"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 50 行）。
- **用途：** 让用户挑选图像文件，不复制到任何地方。
- **输入：** 无。
- **返回：** `Future<File?>` — 所选文件，取消或选择器未给出路径时 `null`。
- **副作用：** 打开原生文件选择器（`FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false)`）。
- **算法：** 挑单个图像；结果为空或 `files.single.path` 为 null 时返回 `null`；否则 `File(pickedPath)`。
- **用法：** 设备编辑器的照片流程（[device_edit_page.md](../../features/devices/views/device_edit_page.md#_pickimage) 中的 `_pickImage`），随后编辑文件或原样存储；也被 `pickAndSaveImage` 调用。
- **备注：** 由调用方决定先编辑（[`loadEditableImage`](#loadeditableimage)）还是原样存储（[`saveImageFile`](#saveimagefile)）。

### `static Future<String> saveImageFile(File source)` <a id="saveimagefile"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 66 行）。
- **用途：** 把图像文件原样复制进应用存储。
- **输入：** `source` — 要复制的文件。
- **返回：** `Future<String>` — 相对路径，如 `images/<uuid>.jpg`。
- **副作用：** 需要时创建图像目录；写入一个文件。
- **算法：** 把副本命名为 `'${Uuid().v4()}${p.extension(source.path)}'`（保留源扩展名），并把 `source.copy` 进 `_getImageDir()`。
- **用法：** `pickAndSaveImage`，以及设备编辑器的"使用原图"路径（图片编辑器无法解码文件时也走此路径）。
- **备注：** 源文件保持原位。

### `static Future<String> saveImageBytes(Uint8List bytes, String ext)` <a id="saveimagebytes"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 79 行）。
- **用途：** 把编码图像字节（如图片编辑器的 PNG）存为新图像文件。
- **输入：** `bytes` — 编码图像数据；`ext` — 含点的扩展名，如 `.png`。
- **返回：** `Future<String>` — 相对路径，如 `images/<uuid>.png`。
- **副作用：** 需要时创建图像目录；写入一个文件（`flush: true`）。
- **算法：** `File(p.join(imgDir, '${Uuid().v4()}$ext')).writeAsBytes(bytes, flush: true)`。
- **用法：** 设备编辑器的 `_pickImage` 和 `_editImage`，写入编辑器的 PNG 结果。
- **备注：** 总是 `images/` 下的新平铺文件，因此备份和同步像其他设备图像一样携带它；绝不覆盖既有文件。

### `static Future<DeviceImageEditRequest?> loadEditableImage(File file, {int maxSide = 1024})` <a id="loadeditableimage"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 92 行）。
- **用途：** 把图像文件解码为图片编辑器能处理的像素。
- **输入：** `file`；`maxSide` — 解码后保留的最长边（默认 1024）。
- **返回：** `Future<DeviceImageEditRequest?>` — 携带直通 alpha RGBA 像素与默认编辑设置的请求，文件无法读取或解码时 `null`。
- **副作用：** 读取文件。
- **算法：** `file.readAsBytes()`（读取错误返回 `null`），然后 [`decodeEditableImage`](#decodeeditableimage)。
- **用法：** [device_image_editor_page.md](../../features/devices/views/device_image_editor_page.md) 中的 `showDeviceImageEditor`，此处返回 `null` 时它回退到"使用原图"（或取消）。
- **备注：** 无。

### `static Future<DeviceImageEditRequest?> decodeEditableImage(Uint8List bytes, {int maxSide = 1024})` <a id="decodeeditableimage"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 113 行）。
- **用途：** 把编码图像字节解码为可编辑 RGBA 请求。
- **输入：** `bytes` — 编码图像数据；`maxSide` — 解码后保留的最长边。
- **返回：** `Future<DeviceImageEditRequest?>` — 请求（`rgba`、`width`、`height`），无解码器接受这些字节时 `null`。
- **副作用：** 无（分配并释放平台图像对象）。
- **算法：**
  1. 先用平台编解码器：`ui.ImmutableBuffer.fromUint8List` → `ui.ImageDescriptor.encoded`；最长边超过 `maxSide` 时向 `instantiateCodec` 传 `targetWidth`（横向/方形）或 `targetHeight`（纵向）= `maxSide`，使缩小在解码时发生；以 `ui.ImageByteFormat.rawStraightRgba` 读取第一帧；释放图像、编解码器、描述符和缓冲区；产生像素时返回请求。
  2. 任何异常（或无像素数据）时回退到 `package:image`：`img.decodeImage`、`img.bakeOrientation`，最长边超过 `maxSide` 时用 `Interpolation.average` 执行 `img.copyResize`，然后转换为 4 通道 uint8 并取 RGBA 字节。
  3. 回退也失败时返回 `null`。
- **用法：** 被 [`loadEditableImage`](#loadeditableimage) 调用。
- **备注：** 先用平台编解码器使 Flutter 能显示的格式（及 EXIF 方向）表现与屏幕上一致，解码时缩小使 48 MP 照片永远不会变成全尺寸缓冲区。回退路径显式烘焙 EXIF 方向。

### `static Future<File> resolve(String relativePath)` <a id="resolve"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 180 行）。
- **用途：** 把相对 `imagePath`（如模型中存储的 `"images/xxx.png"`）变为应用目录下绝对 `File`。
- **输入：** `relativePath`。
- **返回：** `Future<File>`。
- **副作用：** 无（不检查存在性）。
- **算法：** `File(p.join(appDir.path, relativePath))`。
- **用法：** 被 `delete`、`ImageShareService`、设备编辑器的 `_editImage` 和任何需要显示或读取存储图像文件的 UI 代码调用。
- **备注：** 不验证文件存在；需要时调用方必须单独检查。

### `static Future<void> delete(String relativePath)` <a id="delete"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 191 行）。
- **用途：** 存在时删除先前保存的图像文件。
- **输入：** `relativePath`。
- **返回：** `Future<void>`。
- **副作用：** 文件系统删除。
- **算法：** 经 `resolve()` 解析；只在 `await file.exists()` 时删除。
- **用法：** 设备/服务记录图像引用被移除或替换时调用。
- **备注：** 文件已缺失时静默空操作——非错误条件。

### `static Future<String?> saveImageFromUrl(String url)` <a id="saveimagefromurl"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 205 行）。
- **用途：** 从远程 URL 下载图像并保存进应用存储。
- **输入：** `url`。
- **返回：** `Future<String?>` — 如 `"images/<uuid>.jpg"` 的相对路径，任何非 200 响应时 `null`。
- **副作用：** 网络 GET 请求（15 秒超时，`User-Agent: MyDevice/0.1`）；把下载字节写到 `images/`。
- **算法：** GET URL；状态非 200 返回 `null`。从 URL 路径派生扩展名，空或长于 5 字符时回退 `.jpg`（对照非扩展尾随路径段的粗略健全检查）；生成 UUID 文件名并写响应字节。
- **用法：** 应用从在线源（如在线设备/芯片搜索结果）获取设备/芯片图像的任何地方调用。
- **备注：** 无内容类型验证——扩展名纯粹从 URL 路径推断，非从响应 `Content-Type` 页头。
