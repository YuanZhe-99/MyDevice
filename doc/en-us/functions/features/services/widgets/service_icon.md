# `lib/features/services/widgets/service_icon.dart`

Shared fallback mapping from persisted service icon keys to Material `IconData` values. Service
views that render brand artwork use `ServiceAvatar`; this helper supplies the generic icon when a
key is unknown or no brand asset is available. The topology module imports and re-exports this
function for its existing icon-based canvas, where SVG widgets do not fit the node rendering API.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`iconForServiceIcon`](#iconforserviceicon) | top-level function | B | Map a service icon key to its Material icon, falling back to `Icons.dns`. |

## Documentation

### `IconData iconForServiceIcon(String? icon)` <a id="iconforserviceicon"></a>
- **Kind:** top-level function.
- **Source:** `lib/features/services/widgets/service_icon.dart`.
- **Purpose:** Resolve a service's stored icon name to the corresponding Material icon.
- **Inputs:** `icon` — a service or template icon key; may be null.
- **Returns:** `IconData` — the mapped icon, or `Icons.dns` for an unknown or missing key.
- **Side effects:** None.
- **Algorithm:** A switch maps known persisted names to Flutter Material icons and uses `Icons.dns` as
  its default case.
- **Usage:** `ServiceAvatar` uses this as its generic fallback; `iconForService` and topology code
  also use it.
- **Notes:** Keep the accepted keys aligned with existing service-template data and stored service
  records.
