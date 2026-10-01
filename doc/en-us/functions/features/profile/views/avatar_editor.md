# lib/features/profile/views/avatar_editor.dart

The full-screen avatar editor (1.7.1): after an image is picked (or the current avatar is reopened),
the user frames the circle. Opened through `showAvatarEditor`, called by the profile dialog's
`_editAvatar` ([`profile_header.md`](profile_header.md)); the pure image work is in
[`../services/avatar_image.md`](../services/avatar_image.md). See
[`../../../../features/profile.md`](../../../../features/profile.md#avatar-editor-since-171).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`showAvatarEditor`](#showavatareditor) | top-level function | A | Let the user frame an avatar and return the result. |
| `AvatarEditorPage` | constructor (`AvatarEditorPage`) | B | Create the editor from `source`. |
| `_AvatarEditorPageState.createState` | method (widget lifecycle) | B | Create the editor state. |
| `_AvatarEditorPageState.initState` | method (widget lifecycle) | B | Start preparing the image. |
| `_AvatarEditorPageState.dispose` | method (widget lifecycle) | B | Release the transformation controller. |
| [`_prepare`](#_prepare) | method (`_AvatarEditorPageState`) | A | Decode, orient and size the source for the current rotation. |
| [`_rotate`](#_rotate) | method (`_AvatarEditorPageState`) | A | Rotate a quarter turn clockwise. |
| [`_reset`](#_reset) | method (`_AvatarEditorPageState`) | A | Return to the initial framing. |
| [`_save`](#_save) | method (`_AvatarEditorPageState`) | A | Crop what the circle shows and return it. |
| [`build`](#build) | method (`_AvatarEditorPageState`, widget build) | A | Build the editor. |
| `_CircleMaskPainter` | constructor (`_CircleMaskPainter`) | B | Create the mask painter from `scrim` and `ring`. |
| [`_CircleMaskPainter.paint`](#paint) | method (`CustomPainter`) | A | Paint the scrim with a circular hole and the outline. |
| `_CircleMaskPainter.shouldRepaint` | method (`CustomPainter`) | B | Repaint only when the colours change. |

## showAvatarEditor

- **Inputs:** `context`; `source` — the picked image or the current avatar's bytes.
- **Returns:** `Future<Uint8List?>` — a 512-pixel (`ProfileStore.avatarSize`) square JPEG, or null
  when the user backed out.
- **Side effects:** Pushes `AvatarEditorPage` as a full-screen route.
- **Notes:** Throws nothing for bad input: an undecodable image shows `profileAvatarError` in the
  editor instead.

## _prepare

- **Side effects:** Sets `_busy`, runs `prepareAvatarSource(source, quarterTurns: _turns)` in
  `Isolate.run`, stores the result and clears `_failed`; a failure sets `_failed`. Zeroing `_viewport`
  makes the next `build` re-centre the image.

## _rotate

- **Side effects:** `_turns = (_turns + 1) % 4`, then `_prepare` again (the rotation is baked into
  the pixels, so the framing resets).

## _reset

- **Side effects:** Sets the transformation to centre the image in the viewport at zoom 1, so it
  covers the circle.
- **Notes:** Must run in a post-frame callback — a controller cannot be changed during `build`.

## _save

- **Side effects:** Reads the zoom/pan matrix, maps the viewport's top-left and size back to source
  pixels (`x = -tx / scale * toPixels`, likewise `y`, `side = viewport / scale * toPixels`, where
  `toPixels = image.width / baseWidth`), runs `cropAvatarJpeg(..., size: 512)` in `Isolate.run`, then
  pops the route with the JPEG. A failure sets `_failed`.

## build

- **Returns:** A `Scaffold` titled `profileAdjustAvatar` with **Rotate** (`rotate_90_degrees_cw_outlined`,
  `profileAvatarRotate`), **Reset** (`restart_alt`, `profileAvatarReset`) and a **Save** `FilledButton`
  in the app bar; all disabled while busy.
- **Notes:** The body is a square viewport (`min(width, height - 96) - 32`, clamped to 160-480 dp)
  holding a `ClipRect` + `InteractiveViewer` (`constrained: false`, `minScale: 1`, `maxScale: 8`,
  `boundaryMargin: EdgeInsets.zero`, so the image always covers the circle) over the image laid out
  to cover the square, with an `IgnorePointer` `CustomPaint` circle mask on top, and the
  `profileAvatarEditorHint` text underneath. The viewport side and base size are recorded for `_save`.

## paint

- **Side effects:** Fills the square minus the inscribed circle (an even-odd path) with the translucent `scrim`,
  and strokes the circle, deflated by 1 dp, in `ring` (the primary colour).
