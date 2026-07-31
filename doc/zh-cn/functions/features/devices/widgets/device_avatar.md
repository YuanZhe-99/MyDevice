# lib/features/devices/widgets/device_avatar.dart

`DeviceAvatar` 是任何设备需要图标时使用的共享圆形头像渲染器（列表块、详情页头、搜索对话框）。它依赖 `ImageService.resolve()`（`../../../../shared/services/image_service.md`）定位设备图像文件，依赖 [`deviceCategoryIcon`](device_category_icon.md) 作为回退字形。本页镜像的确认优先级见 [设备 — 设备头像渲染](../../../../features/devices.md#device-avatar-rendering)：emoji 已设总是胜出；否则显示中心裁剪的解析 `imagePath` 图像；任何缺失/失败图像（含 `Image.file` 的 `errorBuilder`）回退轮廓类别图标。所有这些决策逻辑直接住在 `build()`，按本文档集分层规则 `build()` 方法无论含多少分支都索引为 Tier B——实际行为见上面文件总览和链接概念文档。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `DeviceAvatar` | 构造函数 | B | 为显式类别/emoji/图像/尺寸字段创建头像。 |
| `DeviceAvatar.fromDevice` | 工厂构造函数 | B | 为给定 `Device` 创建合适尺寸头像。 |
| `build` | 方法（`DeviceAvatar`） | B | 渲染 emoji，否则解析图像，否则类别图标回退。 |
| `_fallbackIcon` | 方法（`DeviceAvatar`，私有） | B | 在 `_AvatarFrame` 内渲染类别图标回退。 |
| `_fallbackIconContent` | 方法（`DeviceAvatar`，私有） | B | 渲染裸类别图标（无框），供 `Image.file` 的 `errorBuilder` 使用。 |
| `_AvatarFrame` | 构造函数（私有类） | B | 创建共享圆形背景/边框框。 |
| `build` | 方法（`_AvatarFrame`） | B | 围绕 `child` 组合尺寸化、带边框、裁剪圆。 |

行数（7）与 `grep -c 'Purpose:' device_avatar.dart`（7）精确匹配。

## 文档

本文件无 Tier A 声明——按本文档集分层规则，每个声明要么是平凡组件构造函数，要么是 `build`/私有 `_build` 风格组件组合方法。值得点出的一个行为（emoji → 图像 → 类别图标回退链，和 `errorBuilder` 捕获失败 `Image.file` 加载）完全在 `build()` 内实现，在文件总览和 [设备 — 设备头像渲染](../../../../features/devices.md#device-avatar-rendering) 描述，后者直接对照本文件源码验证。
