# lib/features/network/views/tailscale_import_page.dart

## Declarations

| Declaration | Kind | Purpose |
|---|---|---|
| `TailscaleImportPage` | constructor | Bind parsed rows, target network and inventory snapshot. |
| `createState` | method | Create preview state. |
| `initState` | method | Suggest unique node-ID/name matches; default others to skip. |
| `_save` | method | Revalidate fresh inventory, create chosen devices, batch memberships. |
| `build` | method | Render per-row choices, raw details, selection count and errors. |
| `_matchLabel` | method | Explain initial matches and candidate ambiguity. |
| `_oldValue` | method | Resolve effective old membership fields for the diff preview. |

No writes occur before Save. Duplicate target devices, deleted networks and retired
targets reject saving. Fresh inventory prevents overwriting existing specs. New
IDs are retained within the preview for retries. Network save is one queued atomic
write, but inventory plus network are not a cross-file transaction; newly saved
devices can remain after a network failure. The preview stays open on failure.

The preview suggests node-ID, exact-name and unique normalized-name matches before
asking the user to review. Each row exposes the matching reason and editable target,
new-device name/category/OS, and individual field checkboxes with old/new values.
Unchecked fields retain current membership values, including their raw CSV columns.
The node ID always identifies the imported membership. Duplicate targets and node
IDs are shown before Save; changes since preview reject saving until reloaded.
