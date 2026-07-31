# 在线搜索与预设

来源：`lib/features/devices/services/device_search_service.dart`、`lib/features/devices/services/chip_search_service.dart` 和 `lib/features/devices/services/preset_service.dart`。`AppFlavor` 见 [架构 — AppFlavor](../architecture.md#appflavor)，这些填充的 `CpuInfo`/`GpuInfo` 形态见 [数据格式](../data-formats.md)。

## 设备规格搜索 — `device_search_service.dart`

`DeviceSearchService` 从两个源获取设备规格，并发运行且各自单独吞错：

- **GSMArena**（`_searchGSMArena` / `_fetchGSMArenaDetail`）。
- **Notebookcheck**（`_searchNotebookcheck` / `_fetchNotebookcheckDetail`）。

```dart
static Future<List<DeviceSearchResult>> search(String query) async {
  if (AppFlavor.isStore) return [];
  ...
}
```

`search()` 和 `fetchDetail()` 两者在 `AppFlavor.isStore` 为 true 时都提前返回（空列表 / 未修改输入结果）——源码直接确认。

## 芯片规格搜索 — `chip_search_service.dart`

`ChipSearchService` 从 TechPowerUp 和 Intel 获取 CPU 规格，从 TechPowerUp 和 AMD 获取 GPU 规格：

- **TechPowerUp** — CPU `th`/`td` 规格表、GPU `og:description` 元标签（`_searchTechPowerUpCpu`、`_searchTechPowerUpGpu`）。
- **AMD**（官方）— 带 `dt`/`dd` 规格对的 CPU/GPU 产品页（`_searchAmdCpu`、`_searchAmdGpu`）。
- **Intel**（官方）— 模型/缓存/最大频率的 URL 段解析（`_searchIntelCpu`）。

源码确认门控：

```dart
static Future<List<ChipSearchResult>> searchCpu(...) async {
  ...
  if (AppFlavor.isFull) {
    // query TechPowerUp / Intel
  }
  ...
}
```

在线 CPU/GPU 搜索只在 `if (AppFlavor.isFull)` 运行——即商店构建完全跳过，与 `device_search_service.dart` 提前返回相同有效行为。

## 商店风格门控要求

按 `AGENTS.md` 的 Build Flavors 小节，在线设备/芯片搜索必须为商店构建完全门控，在**四个调用点**检查：

1. `lib/features/devices/services/device_search_service.dart` — `search()` 和 `fetchDetail()` 商店提前返回。
2. `lib/features/devices/services/chip_search_service.dart` — 在线 CPU/GPU 搜索门控在 `AppFlavor.isFull` 后。
3. `lib/features/devices/views/device_edit_page.dart` — 三个在线搜索按钮商店隐藏。
4. `lib/features/devices/views/device_list_page.dart` — 在线搜索 FAB 商店隐藏。

任何未门控在线搜索路径都是 App Store 拒绝风险（Apple/Google 审核对商店分发应用中第三方站点网络抓取的指南）。`AppFlavor.isStore` 如何从 `FLAVOR` dart-define 派生见 [架构 — AppFlavor](../architecture.md#appflavor)。

## 捆绑预设 — `preset_service.dart`

`PresetService` 经 `rootBundle.loadString()` 从 `assets/presets/` 加载捆绑预设数据：

- `cpus.json` → `loadCpus()` → `List<CpuInfo>`
- `gpus.json` → `loadGpus()` → `List<GpuInfo>`
- `brands.json` → `loadBrands()` → `List<BrandEntry>`
- `device_templates.json` → `loadTemplates()` → `List<DeviceTemplate>`

这些**惰性加载并缓存**——每个 `loadXxx()` 只读并解析其资产文件一次，之后调用复用解析结果，因此反复打开设备编辑器不每次重新解析捆绑 JSON。

## 相关

- [设备](devices.md) 了解 `CpuInfo`/`GpuInfo`/设备字段如何从搜索结果或预设填充。
- [数据格式](../data-formats.md) 了解精确 `CpuInfo`/`GpuInfo` 形态。
