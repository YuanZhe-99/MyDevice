# lib/features/devices/widgets/hardware_entries_editor.dart

## Declarations

| Declaration | Kind | Purpose |
|---|---|---|
| `HardwareEntriesEditor` | constructor | Bind one hardware list to parent drafts. |
| `label` | static method | Localize GPU kinds and display roles, retaining unknown values. |
| `_field` | method | Build a stable controller-backed field. |
| `_gpu` | method | Replace one GPU's fields, retaining ID and unknown keys. |
| `_display` | method | Replace one display's fields, retaining ID and unknown keys. |
| `build` | method | Render add/remove/move-up, presets/search and independent specs. |
| `_HardwareField` | constructor | Bind a label, value and callback. |
| `createState` | method | Create field controller state. |
| `initState` | method | Allocate the text controller. |
| `didUpdateWidget` | method | Reflect externally changed values without resetting matching text. |
| `dispose` | method | Release the controller. |
| `_HardwareFieldState.build` | method | Render the controlled input. |

IDs key cards and fields. Parents own draft lists, so fold/unfold preserves edits.
Preset/search results replace model and architecture only. Unknown type/role values
remain selectable. PPI is computed from each display; numeric partial input stays local.
