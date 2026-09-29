# lib/shared/services/image_service.dart

`ImageService` handles image file picking, decoding for the image editor, storing, URL download,
and deletion for device/service images, storing them as UUID-named files under `images/` inside
the app directory (see [../../../data-formats.md](../../../data-formats.md)). The decode helpers
hand the image editor ([device_image_editor_page.md](../../features/devices/views/device_image_editor_page.md))
a `DeviceImageEditRequest` from [device_image_processing.md](../utils/device_image_processing.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`_getImageDir`](#getimagedir) | static method | A | Resolve (and create if missing) the app's `images/` directory. |
| [`pickAndSaveImage`](#pickandsaveimage) | static method | A | Let the user pick an image file and copy it into app storage unchanged. |
| [`pickImageFile`](#pickimagefile) | static method | A | Let the user pick an image file without copying it. |
| [`saveImageFile`](#saveimagefile) | static method | A | Copy an image file into app storage unchanged. |
| [`saveImageBytes`](#saveimagebytes) | static method | A | Store encoded image bytes (such as the image editor's PNG) as a new file. |
| [`loadEditableImage`](#loadeditableimage) | static method | A | Read and decode an image file into an editable RGBA request. |
| [`decodeEditableImage`](#decodeeditableimage) | static method | A | Decode encoded image bytes into an editable RGBA request, downscaled. |
| [`resolve`](#resolve) | static method | A | Resolve a relative `images/...` path to an absolute `File`. |
| [`delete`](#delete) | static method | A | Delete a previously saved image by relative path. |
| [`saveImageFromUrl`](#saveimagefromurl) | static method | A | Download an image from a URL into app storage. |

Row-count note: `grep -c 'Purpose:'` on this file returns 10, matching the 10 rows above exactly.

## Documentation

### `static Future<Directory> _getImageDir()` <a id="getimagedir"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 21).
- **Purpose:** Resolve the app's `images/` subdirectory, creating it if it doesn't exist.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** File-system: creates the directory (recursively) if absent.
- **Algorithm:** `p.join(appDir.path, 'images')` via `DeviceStorage.getAppDir()`; create
  recursively if `!await imgDir.exists()`.
- **Usage:** Called by `saveImageFile`, `saveImageBytes` and `saveImageFromUrl`.
- **Notes:** Follows the app-wide rule that all file I/O goes through the storage hub's
  `getAppDir()` so custom storage paths work (see this repo's `AGENTS.md`).

### `static Future<String?> pickAndSaveImage()` <a id="pickandsaveimage"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 38).
- **Purpose:** Let the user pick an image file via the system file picker and copy it into app
  storage unchanged under a new UUID filename.
- **Inputs:** None.
- **Returns:** `Future<String?>` — a relative path like `"images/<uuid>.png"`, or `null` if the
  user cancelled or the picked path was unavailable.
- **Side effects:** Opens the native file picker; copies the picked file into `images/`.
- **Algorithm:** Delegates: [`pickImageFile`](#pickimagefile); returns `null` if that did, else
  [`saveImageFile`](#saveimagefile) on the picked file.
- **Usage:** No caller in `lib/` at present — the device editor goes through `pickImageFile` and
  the image editor instead. Kept for callers that want the file as-is.
- **Notes:** The original file is copied, not moved — the source file picked by the user is left
  untouched on disk.

### `static Future<File?> pickImageFile()` <a id="pickimagefile"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 50).
- **Purpose:** Let the user pick an image file without copying it anywhere.
- **Inputs:** None.
- **Returns:** `Future<File?>` — the picked file, or `null` when cancelled or when the picker gave
  no path.
- **Side effects:** Opens the native file picker (`FilePicker.platform.pickFiles(type:
  FileType.image, allowMultiple: false)`).
- **Algorithm:** Pick a single image; return `null` for an empty result or a null
  `files.single.path`; otherwise `File(pickedPath)`.
- **Usage:** The device editor's photo flow (`_pickImage` in
  [device_edit_page.md](../../features/devices/views/device_edit_page.md#_pickimage)), which then
  edits the file or stores it unchanged; also `pickAndSaveImage`.
- **Notes:** The caller decides whether to edit it first ([`loadEditableImage`](#loadeditableimage))
  or store it unchanged ([`saveImageFile`](#saveimagefile)).

### `static Future<String> saveImageFile(File source)` <a id="saveimagefile"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 66).
- **Purpose:** Copy an image file into app storage unchanged.
- **Inputs:** `source` — the file to copy.
- **Returns:** `Future<String>` — the relative path, e.g. `images/<uuid>.jpg`.
- **Side effects:** Creates the images directory if needed; writes one file.
- **Algorithm:** Name the copy `'${Uuid().v4()}${p.extension(source.path)}'` (keeping the source
  extension) and `source.copy` it into `_getImageDir()`.
- **Usage:** `pickAndSaveImage`, and the device editor's "Use original" path (also taken when the
  image editor cannot decode the file).
- **Notes:** The source is left in place.

### `static Future<String> saveImageBytes(Uint8List bytes, String ext)` <a id="saveimagebytes"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 79).
- **Purpose:** Store encoded image bytes, such as the image editor's PNG, as a new image file.
- **Inputs:** `bytes` — encoded image data; `ext` — extension including the dot, e.g. `.png`.
- **Returns:** `Future<String>` — the relative path, e.g. `images/<uuid>.png`.
- **Side effects:** Creates the images directory if needed; writes one file (`flush: true`).
- **Algorithm:** `File(p.join(imgDir, '${Uuid().v4()}$ext')).writeAsBytes(bytes, flush: true)`.
- **Usage:** The device editor's `_pickImage` and `_editImage` with the editor's PNG result.
- **Notes:** Always a new flat file under `images/`, so backup and sync carry it like any other
  device image; it never overwrites an existing file.

### `static Future<DeviceImageEditRequest?> loadEditableImage(File file, {int maxSide = 1024})` <a id="loadeditableimage"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 92).
- **Purpose:** Decode an image file into pixels the image editor can process.
- **Inputs:** `file`; `maxSide` — the longest side kept after decoding (default 1024).
- **Returns:** `Future<DeviceImageEditRequest?>` — a request carrying straight RGBA pixels with
  default edit settings, or `null` when the file cannot be read or decoded.
- **Side effects:** Reads the file.
- **Algorithm:** `file.readAsBytes()` (a read error returns `null`), then
  [`decodeEditableImage`](#decodeeditableimage).
- **Usage:** `showDeviceImageEditor` in
  [device_image_editor_page.md](../../features/devices/views/device_image_editor_page.md), which
  falls back to "Use original" (or cancels) when this returns `null`.
- **Notes:** None.

### `static Future<DeviceImageEditRequest?> decodeEditableImage(Uint8List bytes, {int maxSide = 1024})` <a id="decodeeditableimage"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 113).
- **Purpose:** Decode encoded image bytes into an editable RGBA request.
- **Inputs:** `bytes` — encoded image data; `maxSide` — the longest side kept after decoding.
- **Returns:** `Future<DeviceImageEditRequest?>` — the request (`rgba`, `width`, `height`), or
  `null` when no decoder accepts the bytes.
- **Side effects:** None (allocates and disposes platform image objects).
- **Algorithm:**
  1. Platform codec first: `ui.ImmutableBuffer.fromUint8List` → `ui.ImageDescriptor.encoded`;
     when the longest side exceeds `maxSide`, pass `targetWidth` (landscape/square) or
     `targetHeight` (portrait) = `maxSide` to `instantiateCodec`, so the downscale happens while
     decoding; read the first frame as `ui.ImageByteFormat.rawStraightRgba`; dispose the image,
     codec, descriptor and buffer; return the request if pixels were produced.
  2. On any exception (or no pixel data), fall back to `package:image`: `img.decodeImage`,
     `img.bakeOrientation`, `img.copyResize` with `Interpolation.average` when the longest side
     exceeds `maxSide`, then convert to 4-channel uint8 and take RGBA bytes.
  3. Return `null` if the fallback also fails.
- **Usage:** Called by [`loadEditableImage`](#loadeditableimage).
- **Notes:** Using the platform codec first makes formats Flutter can show (and EXIF orientation)
  behave as they do on screen, and downscaling while decoding keeps a 48 MP photo from ever
  becoming a full-size buffer. The fallback bakes EXIF orientation explicitly.

### `static Future<File> resolve(String relativePath)` <a id="resolve"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 180).
- **Purpose:** Turn a relative `imagePath` (as stored in a model, e.g. `"images/xxx.png"`) into an
  absolute `File` under the app directory.
- **Inputs:** `relativePath`.
- **Returns:** `Future<File>`.
- **Side effects:** None (does not check existence).
- **Algorithm:** `File(p.join(appDir.path, relativePath))`.
- **Usage:** Called by `delete`, by `ImageShareService`, by the device editor's `_editImage`, and
  by any UI code that needs to display or read a stored image file.
- **Notes:** Does not verify the file exists; callers must check separately if needed.

### `static Future<void> delete(String relativePath)` <a id="delete"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 191).
- **Purpose:** Delete a previously saved image file, if it exists.
- **Inputs:** `relativePath`.
- **Returns:** `Future<void>`.
- **Side effects:** File-system deletion.
- **Algorithm:** Resolve via `resolve()`; delete only if `await file.exists()`.
- **Usage:** Called when a device/service record's image reference is removed or replaced.
- **Notes:** Silently no-ops if the file is already missing — not an error condition.

### `static Future<String?> saveImageFromUrl(String url)` <a id="saveimagefromurl"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 205).
- **Purpose:** Download an image from a remote URL and save it into app storage.
- **Inputs:** `url`.
- **Returns:** `Future<String?>` — a relative path like `"images/<uuid>.jpg"`, or `null` on any
  non-200 response.
- **Side effects:** Network GET request (15-second timeout, `User-Agent: MyDevice/0.1`); writes
  the downloaded bytes to `images/`.
- **Algorithm:** GET the URL; if status isn't 200, return `null`. Derive the extension from the
  URL path, falling back to `.jpg` if empty or longer than 5 characters (a crude sanity check
  against non-extension trailing path segments); generate a UUID filename and write the response
  bytes.
- **Usage:** Called wherever the app fetches a device/chip image from an online source (e.g. the
  online device/chip search results).
- **Notes:** No content-type validation — the extension is inferred purely from the URL's path,
  not from the response's `Content-Type` header.
