# lib/features/profile/services/avatar_image.dart

Pure image operations behind the avatar editor (1.7.1). Every function is synchronous and
allocation-only, so callers run them with `Isolate.run` to keep the UI responsive. The file is a
`library;` with no state. See [`../views/avatar_editor.md`](../views/avatar_editor.md),
[`profile_store.md`](profile_store.md) and [`../../../../features/profile.md`](../../../../features/profile.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AvatarSource` constructor | constructor | B | Create an upright, size-limited copy of a picked image (`bytes`, `width`, `height`). |
| `_decode` | top-level function | B | Decode any image without letting a decoder exception escape. |
| [`prepareAvatarSource`](#prepareavatarsource) | top-level function | A | Normalise a picked image for the editor. |
| [`cropAvatarJpeg`](#cropavatarjpeg) | top-level function | A | Cut the square the user framed and encode it as the avatar. |
| [`squareAvatarJpeg`](#squareavatarjpeg) | top-level function | A | Turn any decodable image into a centred square JPEG. |
| [`prepareAvatarSourceInBackground`](#prepareavatarsourceinbackground) | top-level function | A | Run `prepareAvatarSource` in another isolate. |
| [`cropAvatarJpegInBackground`](#cropavatarjpeginbackground) | top-level function | A | Run `cropAvatarJpeg` in another isolate. |

The class `AvatarSource` and the constant `avatarSourceMaxEdge` (`2048`, the longest edge the editor
works with) carry plain `///` descriptions, not `/// Purpose:` blocks. `squareAvatarJpeg` moved here
from `profile_store.dart` in 1.7.1.

## _decode

- **Notes:** Truncated or foreign data can make a format probe throw (for example a `RangeError`)
  instead of returning null; both become a `FormatException('Not a supported image')`.

## prepareAvatarSource

- **Inputs:** `bytes` — the picked file; `quarterTurns` — extra clockwise 90 degree turns (the
  editor's rotate button), default 0.
- **Returns:** `AvatarSource` — upright (EXIF applied), longest edge at most `avatarSourceMaxEdge`,
  encoded as PNG.
- **Algorithm:** `bakeOrientation`, `copyRotate(angle: 90 * (quarterTurns % 4))`, then `copyResize`
  down to 2048 pixels on the longer edge when needed, then `encodePng`.
- **Notes:** Baking the orientation here means the pixels the editor shows and the pixels
  `cropAvatarJpeg` cuts are the same, whatever the platform's own EXIF handling. Throws
  `FormatException` for non-images.

## cropAvatarJpeg

- **Inputs:** `source` — bytes from `prepareAvatarSource`; `x`, `y`, `side` — the square in source
  pixels; `size` — output edge in pixels.
- **Returns:** `Uint8List` — JPEG bytes, `size` x `size`, quality 88.
- **Algorithm:** Clamps `side` to `1..min(width, height)` and the origin so the square stays inside
  the image, `copyCrop`, `copyResize(interpolation: average)`, `encodeJpg(quality: 88)`.
- **Notes:** The clamp means rounding at the edges never fails. Throws `FormatException` for
  non-images. `test/profile_test.dart` checks that the right half of a two-colour image crops to that
  colour and that an over-large square is clamped.

## squareAvatarJpeg

- **Inputs:** `bytes` — the source image; `size` — output edge in pixels.
- **Returns:** `Uint8List` — JPEG bytes.
- **Notes:** The non-interactive path (no editor): applies EXIF orientation and takes the centred
  square with `copyResizeCropSquare`. Throws `FormatException` for non-images. The 1.7.1 UI no
  longer calls it (the editor path replaced it), but it stays as the centred-crop helper.

## prepareAvatarSourceInBackground

- **Inputs:** `bytes`, `quarterTurns` (default 0).
- **Returns:** `Future<AvatarSource>`.
- **Side effects:** Spawns a short-lived isolate.
- **Notes:** A top-level function on purpose: a closure created inside a widget's State method also captures that State (and its controllers), which cannot be sent to another isolate, so the editor used to fail with "This image could not be used". Here the closure captures only the arguments. `test/profile_test.dart` runs both helpers for real.

## cropAvatarJpegInBackground

- **Inputs:** as `cropAvatarJpeg`.
- **Returns:** `Future<Uint8List>` -- the avatar JPEG.
- **Side effects:** Spawns a short-lived isolate.
- **Notes:** Top-level for the same reason as `prepareAvatarSourceInBackground`.
