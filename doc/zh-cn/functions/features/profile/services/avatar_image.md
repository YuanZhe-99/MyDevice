# lib/features/profile/services/avatar_image.dart

头像编辑器背后的纯图像操作（1.7.1）。每个函数都是同步且只做内存分配，因此调用方用 `Isolate.run` 运行它们，让界面保持流畅。该文件是没有状态的 `library;`。见 [`../views/avatar_editor.md`](../views/avatar_editor.md)、[`profile_store.md`](profile_store.md) 和 [`../../../../features/profile.md`](../../../../features/profile.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AvatarSource` 构造函数 | 构造函数 | B | 创建所选图片经转正、限制尺寸后的副本（`bytes`、`width`、`height`）。 |
| `_decode` | 顶层函数 | B | 解码任何图片，且不让解码器异常外泄。 |
| [`prepareAvatarSource`](#prepareavatarsource) | 顶层函数 | A | 为编辑器规范化所选图片。 |
| [`cropAvatarJpeg`](#cropavatarjpeg) | 顶层函数 | A | 裁出用户取景的正方形并编码为头像。 |
| [`squareAvatarJpeg`](#squareavatarjpeg) | 顶层函数 | A | 把任何可解码的图片变成居中裁剪的正方形 JPEG。 |

类 `AvatarSource` 和常量 `avatarSourceMaxEdge`（`2048`，编辑器处理的最长边）只带普通 `///` 描述，没有 `/// Purpose:` 块。`squareAvatarJpeg` 在 1.7.1 中从 `profile_store.dart` 移到这里。

## _decode

- **备注：** 被截断或不属于图片的数据可能让格式探测抛出异常（例如 `RangeError`）而不是返回 null；两者都变成 `FormatException('Not a supported image')`。

## prepareAvatarSource

- **输入：** `bytes`——所选文件；`quarterTurns`——额外的顺时针 90 度旋转次数（编辑器的旋转按钮），默认 0。
- **返回：** `AvatarSource`——已转正（应用 EXIF）、最长边不超过 `avatarSourceMaxEdge`、编码为 PNG。
- **算法：** `bakeOrientation`，`copyRotate(angle: 90 * (quarterTurns % 4))`，必要时 `copyResize` 把长边缩到 2048 像素，然后 `encodePng`。
- **备注：** 在这里烘焙方向，意味着编辑器显示的像素与 `cropAvatarJpeg` 裁剪的像素相同，不论平台自己如何处理 EXIF。对非图片抛出 `FormatException`。

## cropAvatarJpeg

- **输入：** `source`——来自 `prepareAvatarSource` 的字节；`x`、`y`、`side`——源像素中的正方形；`size`——输出边长（像素）。
- **返回：** `Uint8List`——`size` x `size` 的 JPEG 字节，质量 88。
- **算法：** 把 `side` 钳到 `1..min(width, height)`，并钳制起点使正方形留在图内，`copyCrop`，`copyResize(interpolation: average)`，`encodeJpg(quality: 88)`。
- **备注：** 钳制意味着边缘处的取整永远不会失败。对非图片抛出 `FormatException`。`test/profile_test.dart` 检查双色图的右半裁出该颜色，以及过大的正方形会被钳制。

## squareAvatarJpeg

- **输入：** `bytes`——源图片；`size`——输出边长（像素）。
- **返回：** `Uint8List`——JPEG 字节。
- **备注：** 非交互路径（不经编辑器）：应用 EXIF 方向，并用 `copyResizeCropSquare` 取居中正方形。对非图片抛出 `FormatException`。1.7.1 的界面不再调用它（编辑器路径取代了它），但它保留为居中裁剪助手。
