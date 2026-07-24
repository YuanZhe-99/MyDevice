# lib/shared/services/image_service.dart

`ImageService` handles image file picking, URL download, and deletion for device/service images,
storing them as UUID-named files under `images/` inside the app directory (see
[../../../data-formats.md](../../../data-formats.md)).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`_getImageDir`](#getimagedir) | static method | A | Resolve (and create if missing) the app's `images/` directory. |
| [`pickAndSaveImage`](#pickandsaveimage) | static method | A | Let the user pick an image file and copy it into app storage. |
| [`resolve`](#resolve) | static method | A | Resolve a relative `images/...` path to an absolute `File`. |
| [`delete`](#delete) | static method | A | Delete a previously saved image by relative path. |
| [`saveImageFromUrl`](#saveimagefromurl) | static method | A | Download an image from a URL into app storage. |

## Documentation

### `static Future<Directory> _getImageDir()` <a id="getimagedir"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 16).
- **Purpose:** Resolve the app's `images/` subdirectory, creating it if it doesn't exist.
- **Inputs:** None.
- **Returns:** `Future<Directory>`.
- **Side effects:** File-system: creates the directory (recursively) if absent.
- **Algorithm:** `p.join(appDir.path, 'images')` via `DeviceStorage.getAppDir()`; create
  recursively if `!await imgDir.exists()`.
- **Usage:** Called by `pickAndSaveImage` and `saveImageFromUrl`.
- **Notes:** Follows the app-wide rule that all file I/O goes through the storage hub's
  `getAppDir()` so custom storage paths work (see this repo's `AGENTS.md`).

### `static Future<String?> pickAndSaveImage()` <a id="pickandsaveimage"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 32).
- **Purpose:** Let the user pick an image file via the system file picker and copy it into app
  storage under a new UUID filename.
- **Inputs:** None.
- **Returns:** `Future<String?>` — a relative path like `"images/<uuid>.png"`, or `null` if the
  user cancelled or the picked path was unavailable.
- **Side effects:** Opens the native file picker (`FilePicker.platform.pickFiles`); copies the
  picked file into `images/`.
- **Algorithm:** Pick a single image file; if cancelled or no path, return `null`; otherwise
  generate `'${Uuid().v4()}$ext'` (preserving the original extension) and `File.copy` the source
  into `_getImageDir()`.
- **Usage:** Called from device/service edit pages' "add image" flows.
- **Notes:** The original file is copied, not moved — the source file picked by the user is left
  untouched on disk.

### `static Future<File> resolve(String relativePath)` <a id="resolve"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 55).
- **Purpose:** Turn a relative `imagePath` (as stored in a model, e.g. `"images/xxx.png"`) into an
  absolute `File` under the app directory.
- **Inputs:** `relativePath`.
- **Returns:** `Future<File>`.
- **Side effects:** None (does not check existence).
- **Algorithm:** `File(p.join(appDir.path, relativePath))`.
- **Usage:** Called by `delete`, by `ImageShareService`, and by any UI code that needs to display
  or read a stored image file.
- **Notes:** Does not verify the file exists; callers must check separately if needed.

### `static Future<void> delete(String relativePath)` <a id="delete"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 66).
- **Purpose:** Delete a previously saved image file, if it exists.
- **Inputs:** `relativePath`.
- **Returns:** `Future<void>`.
- **Side effects:** File-system deletion.
- **Algorithm:** Resolve via `resolve()`; delete only if `await file.exists()`.
- **Usage:** Called when a device/service record's image reference is removed or replaced.
- **Notes:** Silently no-ops if the file is already missing — not an error condition.

### `static Future<String?> saveImageFromUrl(String url)` <a id="saveimagefromurl"></a>
- **Kind:** static method of `ImageService`.
- **Source:** `lib/shared/services/image_service.dart` (line 80).
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
