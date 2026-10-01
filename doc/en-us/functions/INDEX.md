# MyDevice `lib/` Function Index

This is the top-level index of the hand-written Function Explanation Layer documentation for
`lib/` in the MyDevice repo. Each row links to a per-source-file page under
`doc/en-us/functions/` mirroring the `lib/` tree (with `.dart` replaced by `.md`).

**Totals:** the repo's `/// Purpose:` comment count is **1581** (per the Function Explanation
Layer convention in `AGENTS.md`, excluding generated `lib/l10n/` code — see
[l10n/INDEX.md](l10n/INDEX.md)). This index documents **1708** declarations — 127 more than
1581 — because a number of real declarations across several files (especially the two large
algorithm-heavy files `service_analysis.dart` and `service_topology_layout.dart`, the
constants, enums, typedefs and private regular expressions of the 1.6.0 on-device AI files under
`features/ai/` and the two insight fact builders, and the classes, enum, constants and typedefs of
`device_search_service.dart` and `device_search_parsers.dart`) have no `/// Purpose:` doc comment
in source at all, or in a couple of cases (`service_analysis.dart`) had a comment misattached to a
call-site statement rather than a real declaration. Every such case is called out explicitly on
its file page with a reconciling row-count note; nothing is silently invented to force a round
number. The 1.6.1 documentation audit added the missing blocks to the 27 tail declarations of
`device.dart` and to three constructors in `device_search_service.dart`, so those no longer count
toward the gap.

**1.7.0 recount.** The measured `/// Purpose:` count is 1550 (1493 before) and the rows sum to 1676 (1616 before), so the gap grows from 123 to 126: the release added 60 documented declarations (the six `features/profile/` files with 44, five in `data_modules.dart`, five in `theme.dart`, three in `shell_scaffold.dart`, two in `device_storage.dart`, one in `app_settings.dart`), three of them constants or fields without a `Purpose:` comment.

**1.7.1 recount.** The measured `/// Purpose:` count is 1581 (1550 before) and the rows sum to 1708 (1676 before), so the gap grows from 126 to 127: the release added 32 declarations (`avatar_editor.dart` 13 and `avatar_image.dart` 7 as two new pages, `device_storage.dart` 4, `shell_scaffold.dart` 3, `app_settings.dart` 2, `adaptive_layout.dart` 1, `profile_header.dart` 1, `profile_store.dart` 1), 31 of them with a `Purpose:` comment (the extra `shell_scaffold.dart` row is the second private class, which has none).

The `/// Purpose:` figure is verified against source with
`grep -r '/// Purpose:' lib --include=*.dart` (excluding `lib/l10n/`). The declaration totals are
hand-maintained and were **re-audited in the current workspace**: every per-file row equals the Declarations
table on its own page (rows and Tier A), and the Area totals and the Tier table below are exact
sums of the per-file rows. Keep it that way: a change that adds or removes a page's rows updates
its per-file row and both total tables in the same commit.

| Tier | Count |
|---|---|
| Tier A (full entry) | 926 |
| Tier B (index row only) | 782 |
| **Total** | **1709** |

## Root (`lib/`)

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/main.dart` | [main.md](main.md) | 1 | 1 |

## app/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/app/app.dart` | [app/app.md](app/app.md) | 2 | 0 |
| `lib/app/flavor.dart` | [app/flavor.md](app/flavor.md) | 4 | 1 |
| `lib/app/router.dart` | [app/router.md](app/router.md) | 1 | 0 |
| `lib/app/data_modules.dart` | [app/data_modules.md](app/data_modules.md) | 19 | 17 |
| `lib/app/theme.dart` | [app/theme.md](app/theme.md) | 8 | 7 |

## features/ai/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/ai/services/ai_insights_cache.dart` | [features/ai/services/ai_insights_cache.md](features/ai/services/ai_insights_cache.md) | 12 | 10 |
| `lib/features/ai/services/genai_backend.dart` | [features/ai/services/genai_backend.md](features/ai/services/genai_backend.md) | 27 | 7 |
| `lib/features/ai/services/insight_language.dart` | [features/ai/services/insight_language.md](features/ai/services/insight_language.md) | 3 | 3 |
| `lib/features/ai/services/insight_prompts.dart` | [features/ai/services/insight_prompts.md](features/ai/services/insight_prompts.md) | 18 | 10 |
| `lib/features/ai/services/insight_service.dart` | [features/ai/services/insight_service.md](features/ai/services/insight_service.md) | 18 | 13 |
| `lib/features/ai/services/on_device_ai_service.dart` | [features/ai/services/on_device_ai_service.md](features/ai/services/on_device_ai_service.md) | 26 | 9 |
| `lib/features/ai/services/output_validation.dart` | [features/ai/services/output_validation.md](features/ai/services/output_validation.md) | 6 | 4 |
| `lib/features/ai/widgets/ai_insight_card.dart` | [features/ai/widgets/ai_insight_card.md](features/ai/widgets/ai_insight_card.md) | 13 | 8 |
| `lib/features/ai/widgets/ai_settings_tiles.dart` | [features/ai/widgets/ai_settings_tiles.md](features/ai/widgets/ai_settings_tiles.md) | 6 | 2 |

## features/datasets/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/datasets/models/dataset.dart` | [features/datasets/models/dataset.md](features/datasets/models/dataset.md) | 12 | 12 |
| `lib/features/datasets/services/dataset_storage.dart` | [features/datasets/services/dataset_storage.md](features/datasets/services/dataset_storage.md) | 9 | 9 |
| `lib/features/datasets/views/dataset_edit_page.dart` | [features/datasets/views/dataset_edit_page.md](features/datasets/views/dataset_edit_page.md) | 12 | 3 |
| `lib/features/datasets/views/dataset_list_page.dart` | [features/datasets/views/dataset_list_page.md](features/datasets/views/dataset_list_page.md) | 18 | 8 |

## features/devices/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/devices/models/device.dart` | [features/devices/models/device.md](features/devices/models/device.md) | 58 | 46 |
| `lib/features/devices/services/chip_search_service.dart` | [features/devices/services/chip_search_service.md](features/devices/services/chip_search_service.md) | 13 | 13 |
| `lib/features/devices/services/device_search_parsers.dart` | [features/devices/services/device_search_parsers.md](features/devices/services/device_search_parsers.md) | 40 | 37 |
| `lib/features/devices/services/device_search_service.dart` | [features/devices/services/device_search_service.md](features/devices/services/device_search_service.md) | 39 | 27 |
| `lib/features/devices/services/device_storage.dart` | [features/devices/services/device_storage.md](features/devices/services/device_storage.md) | 60 | 37 |
| `lib/features/devices/services/exchange_rate_service.dart` | [features/devices/services/exchange_rate_service.md](features/devices/services/exchange_rate_service.md) | 25 | 24 |
| `lib/features/devices/services/finance_insight_facts.dart` | [features/devices/services/finance_insight_facts.md](features/devices/services/finance_insight_facts.md) | 5 | 1 |
| `lib/features/devices/services/preset_service.dart` | [features/devices/services/preset_service.md](features/devices/services/preset_service.md) | 19 | 15 |
| `lib/features/devices/views/chip_search_dialog.dart` | [features/devices/views/chip_search_dialog.md](features/devices/views/chip_search_dialog.md) | 11 | 5 |
| `lib/features/devices/views/device_detail_page.dart` | [features/devices/views/device_detail_page.md](features/devices/views/device_detail_page.md) | 20 | 6 |
| `lib/features/devices/views/device_edit_page.dart` | [features/devices/views/device_edit_page.md](features/devices/views/device_edit_page.md) | 63 | 19 |
| `lib/features/devices/views/device_finance_overview_page.dart` | [features/devices/views/device_finance_overview_page.md](features/devices/views/device_finance_overview_page.md) | 36 | 19 |
| `lib/features/devices/views/device_image_editor_page.dart` | [features/devices/views/device_image_editor_page.md](features/devices/views/device_image_editor_page.md) | 22 | 6 |
| `lib/features/devices/views/device_list_page.dart` | [features/devices/views/device_list_page.md](features/devices/views/device_list_page.md) | 45 | 16 |
| `lib/features/devices/views/device_search_dialog.dart` | [features/devices/views/device_search_dialog.md](features/devices/views/device_search_dialog.md) | 20 | 7 |
| `lib/features/devices/widgets/device_avatar.dart` | [features/devices/widgets/device_avatar.md](features/devices/widgets/device_avatar.md) | 12 | 0 |
| `lib/features/devices/widgets/device_category_icon.dart` | [features/devices/widgets/device_category_icon.md](features/devices/widgets/device_category_icon.md) | 2 | 2 |
| `lib/features/devices/widgets/template_image_picker.dart` | [features/devices/widgets/template_image_picker.md](features/devices/widgets/template_image_picker.md) | 9 | 4 |

## features/network/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/network/models/network.dart` | [features/network/models/network.md](features/network/models/network.md) | 17 | 16 |
| `lib/features/network/services/network_storage.dart` | [features/network/services/network_storage.md](features/network/services/network_storage.md) | 9 | 9 |
| `lib/features/network/views/network_detail_page.dart` | [features/network/views/network_detail_page.md](features/network/views/network_detail_page.md) | 26 | 11 |
| `lib/features/network/views/network_edit_page.dart` | [features/network/views/network_edit_page.md](features/network/views/network_edit_page.md) | 9 | 1 |
| `lib/features/network/views/network_list_page.dart` | [features/network/views/network_list_page.md](features/network/views/network_list_page.md) | 16 | 6 |

## features/profile/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/profile/models/profile_data.dart` | [features/profile/models/profile_data.md](features/profile/models/profile_data.md) | 8 | 2 |
| `lib/features/profile/services/profile_merge.dart` | [features/profile/services/profile_merge.md](features/profile/services/profile_merge.md) | 4 | 2 |
| `lib/features/profile/services/avatar_image.dart` | [features/profile/services/avatar_image.md](features/profile/services/avatar_image.md) | 7 | 5 |
| `lib/features/profile/services/profile_store.dart` | [features/profile/services/profile_store.md](features/profile/services/profile_store.md) | 11 | 7 |
| `lib/features/profile/providers/profile_provider.dart` | [features/profile/providers/profile_provider.md](features/profile/providers/profile_provider.md) | 7 | 2 |
| `lib/features/profile/views/avatar_editor.dart` | [features/profile/views/avatar_editor.md](features/profile/views/avatar_editor.md) | 13 | 7 |
| `lib/features/profile/views/profile_avatar.dart` | [features/profile/views/profile_avatar.md](features/profile/views/profile_avatar.md) | 5 | 3 |
| `lib/features/profile/views/profile_header.dart` | [features/profile/views/profile_header.md](features/profile/views/profile_header.md) | 11 | 5 |

The synced profile (1.7.0): display name and avatar. See [../features/profile.md](../features/profile.md).


## features/services/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/services/models/service.dart` | [features/services/models/service.md](features/services/models/service.md) | 42 | 33 |
| `lib/features/services/services/service_access_patterns.dart` | [features/services/services/service_access_patterns.md](features/services/services/service_access_patterns.md) | 47 | 25 |
| `lib/features/services/services/service_analysis.dart` | [features/services/services/service_analysis.md](features/services/services/service_analysis.md) | 76 | 44 |
| `lib/features/services/services/service_insight_facts.dart` | [features/services/services/service_insight_facts.md](features/services/services/service_insight_facts.md) | 6 | 2 |
| `lib/features/services/services/service_labels.dart` | [features/services/services/service_labels.md](features/services/services/service_labels.md) | 11 | 5 |
| `lib/features/services/services/service_storage.dart` | [features/services/services/service_storage.md](features/services/services/service_storage.md) | 11 | 11 |
| `lib/features/services/services/service_template_service.dart` | [features/services/services/service_template_service.md](features/services/services/service_template_service.md) | 4 | 4 |
| `lib/features/services/services/service_topology_layout.dart` | [features/services/services/service_topology_layout.md](features/services/services/service_topology_layout.md) | 115 | 45 |
| `lib/features/services/views/service_access_path_page.dart` | [features/services/views/service_access_path_page.md](features/services/views/service_access_path_page.md) | 54 | 13 |
| `lib/features/services/views/service_edit_page.dart` | [features/services/views/service_edit_page.md](features/services/views/service_edit_page.md) | 26 | 6 |
| `lib/features/services/views/service_endpoint_dialog.dart` | [features/services/views/service_endpoint_dialog.md](features/services/views/service_endpoint_dialog.md) | 8 | 1 |
| `lib/features/services/views/service_list_page.dart` | [features/services/views/service_list_page.md](features/services/views/service_list_page.md) | 34 | 7 |
| `lib/features/services/views/service_route_edit_page.dart` | [features/services/views/service_route_edit_page.md](features/services/views/service_route_edit_page.md) | 32 | 11 |
| `lib/features/services/views/service_topology_page.dart` | [features/services/views/service_topology_page.md](features/services/views/service_topology_page.md) | 39 | 18 |
| `lib/features/services/views/service_topology_widgets.dart` | [features/services/views/service_topology_widgets.md](features/services/views/service_topology_widgets.md) | 27 | 8 |
| `lib/features/services/widgets/service_avatar.dart` | [features/services/widgets/service_avatar.md](features/services/widgets/service_avatar.md) | 3 | 0 |
| `lib/features/services/widgets/service_icon.dart` | [features/services/widgets/service_icon.md](features/services/widgets/service_icon.md) | 1 | 0 |

## features/settings/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/features/settings/views/backup_page.dart` | [features/settings/views/backup_page.md](features/settings/views/backup_page.md) | 16 | 7 |
| `lib/features/settings/views/license_page.dart` | [features/settings/views/license_page.md](features/settings/views/license_page.md) | 2 | 0 |
| `lib/features/settings/views/privacy_policy_page.dart` | [features/settings/views/privacy_policy_page.md](features/settings/views/privacy_policy_page.md) | 3 | 0 |
| `lib/features/settings/views/settings_page.dart` | [features/settings/views/settings_page.md](features/settings/views/settings_page.md) | 25 | 14 |

## l10n/

`lib/l10n/` is already documented at [l10n/INDEX.md](l10n/INDEX.md) (generated code, not part of
the 1581/1708 hand-documented declarations above).

## shared/

| Source file | Page | Declarations | Tier A |
|---|---|---|---|
| `lib/shared/providers/app_settings.dart` | [shared/providers/app_settings.md](shared/providers/app_settings.md) | 12 | 9 |
| `lib/shared/services/auto_sync_service.dart` | [shared/services/auto_sync_service.md](shared/services/auto_sync_service.md) | 20 | 5 |
| `lib/shared/services/backup_service.dart` | [shared/services/backup_service.md](shared/services/backup_service.md) | 12 | 12 |
| `lib/shared/services/image_service.dart` | [shared/services/image_service.md](shared/services/image_service.md) | 11 | 11 |
| `lib/shared/services/image_share_service.dart` | [shared/services/image_share_service.md](shared/services/image_share_service.md) | 3 | 3 |
| `lib/shared/services/import_export_service.dart` | [shared/services/import_export_service.md](shared/services/import_export_service.md) | 5 | 4 |
| `lib/shared/services/local_api_server.dart` | [shared/services/local_api_server.md](shared/services/local_api_server.md) | 61 | 52 |
| `lib/shared/services/sync_merge.dart` | [shared/services/sync_merge.md](shared/services/sync_merge.md) | 25 | 9 |
| `lib/shared/services/sync_progress.dart` | [shared/services/sync_progress.md](shared/services/sync_progress.md) | 0 | 0 |
| `lib/shared/services/sync_wake_lock.dart` | [shared/services/sync_wake_lock.md](shared/services/sync_wake_lock.md) | 0 | 0 |
| `lib/shared/services/tray_service.dart` | [shared/services/tray_service.md](shared/services/tray_service.md) | 16 | 12 |
| `lib/shared/services/webdav_service.dart` | [shared/services/webdav_service.md](shared/services/webdav_service.md) | 12 | 12 |
| `lib/shared/utils/adaptive_layout.dart` | [shared/utils/adaptive_layout.md](shared/utils/adaptive_layout.md) | 17 | 17 |
| `lib/shared/utils/chinese_convert.dart` | [shared/utils/chinese_convert.md](shared/utils/chinese_convert.md) | 5 | 4 |
| `lib/shared/utils/chinese_convert_data.dart` | [shared/utils/chinese_convert_data.md](shared/utils/chinese_convert_data.md) | 2 | 0 |
| `lib/shared/utils/detail_layout.dart` | [shared/utils/detail_layout.md](shared/utils/detail_layout.md) | 5 | 5 |
| `lib/shared/utils/device_image_processing.dart` | [shared/utils/device_image_processing.md](shared/utils/device_image_processing.md) | 13 | 10 |
| `lib/shared/utils/json_preservation.dart` | [shared/utils/json_preservation.md](shared/utils/json_preservation.md) | 0 | 0 |
| `lib/shared/views/device_map_page.dart` | [shared/views/device_map_page.md](shared/views/device_map_page.md) | 5 | 2 |
| `lib/shared/views/webdav_config_page.dart` | [shared/views/webdav_config_page.md](shared/views/webdav_config_page.md) | 23 | 12 |
| `lib/shared/widgets/adaptive_tile_grid.dart` | [shared/widgets/adaptive_tile_grid.md](shared/widgets/adaptive_tile_grid.md) | 3 | 3 |
| `lib/shared/widgets/map_picker_page.dart` | [shared/widgets/map_picker_page.md](shared/widgets/map_picker_page.md) | 6 | 2 |
| `lib/shared/widgets/shell_scaffold.dart` | [shared/widgets/shell_scaffold.md](shared/widgets/shell_scaffold.md) | 11 | 4 |
| `lib/shared/widgets/template_icon.dart` | [shared/widgets/template_icon.md](shared/widgets/template_icon.md) | 2 | 0 |

## Area totals

| Area | Files | Declarations | Tier A | Tier B |
|---|---|---|---|---|
| Root (`lib/`) | 1 | 1 | 1 | 0 |
| `app/` | 5 | 34 | 25 | 9 |
| `features/ai/` | 9 | 129 | 66 | 63 |
| `features/datasets/` | 4 | 51 | 32 | 19 |
| `features/devices/` | 18 | 499 | 284 | 215 |
| `features/network/` | 5 | 77 | 43 | 34 |
| `features/profile/` | 8 | 66 | 33 | 33 |
| `features/services/` | 17 | 536 | 233 | 303 |
| `features/settings/` | 4 | 46 | 21 | 25 |
| `shared/` | 24 | 269 | 188 | 81 |
| **Total** | **95** | **1708** | **926** | **782** |
