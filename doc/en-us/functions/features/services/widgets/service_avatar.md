# lib/features/services/widgets/service_avatar.dart

`ServiceAvatar` resolves a bundled brand mark from the stable template ID only when the stored
Material icon is unchanged (or absent). An explicit custom icon and an unknown template retain the
Material fallback. `serviceTemplateIconAssets` maps variants to a shared asset without changing
persisted service data. `TemplateIcon` provides transparent, circular-safe vector containment.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ServiceAvatar` | constructor | B | Configure template identity, icon and size. |
| `ServiceAvatar.fromService` | constructor | B | Read display metadata from an existing service. |
| `build` | method | B | Resolve an unchanged template icon to a bundled brand asset. |

## Documentation

Monochrome marks and selected neutral foregrounds follow the theme for light/dark contrast. Bundled logos work offline and do not replace user-selected icons. Asset provenance is recorded
in `assets/service_icons/SOURCES.md`.
