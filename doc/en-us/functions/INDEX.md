# MyDevice `lib/` Function Index

This is the top-level index of the hand-written Function Explanation Layer documentation for
`lib/` in the MyDevice repo. Each row links to a per-source-file page under
`doc/en-us/functions/` mirroring the `lib/` tree (with `.dart` replaced by `.md`).

**Totals:** the repo's `/// Purpose:` comment count is **943** (per the Function Explanation
Layer convention in `AGENTS.md`, excluding generated `lib/l10n/` code — see
[l10n/INDEX.md](l10n/INDEX.md)). This index documents **1132** declarations — 189 more than
943 — because a number of real declarations across several files (especially the two large
algorithm-heavy files `service_analysis.dart` and `service_topology_layout.dart`, plus tail
sections of `device.dart` and `service_list_page.dart`) have no `/// Purpose:` doc comment in
source at all, or in a couple of cases (`service_analysis.dart`) had a comment misattached to a
call-site statement rather than a real declaration. Every such case is called out explicitly on
its file page with a reconciling row-count note; nothing is silently invented to force a round
number.

The `/// Purpose:` figure is verified against source with
`grep -r '/// Purpose:' lib --include=*.dart`. The declaration total is hand-maintained and is
currently **known to be drifted** in two ways. First, a row-level sweep of the per-file pages
counts roughly 1023 declaration rows, not 1132. Second, the Tier A/B split in this table and the
split summed from the Area totals table below disagree by 15 (670/462 summed versus 685/447
stated), even though both agree on the 1132 grand total. Both gaps predate the
`device_search_parsers.dart` entry and were carried forward unchanged rather than papered over,
because reconciling them means re-auditing every page rather than editing these tables. Treat the
per-file rows as authoritative and both totals as approximate until that sweep happens.

| Tier | Count |
|---|---|
| Tier A (full entry) | 685 |
| Tier B (index row only) | 447 |
| **Total** | **1132** |

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
| `lib/app/data_modules.dart` | [app/data_modules.md](app/data_modules.md) | 11 | 11 |
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
| `lib/features/devices/services/device_storage.dart` | [features/devices/services/device_storage.md](features/devices/services/device_storage.md) | 30 | 22 |
| `lib/features/devices/services/exchange_rate_service.dart` | [features/devices/services/exchange_rate_service.md](features/devices/services/exchange_rate_service.md) | 21 | 20 |
| `lib/features/devices/services/preset_service.dart` | [features/devices/services/preset_service.md](features/devices/services/preset_service.md) | 12 | 11 |
| `lib/features/devices/views/chip_search_dialog.dart` | [features/devices/views/chip_search_dialog.md](features/devices/views/chip_search_dialog.md) | 11 | 4 |
| `lib/features/devices/views/device_detail_page.dart` | [features/devices/views/device_detail_page.md](features/devices/views/device_detail_page.md) | 20 | 6 |
| `lib/features/devices/views/device_edit_page.dart` | [features/devices/views/device_edit_page.md](features/devices/views/device_edit_page.md) | 59 | 14 |
| `lib/features/devices/views/device_finance_overview_page.dart` | [features/devices/views/device_finance_overview_page.md](features/devices/views/device_finance_overview_page.md) | 34 | 16 |
| `lib/features/devices/views/device_list_page.dart` | [features/devices/views/device_list_page.md](features/devices/views/device_list_page.md) | 46 | 16 |
| `lib/features/devices/views/device_search_dialog.dart` | [features/devices/views/device_search_dialog.md](features/devices/views/device_search_dialog.md) | 20 | 7 |
| `lib/features/devices/widgets/device_avatar.dart` | [features/devices/widgets/device_avatar.md](features/devices/widgets/device_avatar.md) | 7 | 0 |
| `lib/features/devices/widgets/device_category_icon.dart` | [features/devices/widgets/device_category_icon.md](features/devices/widgets/device_category_icon.md) | 1 | 1 |

## features/network/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/network/models/network.dart` | [features/network/models/network.md](features/network/models/network.md) | 17 | 16 |
| `lib/features/network/services/network_storage.dart` | [features/network/services/network_storage.md](features/network/services/network_storage.md) | 7 | 7 |
| `lib/features/network/views/network_detail_page.dart` | [features/network/views/network_detail_page.md](features/network/views/network_detail_page.md) | 27 | 11 |
| `lib/features/network/views/network_edit_page.dart` | [features/network/views/network_edit_page.md](features/network/views/network_edit_page.md) | 9 | 1 |
| `lib/features/network/views/network_list_page.dart` | [features/network/views/network_list_page.md](features/network/views/network_list_page.md) | 16 | 6 |

## features/services/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/services/models/service.dart` | [features/services/models/service.md](features/services/models/service.md) | 42 | 33 |
| `lib/features/services/services/service_analysis.dart` | [features/services/services/service_analysis.md](features/services/services/service_analysis.md) | 52 | 36 |
| `lib/features/services/services/service_storage.dart` | [features/services/services/service_storage.md](features/services/services/service_storage.md) | 8 | 8 |
| `lib/features/services/services/service_template_service.dart` | [features/services/services/service_template_service.md](features/services/services/service_template_service.md) | 4 | 4 |
| `lib/features/services/services/service_topology_layout.dart` | [features/services/services/service_topology_layout.md](features/services/services/service_topology_layout.md) | 87 | 34 |
| `lib/features/services/views/service_edit_page.dart` | [features/services/views/service_edit_page.md](features/services/views/service_edit_page.md) | 25 | 6 |
| `lib/features/services/views/service_list_page.dart` | [features/services/views/service_list_page.md](features/services/views/service_list_page.md) | 84 | 24 |
| `lib/features/services/views/service_route_edit_page.dart` | [features/services/views/service_route_edit_page.md](features/services/views/service_route_edit_page.md) | 24 | 8 |

## features/settings/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/settings/views/backup_page.dart` | [features/settings/views/backup_page.md](features/settings/views/backup_page.md) | 16 | 7 |
| `lib/features/settings/views/license_page.dart` | [features/settings/views/license_page.md](features/settings/views/license_page.md) | 2 | 0 |
| `lib/features/settings/views/privacy_policy_page.dart` | [features/settings/views/privacy_policy_page.md](features/settings/views/privacy_policy_page.md) | 3 | 0 |
| `lib/features/settings/views/settings_page.dart` | [features/settings/views/settings_page.md](features/settings/views/settings_page.md) | 21 | 14 |

## l10n/

`lib/l10n/` is already documented at [l10n/INDEX.md](l10n/INDEX.md) (generated code, not part of
the 943/1132 hand-documented declarations above).

## shared/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/shared/providers/app_settings.dart` | [shared/providers/app_settings.md](shared/providers/app_settings.md) | 6 | 6 |
| `lib/shared/services/auto_sync_service.dart` | [shared/services/auto_sync_service.md](shared/services/auto_sync_service.md) | 15 | 15 |
| `lib/shared/services/backup_service.dart` | [shared/services/backup_service.md](shared/services/backup_service.md) | 12 | 12 |
| `lib/shared/services/image_service.dart` | [shared/services/image_service.md](shared/services/image_service.md) | 5 | 5 |
| `lib/shared/services/image_share_service.dart` | [shared/services/image_share_service.md](shared/services/image_share_service.md) | 3 | 3 |
| `lib/shared/services/import_export_service.dart` | [shared/services/import_export_service.md](shared/services/import_export_service.md) | 5 | 4 |
| `lib/shared/services/local_api_server.dart` | [shared/services/local_api_server.md](shared/services/local_api_server.md) | 58 | 49 |
| `lib/shared/services/sync_merge.dart` | [shared/services/sync_merge.md](shared/services/sync_merge.md) | 11 | 11 |
| `lib/shared/services/sync_progress.dart` | [shared/services/sync_progress.md](shared/services/sync_progress.md) | 0 | 0 |
| `lib/shared/services/sync_wake_lock.dart` | [shared/services/sync_wake_lock.md](shared/services/sync_wake_lock.md) | 0 | 0 |
| `lib/shared/services/tray_service.dart` | [shared/services/tray_service.md](shared/services/tray_service.md) | 16 | 12 |
| `lib/shared/services/webdav_service.dart` | [shared/services/webdav_service.md](shared/services/webdav_service.md) | 12 | 12 |
| `lib/shared/utils/adaptive_layout.dart` | [shared/utils/adaptive_layout.md](shared/utils/adaptive_layout.md) | 14 | 14 |
| `lib/shared/utils/detail_layout.dart` | [shared/utils/detail_layout.md](shared/utils/detail_layout.md) | 4 | 4 |
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
| `app/` | 4 | 9 | 4 | 5 |
| `features/datasets/` | 4 | 49 | 30 | 19 |
| `features/devices/` | 15 | 381 | 201 | 180 |
| `features/network/` | 5 | 76 | 41 | 35 |
| `features/services/` | 8 | 326 | 153 | 173 |
| `features/settings/` | 4 | 42 | 21 | 21 |
| `shared/` | 20 | 307 | 243 | 64 |
| **Total** | **61** | **1191** | **709** | **482** |
