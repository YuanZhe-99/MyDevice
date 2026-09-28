# lib/features/devices/widgets/device_avatar.dart

`DeviceAvatar` is the shared circular avatar renderer used anywhere a device needs an icon (list
tiles, detail headers, search dialogs). It depends on `ImageService.resolve()`
(`../../../../shared/services/image_service.md`) to locate a device's image file, on
[`PresetService.matchTemplateImage`](../services/preset_service.md#matchtemplateimage) for the
bundled template thumbnail, and on [`deviceCategoryIcon`](device_category_icon.md) for the
fallback glyph. See [Devices](../../../../features/devices.md#device-avatar-rendering) for the
confirmed precedence this page mirrors: an emoji, if set, always wins; otherwise a resolved
`imagePath` image is shown center-cropped; otherwise the thumbnail of a matching template (by
brand/model/name) is shown; any missing/failed image (including the `errorBuilder`s) falls back to
the outline category icon. Per this doc set's tiering rule, `build()` methods and private
widget-composition helpers are indexed as Tier B regardless of how much branching they contain.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DeviceAvatar` | constructor | B | Create an avatar for explicit category/emoji/image/identity/size fields. |
| `DeviceAvatar.fromDevice` | factory constructor | B | Create an avatar for a given `Device`, passing its brand/model/name for template matching. |
| `build` | method (`DeviceAvatar`) | B | Render emoji, else resolved image, else template thumbnail, else category icon. |
| `_templateOrFallback` | method (`DeviceAvatar`, private) | B | Resolve the matching template thumbnail (synchronously once the catalog is cached) or fall back. |
| `_templateImage` | method (`DeviceAvatar`, private) | B | Render a bundled, circle-safe thumbnail on a `surfaceContainerHighest` circle. |
| `_fallbackIcon` | method (`DeviceAvatar`, private) | B | Render the category-icon fallback inside an `_AvatarFrame`. |
| `_fallbackIconContent` | method (`DeviceAvatar`, private) | B | Render the bare category icon (no frame), used by the image `errorBuilder`s. |
| `_AvatarFrame` | constructor (private class) | B | Create the shared circular background/border frame. |
| `build` | method (`_AvatarFrame`) | B | Compose the sized, bordered, clipped circle around `child`. |

Row count (9) matches `grep -c 'Purpose:' device_avatar.dart` (9) exactly.

## Documentation

No Tier A declarations in this file. The behavior worth calling out is the fallback chain
**emoji → user photo → template thumbnail → category icon**, and two details of the thumbnail step:

- It is display-only. The matched asset path is never stored on the device, so no data format,
  sync payload or backup changes, and a device created before thumbnails existed still gets one.
- `_templateOrFallback` matches synchronously against `PresetService.cachedTemplates` when the
  catalog is loaded, and only uses a `FutureBuilder` for the very first load. This keeps list
  rebuilds from flashing the category icon.

Thumbnails are transparent and already keep every visible pixel inside the inscribed circle (see
[Online Search and Presets](../../../../features/online-search-and-presets.md)), so they are drawn
with `BoxFit.contain` at the full diameter without cropping.
