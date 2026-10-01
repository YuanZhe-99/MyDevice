# lib/features/profile/views/avatar_editor.dart

全屏头像编辑器（1.7.1）：选图之后（或重新打开当前头像时），用户为圆形取景。通过 `showAvatarEditor` 打开，由个人资料对话框的 `_editAvatar`（[`profile_header.md`](profile_header.md)）调用；纯图像处理在 [`../services/avatar_image.md`](../services/avatar_image.md)。见 [`../../../../features/profile.md`](../../../../features/profile.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`showAvatarEditor`](#showavatareditor) | 顶层函数 | A | 让用户为头像取景并返回结果。 |
| `AvatarEditorPage` | 构造函数（`AvatarEditorPage`） | B | 由 `source` 创建编辑器。 |
| `_AvatarEditorPageState.createState` | 方法（组件生命周期） | B | 创建编辑器状态。 |
| `_AvatarEditorPageState.initState` | 方法（组件生命周期） | B | 开始准备图片。 |
| `_AvatarEditorPageState.dispose` | 方法（组件生命周期） | B | 释放变换控制器。 |
| [`_prepare`](#_prepare) | 方法（`_AvatarEditorPageState`） | A | 按当前旋转解码、转正并限制源图尺寸。 |
| [`_rotate`](#_rotate) | 方法（`_AvatarEditorPageState`） | A | 顺时针旋转四分之一圈。 |
| [`_reset`](#_reset) | 方法（`_AvatarEditorPageState`） | A | 回到初始取景。 |
| [`_save`](#_save) | 方法（`_AvatarEditorPageState`） | A | 裁出圆形所显示的内容并返回。 |
| [`build`](#build) | 方法（`_AvatarEditorPageState`，组件构建） | A | 构建编辑器。 |
| `_CircleMaskPainter` | 构造函数（`_CircleMaskPainter`） | B | 由 `scrim` 和 `ring` 创建遮罩绘制器。 |
| [`_CircleMaskPainter.paint`](#paint) | 方法（`CustomPainter`） | A | 绘制带圆形镂空的遮罩和轮廓。 |
| `_CircleMaskPainter.shouldRepaint` | 方法（`CustomPainter`） | B | 仅在颜色变化时重绘。 |

## showAvatarEditor

- **输入：** `context`；`source`——所选图片或当前头像的字节。
- **返回：** `Future<Uint8List?>`——512 像素（`ProfileStore.avatarSize`）的正方形 JPEG；用户退出时为 null。
- **副作用：** 以全屏路由推入 `AvatarEditorPage`。
- **备注：** 对错误输入不抛出异常：无法解码的图片会在编辑器中显示 `profileAvatarError`。

## _prepare

- **副作用：** 设置 `_busy`，在 `Isolate.run` 中运行 `prepareAvatarSource(source, quarterTurns: _turns)`，保存结果并清除 `_failed`；失败则设置 `_failed`。把 `_viewport` 清零会让下一次 `build` 重新居中图片。

## _rotate

- **副作用：** `_turns = (_turns + 1) % 4`，然后再次 `_prepare`（旋转已烘焙进像素，所以取景重置）。

## _reset

- **副作用：** 把变换设为让图片在视口中以 1 倍缩放居中，使其铺满圆形。
- **备注：** 必须在 post-frame 回调中执行——不能在 `build` 期间修改控制器。

## _save

- **副作用：** 读取缩放/平移矩阵，把视口的左上角和尺寸映射回源像素（`x = -tx / scale * toPixels`，`y` 同理，`side = viewport / scale * toPixels`，其中 `toPixels = image.width / baseWidth`），在 `Isolate.run` 中运行 `cropAvatarJpeg(..., size: 512)`，然后带着 JPEG 弹出路由。失败则设置 `_failed`。

## build

- **返回：** 标题为 `profileAdjustAvatar` 的 `Scaffold`，应用栏有**旋转**（`rotate_90_degrees_cw_outlined`，`profileAvatarRotate`）、**重置**（`restart_alt`，`profileAvatarReset`）和**保存** `FilledButton`；忙碌时均禁用。
- **备注：** body 是一个正方形视口（`min(width, height - 96) - 32`，限制在 160–480 dp），内含 `ClipRect` + `InteractiveViewer`（`constrained: false`，`minScale: 1`，`maxScale: 8`，`boundaryMargin: EdgeInsets.zero`，所以图片始终铺满圆形），其下是按铺满正方形排布的图片，上面盖一层 `IgnorePointer` 的 `CustomPaint` 圆形遮罩，下方是 `profileAvatarEditorHint` 文本。视口边长和基准尺寸被记录下来供 `_save` 使用。

## paint

- **副作用：** 用半透明 `scrim` 填充正方形减去内切圆的区域（奇偶填充路径），并以 `ring`（主色）描出向内缩 1 dp 的圆形轮廓。
