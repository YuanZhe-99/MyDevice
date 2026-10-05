# Shared UI foundations

MyApps-UI `v0.1.2` is embedded at `packages/myapps_ui`, with relative URL
`../MyApps-UI.git`. Initialize submodules recursively after cloning.

`lib/app/theme.dart` delegates to `myapps_ui`, preserving the blue `0xFF1565C0`
seed and all public methods. Style/navigation enums retain serialized names.
Dynamic-color eligibility remains app-owned and Android-only.

`lib/shared/utils/adaptive_layout.dart` re-exports common thresholds and the
four pure helpers `canSplitLayout`, `useNavigationRail`, `columnCapacity`,
`listRowCount` from `myapps_adaptive`. Devices, service metrics, topology,
finance summaries and dialog constraints remain app-owned.
Profile, settings and sync formats do not change.

## Updating

Publish the library to both remotes first. Pin a tagged commit, validate the app
and only then commit its pointer. Shared declarations are documented in the library;
the app documents its adapters, brand and content-specific layout.

## P2 navigation and actual space

The application now delegates navigation rendering to `MyAppsNavigationShell`.
App-side shells retain routes, destination filtering, selection persistence and reminder
callbacks. Each page passes `context` to its width and bottom-inset helpers: measured
shell content width is used once, and full-window routes subtract no rail. The legacy
context-free helper remains for callers that explicitly request the old calculation.
The stable content slot preserves page state across resize, style and rail-side changes.
MyVidComp retains classic navigation, extended rails and review badges.

Profile extraction is complete in P3; data formats are unchanged.

## P3 profile and avatar

The five profile-bearing apps consume `myapps_profile`. Profile model, merge,
image processing, repository, avatar rendering, editor and header view are shared.
App ProfileStore supplies active storage root, atomic writer and sync notification;
image-service resolution/deletion remains injected. Existing imports are re-export
shims. App Riverpod providers, data-module registry, picker and localized edit dialog
remain adapters. JSON, module order, image naming and field-merge behavior are unchanged.
