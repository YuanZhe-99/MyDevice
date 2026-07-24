# lib/shared/services/image_share_service.dart

`ImageShareService` shares in-memory PNG bytes (e.g. the Services topology export from
[../../../features/services-topology.md](../../../features/services-topology.md)) via the
platform-appropriate share path: Android method channel, iOS `share_plus`, or a desktop preview
dialog with copy/save actions.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`sharePngBytes`](#sharepngbytes) | static method | A | Share PNG bytes via the platform-appropriate path. |
| [`_showDesktopPreview`](#showdesktoppreview) | static method | A | Show a desktop preview dialog with copy/save-as actions. |
| [`_copyImageToClipboard`](#copyimagetoclipboard) | static method | A | Copy an image file to the OS clipboard on desktop. |

## Documentation

### `static Future<void> sharePngBytes(BuildContext context, Uint8List imageBytes, {required String fileName})` <a id="sharepngbytes"></a>
- **Kind:** static method of `ImageShareService`.
- **Source:** `lib/shared/services/image_share_service.dart` (line 18).
- **Purpose:** Write PNG bytes to a temp file and hand it off to the platform's native share
  mechanism, or a desktop preview dialog.
- **Inputs:** `context`; `imageBytes`; `fileName` (used both for the temp file and any save-as
  dialog).
- **Returns:** `Future<void>`.
- **Side effects:** Writes a temp file (`path_provider`'s temporary directory); on Android,
  invokes the `com.yuanzhe.my_device/share` method channel; on iOS, calls `Share.shareXFiles`; on
  desktop, opens a dialog.
- **Algorithm:** Write `imageBytes` to `<tempDir>/<fileName>`; re-check `context.mounted` after the
  await; branch on `Platform.isAndroid` (method channel `shareFile` with `path`/`mimeType`),
  `Platform.isIOS` (`Share.shareXFiles`), else (desktop) `_showDesktopPreview`.
- **Usage:** Called wherever the app shares a generated PNG, e.g. the Services topology PNG
  export.
- **Notes:** Mirrors the same three-platform-branch sharing pattern used by other export flows in
  the sibling apps (Android method channel / iOS `share_plus` / desktop preview dialog).

### `static Future<void> _showDesktopPreview(BuildContext context, Uint8List imageBytes, String tempPath, AppLocalizations l10n, {required String fileName})` <a id="showdesktoppreview"></a>
- **Kind:** static method of `ImageShareService`.
- **Source:** `lib/shared/services/image_share_service.dart` (line 54).
- **Purpose:** Show a modal dialog previewing the image with "Copy" and "Save As" actions, for
  desktop platforms that have no native share sheet.
- **Inputs:** `context`, `imageBytes`, `tempPath` (the already-written temp file), `l10n`,
  `fileName`.
- **Returns:** `Future<void>`.
- **Side effects:** Opens a `showDialog`; "Copy" calls `_copyImageToClipboard`; "Save As" opens
  `FilePicker.platform.saveFile` and writes `imageBytes` to the chosen path.
- **Algorithm:** Render the image via `Image.memory` inside a constrained `Dialog`, with a
  bottom action row. Copy button: copy to clipboard, pop the dialog, show a "copied" snackbar.
  Save button: open a native save dialog pre-filled with `fileName`; if a path is chosen, write
  the bytes there, pop the dialog, show a "saved" snackbar. Both actions guard `ctx.mounted`
  before touching the navigator/scaffold messenger after their awaits.
- **Usage:** Called only from `sharePngBytes`'s desktop branch.
- **Notes:** "Save As" writes a second copy of the file at the user-chosen location — the
  original temp file from `sharePngBytes` is not deleted or moved.

### `static Future<void> _copyImageToClipboard(String imagePath)` <a id="copyimagetoclipboard"></a>
- **Kind:** static method of `ImageShareService`.
- **Source:** `lib/shared/services/image_share_service.dart` (line 129).
- **Purpose:** Copy an image file's contents to the OS clipboard as an image, using a
  platform-specific external process since Flutter has no built-in cross-platform image-clipboard
  API.
- **Inputs:** `imagePath` — absolute path to the image file.
- **Returns:** `Future<void>`.
- **Side effects:** Spawns an external process: PowerShell (Windows, via `System.Drawing` +
  `System.Windows.Forms.Clipboard`), `osascript` (macOS, AppleScript clipboard-set), or `xclip`
  (Linux, `image/png` target).
- **Algorithm:** Branch on `Platform.isWindows`/`isMacOS`/`isLinux` and run the corresponding
  external command via `Process.run` with the image path embedded in the command string/args.
- **Usage:** Called only from `_showDesktopPreview`'s "Copy" button.
- **Notes:** The Windows branch interpolates `imagePath` directly into a PowerShell command
  string; since this path always originates from this app's own temp-file write (not user input),
  it is not treated as an injection risk in the current implementation, but any future caller
  passing an untrusted path would need to reconsider this.
