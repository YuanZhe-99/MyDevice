# MyDevice `lib/` Function Index

This is the top-level index of the hand-written Function Explanation Layer documentation for
`lib/` in the MyDevice repo. Each row links to a per-source-file page under
`doc/en-us/functions/` mirroring the `lib/` tree (with `.dart` replaced by `.md`).

**Totals:** the repo's `/// Purpose:` comment count is **1214** (per the Function Explanation
Layer convention in `AGENTS.md`, excluding generated `lib/l10n/` code — see
[l10n/INDEX.md](l10n/INDEX.md)). This index documents **1336** declarations — 122 more than
1214 — because a number of real declarations across several files (especially the two large
algorithm-heavy files `service_analysis.dart` and `service_topology_layout.dart`, plus the tail
section of `device.dart`) have no `/// Purpose:` doc comment in
source at all, or in a couple of cases (`service_analysis.dart`) had a comment misattached to a
call-site statement rather than a real declaration. Every such case is called out explicitly on
its file page with a reconciling row-count note; nothing is silently invented to force a round
number.

The `/// Purpose:` figure is verified against source with
`grep -r '/// Purpose:' lib --include=*.dart` (excluding `lib/l10n/`). The declaration totals are
hand-maintained and were **re-audited for 1.5.6**: every per-file row equals the Declarations
table on its own page (rows and Tier A), and the Area totals and the Tier table below are exact
sums of the per-file rows. Keep it that way: a change that adds or removes a page's rows updates
its per-file row and both total tables in the same commit.

| Tier | Count |
|---|---|
| Tier A (full entry) | 720 |
| Tier B (index row only) | 616 |
| **Total** | **1336** |

## Root (`lib/`)

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/main.dart` | [main.md](main.md) | 1 | 1 |

## app/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/app/app.dart` | [app/app.md](app/app.md) | 2 | 0 |
| `lib/app/flavor.dart` | [app/flavor.md](app/flavor.md) | 3 | 1 |
| `lib/app/router.dart` | [app/router.md](app/router.md) | 1 | 0 |
| `lib/app/data_modules.dart` | [app/data_modules.md](app/data_modules.md) | 14 | 14 |
| `lib/app/theme.dart` | [app/theme.md](app/theme.md) | 3 | 3 |

## features/datasets/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/datasets/models/dataset.dart` | [features/datasets/models/dataset.md](features/datasets/models/dataset.md) | 12 | 12 |
| `lib/features/datasets/services/dataset_storage.dart` | [features/datasets/services/dataset_storage.md](features/datasets/services/dataset_storage.md) | 7 | 7 |
| `lib/features/datasets/views/dataset_edit_page.dart` | [features/datasets/views/dataset_edit_page.md](features/datasets/views/dataset_edit_page.md) | 12 | 3 |
| `lib/features/datasets/views/dataset_list_page.dart` | [features/datasets/views/dataset_list_page.md](features/datasets/views/dataset_list_page.md) | 18 | 8 |

## features/devices/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/devices/models/device.dart` | [features/devices/models/device.md](features/devices/models/device.md) | 58 | 46 |
| `lib/features/devices/services/chip_search_service.dart` | [features/devices/services/chip_search_service.md](features/devices/services/chip_search_service.md) | 13 | 13 |
| `lib/features/devices/services/device_search_parsers.dart` | [features/devices/services/device_search_parsers.md](features/devices/services/device_search_parsers.md) | 25 | 24 |
| `lib/features/devices/services/device_search_service.dart` | [features/devices/services/device_search_service.md](features/devices/services/device_search_service.md) | 24 | 16 |
| `lib/features/devices/services/device_storage.dart` | [features/devices/services/device_storage.md](features/devices/services/device_storage.md) | 44 | 26 |
| `lib/features/devices/services/exchange_rate_service.dart` | [features/devices/services/exchange_rate_service.md](features/devices/services/exchange_rate_service.md) | 21 | 20 |
| `lib/features/devices/services/preset_service.dart` | [features/devices/services/preset_service.md](features/devices/services/preset_service.md) | 12 | 11 |
| `lib/features/devices/views/chip_search_dialog.dart` | [features/devices/views/chip_search_dialog.md](features/devices/views/chip_search_dialog.md) | 11 | 5 |
| `lib/features/devices/views/device_detail_page.dart` | [features/devices/views/device_detail_page.md](features/devices/views/device_detail_page.md) | 20 | 6 |
| `lib/features/devices/views/device_edit_page.dart` | [features/devices/views/device_edit_page.md](features/devices/views/device_edit_page.md) | 58 | 14 |
| `lib/features/devices/views/device_finance_overview_page.dart` | [features/devices/views/device_finance_overview_page.md](features/devices/views/device_finance_overview_page.md) | 33 | 16 |
| `lib/features/devices/views/device_list_page.dart` | [features/devices/views/device_list_page.md](features/devices/views/device_list_page.md) | 45 | 16 |
| `lib/features/devices/views/device_search_dialog.dart` | [features/devices/views/device_search_dialog.md](features/devices/views/device_search_dialog.md) | 20 | 7 |
| `lib/features/devices/widgets/device_avatar.dart` | [features/devices/widgets/device_avatar.md](features/devices/widgets/device_avatar.md) | 7 | 0 |
| `lib/features/devices/widgets/device_category_icon.dart` | [features/devices/widgets/device_category_icon.md](features/devices/widgets/device_category_icon.md) | 2 | 2 |

## features/network/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/network/models/network.dart` | [features/network/models/network.md](features/network/models/network.md) | 17 | 16 |
| `lib/features/network/services/network_storage.dart` | [features/network/services/network_storage.md](features/network/services/network_storage.md) | 7 | 7 |
| `lib/features/network/views/network_detail_page.dart` | [features/network/views/network_detail_page.md](features/network/views/network_detail_page.md) | 26 | 11 |
| `lib/features/network/views/network_edit_page.dart` | [features/network/views/network_edit_page.md](features/network/views/network_edit_page.md) | 9 | 1 |
| `lib/features/network/views/network_list_page.dart` | [features/network/views/network_list_page.md](features/network/views/network_list_page.md) | 16 | 6 |

## features/services/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/services/models/service.dart` | [features/services/models/service.md](features/services/models/service.md) | 42 | 33 |
| `lib/features/services/services/service_access_patterns.dart` | [features/services/services/service_access_patterns.md](features/services/services/service_access_patterns.md) | 47 | 25 |
| `lib/features/services/services/service_analysis.dart` | [features/services/services/service_analysis.md](features/services/services/service_analysis.md) | 76 | 44 |
| `lib/features/services/services/service_labels.dart` | [features/services/services/service_labels.md](features/services/services/service_labels.md) | 11 | 5 |
| `lib/features/services/services/service_storage.dart` | [features/services/services/service_storage.md](features/services/services/service_storage.md) | 8 | 8 |
| `lib/features/services/services/service_template_service.dart` | [features/services/services/service_template_service.md](features/services/services/service_template_service.md) | 4 | 4 |
| `lib/features/services/services/service_topology_layout.dart` | [features/services/services/service_topology_layout.md](features/services/services/service_topology_layout.md) | 115 | 45 |
| `lib/features/services/views/service_access_path_page.dart` | [features/services/views/service_access_path_page.md](features/services/views/service_access_path_page.md) | 54 | 13 |
| `lib/features/services/views/service_edit_page.dart` | [features/services/views/service_edit_page.md](features/services/views/service_edit_page.md) | 26 | 6 |
| `lib/features/services/views/service_endpoint_dialog.dart` | [features/services/views/service_endpoint_dialog.md](features/services/views/service_endpoint_dialog.md) | 8 | 1 |
| `lib/features/services/views/service_list_page.dart` | [features/services/views/service_list_page.md](features/services/views/service_list_page.md) | 34 | 7 |
| `lib/features/services/views/service_route_edit_page.dart` | [features/services/views/service_route_edit_page.md](features/services/views/service_route_edit_page.md) | 32 | 11 |
| `lib/features/services/views/service_topology_page.dart` | [features/services/views/service_topology_page.md](features/services/views/service_topology_page.md) | 39 | 18 |
| `lib/features/services/views/service_topology_widgets.dart` | [features/services/views/service_topology_widgets.md](features/services/views/service_topology_widgets.md) | 28 | 8 |

## features/settings/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/settings/views/backup_page.dart` | [features/settings/views/backup_page.md](features/settings/views/backup_page.md) | 16 | 7 |
| `lib/features/settings/views/license_page.dart` | [features/settings/views/license_page.md](features/settings/views/license_page.md) | 2 | 0 |
| `lib/features/settings/views/privacy_policy_page.dart` | [features/settings/views/privacy_policy_page.md](features/settings/views/privacy_policy_page.md) | 3 | 0 |
| `lib/features/settings/views/settings_page.dart` | [features/settings/views/settings_page.md](features/settings/views/settings_page.md) | 25 | 14 |

## l10n/

`lib/l10n/` is already documented at [l10n/INDEX.md](l10n/INDEX.md) (generated code, not part of
the 1214/1336 hand-documented declarations above).

## shared/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/shared/providers/app_settings.dart` | [shared/providers/app_settings.md](shared/providers/app_settings.md) | 6 | 6 |
| `lib/shared/services/auto_sync_service.dart` | [shared/services/auto_sync_service.md](shared/services/auto_sync_service.md) | 20 | 5 |
| `lib/shared/services/backup_service.dart` | [shared/services/backup_service.md](shared/services/backup_service.md) | 12 | 12 |
| `lib/shared/services/image_service.dart` | [shared/services/image_service.md](shared/services/image_service.md) | 5 | 5 |
| `lib/shared/services/image_share_service.dart` | [shared/services/image_share_service.md](shared/services/image_share_service.md) | 3 | 3 |
| `lib/shared/services/import_export_service.dart` | [shared/services/import_export_service.md](shared/services/import_export_service.md) | 5 | 4 |
| `lib/shared/services/local_api_server.dart` | [shared/services/local_api_server.md](shared/services/local_api_server.md) | 58 | 49 |
| `lib/shared/services/sync_merge.dart` | [shared/services/sync_merge.md](shared/services/sync_merge.md) | 25 | 9 |
| `lib/shared/services/sync_progress.dart` | [shared/services/sync_progress.md](shared/services/sync_progress.md) | 0 | 0 |
| `lib/shared/services/sync_wake_lock.dart` | [shared/services/sync_wake_lock.md](shared/services/sync_wake_lock.md) | 0 | 0 |
| `lib/shared/services/tray_service.dart` | [shared/services/tray_service.md](shared/services/tray_service.md) | 16 | 12 |
| `lib/shared/services/webdav_service.dart` | [shared/services/webdav_service.md](shared/services/webdav_service.md) | 12 | 12 |
| `lib/shared/utils/adaptive_layout.dart` | [shared/utils/adaptive_layout.md](shared/utils/adaptive_layout.md) | 16 | 16 |
| `lib/shared/utils/detail_layout.dart` | [shared/utils/detail_layout.md](shared/utils/detail_layout.md) | 5 | 5 |
| `lib/shared/utils/json_preservation.dart` | [shared/utils/json_preservation.md](shared/utils/json_preservation.md) | 0 | 0 |
| `lib/shared/views/device_map_page.dart` | [shared/views/device_map_page.md](shared/views/device_map_page.md) | 5 | 2 |
| `lib/shared/views/webdav_config_page.dart` | [shared/views/webdav_config_page.md](shared/views/webdav_config_page.md) | 23 | 12 |
| `lib/shared/widgets/adaptive_tile_grid.dart` | [shared/widgets/adaptive_tile_grid.md](shared/widgets/adaptive_tile_grid.md) | 3 | 3 |
| `lib/shared/widgets/map_picker_page.dart` | [shared/widgets/map_picker_page.md](shared/widgets/map_picker_page.md) | 6 | 2 |
| `lib/shared/widgets/shell_scaffold.dart` | [shared/widgets/shell_scaffold.md](shared/widgets/shell_scaffold.md) | 5 | 2 |

## Area totals

| Area | Files | Declarations | Tier A | Tier B |
|---|---|---|---|---|
| Root (`lib/`) | 1 | 1 | 1 | 0 |
| `app/` | 5 | 23 | 18 | 5 |
| `features/datasets/` | 4 | 49 | 30 | 19 |
| `features/devices/` | 15 | 393 | 222 | 171 |
| `features/network/` | 5 | 75 | 41 | 34 |
| `features/services/` | 14 | 524 | 228 | 296 |
| `features/settings/` | 4 | 46 | 21 | 25 |
| `shared/` | 20 | 225 | 159 | 66 |
| **Total** | **68** | **1336** | **720** | **616** |
