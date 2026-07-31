# lib/shared/services/image_service.dart

`ImageService` 处理设备/服务图像的图像文件挑选、URL 下载和删除，把它们以 UUID 命名文件存到应用目录内 `images/` 下（见 [数据格式](../../../data-formats.md)）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`_getImageDir`](#getimagedir) | 静态方法 | A | 解析（缺失时创建）应用 `images/` 目录。 |
| [`pickAndSaveImage`](#pickandsaveimage) | 静态方法 | A | 让用户挑选图像文件并复制进应用存储。 |
| [`resolve`](#resolve) | 静态方法 | A | 把相对 `images/...` 路径解析为绝对 `File`。 |
| [`delete`](#delete) | 静态方法 | A | 按相对路径删除先前保存的图像。 |
| [`saveImageFromUrl`](#saveimagefromurl) | 静态方法 | A | 从 URL 下载图像进应用存储。 |

## 文档

### `static Future<Directory> _getImageDir()` <a id="getimagedir"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 16 行）。
- **用途：** 解析应用 `images/` 子目录，不存在时创建。
- **输入：** 无。
- **返回：** `Future<Directory>`。
- **副作用：** 文件系统：缺席时创建目录（递归）。
- **算法：** 经 `DeviceStorage.getAppDir()` `p.join(appDir.path, 'images')`；`!await imgDir.exists()` 时递归创建。
- **用法：** 被 `pickAndSaveImage` 和 `saveImageFromUrl` 调用。
- **备注：** 遵循全应用规则，所有文件 IO 经存储枢纽 `getAppDir()`，使自定义存储路径工作（见本仓库 `AGENTS.md`）。

### `static Future<String?> pickAndSaveImage()` <a id="pickandsaveimage"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 32 行）。
- **用途：** 让用户经系统文件选择器挑选图像文件并以新 UUID 文件名复制进应用存储。
- **输入：** 无。
- **返回：** `Future<String?>` — 如 `"images/<uuid>.png"` 的相对路径，用户取消或所选路径不可用时 `null`。
- **副作用：** 打开原生文件选择器（`FilePicker.platform.pickFiles`）；把所选文件复制进 `images/`。
- **算法：** 挑单个图像文件；取消或无路径返回 `null`；否则生成 `'${Uuid().v4()}$ext'`（保留原始扩展名）并把源 `File.copy` 进 `_getImageDir()`。
- **用法：** 从设备/服务编辑页"添加图像"流程调用。
- **备注：** 原始文件被复制而非移动——用户挑的源文件在磁盘上保持不动。

### `static Future<File> resolve(String relativePath)` <a id="resolve"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 55 行）。
- **用途：** 把相对 `imagePath`（如模型中存储的 `"images/xxx.png"`）变为应用目录下绝对 `File`。
- **输入：** `relativePath`。
- **返回：** `Future<File>`。
- **副作用：** 无（不检查存在性）。
- **算法：** `File(p.join(appDir.path, relativePath))`。
- **用法：** 被 `delete`、`ImageShareService` 和任何需要显示或读取存储图像文件的 UI 代码调用。
- **备注：** 不验证文件存在；需要时调用方必须单独检查。

### `static Future<void> delete(String relativePath)` <a id="delete"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 66 行）。
- **用途：** 存在时删除先前保存的图像文件。
- **输入：** `relativePath`。
- **返回：** `Future<void>`。
- **副作用：** 文件系统删除。
- **算法：** 经 `resolve()` 解析；只在 `await file.exists()` 时删除。
- **用法：** 设备/服务记录图像引用被移除或替换时调用。
- **备注：** 文件已缺失时静默空操作——非错误条件。

### `static Future<String?> saveImageFromUrl(String url)` <a id="saveimagefromurl"></a>
- **种类：** `ImageService` 的静态方法。
- **来源：** `lib/shared/services/image_service.dart`（第 80 行）。
- **用途：** 从远程 URL 下载图像并保存进应用存储。
- **输入：** `url`。
- **返回：** `Future<String?>` — 如 `"images/<uuid>.jpg"` 的相对路径，任何非 200 响应时 `null`。
- **副作用：** 网络 GET 请求（15 秒超时，`User-Agent: MyDevice/0.1`）；把下载字节写到 `images/`。
- **算法：** GET URL；状态非 200 返回 `null`。从 URL 路径派生扩展名，空或长于 5 字符时回退 `.jpg`（对照非扩展尾随路径段的粗略健全检查）；生成 UUID 文件名并写响应字节。
- **用法：** 应用从在线源（如在线设备/芯片搜索结果）获取设备/芯片图像的任何地方调用。
- **备注：** 无内容类型验证——扩展名纯粹从 URL 路径推断，非从响应 `Content-Type` 页头。
