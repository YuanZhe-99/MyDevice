# Shared UI foundations

MyApps-UI `v0.1.0` is embedded at `packages/myapps_ui`, with relative URL
`../MyApps-UI.git`. Initialize submodules recursively after cloning.

`lib/app/theme.dart` delegates to `myapps_ui`, preserving the blue `0xFF1565C0`
seed and all public methods. Style/navigation enums retain serialized names.
Dynamic-color eligibility remains app-owned and Android-only.

`lib/shared/utils/adaptive_layout.dart` re-exports common thresholds and the
four pure helpers `canSplitLayout`, `useNavigationRail`, `columnCapacity`,
`listRowCount` from `myapps_adaptive`. Devices, service metrics, topology,
finance summaries and dialog constraints remain app-owned.
Content-width prediction stays unchanged pending the navigation-container stage.
Profile, settings and sync formats do not change.

## Updating

Publish the library to both remotes first. Pin a tagged commit, validate the app
and only then commit its pointer. Shared declarations are documented in the library;
the app documents its adapters, brand and content-specific layout.
