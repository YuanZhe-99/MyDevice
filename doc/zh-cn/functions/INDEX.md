# MyDevice `lib/` 函数索引

这是 MyDevice 仓库 `lib/` 的手写 Function Explanation Layer 文档顶层索引。每行链接到 `doc/en-us/functions/` 下镜像 `lib/` 树（`.dart` 替换为 `.md`）的逐源文件页。

**总计：** 仓库 `/// Purpose:` 注释计数是 **1214**（按 `AGENTS.md` 的 Function Explanation Layer 约定，排除生成 `lib/l10n/` 代码——见 [l10n/INDEX.md](l10n/INDEX.md)）。此索引文档化 **1328** 个声明——比 1214 多 114——因为几个文件中若干真实声明（尤其两个算法密集大文件 `service_analysis.dart` 和 `service_topology_layout.dart`，加 `device.dart` 的尾部小节）源码完全无 `/// Purpose:` 文档注释，或个别情况（`service_analysis.dart`）注释错附到调用点语句而非真实声明。每种情况都在其文件页以对账行数说明显式点出；不静默发明任何东西强凑整数。

`/// Purpose:` 的数字通过 `grep -r '/// Purpose:' lib --include=*.dart`（排除 `lib/l10n/`）对源码核验。声明总数是手工维护的，并已**在 1.5.6 重新核查**：每个文件行都与其自身页面的声明表一致（行数和 Tier A），「区域总计」表和下方的 Tier 表都是各文件行的精确合计。请保持如此：增删某页面行的改动，须在同一提交中更新其文件行和两张总计表。

| Tier | 数量 |
|---|---|
| Tier A（完整条目） | 713 |
| Tier B（仅索引行） | 615 |
| **总计** | **1328** |

## 根（`lib/`）

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/main.dart` | [main.md](main.md) | 1 | 1 |

## app/

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/app/app.dart` | [app/app.md](app/app.md) | 2 | 0 |
| `lib/app/flavor.dart` | [app/flavor.md](app/flavor.md) | 3 | 1 |
| `lib/app/router.dart` | [app/router.md](app/router.md) | 1 | 0 |
| `lib/app/data_modules.dart` | [app/data_modules.md](app/data_modules.md) | 11 | 11 |
| `lib/app/theme.dart` | [app/theme.md](app/theme.md) | 3 | 3 |

## features/datasets/

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/features/datasets/models/dataset.dart` | [features/datasets/models/dataset.md](features/datasets/models/dataset.md) | 12 | 12 |
| `lib/features/datasets/services/dataset_storage.dart` | [features/datasets/services/dataset_storage.md](features/datasets/services/dataset_storage.md) | 7 | 7 |
| `lib/features/datasets/views/dataset_edit_page.dart` | [features/datasets/views/dataset_edit_page.md](features/datasets/views/dataset_edit_page.md) | 12 | 3 |
| `lib/features/datasets/views/dataset_list_page.dart` | [features/datasets/views/dataset_list_page.md](features/datasets/views/dataset_list_page.md) | 18 | 8 |

## features/devices/

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/features/devices/models/device.dart` | [features/devices/models/device.md](features/devices/models/device.md) | 58 | 46 |
| `lib/features/devices/services/chip_search_service.dart` | [features/devices/services/chip_search_service.md](features/devices/services/chip_search_service.md) | 13 | 13 |
| `lib/features/devices/services/device_search_parsers.dart` | [features/devices/services/device_search_parsers.md](features/devices/services/device_search_parsers.md) | 25 | 24 |
| `lib/features/devices/services/device_search_service.dart` | [features/devices/services/device_search_service.md](features/devices/services/device_search_service.md) | 24 | 16 |
| `lib/features/devices/services/device_storage.dart` | [features/devices/services/device_storage.md](features/devices/services/device_storage.md) | 35 | 22 |
| `lib/features/devices/services/exchange_rate_service.dart` | [features/devices/services/exchange_rate_service.md](features/devices/services/exchange_rate_service.md) | 21 | 20 |
| `lib/features/devices/services/preset_service.dart` | [features/devices/services/preset_service.md](features/devices/services/preset_service.md) | 12 | 11 |
| `lib/features/devices/views/chip_search_dialog.dart` | [features/devices/views/chip_search_dialog.md](features/devices/views/chip_search_dialog.md) | 11 | 5 |
| `lib/features/devices/views/device_detail_page.dart` | [features/devices/views/device_detail_page.md](features/devices/views/device_detail_page.md) | 20 | 6 |
| `lib/features/devices/views/device_edit_page.dart` | [features/devices/views/device_edit_page.md](features/devices/views/device_edit_page.md) | 59 | 14 |
| `lib/features/devices/views/device_finance_overview_page.dart` | [features/devices/views/device_finance_overview_page.md](features/devices/views/device_finance_overview_page.md) | 34 | 16 |
| `lib/features/devices/views/device_list_page.dart` | [features/devices/views/device_list_page.md](features/devices/views/device_list_page.md) | 46 | 16 |
| `lib/features/devices/views/device_search_dialog.dart` | [features/devices/views/device_search_dialog.md](features/devices/views/device_search_dialog.md) | 20 | 7 |
| `lib/features/devices/widgets/device_avatar.dart` | [features/devices/widgets/device_avatar.md](features/devices/widgets/device_avatar.md) | 7 | 0 |
| `lib/features/devices/widgets/device_category_icon.dart` | [features/devices/widgets/device_category_icon.md](features/devices/widgets/device_category_icon.md) | 2 | 2 |

## features/network/

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/features/network/models/network.dart` | [features/network/models/network.md](features/network/models/network.md) | 17 | 16 |
| `lib/features/network/services/network_storage.dart` | [features/network/services/network_storage.md](features/network/services/network_storage.md) | 7 | 7 |
| `lib/features/network/views/network_detail_page.dart` | [features/network/views/network_detail_page.md](features/network/views/network_detail_page.md) | 27 | 11 |
| `lib/features/network/views/network_edit_page.dart` | [features/network/views/network_edit_page.md](features/network/views/network_edit_page.md) | 9 | 1 |
| `lib/features/network/views/network_list_page.dart` | [features/network/views/network_list_page.md](features/network/views/network_list_page.md) | 16 | 6 |

## features/services/

| 源文件 | 页面 | 声明 | Tier A |
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

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/features/settings/views/backup_page.dart` | [features/settings/views/backup_page.md](features/settings/views/backup_page.md) | 16 | 7 |
| `lib/features/settings/views/license_page.dart` | [features/settings/views/license_page.md](features/settings/views/license_page.md) | 2 | 0 |
| `lib/features/settings/views/privacy_policy_page.dart` | [features/settings/views/privacy_policy_page.md](features/settings/views/privacy_policy_page.md) | 3 | 0 |
| `lib/features/settings/views/settings_page.dart` | [features/settings/views/settings_page.md](features/settings/views/settings_page.md) | 25 | 14 |

## l10n/

`lib/l10n/` 已在 [l10n/INDEX.md](l10n/INDEX.md) 文档化（生成代码，不属上面 1214/1328 手写声明）。

## shared/

| 源文件 | 页面 | 声明 | Tier A |
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

## 区域总计

| 区域 | 文件 | 声明 | Tier A | Tier B |
|---|---|---|---|---|
| 根（`lib/`） | 1 | 1 | 1 | 0 |
| `app/` | 5 | 20 | 15 | 5 |
| `features/datasets/` | 4 | 49 | 30 | 19 |
| `features/devices/` | 15 | 387 | 218 | 169 |
| `features/network/` | 5 | 76 | 41 | 35 |
| `features/services/` | 14 | 524 | 228 | 296 |
| `features/settings/` | 4 | 46 | 21 | 25 |
| `shared/` | 20 | 225 | 159 | 66 |
| **总计** | **68** | **1328** | **713** | **615** |
