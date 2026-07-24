# lib/features/devices/widgets/device_avatar.dart

`DeviceAvatar` is the shared circular avatar renderer used anywhere a device needs an icon (list
tiles, detail headers, search dialogs). It depends on `ImageService.resolve()`
(`../../../../shared/services/image_service.md`) to locate a device's image file and on
[`deviceCategoryIcon`](device_category_icon.md) for the fallback glyph. See
[Devices](../../../../features/devices.md#device-avatar-rendering) for the confirmed precedence
this page mirrors: an emoji, if set, always wins; otherwise a resolved `imagePath` image is shown
center-cropped; any missing/failed image (including `Image.file`'s `errorBuilder`) falls back to
the outline category icon. All of this decision logic lives directly in `build()`, and per this
doc set's tiering rule `build()` methods are indexed as Tier B regardless of how much branching
they contain — see the file overview above and the linked concept doc for the actual behavior.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DeviceAvatar` | constructor | B | Create an avatar for explicit category/emoji/image/size fields. |
| `DeviceAvatar.fromDevice` | factory constructor | B | Create an avatar sized for a given `Device`. |
| `build` | method (`DeviceAvatar`) | B | Render emoji, else resolved image, else category-icon fallback. |
| `_fallbackIcon` | method (`DeviceAvatar`, private) | B | Render the category-icon fallback inside an `_AvatarFrame`. |
| `_fallbackIconContent` | method (`DeviceAvatar`, private) | B | Render the bare category icon (no frame), used by `Image.file`'s `errorBuilder`. |
| `_AvatarFrame` | constructor (private class) | B | Create the shared circular background/border frame. |
| `build` | method (`_AvatarFrame`) | B | Compose the sized, bordered, clipped circle around `child`. |

Row count (7) matches `grep -c 'Purpose:' device_avatar.dart` (7) exactly.

## Documentation

No Tier A declarations in this file — every declaration is either a trivial widget constructor or
a `build`/private-`_build`-style widget-composition method, per this doc set's tiering rule. The
one behavior worth calling out (the emoji → image → category-icon fallback chain, and the
`errorBuilder` catching a failed `Image.file` load) is implemented entirely inside `build()` and is
described in the file overview above and in
[Devices](../../../../features/devices.md#device-avatar-rendering), which was verified directly
against this file's source.
