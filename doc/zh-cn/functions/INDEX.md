# MyDevice `lib/` 函数索引

这是 MyDevice 仓库 `lib/` 的手写 Function Explanation Layer 文档顶层索引。每行链接到 `doc/en-us/functions/` 下镜像 `lib/` 树（`.dart` 替换为 `.md`）的逐源文件页。

**总计：** 仓库 `/// Purpose:` 注释计数是 **943**（按 `AGENTS.md` 的 Function Explanation Layer 约定，排除生成 `lib/l10n/` 代码——见 [l10n/INDEX.md](l10n/INDEX.md)）。此索引文档化 **1132** 个声明——比 943 多 189——因为几个文件中若干真实声明（尤其两个算法密集大文件 `service_analysis.dart` 和 `service_topology_layout.dart`，加 `device.dart` 和 `service_list_page.dart` 的尾部小节）源码完全无 `/// Purpose:` 文档注释，或个别情况（`service_analysis.dart`）注释错附到调用点语句而非真实声明。每种情况都在其文件页以对账行数说明显式点出；不静默发明任何东西强凑整数。

`/// Purpose:` 的数字通过 `grep -r '/// Purpose:' lib --include=*.dart` 对源码核验。声明总数是手工维护的，目前**已知存在两处偏差**。其一，对各文件页做行级统计约得到 1023 个声明行，而非 1132。其二，本表的 Tier A/B 拆分与下方「区域总计」表逐行相加得到的拆分相差 15（相加为 670/462，本表标称 685/447），尽管两者的 1132 总数一致。两处偏差都早于 `device_search_parsers.dart` 条目就已存在，此处原样保留而非掩盖，因为要对账它们需要重新审计每一页，而不是改动这两张表。在完成那次审计之前，请以各文件页的行为准，并把两个总数都视为近似值。

| Tier | 数量 |
|---|---|
| Tier A（完整条目） | 685 |
| Tier B（仅索引行） | 447 |
| **总计** | **1132** |

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
| `lib/features/services/services/service_analysis.dart` | [features/services/services/service_analysis.md](features/services/services/service_analysis.md) | 52 | 36 |
| `lib/features/services/services/service_storage.dart` | [features/services/services/service_storage.md](features/services/services/service_storage.md) | 8 | 8 |
| `lib/features/services/services/service_template_service.dart` | [features/services/services/service_template_service.md](features/services/services/service_template_service.md) | 4 | 4 |
| `lib/features/services/services/service_topology_layout.dart` | [features/services/services/service_topology_layout.md](features/services/services/service_topology_layout.md) | 87 | 34 |
| `lib/features/services/views/service_edit_page.dart` | [features/services/views/service_edit_page.md](features/services/views/service_edit_page.md) | 25 | 6 |
| `lib/features/services/views/service_list_page.dart` | [features/services/views/service_list_page.md](features/services/views/service_list_page.md) | 84 | 24 |
| `lib/features/services/views/service_route_edit_page.dart` | [features/services/views/service_route_edit_page.md](features/services/views/service_route_edit_page.md) | 24 | 8 |

## features/settings/

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/features/settings/views/backup_page.dart` | [features/settings/views/backup_page.md](features/settings/views/backup_page.md) | 16 | 7 |
| `lib/features/settings/views/license_page.dart` | [features/settings/views/license_page.md](features/settings/views/license_page.md) | 2 | 0 |
| `lib/features/settings/views/privacy_policy_page.dart` | [features/settings/views/privacy_policy_page.md](features/settings/views/privacy_policy_page.md) | 3 | 0 |
| `lib/features/settings/views/settings_page.dart` | [features/settings/views/settings_page.md](features/settings/views/settings_page.md) | 25 | 14 |

## l10n/

`lib/l10n/` 已在 [l10n/INDEX.md](l10n/INDEX.md) 文档化（生成代码，不属上面 943/1132 手写声明）。

## shared/

| 源文件 | 页面 | 声明 | Tier A |
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
| `lib/shared/utils/adaptive_layout.dart` | [shared/utils/adaptive_layout.md](shared/utils/adaptive_layout.md) | 15 | 15 |
| `lib/shared/utils/detail_layout.dart` | [shared/utils/detail_layout.md](shared/utils/detail_layout.md) | 4 | 4 |
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
| `app/` | 4 | 9 | 4 | 5 |
| `features/datasets/` | 4 | 49 | 30 | 19 |
| `features/devices/` | 15 | 381 | 201 | 180 |
| `features/network/` | 5 | 76 | 41 | 35 |
| `features/services/` | 8 | 326 | 153 | 173 |
| `features/settings/` | 4 | 46 | 21 | 25 |
| `shared/` | 20 | 308 | 244 | 64 |
| **总计** | **61** | **1196** | **710** | **486** |
