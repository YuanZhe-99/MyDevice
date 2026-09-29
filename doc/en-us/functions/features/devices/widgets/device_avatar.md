# lib/features/devices/widgets/device_avatar.dart

`DeviceAvatar` is the shared circular avatar renderer used anywhere a device needs an icon (list
tiles, detail headers, search dialogs). It depends on `ImageService.resolve()`
(`../../../../shared/services/image_service.md`) to locate a device's image file, on
[`PresetService.isTemplateImage`](../services/preset_service.md#istemplateimage) and
[`PresetService.matchTemplateImage`](../services/preset_service.md#matchtemplateimage) for the
bundled template thumbnail, and on [`deviceCategoryIcon`](device_category_icon.md) for the
fallback glyph. See [Devices](../../../../features/devices.md#device-avatar-rendering) for the
confirmed precedence this page mirrors: an emoji, if set, always wins; otherwise a resolved
`imagePath` image is shown center-cropped; otherwise the hand-picked `templateImage` thumbnail is
shown while it is still bundled; otherwise the thumbnail of a matching template (by
brand/model/name) is shown; any missing/failed image (including the `errorBuilder`s) falls back to
the outline category icon. Per this doc set's tiering rule, `build()` methods and private
widget-composition helpers are indexed as Tier B regardless of how much branching they contain.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `createState` | method (`DeviceAvatar`) | B | Create the state that caches the image lookup. |
| `_resolveFile` | method (`_DeviceAvatarState`, private) | B | Return the cached future resolving the image path to a file. |
| `DeviceAvatar` | constructor | B | Create an avatar for explicit category/emoji/image/templateImage/identity/size fields. |
| `DeviceAvatar.fromDevice` | factory constructor | B | Create an avatar for a given `Device`, passing its `templateImage` and brand/model/name for template matching. |
| `build` | method (`DeviceAvatar`) | B | Render emoji, else resolved image, else template thumbnail, else category icon. |
| `_templateOrFallback` | method (`DeviceAvatar`, private) | B | Resolve the chosen or matching template thumbnail (synchronously once the catalog is cached) or fall back. |
| `_resolveTemplate` | method (`DeviceAvatar`, private) | B | Return the hand-picked asset while it is still bundled, otherwise the automatically matched one, or null. |
| `_templateImage` | method (`DeviceAvatar`, private) | B | Render a bundled, circle-safe thumbnail on a `surfaceContainerHighest` circle. |
| `_fallbackIcon` | method (`DeviceAvatar`, private) | B | Render the category-icon fallback inside an `_AvatarFrame`. |
| `_fallbackIconContent` | method (`DeviceAvatar`, private) | B | Render the bare category icon (no frame), used by the image `errorBuilder`s. |
| `_AvatarFrame` | constructor (private class) | B | Create the shared circular background/border frame. |
| `build` | method (`_AvatarFrame`) | B | Compose the sized, bordered, clipped circle around `child`. |

Row count (12) matches `grep -c 'Purpose:' device_avatar.dart` (12) exactly.

Since 1.6.2 `DeviceAvatar` is a `StatefulWidget` (the `build` and helper rows above now live on
`_DeviceAvatarState`): the `ImageService.resolve` future is created once per image path instead of
in every `build`, `ImageService.cachedResolve` supplies `initialData`, and `Image.file` decodes at
avatar size (`cacheWidth`), so scrolling lists neither flash the fallback icon nor decode
full-resolution photos.

## Documentation

No Tier A declarations in this file. The behavior worth calling out is the fallback chain
**emoji → user photo → hand-picked thumbnail → matched template thumbnail → category icon**, and
three details of the thumbnail steps:

- A hand-picked thumbnail is the device's stored `templateImage` field (see
  [`Device`](../models/device.md)), set by the editor's thumbnail chooser or by
  [`DeviceTemplate.toDevice`](../services/preset_service.md#todevice). `_resolveTemplate` uses it
  only while [`PresetService.isTemplateImage`](../services/preset_service.md#istemplateimage)
  confirms the asset is still in the catalog; a thumbnail a later release renamed or dropped is
  ignored in favour of automatic matching instead of showing a broken image.
- Automatic matching stays display-only. The matched asset path is never stored on the device, so a
  device created before thumbnails existed still gets one.
- `_templateOrFallback` resolves synchronously against `PresetService.cachedTemplates` when the
  catalog is loaded, and only uses a `FutureBuilder` over `PresetService.loadTemplates()` for the
  very first load. This keeps list rebuilds from flashing the category icon.

Thumbnails are transparent and already keep every visible pixel inside the inscribed circle (see
[Online Search and Presets](../../../../features/online-search-and-presets.md)), so they are drawn
with `BoxFit.contain` at the full diameter without cropping.
