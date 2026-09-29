# lib/shared/utils/device_image_processing.dart

The device-image pipeline shared by the in-app image editor
([`device_image_editor_page.md`](../../features/devices/views/device_image_editor_page.md)) and the
thumbnail tooling: `tool/prepare_device_image.dart` (which re-exports `applyRoundRectMask`,
`fitIntoCircle`, `prepareDeviceImage`, `removeEdgeBackground` and `removeSpecks`),
`tool/device_image_check.dart` (which re-exports `checkDeviceImage` and the three constants) and
`tool/validate_json.dart` (which runs `checkDeviceImage` over every bundled thumbnail). It is pure
Dart on `package:image` with no Flutter imports, so `processDeviceImage` can run inside
`Isolate.run` and the tools can run under `dart run`. The rules a bundled thumbnail must meet —
square, transparent, every visible pixel inside the avatar circle — live here too, so the app, the
tools and the tests (`test/device_image_test.dart`, `test/device_image_editor_test.dart`) share
one definition. `ImageService.loadEditableImage` / `decodeEditableImage`
([`image_service.md`](../services/image_service.md)) build the `DeviceImageEditRequest` the editor
starts from. The user-facing behavior is described in
[Devices — Icon and image](../../../features/devices.md#icon-and-image) and the bundled-thumbnail
rules in [Online Search and Presets — Device thumbnails](../../../features/online-search-and-presets.md#device-thumbnails).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`checkDeviceImage`](#checkdeviceimage) | top-level function | A | Check a decoded thumbnail against the device-image rules. |
| [`prepareDeviceImage`](#preparedeviceimage) | top-level function | A | Run the whole thumbnail pipeline on a decoded image. |
| [`applyRoundRectMask`](#applyroundrectmask) | top-level function | A | Keep only a rounded rectangle filling the image. |
| [`removeSpecks`](#removespecks) | top-level function | A | Clear small opaque islands left behind by background removal. |
| `_edgesTransparent` | private top-level function | B | Tell whether the image border is already fully transparent. |
| `_borderPixels` | private top-level function (generator) | B | Enumerate the coordinates on an image's outer border. |
| [`removeEdgeBackground`](#removeedgebackground) | top-level function | A | Make a plain background transparent by flooding in from the edges. |
| [`fitIntoCircle`](#fitintocircle) | top-level function | A | Trim to visible content and centre it inside the circle-safe box. |
| `_premultiply` | private top-level function | B | Convert an RGBA image between straight and premultiplied alpha. |
| [`DeviceImageEditRequest`](#deviceimageeditrequest) (constructor) | const constructor | A | Create an image edit request. |
| [`copyWith`](#copywith) | method (`DeviceImageEditRequest`) | A | Copy this request with some settings changed. |
| [`cropRectOf`](#croprectof) | top-level function | A | Turn the region a request keeps into source pixels. |
| [`processDeviceImage`](#processdeviceimage) | top-level function | A | Run the editor's pipeline and encode the result. |

Row count (13) matches `grep -c 'Purpose:' device_image_processing.dart` (13) exactly. The three
constants (`deviceImageSize` = 256, `deviceImageSafeFraction` = 0.64, `deviceImageAlphaThreshold`
= 8), the `DeviceImageEditRequest` class and its fields carry plain `///` doc comments rather than
`Purpose:` blocks; they are described in the entries below and are not separate rows.

## Documentation

### `List<String> checkDeviceImage(img.Image image)` <a id="checkdeviceimage"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/device_image_processing.dart` (line 35).
- **Purpose:** Check a decoded thumbnail against the device-image rules.
- **Inputs:** `image` — the decoded PNG.
- **Returns:** `List<String>` of human-readable problems; empty when the image passes.
- **Side effects:** None.
- **Algorithm:**
  1. Not square → one problem, return immediately.
  2. Width under 128 px → problem (checking continues).
  3. Fewer than 4 channels → "no alpha channel; background was not removed", return.
  4. Any of the four corners with alpha ≠ 0 → one "background remains" problem (the first
     offending corner only).
  5. Counts pixels with alpha above `deviceImageAlphaThreshold` (8) whose centre lies outside the
     inscribed circle of radius `width / 2 − 1`; a non-zero count adds one problem.
- **Usage:** `tool/validate_json.dart` (`for (final problem in checkDeviceImage(decoded))`) for
  every template `image`; `tool/prepare_device_image.dart` on its output (exit code 1 on
  problems); `test/device_image_test.dart`.
- **Notes:** The circle rule exists because every avatar that shows the image clips it to that
  circle. A user's own edited photo is never checked — it may legitimately fill past the circle.

### `img.Image prepareDeviceImage(img.Image source, {int tolerance = 28, double? roundRect, bool removeBackground = true, int maxSource = 1024, int size = deviceImageSize, double safeFraction = deviceImageSafeFraction})` <a id="preparedeviceimage"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/device_image_processing.dart` (line 87).
- **Purpose:** Run the whole thumbnail pipeline on a decoded image.
- **Inputs:** `source`; `tolerance` — colour distance counted as background; `roundRect` — when
  set, the corner-radius fraction for [`applyRoundRectMask`](#applyroundrectmask), used instead of
  background removal; `removeBackground` — false keeps every pixel; `maxSource` — longest side
  processed; `size`, `safeFraction` — passed to [`fitIntoCircle`](#fitintocircle).
- **Returns:** A new `size`-square RGBA image.
- **Side effects:** None (works on a converted copy of `source`).
- **Algorithm:**
  1. Converts to 4-channel uint8; if the longer side exceeds `maxSource`, resizes it down to
     `maxSource` (average interpolation).
  2. If `roundRect != null`, applies the rounded mask; else if `removeBackground`, runs
     [`removeEdgeBackground`](#removeedgebackground) unless the border is already transparent
     (`_edgesTransparent`), then [`removeSpecks`](#removespecks).
  3. Returns `fitIntoCircle(work, size: size, safeFraction: safeFraction)`.
- **Usage:** [`processDeviceImage`](#processdeviceimage) (after cropping);
  `tool/prepare_device_image.dart`
  (`prepareDeviceImage(decoded, tolerance: tolerance, roundRect: roundRect, removeBackground: !keepBackground)`).
- **Notes:** The transparent-border skip guards against the failure that broke the Switch OLED and
  Steam Deck cut-outs before 1.6.1: flood-filling an already transparent render damages it. The mask suits a phone or tablet photographed straight on
  against a busy surface, where a flood fill cannot tell background from device.

### `void applyRoundRectMask(img.Image image, double radiusFraction)` <a id="applyroundrectmask"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/device_image_processing.dart` (line 122).
- **Purpose:** Keep only a rounded rectangle filling the image.
- **Inputs:** `image` — RGBA, modified in place; `radiusFraction` — corner radius as a fraction of
  the shorter side.
- **Returns:** None.
- **Side effects:** Scales alpha down outside the rounded rectangle.
- **Algorithm:** `r = min(w, h) × radiusFraction`. Only pixels in the four `r × r` corner squares
  are visited; each is sampled 4×4 against the rounded rectangle and its alpha multiplied by the
  covered fraction (`cover / 16`).
- **Usage:** [`prepareDeviceImage`](#preparedeviceimage) when `roundRect` is set — from the editor's
  **Rounded corners** switch (fraction 0.12) and `tool/prepare_device_image.dart --roundrect`.
- **Notes:** Antialiased edge rather than stair steps. The caller crops tightly to the device
  first.

### `void removeSpecks(img.Image image, {double minFraction = 0.02})` <a id="removespecks"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/device_image_processing.dart` (line 155).
- **Purpose:** Clear small opaque islands left behind by background removal.
- **Inputs:** `image` — RGBA, modified in place; `minFraction` — share of the largest island's
  area below which an island is cleared.
- **Returns:** None.
- **Side effects:** Sets alpha 0 on the pixels of small islands.
- **Algorithm:** Labels 8-connected islands of pixels above `deviceImageAlphaThreshold` with an
  explicit stack; if there are at least two, clears every island smaller than
  `largest × minFraction`.
- **Usage:** [`prepareDeviceImage`](#preparedeviceimage) after background removal.
- **Notes:** Shadow fragments and noise would otherwise stretch the trim box and shrink the
  device. 8-connectivity keeps a thin cable attached.

### `void removeEdgeBackground(img.Image image, int tolerance)` <a id="removeedgebackground"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/device_image_processing.dart` (line 235).
- **Purpose:** Make a plain background transparent by flooding in from the edges.
- **Inputs:** `image` — RGBA uint8, modified in place; `tolerance` — Euclidean RGB distance counted
  as background.
- **Returns:** None.
- **Side effects:** Rewrites the alpha of background pixels in `image`.
- **Algorithm:**
  1. Reference colour = per-channel median of the border pixels.
  2. Seeds a 4-connected breadth-first flood with every border pixel within `tolerance`, and grows
     it through neighbours within `tolerance`.
  3. Flooded pixels get alpha 0; a non-flooded pixel touching the flood and within
     `2 × tolerance` gets half alpha (a one-pixel feather).
- **Usage:** [`prepareDeviceImage`](#preparedeviceimage); re-exported by
  `tool/prepare_device_image.dart`.
- **Notes:** The median resists a vignette or a stray corner. Only pixels connected to the border
  are cleared, so a white screen or logo inside the device survives.

### `img.Image fitIntoCircle(img.Image image, {int size = deviceImageSize, double safeFraction = deviceImageSafeFraction})` <a id="fitintocircle"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/device_image_processing.dart` (line 298).
- **Purpose:** Trim to visible content and centre it inside the circle-safe box.
- **Inputs:** `image` with transparency; `size` — output edge length; `safeFraction` — fraction of
  the edge the content's longer side fills.
- **Returns:** A new `size`-square RGBA image (fully transparent when nothing is visible).
- **Side effects:** None.
- **Algorithm:**
  1. Finds the bounding box of pixels above `deviceImageAlphaThreshold`; none → empty canvas.
  2. Crops to it, scales so the longer side is `floor(size × safeFraction)`, preserving aspect.
  3. Resamples in premultiplied alpha (`_premultiply` forward, resize, back) and composites the
     result centred on a transparent canvas.
- **Usage:** [`prepareDeviceImage`](#preparedeviceimage); re-exported by
  `tool/prepare_device_image.dart`.
- **Notes:** With the default `deviceImageSafeFraction` (0.64; 0.64 × √2 < 1, the same safe box
  `TemplateIcon` uses) the bounding box — and so every visible pixel — lies inside the inscribed
  circle. Larger fractions are allowed for a user's own photo (the editor's slider reaches 1.0).
  Premultiplied resampling stops the removed background's colour bleeding into the edge as a halo.

### `const DeviceImageEditRequest({required Uint8List rgba, required int width, required int height, (double, double, double, double)? crop, bool removeBackground = true, int tolerance = 28, double? roundRect, double scale = deviceImageSafeFraction, int outputSize = 512, int maxSource = 1024})` <a id="deviceimageeditrequest"></a>
- **Kind:** const constructor of `DeviceImageEditRequest` ("one run of the image editor: the
  source pixels plus the user's settings").
- **Source:** `lib/shared/utils/device_image_processing.dart` (line 402).
- **Purpose:** Create an image edit request.
- **Inputs:** `rgba` — straight-alpha RGBA bytes, `width × height × 4` long; `crop` — region kept as
  `(left, top, width, height)` fractions of the source, null for everything; `removeBackground`;
  `tolerance`; `roundRect` — mask corner fraction, null for none; `scale` — fraction of the output
  edge the device's longer side fills; `outputSize` — output edge in px; `maxSource` — longest
  source side processed.
- **Returns:** A new `DeviceImageEditRequest`.
- **Side effects:** None.
- **Usage:** `ImageService.decodeEditableImage` builds one with only `rgba`/`width`/`height`, so the
  editor starts from these defaults; the editor page derives every later request with
  [`copyWith`](#copywith).
- **Notes:** Plain data, so it can be sent to an isolate. The final image is 512 px; the editor's
  live preview overrides `maxSource`/`outputSize` to 384/256.

### `DeviceImageEditRequest copyWith({(double, double, double, double)? crop, bool clearCrop = false, bool? removeBackground, int? tolerance, double? roundRect, bool clearRoundRect = false, double? scale, int? outputSize, int? maxSource})` <a id="copywith"></a>
- **Kind:** method of `DeviceImageEditRequest`.
- **Source:** `lib/shared/utils/device_image_processing.dart` (line 421).
- **Purpose:** Copy this request with some settings changed.
- **Inputs:** Any setting to replace; `clearCrop` / `clearRoundRect` reset those two nullable
  settings to null (a null argument alone means "keep").
- **Returns:** A new `DeviceImageEditRequest`.
- **Side effects:** None.
- **Usage:** Every control in `DeviceImageEditorPageState` (e.g.
  `_request.copyWith(clearRoundRect: true)`), and the preview's
  `_request.copyWith(maxSource: previewMaxSource, outputSize: previewOutputSize)`.
- **Notes:** The source pixels are shared, not copied.

### `(int, int, int, int) cropRectOf(DeviceImageEditRequest request)` <a id="croprectof"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/device_image_processing.dart` (line 451).
- **Purpose:** Turn the region a request keeps into source pixels.
- **Inputs:** `request`.
- **Returns:** `(x, y, width, height)` inside the source, at least 1×1; the whole image when
  `crop` is null.
- **Side effects:** None.
- **Algorithm:** Clamps left/top and right/bottom fractions to `[0, 1]`, floors the start (capped
  at `width − 1` / `height − 1`) and ceils the end, then returns the size as `max(1, end − start)`.
- **Usage:** [`processDeviceImage`](#processdeviceimage); `test/device_image_editor_test.dart`.
- **Notes:** A crop reaching past the image (the user zoomed out beyond it) is clamped; margin
  comes from `scale` instead.

### `Uint8List processDeviceImage(DeviceImageEditRequest request)` <a id="processdeviceimage"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/device_image_processing.dart` (line 479).
- **Purpose:** Run the editor's pipeline and encode the result.
- **Inputs:** `request`.
- **Returns:** PNG bytes (compression level 6) of a transparent `outputSize` square.
- **Side effects:** None.
- **Algorithm:** Wraps `rgba` as a 4-channel `img.Image` without copying, crops to
  [`cropRectOf`](#croprectof), then calls [`prepareDeviceImage`](#preparedeviceimage) with the
  request's `tolerance`, `roundRect`, `removeBackground`, `maxSource`, `outputSize` (as `size`) and
  `scale` (as `safeFraction`), and encodes the result.
- **Usage:** `processDeviceImageInIsolate` in `device_image_editor_page.dart`
  (`Isolate.run(() => processDeviceImage(request))`); tests call it synchronously.
- **Notes:** Top-level so `Isolate.run` can call it. Order: crop, reduce to `maxSource`, remove
  the background (or apply the rounded mask), trim, fit at `scale` into the centre of the square.
