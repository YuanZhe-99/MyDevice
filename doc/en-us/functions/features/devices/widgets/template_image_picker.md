# lib/features/devices/widgets/template_image_picker.dart

The thumbnail chooser: a modal bottom sheet with a searchable grid of bundled template thumbnails,
best candidates first, that lets the user pick a hand-picked thumbnail for a device when automatic
matching misses (a device named differently from its template). It depends on
[`PresetService`](../services/preset_service.md) — `loadTemplates` for the catalog and
[`rankTemplateImageCandidates`](../services/preset_service.md#ranktemplateimagecandidates) for the order — on [`DeviceAvatar`](device_avatar.md) to draw each
tile, and on `sheetInitialSize` / `sheetMaxSize` from
[`adaptive_layout.md`](../../../shared/utils/adaptive_layout.md) for the sheet's size. The only
call site is `_chooseThumbnail` in [`device_edit_page.dart`](../views/device_edit_page.md), which
stores the result as the device's `templateImage`. See
[Devices — Icon and image](../../../../features/devices.md#icon-and-image) and
[Online Search and Presets — Device thumbnails](../../../../features/online-search-and-presets.md#device-thumbnails).
Per this doc set's tiering rule, `build()` methods and private widget-composition helpers are
Tier B.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`TemplateImageChoice`](#templateimagechoice) (constructor) | const constructor | A | Create a template image choice instance; wraps the asset so a dismissed sheet differs from "Automatic". |
| [`showTemplateImagePicker`](#showtemplateimagepicker) | top-level function | A | Let the user choose a bundled thumbnail for a device by hand. |
| `TemplateImagePickerSheet` (constructor) | const constructor | B | Create a template image picker sheet instance; public so widget tests can pump it without a route. |
| `createState` | method (`TemplateImagePickerSheet`) | B | Create the mutable state object for this widget. |
| [`initState`](#initstate) | method (widget lifecycle) | A | Rank the candidates once when the sheet opens and build the name index. |
| [`_filtered`](#_filtered) | getter (`_TemplateImagePickerSheetState`) | A | Provide the candidates that match the search field. |
| `build` | method (widget) | B | Build the searchable thumbnail grid, with "Automatic" as the first tile. |
| `_Tile` (constructor) | const constructor | B | Create a thumbnail tile instance. |
| `build` | method (`_Tile`) | B | Build one selectable thumbnail with its name; the current choice gets a primary-coloured outline. |

Row count (9) matches `grep -c 'Purpose:' template_image_picker.dart` (9) exactly. The
`TemplateImageChoice` and `TemplateImagePickerSheet` classes and the `_namesByImage` field carry
plain `///` doc comments rather than `Purpose:` blocks and are not separate rows.

## Documentation

### `const TemplateImageChoice(String? asset)` <a id="templateimagechoice"></a>
- **Kind:** const constructor of `TemplateImageChoice` ("what the user picked in the thumbnail
  chooser").
- **Source:** `lib/features/devices/widgets/template_image_picker.dart` (line 19).
- **Purpose:** Create a template image choice instance.
- **Inputs:** `asset` — the chosen bundled thumbnail path, or null for "Automatic" (match by
  identity).
- **Returns:** A new `TemplateImageChoice`.
- **Side effects:** None.
- **Usage:** Popped by the sheet's tiles: `Navigator.pop(context, const TemplateImageChoice(null))`
  for Automatic, `Navigator.pop(context, TemplateImageChoice(t.image))` for a thumbnail.
- **Notes:** The wrapper exists so a dismissed sheet (`null` future result) is distinguishable from
  choosing Automatic (`TemplateImageChoice(null)`); the caller leaves the device unchanged on the
  first and clears `templateImage` on the second.

### `Future<TemplateImageChoice?> showTemplateImagePicker(BuildContext context, {required DeviceCategory category, String? brand, String? model, String? name, String? current})` <a id="showtemplateimagepicker"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/devices/widgets/template_image_picker.dart` (line 31).
- **Purpose:** Let the user choose a bundled thumbnail for a device by hand.
- **Inputs:** `context`; `category`, `brand`, `model`, `name` — the device identity used to rank
  candidates and to render the Automatic tile; `current` — the thumbnail chosen so far (outlined).
- **Returns:** `Future<TemplateImageChoice?>` — the choice, or null when the sheet was dismissed or
  the context unmounted while the catalog loaded.
- **Side effects:** Loads the template catalog (`PresetService.loadTemplates`, cached after the
  first call); shows a scroll-controlled modal bottom sheet.
- **Algorithm:** Awaits `loadTemplates()`, returns null if `context` is no longer mounted, then
  `showModalBottomSheet<TemplateImageChoice>(isScrollControlled: true)` with a
  `TemplateImagePickerSheet` built from the loaded templates and the arguments.
- **Usage:**
  ```dart
  final choice = await showTemplateImagePicker(
    context,
    category: _category,
    brand: _nonEmpty(_brandCtrl.text),
    model: _nonEmpty(_modelCtrl.text),
    name: _nonEmpty(_nameCtrl.text),
    current: _templateImage,
  );
  ```
  (from `_chooseThumbnail` in `lib/features/devices/views/device_edit_page.dart`, line 1128,
  wired to the **Thumbnail** chip).
- **Notes:** Candidates are ranked against what is typed in the form now, not the saved device.
  Choosing a thumbnail makes the caller clear the emoji and photo so it is what the avatar shows.

### `void initState()` <a id="initstate"></a>
- **Kind:** method of `_TemplateImagePickerSheetState` (widget lifecycle).
- **Source:** `lib/features/devices/widgets/template_image_picker.dart` (line 104).
- **Purpose:** Rank the candidates once when the sheet opens.
- **Inputs:** None (reads `widget.templates`, `brand`, `model`, `name`).
- **Returns:** None.
- **Side effects:** Initializes `_ranked` and `_namesByImage`.
- **Algorithm:**
  1. `_ranked = PresetService.rankTemplateImageCandidates(templates, brand:, model:, name:)` — one
     entry per distinct thumbnail, exact identity match first, then shared words, then the rest.
  2. For every template with an `image`, appends its `name`, `brand` and `model` to
     `_namesByImage[image]`.
- **Usage:** Framework lifecycle.
- **Notes:** Several templates can share one thumbnail file; the name index lets a search for a
  sibling model still find the file it borrows even though only one of them is in `_ranked`.

### `List<DeviceTemplate> get _filtered` <a id="_filtered"></a>
- **Kind:** getter of `_TemplateImagePickerSheetState`.
- **Source:** `lib/features/devices/widgets/template_image_picker.dart` (line 130).
- **Purpose:** Provide the candidates that match the search field.
- **Inputs:** None (reads `_query`).
- **Returns:** `List<DeviceTemplate>` in rank order; all of `_ranked` when the query is blank.
- **Side effects:** None.
- **Algorithm:** Lower-cases and trims `_query`; keeps each ranked template for which any name in
  `_namesByImage[t.image]` contains the query (case-insensitive substring).
- **Usage:** `build` (`final items = _filtered;`), recomputed on each keystroke.
- **Notes:** The Automatic tile is not part of this list; `build` always prepends it, so it stays
  first whatever is typed.
