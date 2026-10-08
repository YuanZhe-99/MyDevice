# MyDevice `lib/` 函数索引


WebDAVConfigPage.build 将通用设置控件委托给 myapps_data。声明数量不变，
应用操作回调留在此处。

设置显示委托 myapps_ui，见 [shared-ui.md](../shared-ui.md)。

资料条目现在描述公共导出和应用适配，实现归属见 [shared-ui.md](../shared-ui.md)。

1.9.0 更新设备模型/编辑/详情/预设、网络模型/存储/详情、API 和 Markdown 输出。
新增页面：

| 源文件 | 页面 | 声明数 | Tier A |
|---|---|---|---|
| `lib/features/ai/services/ai_source_backend.dart` | [features/ai/services/ai_source_backend.md](features/ai/services/ai_source_backend.md) | 1 | 0 |
| `lib/features/ai/widgets/ai_source_controls.dart` | [features/ai/widgets/ai_source_controls.md](features/ai/widgets/ai_source_controls.md) | 8 | 0 |
| `lib/shared/services/webdav_privacy.dart` | [shared/services/webdav_privacy.md](shared/services/webdav_privacy.md) | 3 | 0 |
| `lib/features/devices/widgets/hardware_entries_editor.dart` | [features/devices/widgets/hardware_entries_editor.md](features/devices/widgets/hardware_entries_editor.md) | 12 | 5 |
| `lib/features/network/services/tailscale_csv.dart` | [features/network/services/tailscale_csv.md](features/network/services/tailscale_csv.md) | 4 | 4 |
| `lib/features/network/views/network_config_page.dart` | [features/network/views/network_config_page.md](features/network/views/network_config_page.md) | 6 | 2 |
| `lib/features/network/views/tailscale_import_page.dart` | [features/network/views/tailscale_import_page.md](features/network/views/tailscale_import_page.md) | 7 | 4 |

这是 MyDevice 仓库 `lib/` 的手写 Function Explanation Layer 文档顶层索引。每行链接到 `doc/en-us/functions/` 下镜像 `lib/` 树（`.dart` 替换为 `.md`）的逐源文件页。

**历史提取总计：** 仓库 `/// Purpose:` 注释计数是 **1719**（按 `AGENTS.md` 的 Function Explanation Layer 约定，排除生成 `lib/l10n/` 代码——见 [l10n/INDEX.md](l10n/INDEX.md)）。此索引文档化 **1862** 个声明——比 1719 多 143——因为几个文件中若干真实声明（尤其两个算法密集大文件 `service_analysis.dart` 和 `service_topology_layout.dart`，1.6.0 `features/ai/` 下端侧 AI 文件与两个洞察事实构建器中的常量、枚举、typedef 和私有正则表达式，以及 `device_search_service.dart` 和 `device_search_parsers.dart` 的类、枚举、常量和 typedef）源码完全无 `/// Purpose:` 文档注释，或个别情况（`service_analysis.dart`）注释错附到调用点语句而非真实声明。每种情况都在其文件页以对账行数说明显式点出；不静默发明任何东西强凑整数。1.6.1 文档审核为 `device.dart` 尾部的 27 个声明和 `device_search_service.dart` 中的三个构造函数补上了缺失的注释块，因此它们不再计入差额。

**1.7.0 重新计数。**实测 `/// Purpose:` 计数为 1550（此前 1493），各行之和为 1676（此前 1616），因此差额由 123 增至 126：本次发布新增 60 个已文档化声明（六个 `features/profile/` 文件 44 个，`data_modules.dart` 5 个，`theme.dart` 5 个，`shell_scaffold.dart` 3 个，`device_storage.dart` 2 个，`app_settings.dart` 1 个），其中三个是没有 `Purpose:` 注释的常量或字段。

**1.7.1 重新计数。**实测 `/// Purpose:` 计数为 1581（此前 1550），各行之和为 1708（此前 1676），因此差额由 126 增至 127：本次发布新增 32 个声明（新增两页 `avatar_editor.dart` 13 个和 `avatar_image.dart` 7 个，`device_storage.dart` 4 个，`shell_scaffold.dart` 3 个，`app_settings.dart` 2 个，`adaptive_layout.dart` 1 个，`profile_header.dart` 1 个，`profile_store.dart` 1 个），其中 31 个带有 `Purpose:` 注释（`shell_scaffold.dart` 多出的一行是第二个私有类，它没有该注释）。

**1.8.3 重新计数。**实测 `/// Purpose:` 计数为 1719（此前 1699），各行之和为 1862（此前 1826），因此差额从 127 增至 143。`service_topology_layout.dart` 新增 19 个带注释的声明：16 个用于对齐、错开与锚点拉平的 Tier A 辅助，以及 `_TrackSegment` 的构造函数、`overlaps` 和 `contains`。另有 16 个不带注释的声明：`_TrackSegment` 类及其 9 个字段、5 个新的 `static const`，以及顶层 `_nearLine`。该文件从 115 行增至 150 行。`service_topology_widgets.dart` 新增 `topologyEdgePath`（Tier A），从 25 行增至 26 行。

**1.8.2 重新计数。**实测 `/// Purpose:` 计数为 1699（此前 1659），各行之和为 1826（此前 1786），因此差额保持 127：RAID 阵列和硬盘健康状况新增 40 个声明，每一个都带有 `Purpose:` 注释——新增两页（`dataset_copy_summary.dart` 2 个、`storage_health_label.dart` 1 个），`device.dart` +12，`dataset_placement.dart` +14，`device_edit_page.dart` +5，`device_detail_page.dart` +2，`dataset.dart`、`dataset_storage.dart`、`dataset_topology.dart` 和 `dataset_edit_page.dart` 各 +1。`dataset_edit_page.md` 的行数说明此前写作 9，与 12 行和 12 条注释不符，现已更正。

**1.8.1 重新计数。**`dataset_topology.dart` 新增 `storageHeight`、`_packColumns` 和 `_columnCount`（+3，其中两个 Tier A）：1659 条注释，1786 行，差额 127。

**1.8.0 重新计数。**实测 `/// Purpose:` 计数为 1656（此前 1581），各行之和为 1783（此前 1708），因此差额保持 127：新增四页（`topology_canvas_viewer.dart` 22 个、`dataset_topology_page.dart` 30 个、`dataset_topology.dart` 10 个、`dataset_placement.dart` 8 个），`dataset_list_page.dart` +6，`service_topology_page.dart` +1，`service_topology_widgets.dart` −2（`fitTransform` 及其嵌套的 `offset` 移到了查看器），每一个都带有 `Purpose:` 注释。Tier 表的总计此前为 1709，与 1708 行不符，现已更正。

`/// Purpose:` 的数字通过 `grep -r '/// Purpose:' lib --include=*.dart`（排除 `lib/l10n/`）对源码核验。声明总数是手工维护的，并已**按当前工作区重新核对**：每个文件行都与其自身页面的声明表一致（行数和 Tier A），「区域总计」表和下方的 Tier 表都是各文件行的精确合计。请保持如此：增删某页面行的改动，须在同一提交中更新其文件行和两张总计表。

| Tier | 数量 |
|---|---|
| Tier A（完整条目） | 983 |
| Tier B（仅索引行） | 879 |
| **总计** | **1862** |

## 根（`lib/`）

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/main.dart` | [main.md](main.md) | 1 | 1 |

## app/

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/app/app.dart` | [app/app.md](app/app.md) | 2 | 0 |
| `lib/app/flavor.dart` | [app/flavor.md](app/flavor.md) | 4 | 1 |
| `lib/app/router.dart` | [app/router.md](app/router.md) | 1 | 0 |
| `lib/app/data_modules.dart` | [app/data_modules.md](app/data_modules.md) | 19 | 17 |
| `lib/app/theme.dart` | [app/theme.md](app/theme.md) | 7 | 6 |

## features/ai/

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/features/ai/services/ai_insights_cache.dart` | [features/ai/services/ai_insights_cache.md](features/ai/services/ai_insights_cache.md) | 8 | 7 |
| `lib/features/ai/services/genai_backend.dart` | [features/ai/services/genai_backend.md](features/ai/services/genai_backend.md) | 3 | 0 |
| `lib/features/ai/services/insight_language.dart` | [features/ai/services/insight_language.md](features/ai/services/insight_language.md) | 3 | 3 |
| `lib/features/ai/services/insight_prompts.dart` | [features/ai/services/insight_prompts.md](features/ai/services/insight_prompts.md) | 18 | 10 |
| `lib/features/ai/services/insight_service.dart` | [features/ai/services/insight_service.md](features/ai/services/insight_service.md) | 12 | 0 |
| `lib/features/ai/services/on_device_ai_service.dart` | [features/ai/services/on_device_ai_service.md](features/ai/services/on_device_ai_service.md) | 4 | 0 |
| `lib/features/ai/services/output_validation.dart` | [features/ai/services/output_validation.md](features/ai/services/output_validation.md) | 0 | 0 |
| `lib/features/ai/widgets/ai_insight_card.dart` | [features/ai/widgets/ai_insight_card.md](features/ai/widgets/ai_insight_card.md) | 11 | 0 |
| `lib/features/ai/widgets/ai_settings_tiles.dart` | [features/ai/widgets/ai_settings_tiles.md](features/ai/widgets/ai_settings_tiles.md) | 6 | 0 |

## features/datasets/

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/features/datasets/models/dataset.dart` | [features/datasets/models/dataset.md](features/datasets/models/dataset.md) | 13 | 13 |
| `lib/features/datasets/services/dataset_storage.dart` | [features/datasets/services/dataset_storage.md](features/datasets/services/dataset_storage.md) | 10 | 10 |
| `lib/features/datasets/services/dataset_placement.dart` | [features/datasets/services/dataset_placement.md](features/datasets/services/dataset_placement.md) | 22 | 5 |
| `lib/features/datasets/services/dataset_topology.dart` | [features/datasets/services/dataset_topology.md](features/datasets/services/dataset_topology.md) | 14 | 5 |
| `lib/features/datasets/views/dataset_edit_page.dart` | [features/datasets/views/dataset_edit_page.md](features/datasets/views/dataset_edit_page.md) | 13 | 4 |
| `lib/features/datasets/views/dataset_copy_summary.dart` | [features/datasets/views/dataset_copy_summary.md](features/datasets/views/dataset_copy_summary.md) | 2 | 2 |
| `lib/features/datasets/views/dataset_list_page.dart` | [features/datasets/views/dataset_list_page.md](features/datasets/views/dataset_list_page.md) | 24 | 9 |
| `lib/features/datasets/views/dataset_topology_page.dart` | [features/datasets/views/dataset_topology_page.md](features/datasets/views/dataset_topology_page.md) | 30 | 7 |

## features/devices/

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/features/devices/models/device.dart` | [features/devices/models/device.md](features/devices/models/device.md) | 79 | 60 |
| `lib/features/devices/services/chip_search_service.dart` | [features/devices/services/chip_search_service.md](features/devices/services/chip_search_service.md) | 13 | 13 |
| `lib/features/devices/services/device_search_parsers.dart` | [features/devices/services/device_search_parsers.md](features/devices/services/device_search_parsers.md) | 40 | 37 |
| `lib/features/devices/services/device_search_service.dart` | [features/devices/services/device_search_service.md](features/devices/services/device_search_service.md) | 39 | 27 |
| `lib/features/devices/services/device_storage.dart` | [features/devices/services/device_storage.md](features/devices/services/device_storage.md) | 60 | 37 |
| `lib/features/devices/services/exchange_rate_service.dart` | [features/devices/services/exchange_rate_service.md](features/devices/services/exchange_rate_service.md) | 25 | 24 |
| `lib/features/devices/services/finance_insight_facts.dart` | [features/devices/services/finance_insight_facts.md](features/devices/services/finance_insight_facts.md) | 5 | 1 |
| `lib/features/devices/services/preset_service.dart` | [features/devices/services/preset_service.md](features/devices/services/preset_service.md) | 19 | 15 |
| `lib/features/devices/views/chip_search_dialog.dart` | [features/devices/views/chip_search_dialog.md](features/devices/views/chip_search_dialog.md) | 11 | 5 |
| `lib/features/devices/views/device_detail_page.dart` | [features/devices/views/device_detail_page.md](features/devices/views/device_detail_page.md) | 22 | 7 |
| `lib/features/devices/views/device_edit_page.dart` | [features/devices/views/device_edit_page.md](features/devices/views/device_edit_page.md) | 68 | 20 |
| `lib/features/devices/views/device_finance_overview_page.dart` | [features/devices/views/device_finance_overview_page.md](features/devices/views/device_finance_overview_page.md) | 36 | 19 |
| `lib/features/devices/views/device_image_editor_page.dart` | [features/devices/views/device_image_editor_page.md](features/devices/views/device_image_editor_page.md) | 22 | 6 |
| `lib/features/devices/views/device_list_page.dart` | [features/devices/views/device_list_page.md](features/devices/views/device_list_page.md) | 45 | 16 |
| `lib/features/devices/views/device_search_dialog.dart` | [features/devices/views/device_search_dialog.md](features/devices/views/device_search_dialog.md) | 20 | 7 |
| `lib/features/devices/widgets/device_avatar.dart` | [features/devices/widgets/device_avatar.md](features/devices/widgets/device_avatar.md) | 12 | 0 |
| `lib/features/devices/widgets/device_category_icon.dart` | [features/devices/widgets/device_category_icon.md](features/devices/widgets/device_category_icon.md) | 2 | 2 |
| `lib/features/devices/widgets/storage_health_label.dart` | [features/devices/widgets/storage_health_label.md](features/devices/widgets/storage_health_label.md) | 1 | 1 |
| `lib/features/devices/widgets/template_image_picker.dart` | [features/devices/widgets/template_image_picker.md](features/devices/widgets/template_image_picker.md) | 9 | 4 |

## features/network/

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/features/network/models/network.dart` | [features/network/models/network.md](features/network/models/network.md) | 17 | 16 |
| `lib/features/network/services/network_storage.dart` | [features/network/services/network_storage.md](features/network/services/network_storage.md) | 11 | 11 |
| `lib/features/network/views/network_detail_page.dart` | [features/network/views/network_detail_page.md](features/network/views/network_detail_page.md) | 28 | 13 |
| `lib/features/network/views/network_edit_page.dart` | [features/network/views/network_edit_page.md](features/network/views/network_edit_page.md) | 9 | 1 |
| `lib/features/network/views/network_list_page.dart` | [features/network/views/network_list_page.md](features/network/views/network_list_page.md) | 16 | 6 |

## features/profile/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/features/profile/models/profile_data.dart` | [features/profile/models/profile_data.md](features/profile/models/profile_data.md) | 8 | 2 |
| `lib/features/profile/services/profile_merge.dart` | [features/profile/services/profile_merge.md](features/profile/services/profile_merge.md) | 4 | 2 |
| `lib/features/profile/services/avatar_image.dart` | [features/profile/services/avatar_image.md](features/profile/services/avatar_image.md) | 7 | 5 |
| `lib/features/profile/services/profile_store.dart` | [features/profile/services/profile_store.md](features/profile/services/profile_store.md) | 11 | 7 |
| `lib/features/profile/providers/profile_provider.dart` | [features/profile/providers/profile_provider.md](features/profile/providers/profile_provider.md) | 7 | 2 |
| `lib/features/profile/views/avatar_editor.dart` | [features/profile/views/avatar_editor.md](features/profile/views/avatar_editor.md) | 13 | 7 |
| `lib/features/profile/views/profile_avatar.dart` | [features/profile/views/profile_avatar.md](features/profile/views/profile_avatar.md) | 5 | 3 |
| `lib/features/profile/views/profile_header.dart` | [features/profile/views/profile_header.md](features/profile/views/profile_header.md) | 11 | 5 |

同步的个人资料（1.7.0）：名称和头像。见 [../features/profile.md](../features/profile.md)。

## features/services/

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/features/services/models/service.dart` | [features/services/models/service.md](features/services/models/service.md) | 42 | 33 |
| `lib/features/services/services/service_access_patterns.dart` | [features/services/services/service_access_patterns.md](features/services/services/service_access_patterns.md) | 47 | 25 |
| `lib/features/services/services/service_analysis.dart` | [features/services/services/service_analysis.md](features/services/services/service_analysis.md) | 76 | 44 |
| `lib/features/services/services/service_insight_facts.dart` | [features/services/services/service_insight_facts.md](features/services/services/service_insight_facts.md) | 6 | 2 |
| `lib/features/services/services/service_labels.dart` | [features/services/services/service_labels.md](features/services/services/service_labels.md) | 11 | 5 |
| `lib/features/services/services/service_storage.dart` | [features/services/services/service_storage.md](features/services/services/service_storage.md) | 11 | 11 |
| `lib/features/services/services/service_template_service.dart` | [features/services/services/service_template_service.md](features/services/services/service_template_service.md) | 4 | 4 |
| `lib/features/services/services/service_topology_layout.dart` | [features/services/services/service_topology_layout.md](features/services/services/service_topology_layout.md) | 150 | 61 |
| `lib/features/services/views/service_access_path_page.dart` | [features/services/views/service_access_path_page.md](features/services/views/service_access_path_page.md) | 54 | 13 |
| `lib/features/services/views/service_edit_page.dart` | [features/services/views/service_edit_page.md](features/services/views/service_edit_page.md) | 26 | 6 |
| `lib/features/services/views/service_endpoint_dialog.dart` | [features/services/views/service_endpoint_dialog.md](features/services/views/service_endpoint_dialog.md) | 8 | 1 |
| `lib/features/services/views/service_list_page.dart` | [features/services/views/service_list_page.md](features/services/views/service_list_page.md) | 34 | 7 |
| `lib/features/services/views/service_route_edit_page.dart` | [features/services/views/service_route_edit_page.md](features/services/views/service_route_edit_page.md) | 32 | 11 |
| `lib/features/services/views/service_topology_page.dart` | [features/services/views/service_topology_page.md](features/services/views/service_topology_page.md) | 40 | 18 |
| `lib/features/services/views/service_topology_widgets.dart` | [features/services/views/service_topology_widgets.md](features/services/views/service_topology_widgets.md) | 26 | 8 |
| `lib/features/services/widgets/service_avatar.dart` | [features/services/widgets/service_avatar.md](features/services/widgets/service_avatar.md) | 3 | 0 |
| `lib/features/services/widgets/service_icon.dart` | [features/services/widgets/service_icon.md](features/services/widgets/service_icon.md) | 1 | 0 |

## features/settings/

| 源文件 | 页面 | 声明 | Tier A |
|---|---|---|---|
| `lib/features/settings/views/backup_page.dart` | [features/settings/views/backup_page.md](features/settings/views/backup_page.md) | 16 | 7 |
| `lib/features/settings/views/license_page.dart` | [features/settings/views/license_page.md](features/settings/views/license_page.md) | 2 | 0 |
| `lib/features/settings/views/privacy_policy_page.dart` | [features/settings/views/privacy_policy_page.md](features/settings/views/privacy_policy_page.md) | 3 | 0 |
| `lib/features/settings/views/settings_page.dart` | [features/settings/views/settings_page.md](features/settings/views/settings_page.md) | 25 | 14 |

## l10n/

`lib/l10n/` 已在 [l10n/INDEX.md](l10n/INDEX.md) 文档化（生成代码，不属上面 1719/1862 手写声明）。

## shared/

| 源文件 | 页面 | 声明 | Tier A |
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
| `lib/shared/widgets/shell_scaffold.dart` | [shared/widgets/shell_scaffold.md](shared/widgets/shell_scaffold.md) | 5 | 2 |
| `lib/shared/widgets/template_icon.dart` | [shared/widgets/template_icon.md](shared/widgets/template_icon.md) | 2 | 0 |
| `lib/shared/widgets/topology_canvas_viewer.dart` | [shared/widgets/topology_canvas_viewer.md](shared/widgets/topology_canvas_viewer.md) | 22 | 6 |

## 区域总计

| 区域 | 文件 | 声明 | Tier A | Tier B |
|---|---|---|---|---|
| 根（`lib/`） | 1 | 1 | 1 | 0 |
| `app/` | 5 | 34 | 25 | 9 |
| `features/ai/` | 11 | 90 | 20 | 70 |
| `features/datasets/` | 8 | 128 | 55 | 73 |
| `features/devices/` | 19 | 519 | 296 | 223 |
| `features/network/` | 5 | 77 | 43 | 34 |
| `features/profile/` | 8 | 66 | 33 | 33 |
| `features/services/` | 17 | 571 | 249 | 322 |
| `features/settings/` | 4 | 46 | 21 | 25 |
| `shared/` | 26 | 288 | 192 | 96 |
| **总计** | **101** | **1862** | **983** | **879** |
当前逐文件表合计：108 个文件、1861 个声明（Tier A 958，Tier B 903）。
