# lib/features/devices/views/device_image_editor_page.dart

The full-screen image editor for a user's own device photo: crop by pan and zoom with a circle
guide, remove a plain background (with a tolerance slider) or apply a rounded-corner mask, and set
how much of the avatar circle the device fills. A live preview runs in an isolate after each
change and is shown both large and at list size. All pixel work is `processDeviceImage` and
`DeviceImageEditRequest` from
[`device_image_processing.md`](../../../shared/utils/device_image_processing.md); the file is
decoded by `ImageService.loadEditableImage` ([`image_service.md`](../../../shared/services/image_service.md)).
It is opened from `_pickImage` (with **Use Original**) and `_editImage` in
[`device_edit_page.dart`](device_edit_page.md), which save the returned PNG as a new file under
`images/`. See [Devices — Icon and image](../../../../features/devices.md#icon-and-image) for the
user-facing behavior. Widget tests live in `test/device_image_editor_test.dart`. Per this doc
set's tiering rule, `build()` methods and private widget-composition helpers are Tier B.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`processDeviceImageInIsolate`](#processdeviceimageinisolate) | top-level function | A | Run `processDeviceImage` off the UI isolate. |
| `DeviceImageEditorResult` (constructor) | const constructor | B | Create an image editor result instance; `png` null means "use the original". |
| `keepOriginal` | getter (`DeviceImageEditorResult`) | B | Tell whether the user chose to keep the original file. |
| [`showDeviceImageEditor`](#showdeviceimageeditor) | top-level function | A | Open the image editor on a file and wait for the user. |
| `DeviceImageEditorPage` (constructor) | const constructor | B | Create a device image editor page instance; pops with a `DeviceImageEditorResult`, or null on cancel. |
| `createState` | method (`DeviceImageEditorPage`) | B | Create the mutable state object for this widget. |
| `request` | getter (`DeviceImageEditorPageState`) | B | Expose the settings the editor would apply now; read by widget tests. |
| `initState` | method (widget lifecycle) | B | Start from the source's defaults and render a first preview. |
| `dispose` | method (widget lifecycle) | B | Release the debounce timer and transform controller. |
| `_update` | method (`DeviceImageEditorPageState`) | B | Change the settings and refresh the preview. |
| [`_schedulePreview`](#_schedulepreview) | method (`DeviceImageEditorPageState`) | A | Debounce and run a small preview of the current settings. |
| [`_onCropChanged`](#_oncropchanged) | method (`DeviceImageEditorPageState`) | A | Read the crop area's pan and zoom into a source region. |
| [`_reset`](#_reset) | method (`DeviceImageEditorPageState`) | A | Put every setting and the crop back to the defaults. |
| [`_use`](#_use) | method (`DeviceImageEditorPageState`) | A | Make the full-size image and close the editor with it. |
| `build` | method (widget) | B | Build the editor; at 720 px and wider the crop area sits beside the preview and controls, narrower windows stack them. |
| `_buildCropArea` | method (widget helper) | B | Build the pan-and-zoom crop area with the circle guide; records the edge length for crop maths. |
| `_buildPreview` | method (widget helper) | B | Show the result the way the device list will: a 160 px and a 48 px circle on the avatar's fill. |
| `_buildControls` | method (widget helper) | B | Build the setting controls; the background switch is disabled while the rounded-corner mask is on. |
| `_labeledSlider` | method (widget helper) | B | Build a slider row with a label and its current value. |
| `_CircleGuidePainter` (constructor) | constructor | B | Create a circle guide painter instance. |
| `paint` | method (`_CircleGuidePainter`) | B | Dim the corners and outline the avatar circle. |
| `shouldRepaint` | method (`_CircleGuidePainter`) | B | Repaint only when the outline colour changes. |

Row count (22) matches `grep -c 'Purpose:' device_image_editor_page.dart` (22) exactly. The
`DeviceImageProcessor` typedef, the `DeviceImageEditorResult`, `DeviceImageEditorPage` and
`DeviceImageEditorPageState` classes, and the static constants `previewMaxSource` (384),
`previewOutputSize` (256) and `roundRectFraction` (0.12) carry plain `///` doc comments rather than
`Purpose:` blocks and are not separate rows.

## Documentation

### `Future<Uint8List> processDeviceImageInIsolate(DeviceImageEditRequest request)` <a id="processdeviceimageinisolate"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/devices/views/device_image_editor_page.dart` (line 22).
- **Purpose:** Run [`processDeviceImage`](../../../shared/utils/device_image_processing.md#processdeviceimage)
  off the UI isolate.
- **Inputs:** `request`.
- **Returns:** `Future<Uint8List>` — the PNG bytes.
- **Side effects:** Spawns a short-lived isolate (`Isolate.run`).
- **Usage:** The default `processor` of both `showDeviceImageEditor` and `DeviceImageEditorPage`.
- **Notes:** It is the default `DeviceImageProcessor`
  (`Future<Uint8List> Function(DeviceImageEditRequest)`); tests pass a synchronous one that wraps
  `processDeviceImage` and records each request.

### `Future<DeviceImageEditorResult?> showDeviceImageEditor(BuildContext context, File file, {bool allowOriginal = false, DeviceImageProcessor processor = processDeviceImageInIsolate})` <a id="showdeviceimageeditor"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/devices/views/device_image_editor_page.dart` (line 55).
- **Purpose:** Open the image editor on a file and wait for the user.
- **Inputs:** `context`; `file` — the image to edit; `allowOriginal` — offer **Use Original**
  (true when adding a newly picked photo); `processor` — the pipeline runner.
- **Returns:** `Future<DeviceImageEditorResult?>` — `DeviceImageEditorResult(png)` for an edited
  image, `DeviceImageEditorResult(null)` (`keepOriginal`) for "use the original", or null when
  cancelled, when the context unmounted, or when the file cannot be decoded and `allowOriginal` is
  false.
- **Side effects:** Decodes and reads the file; may show a `imageEditorDecodeFailed` snack bar;
  pushes a full-screen `MaterialPageRoute` on the root navigator.
- **Algorithm:**
  1. `ImageService.loadEditableImage(file)` (platform codec first, `package:image` fallback,
     reduced to 1024 px while decoding).
  2. Decode failure → snack bar, then return "keep original" if allowed, else null.
  3. Reads the raw bytes for display, then pushes `DeviceImageEditorPage(source, displayBytes,
     allowOriginal, processor)` as a `fullscreenDialog` and returns what it pops.
- **Usage:**
  ```dart
  final result = await showDeviceImageEditor(context, file, allowOriginal: true);
  ```
  (from `_pickImage` in `lib/features/devices/views/device_edit_page.dart`, line 1071 — a missing
  `png` there means `ImageService.saveImageFile(file)`), and
  `showDeviceImageEditor(context, file)` from `_editImage` (line 1097), which only saves a
  non-null `png`.
- **Notes:** A file the decoders refuse is returned as "keep original" when that is allowed, so a
  format the editor cannot read never blocks adding the photo.

### `void _schedulePreview({bool immediate = false})` <a id="_schedulepreview"></a>
- **Kind:** method of `DeviceImageEditorPageState`.
- **Source:** `lib/features/devices/views/device_image_editor_page.dart` (line 182).
- **Purpose:** Debounce and run a small preview of the current settings.
- **Inputs:** `immediate` — skip the debounce (used by `initState`).
- **Returns:** None.
- **Side effects:** Cancels any pending timer; runs `widget.processor`; `setState` for
  `_processing` and `_preview`.
- **Algorithm:**
  1. Cancels `_debounce`. The run step increments `_generation`, sets `_processing`, and processes
     `_request.copyWith(maxSource: previewMaxSource, outputSize: previewOutputSize)` (384 / 256).
  2. Applies the PNG only if still mounted and the generation is unchanged; an error just clears
     `_processing` under the same check.
  3. Runs now when `immediate`, otherwise after a 150 ms `Timer`.
- **Usage:** `initState` (`immediate: true`) and `_update` after every settings change.
- **Notes:** The generation counter drops results that a newer change has already superseded, so a
  slow preview can never overwrite a newer one.

### `void _onCropChanged()` <a id="_oncropchanged"></a>
- **Kind:** method of `DeviceImageEditorPageState`.
- **Source:** `lib/features/devices/views/device_image_editor_page.dart` (line 221).
- **Purpose:** Read the crop area's pan and zoom into a source region.
- **Inputs:** None (reads `_transform.value` and `_cropSide`).
- **Returns:** None.
- **Side effects:** Updates the request via `_update`.
- **Algorithm:**
  1. Returns if the crop area has not been laid out (`_cropSide <= 0`).
  2. Identity transform → `copyWith(clearCrop: true)` (whole image).
  3. Otherwise, with scale `k` and translation `t`, the image is `contain`-fitted into the square
     (`f = side / max(w, h)`, offsets `ox`, `oy`); the visible square `(-t.x / k, -t.y / k,
     side / k)` is converted to fractions of the drawn image and stored as `crop`.
- **Usage:** `InteractiveViewer.onInteractionEnd` in `_buildCropArea`.
- **Notes:** `InteractiveViewer` allows a `side / 2` boundary margin, so the crop can extend past
  the image; `cropRectOf` clamps it and the margin then comes from **Size in circle**.

### `void _reset()` <a id="_reset"></a>
- **Kind:** method of `DeviceImageEditorPageState`.
- **Source:** `lib/features/devices/views/device_image_editor_page.dart` (line 248).
- **Purpose:** Put every setting and the crop back to the defaults.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Resets `_transform` to identity and `_request` to `widget.source`; schedules a
  preview.
- **Usage:** The **Reset** button at the end of `_buildControls`.
- **Notes:** `widget.source` is the decoded request with default settings, so this also restores
  tolerance 28, background removal on, no mask and scale 0.64.

### `Future<void> _use()` <a id="_use"></a>
- **Kind:** method of `DeviceImageEditorPageState`.
- **Source:** `lib/features/devices/views/device_image_editor_page.dart` (line 258).
- **Purpose:** Make the full-size image and close the editor with it.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Sets `_saving` (disables both app-bar actions and shows the spinner); runs
  `widget.processor(_request)` at the request's own sizes (512 px output); pops the route with
  `DeviceImageEditorResult(png)`.
- **Usage:** The **Use** app-bar action (`ValueKey('imageEditorUse')`).
- **Notes:** On a processing error the editor stays open and `_saving` is cleared; nothing is
  reported to the user.
