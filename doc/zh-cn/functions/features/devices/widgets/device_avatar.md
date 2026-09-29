# lib/features/devices/widgets/device_avatar.dart

`DeviceAvatar` 是任何设备需要图标时使用的共享圆形头像渲染器（列表块、详情页头、搜索对话框）。它依赖 `ImageService.resolve()`（`../../../../shared/services/image_service.md`）定位设备图像文件，依赖 [`PresetService.isTemplateImage`](../services/preset_service.md#istemplateimage) 和 [`PresetService.matchTemplateImage`](../services/preset_service.md#matchtemplateimage) 获取内置模板缩略图，依赖 [`deviceCategoryIcon`](device_category_icon.md) 作为回退字形。本页镜像的确认优先级见 [设备 — 设备头像渲染](../../../../features/devices.md#device-avatar-rendering)：emoji 已设总是胜出；否则显示中心裁剪的解析 `imagePath` 图像；否则在手选的 `templateImage` 缩略图仍内置时显示它；否则显示（按品牌/型号/名称）匹配模板的缩略图；任何缺失/失败图像（含各个 `errorBuilder`）回退轮廓类别图标。按本文档集分层规则，`build()` 方法和私有组件组合辅助方法无论含多少分支都索引为 Tier B。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `createState` | 方法（`DeviceAvatar`） | B | 创建缓存图片查找的状态。 |
| `_resolveFile` | 方法（`_DeviceAvatarState`，私有） | B | 返回把图片路径解析为文件的已缓存 future。 |
| `DeviceAvatar` | 构造函数 | B | 为显式类别/emoji/图像/templateImage/身份/尺寸字段创建头像。 |
| `DeviceAvatar.fromDevice` | 工厂构造函数 | B | 为给定 `Device` 创建头像，并传入其 `templateImage` 和品牌/型号/名称用于模板匹配。 |
| `build` | 方法（`DeviceAvatar`） | B | 渲染 emoji，否则解析图像，否则模板缩略图，否则类别图标。 |
| `_templateOrFallback` | 方法（`DeviceAvatar`，私有） | B | 解析手选或匹配的模板缩略图（目录缓存后同步进行），否则回退。 |
| `_resolveTemplate` | 方法（`DeviceAvatar`，私有） | B | 手选资源仍内置时返回它，否则返回自动匹配的资源，或 null。 |
| `_templateImage` | 方法（`DeviceAvatar`，私有） | B | 在 `surfaceContainerHighest` 色圆上渲染内置的圆内安全缩略图。 |
| `_fallbackIcon` | 方法（`DeviceAvatar`，私有） | B | 在 `_AvatarFrame` 内渲染类别图标回退。 |
| `_fallbackIconContent` | 方法（`DeviceAvatar`，私有） | B | 渲染裸类别图标（无框），供各个图像 `errorBuilder` 使用。 |
| `_AvatarFrame` | 构造函数（私有类） | B | 创建共享圆形背景/边框框。 |
| `build` | 方法（`_AvatarFrame`） | B | 围绕 `child` 组合尺寸化、带边框、裁剪圆。 |

行数（12）与 `grep -c 'Purpose:' device_avatar.dart`（12）精确匹配。

自 1.6.2 起 `DeviceAvatar` 是 `StatefulWidget`（上面的 `build` 和辅助行现在位于 `_DeviceAvatarState`）：`ImageService.resolve` 的 future 每个图片路径只创建一次，而非在每次 `build` 中创建，`ImageService.cachedResolve` 提供 `initialData`，`Image.file` 按头像尺寸解码（`cacheWidth`），因此滚动列表既不闪现回退图标，也不解码全分辨率照片。

## 文档

本文件无 Tier A 声明。值得点出的行为是回退链 **emoji → 用户照片 → 手选缩略图 → 匹配的模板缩略图 → 类别图标**，以及缩略图这几步的三个细节：

- 手选缩略图是设备存储的 `templateImage` 字段（见 [`Device`](../models/device.md)），由编辑器的缩略图选择器或 [`DeviceTemplate.toDevice`](../services/preset_service.md#todevice) 设置。`_resolveTemplate` 只在 [`PresetService.isTemplateImage`](../services/preset_service.md#istemplateimage) 确认该资源仍在目录中时才使用它；后续版本改名或删除的缩略图会被忽略、转而自动匹配，而不是显示损坏的图像。
- 自动匹配仍只用于显示。匹配到的资源路径绝不存储在设备上，因此缩略图出现之前创建的设备也能获得缩略图。
- 目录已加载时，`_templateOrFallback` 对照 `PresetService.cachedTemplates` 同步解析，只在首次加载时对 `PresetService.loadTemplates()` 使用 `FutureBuilder`。这避免列表重建时闪现类别图标。

缩略图是透明的，并且每个可见像素都已位于内切圆内（见 [在线搜索与预设](../../../../features/online-search-and-presets.md)），因此以 `BoxFit.contain` 按完整直径绘制，不做裁剪。
