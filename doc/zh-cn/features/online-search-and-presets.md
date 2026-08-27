# 在线搜索与预设

来源：`lib/features/devices/services/device_search_service.dart`、`lib/features/devices/services/chip_search_service.dart` 和 `lib/features/devices/services/preset_service.dart`。`AppFlavor` 见 [架构 — AppFlavor](../architecture.md#appflavor)，这些填充的 `CpuInfo`/`GpuInfo` 形态见 [数据格式](../data-formats.md)。

## 设备规格搜索 — `device_search_service.dart`

`DeviceSearchService` 从两个源获取设备规格，共用一个客户端并发运行，各自上报自己的结果状态，而不是把失败吞掉：

- **Notebookcheck**（`_searchNotebookcheck` / `_fetchNotebookcheckDetail`）—— 笔记本、平板、手机和智能手表；
  详情页带有完整的规格表。
- **PhoneDB**（`_searchPhonedb` / `_fetchPhonedbDetail`）—— 细到 SKU 级别的手机数据，并加了一道相关性闸门，
  因为它对未收录的型号会以宽松的全文匹配作答。

所有页面解析都放在 `device_search_parsers.dart` 中，该文件不涉及网络，并针对 `test/fixtures/` 中保存的固定样本
做单元测试。

```dart
static Future<DeviceSearchResponse> search(String query) async {
  if (AppFlavor.isStore) {
    return const DeviceSearchResponse(results: [], outcomes: []);
  }
  ...
}
```

`search()` 和 `fetchDetail()` 两者在 `AppFlavor.isStore` 为 true 时都提前返回（空响应 / 未修改输入结果）——源码直接确认。

**GSMArena 已被移除。** 它对每个请求都返回以 HTTP 200 承载的 Cloudflare Turnstile 验证页。旧代码只检查状态码，
随后其行匹配模式失配并返回空列表——这与「没有这台设备」无法区分。纯 HTTP 客户端无法通过该验证，因此这个数据源
无法靠抓取恢复。

### 如实上报失败

正是那次静默故障，使得 `search()` 现在返回 `DeviceSearchResponse`，其中为每个数据源各带一条
`DeviceSourceOutcome`，其 `DeviceSearchStatus` 取值为：

| Status | Meaning | Retry helps? |
|---|---|---|
| `ok` | 数据源已响应且解析成功；`resultCount` 仍可能为 0 | 不适用 |
| `blocked` | 返回的是机器人验证墙或验证页，而非内容 | 否 |
| `unreachable` | DNS、套接字、超时，或非 200 状态码 | 是 |
| `markupChanged` | 有响应，但解析器依赖的结构一个都不存在 | 否——需要改代码 |

零匹配的搜索被有意判定为 **`ok` 而非失败**：`isNotebookcheckSearchPage` 和 `isPhonedbResultsPage` 能识别出
「页面健康但没有结果行」。缺少这个区分，新增的信号就会对每一台该数据源未收录的设备虚报警。

`tool/check_sources.dart` 会探测每个数据源并打印同样的分类，因此抓取逻辑是否腐化可以用一条命令查明，而不必等
用户发现。它有意**不**接入 CI，因为它会向第三方发起真实网络请求。

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
