# lib/features/devices/services/device_search_service.dart

`DeviceSearchService` 从两个公共站——GSMArena 和 Notebookcheck——抓取设备规格（手机、笔记本、平板），并发运行、各单独吞错。它无捆绑 API 密钥；每个结果都来自直接解析站点 HTML。概念总览见 [在线搜索与预设 — 设备规格搜索](../../../../features/online-search-and-presets.md#device-spec-search---device_search_servicedart)，`DeviceSearchResult` 最终经设备编辑页（不在此文件）填充进 `Device` 的 `CpuInfo`/`GpuInfo`/`StorageInfo` 形态见 [`device.md`](../models/device.md)。

**商店风格门控**：两个公共入口点 [`search`](#search) 和 [`fetchDetail`](#fetchdetail) 在 `AppFlavor.isFull` 为 false（即 `AppFlavor.isStore` 为 true）时都提前返回——分别空列表和未修改输入结果——源码直接确认。这是 `AGENTS.md` Build Flavors 小节要求的四个门控检查之一（`AppFlavor` 见 [架构](../../../../architecture.md#appflavor)）；其他三个是 [`chip_search_service.md`](chip_search_service.md) 的 `AppFlavor.isFull` 检查和不在此文件、不在此批重新验证的两个 UI 调用点（`device_edit_page.dart` 的三个在线搜索按钮、`device_list_page.dart` 的在线搜索 FAB）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`DeviceSearchResult`](#devicesearchresult-new) | 构造函数 | A | 创建 `DeviceSearchResult` 实例。 |
| [`withDetail`](#withdetail) | 方法（`DeviceSearchResult`） | A | 创建带详情页字段填充、标记 `detailFetched: true` 的副本。 |
| [`search`](#search) | 静态方法 | A | 并发搜索 GSMArena 和 Notebookcheck 获取快速结果。 |
| [`fetchDetail`](#fetchdetail) | 静态方法 | A | 抓取其详情页为搜索结果获取完整详情。 |
| [`_searchGSMArena`](#_searchgsmarena) | 静态方法（私有） | A | 抓取 GSMArena 的快速搜索结果页。 |
| [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail) | 静态方法（私有） | A | 抓取 GSMArena 设备详情页获取完整规格。 |
| [`_spec`](#_spec) | 静态方法（私有） | A | 从 GSMArena 详情 HTML 提取一个 `data-spec="key"` 值。 |
| [`_splitBrandModel`](#_splitbrandmodel) | 静态方法（私有） | A | 在第一个空格把设备名拆分为品牌和型号。 |
| [`_parseMemory`](#_parsememory) | 静态方法（私有） | A | 把组合存储+RAM 字符串解析为单独 RAM/存储值。 |
| [`_parseScreenSize`](#_parsescreensize) | 静态方法（私有） | A | 从自由文本提取英寸屏幕尺寸。 |
| [`_parseResolution`](#_parseresolution) | 静态方法（私有） | A | 从自由文本提取 `W x H` 分辨率对。 |
| [`_parseBattery`](#_parsebattery) | 静态方法（私有） | A | 从自由文本提取毫安时电池容量。 |
| [`_parseReleaseDate`](#_parsereleasedate) | 静态方法（私有） | A | 把 GSMArena 发布日期字符串解析为 `DateTime`。 |
| [`_parseMonth`](#_parsemonth) | 静态方法（私有） | A | 把英文月份名映射到其基于 1 的数字。 |
| [`_isDeviceImage`](#_isdeviceimage) | 静态方法（私有） | A | 拒绝广告/联盟/跟踪图像 URL，接受真实设备照片。 |
| [`_stripHtml`](#_striphtml) | 静态方法（私有） | A | 从片段剥离 HTML 标签和实体，折叠空白。 |
| [`_searchNotebookcheck`](#_searchnotebookcheck) | 静态方法（私有） | A | 抓取 Notebookcheck 的笔记本搜索结果表。 |
| [`_fetchNotebookcheckDetail`](#_fetchnotebookcheckdetail) | 静态方法（私有） | A | 从 Notebookcheck 详情页 JSON-LD 提取设备图像。 |

行数（18）不匹配 `grep -c 'Purpose:' device_search_service.dart`（16）：`DeviceSearchResult` 构造函数和其 `withDetail` 方法（前两行）无 `/// Purpose:` 文档注释块——`DeviceSearchService` 自己的每个方法都有。

## 文档

### `const DeviceSearchResult({required this.source, this.sourceUrl, ..., this.detailFetched = false})` <a id="devicesearchresult-new"></a>
- **种类：** `DeviceSearchResult` 的构造函数。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 28 行）。
- **用途：** 持有一个来自在线设备数据库的搜索结果——来源名/URL、缩略图，和（已获取时）完整详情字段。
- **输入：** `source` 必填；每个规格字段可选；`detailFetched` 默认 `false`。
- **返回：** 新 `DeviceSearchResult`。
- **副作用：** 无。
- **算法：** 平凡字段赋值。
- **用法：** 由 [`_searchGSMArena`](#_searchgsmarena) 和 [`_searchNotebookcheck`](#_searchnotebookcheck) 为每个快速结果构造；被用户挑一个时调用 [`fetchDetail`](#fetchdetail) 的设备搜索对话框 UI 消费。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释（见声明表上方行数说明）。

### `DeviceSearchResult withDetail({String? imageUrl, ..., DateTime? releaseDate})` <a id="withdetail"></a>
- **种类：** `DeviceSearchResult` 的方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 49 行）。
- **用途：** 创建带详情页字段填充、标记 `detailFetched: true` 使 UI 知道完整详情已加载的副本。
- **输入：** 所有详情字段可选；未提供时各经 `?? this.xxx` 回退既有值。
- **返回：** 新 `DeviceSearchResult`——`source`/`sourceUrl`/`name`/`brand`/`model`/`thumbnailUrl` 总是从 `this` 原样带过（不可经此方法替换）；结果上 `detailFetched` 无条件 `true`。
- **副作用：** 无。
- **算法：** 构造新 `DeviceSearchResult`，逐字复制身份/快速搜索字段并对每个详情字段应用 `field ?? this.field`。
- **用法：**
  ```dart
  return result.withDetail(
    imageUrl: deviceImageUrl,
    chipset: chipset,
    gpuName: gpu,
    ram: ram,
    storage: storage,
    screenSize: screenSize,
    screenResolutionW: resW,
    screenResolutionH: resH,
    battery: battery,
    os: os,
    releaseDate: releaseDate,
  );
  ```
  （来自 [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail)；[`_fetchNotebookcheckDetail`](#_fetchnotebookcheckdetail) 也调用它，重新传已解析内联规格使它们不丢失）
- **备注：** 此声明源码无 `/// Purpose:` 文档注释。与典型 `copyWith` 不同，身份字段（`source`、`name`、`brand`、`model`、`thumbnailUrl`）这里根本不是参数——按设计只能经此方法设置详情字段，因为详情获取绝不应改变结果所指的设备。

### `static Future<List<DeviceSearchResult>> search(String query)` <a id="search"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 95 行）。
- **用途：** 跨 GSMArena 和 Notebookcheck 并发按名搜索设备，返回快速结果（名、品牌/型号、缩略图——尚无完整规格详情）。
- **输入：** `query`。
- **返回：** `Future<List<DeviceSearchResult>>` — 两个源结果的连接；商店风格构建立即 `[]`。
- **副作用：** 非商店风格时两个并发 HTTP 请求（每源一个）。
- **算法：** 1. `AppFlavor.isStore` 时立即返回 `[]`——完全无网络调用。2. 否则经 `Future.wait` 并发运行 `_searchGSMArena`/`_searchNotebookcheck`，各包在 `.catchError((_) => <DeviceSearchResult>[])` 使一个源失败不使另一个失败。3. 展平（`expand`）两个结果列表为一个。
- **用法：** 用户提交查询时从设备搜索对话框调用（见 [在线搜索与预设 — 设备规格搜索](../../../../features/online-search-and-presets.md#device-spec-search---device_search_servicedart)）。
- **备注：** 商店风格检查在*任何*网络调用尝试*前*发生——商店构建甚至不构造请求，不只丢弃响应。

### `static Future<DeviceSearchResult> fetchDetail(DeviceSearchResult result)` <a id="fetchdetail"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 110 行）。
- **用途：** 抓取其详情页为先前找到的搜索结果获取完整规格详情，基于 `result.source` 分发到正确抓取器。
- **输入：** `result` — 典型为 [`search`](#search) 返回的一个。
- **返回：** `Future<DeviceSearchResult>` — 商店风格构建、`sourceUrl` 缺失或 `source` 无法识别时为未修改 `result`；否则详情富化结果。
- **副作用：** 对结果详情页一次 HTTP 请求，可识别非商店 case。
- **算法：** 1. `AppFlavor.isStore` 或 `result.sourceUrl == null` 时原样返回 `result`。2. `switch (result.source)`：`'GSMArena'` → `_fetchGSMArenaDetail`；`'Notebookcheck'` → `_fetchNotebookcheckDetail`；任何其他 → 原样返回 `result`。
- **用法：** 用户挑快速结果后、预填设备编辑表单前由设备搜索对话框调用。
- **备注：** 无法识别 `source` 字符串降级为空操作（而非抛）意味着未来在 `search()` 添加无匹配 `fetchDetail` case 的第三源会静默永不获取详情，而非崩溃。

### `static Future<List<DeviceSearchResult>> _searchGSMArena(String query)` <a id="_searchgsmarena"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 132 行）。
- **用途：** 查询 GSMArena 快速搜索端点并把 `<div class="makers">` 结果列表解析为至多 10 个 `DeviceSearchResult`。
- **输入：** `query`。
- **返回：** `Future<List<DeviceSearchResult>>` — 非 200 响应或无 `makers` div 找到时 `[]`。
- **副作用：** 一次到 `gsmarena.com/results.php3` 的 HTTP GET，带伪造桌面 `User-Agent` 和 15s 超时。
- **算法：** 1. GET 快速搜索 URL。2. 正则提取 `<div class="makers">...</div>` 块。3. 迭代其中 `<li>` 条目（上限 10）。4. 每条目正则提取 `href`、`<img src>` 和 `<span>` 名（品牌/型号间可含 `<br>`——去标签并折叠空白）。5. 经 [`_splitBrandModel`](#_splitbrandmodel) 把清洗名拆分为品牌/型号并构建 `source: 'GSMArena'` 的 `DeviceSearchResult`。
- **用法：** 被 [`search`](#search) 经 `Future.wait` 调用。
- **备注：** 解析是基于正则的 HTML 抓取，非真实 HTML 解析器——它依赖 GSMArena 当前标记结构（`class="makers"`、`<li>`/`<span>`/`<img>` 形态），该标记变化时会静默开始返回 `[]` 而非抛错。

### `static Future<DeviceSearchResult> _fetchGSMArenaDetail(DeviceSearchResult result)` <a id="_fetchgsmarenadetail"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 206 行）。
- **用途：** 获取 GSMArena 设备详情页并提取其主照片加芯片组、GPU、内存、屏幕、电池、操作系统和发布日期规格。
- **输入：** `result` — `result.sourceUrl!` 必须已设。
- **返回：** `Future<DeviceSearchResult>` — 非 200 响应时 `result` 不变，否则带每个解析字段的 [`withDetail`](#withdetail) 结果。
- **副作用：** 一次到详情 URL 的 HTTP GET，15s 超时。
- **算法：** 1. GET 页面。2. 找 [`_isDeviceImage`](#_isdeviceimage) 接受的第一个 `specs-photo-main` 图像 URL（跳过广告/联盟图像）。3. 经 [`_spec`](#_spec) 提取 `chipset`/`gpu`/`internalmemory`/`displaysize`/`displayresolution`/`batdescription1`/`os`。4. 经 [`_parseMemory`](#_parsememory) 解析内存、[`_parseScreenSize`](#_parsescreensize) 屏幕尺寸、[`_parseResolution`](#_parseresolution) 分辨率、[`_parseBattery`](#_parsebattery) 电池。5. 经 [`_parseReleaseDate`](#_parsereleasedate) 从 `released-hl`（缺席回退 `status`）解析发布日期。6. 用收集的一切调用 `result.withDetail(...)`。
- **用法：** 被 [`fetchDetail`](#fetchdetail) 为 `result.source == 'GSMArena'` 调用。
- **备注：** 主图像搜索迭代*所有* `specs-photo-main` 图像匹配并挑 [`_isDeviceImage`](#_isdeviceimage) 接受的第一个，而非盲目取第一个匹配——这正是过滤掉有时出现在该标记区域真实设备照片前的广告/跟踪图像的东西。

### `static String? _spec(String html, String key)` <a id="_spec"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 271 行）。
- **用途：** 从 GSMArena 详情页 HTML 提取一个 `data-spec="key"` 值。
- **输入：** `html`、`key` — 规格属性名（如 `'chipset'`）。
- **返回：** `String?` — 未找到或清洗值为空时 `null`。
- **副作用：** 无。
- **算法：** 正则匹配 `data-spec="$key"[^>]*>\s*(.+?)\s*</(?:td|span|div|li)>`（非贪婪、点全部），然后对捕获组剥离内部标签并折叠空白。
- **用法：** 被 [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail) 重复调用，每个规格键一次。
- **备注：** 匹配先闭合值的 `td`/`span`/`div`/`li` 任一——GSMArena 对不同规格行用不同包装元素。

### `static (String?, String?) _splitBrandModel(String name)` <a id="_splitbrandmodel"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 293 行）。
- **用途：** 在第一个空格把设备完整显示名拆分为品牌和型号。
- **输入：** `name`。
- **返回：** `(String?, String?)` 记录 — 完全无空格时 `(name, null)`。
- **副作用：** 无。
- **算法：** 找第一个空格；在那里拆分。
- **用法：** 被 [`_searchGSMArena`](#_searchgsmarena) 和 [`_searchNotebookcheck`](#_searchnotebookcheck) 两者调用。
- **备注：** 朴素首空格拆分——多词品牌（此域罕见）会被错误拆分，但这匹配 GSMArena/Notebookcheck 名称惯用格式（`"Brand Model..."`）。

### `static (String? ram, String? storage) _parseMemory(String? raw)` <a id="_parsememory"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 304 行）。
- **用途：** 把 GSMArena 组合 `internalmemory` 规格文本（如 `"128GB 8GB RAM, ..."`）解析为单独存储和 RAM 值。
- **输入：** `raw` — 可空自由文本；只考虑第一个逗号分隔段。
- **返回：** `(String? ram, String? storage)` 记录 — 无模式匹配时都 `null`。
- **副作用：** 无。
- **算法：** 对第一逗号段依次试三个正则模式：1. `"<N>GB <M>GB RAM"` → `(ram: M GB, storage: N GB)`。2. `"<N>TB <M>GB RAM"` → `(ram: M GB, storage: N TB)`。3. 仅 RAM `"<N>(GB|MB) RAM"`（对照完整 `raw` 而非只第一段匹配）→ `(ram: N <unit>, storage: null)`。都不匹配返回 `(null, null)`。
- **用法：** 被 [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail) 调用。
- **备注：** 前两模式存储在前排序（`storage GB/TB` 在 `RAM GB` 前）匹配 GSMArena 在该字段先列存储容量后 RAM 的自身约定。

### `static String? _parseScreenSize(String? raw)` <a id="_parsescreensize"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 343 行）。
- **用途：** 从 GSMArena 的 `displaysize` 规格文本提取英寸屏幕尺寸。
- **输入：** `raw` — 可空。
- **返回：** `String?` — 如 `'6.7"'`，无 `"<number> inches"` 模式找到时 `null`。
- **副作用：** 无。
- **算法：** 正则 `([\d.]+)\s*inches`；把捕获数字包进尾随 `"`。
- **用法：** 被 [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail) 调用。
- **备注：** 产生 [`device.md`](../models/device.md#_parsescreendiagonal) 期望为 `Device.ppi` 解析回的相同 `N"` 形态——该往返两侧住在不同文件但依赖相同尾引号约定。

### `static (int?, int?) _parseResolution(String? raw)` <a id="_parseresolution"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 354 行）。
- **用途：** 从 GSMArena 的 `displayresolution` 规格文本提取 `width x height` 分辨率对。
- **输入：** `raw` — 可空。
- **返回：** `(int?, int?)` 记录 — 无 `"<N> x <M>"` 模式匹配时 `(null, null)`。
- **副作用：** 无。
- **算法：** 正则 `(\d+)\s*x\s*(\d+)`；把两个捕获组解析为 `int`。
- **用法：** 被 [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail) 调用。
- **备注：** 无。

### `static String? _parseBattery(String? raw)` <a id="_parsebattery"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 366 行）。
- **用途：** 从 GSMArena 的 `batdescription1` 规格文本提取毫安时电池容量。
- **输入：** `raw` — 可空。
- **返回：** `String?` — 如 `'5000 mAh'`，无 `"<N> mAh"` 模式匹配时 `null`。
- **副作用：** 无。
- **算法：** 正则 `(\d+)\s*mAh`。
- **用法：** 被 [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail) 调用。
- **备注：** 无。

### `static DateTime? _parseReleaseDate(String? raw)` <a id="_parsereleasedate"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 377 行）。
- **用途：** 把 GSMArena 自由文本发布日期规格（如 `"Released 2024, September 20"` 或 `"2024, September"`）解析为 `DateTime`。
- **输入：** `raw` — 可空。
- **返回：** `DateTime?` — 两模式都不匹配或月份名无法识别时 `null`。
- **副作用：** 无。
- **算法：** 1. 试完整模式 `(\d{4}),?\s+(\w+)\s+(\d{1,2})`（年、月名、日）；匹配且经 [`_parseMonth`](#_parsemonth) 解析月份时返回 `DateTime(year, month, day)`。2. 否则试仅年月模式 `(\d{4}),?\s+(\w+)`；匹配且解析月份时返回 `DateTime(year, month)`（日默认 1 号）。3. 否则 `null`。
- **用法：** 被 [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail) 调用。
- **备注：** 可解析年+月但不可解析日模式仍落到对*原始* `raw` 字符串的仅年月尝试，非部分匹配剩余——两个正则都对照相同输入独立试。

### `static int? _parseMonth(String m)` <a id="_parsemonth"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 401 行）。
- **用途：** 把完整英文月份名映射到其基于 1 的日历数字。
- **输入：** `m` — 不区分大小写。
- **返回：** `int?` — 不是 12 个识别英文月份名之一时 `null`。
- **副作用：** 无。
- **算法：** 以小写月份名键控、按 `m.toLowerCase()` 索引的固定 `const` 查找映射。
- **用法：** 被 [`_parseReleaseDate`](#_parsereleasedate) 调用两次。
- **备注：** 只识别英文月份名——GSMArena 站点是英语，因此实践中这不是本地化缺口，但将来添加非英语源时会是。

### `static bool _isDeviceImage(String url)` <a id="_isdeviceimage"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 425 行）。
- **用途：** 决定 GSMArena 详情页图像 URL 是否为真实设备照片，拒绝广告/联盟/跟踪图像。
- **输入：** `url`。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 1. 小写 URL 含固定黑名单任一则拒绝（`false`）：`amazon`、`amzn`、`affiliate`、`banner`、`advert`、`tracking`、`click.`、`/ad/`、`doubleclick`、`googlesyndication`。2. 含 `gsmarena.com`/`fdn.gsmarena.com`（GSMArena 自己 CDN）则接受（`true`）。3. 以 `.jpg`/`.jpeg`/`.png`/`.webp` 结尾（任何主机）则接受（`true`）。4. 否则拒绝（`false`）。
- **用法：** [`_fetchGSMArenaDetail`](#_fetchgsmarenadetail) 扫描候选 `specs-photo-main` 图像 URL 时调用。
- **备注：** 黑名单检查在 GSMArena-CDN 白名单检查*前*运行，因此碰巧两者都匹配的 URL（如含 `gsmarena.com` 也含 `tracking`）仍被拒绝——黑名单优先。

### `static String _stripHtml(String html)` <a id="_striphtml"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 459 行）。
- **用途：** 从 HTML 片段剥离 HTML 标签和常见实体，把空白折叠为单空格。
- **输入：** `html`。
- **返回：** `String` — 修剪纯文本。
- **副作用：** 无。
- **算法：** 链式 `replaceAll`：剥离 `<...>` 标签、剥离命名实体（`&[a-zA-Z]+;`）、剥离数字实体（`&#\d+;`）、把空白运行折叠为一个空格、修剪。
- **用法：** [`_searchNotebookcheck`](#_searchnotebookcheck) 清洗结果行 `<br/>` 后内联规格文本时调用。
- **备注：** 命名/数字 HTML 实体完全剥离（非解码为其字符）——如 `&amp;` 变成空，非 `&`。对此函数实践中用于的数字规格文本可接受，但会损坏含真实标点实体的文本。

### `static Future<List<DeviceSearchResult>> _searchNotebookcheck(String query)` <a id="_searchnotebookcheck"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 477 行）。
- **用途：** 查询 Notebookcheck 的 Laptop Search 工具（也覆盖平板、手机和智能手表）并把其结果表解析为至多 8 个带内联规格的 `DeviceSearchResult`。
- **输入：** `query`。
- **返回：** `Future<List<DeviceSearchResult>>` — 非 200 响应时 `[]`。
- **副作用：** 一次到 `notebookcheck.net/Laptop_Search.8223.0.html` 的 HTTP GET，15s 超时。
- **算法：** 1. GET 搜索 URL。2. 正则迭代类含 `odd`/`even` 的 `<tr>` 行（上限 8 结果）。3. 跳过分隔行（同时含 `nb_model` 和 `colspan`）。4. 经正则提取结果链接/名；名称为空、太短（`< 3` 字符）、太长（`> 80` 字符）或匹配评论文章关键词正则（`review|comparison|versus|benchmark|test[:\s]`，不区分大小写）时跳过——过滤掉也匹配行模式的评论文章。5. 行含 `<br/>` 时经 [`_stripHtml`](#_striphtml) 剥离其后文本的 HTML 并按逗号拆分：部分 0 → `gpuName`、部分 1 → `chipset`；扫描剩余部分找 `"<size>\" <W>x<H>"` 模式填充 `screenSize`/`screenResolutionW`/`screenResolutionH`，在第一个匹配停止。6. 经 [`_splitBrandModel`](#_splitbrandmodel) 拆分名称并构建 `source: 'Notebookcheck'` 的结果。
- **用法：** 被 [`search`](#search) 经 `Future.wait` 调用。
- **备注：** 评论文章过滤器（名称长度/关键词检查）存在因为 Notebookcheck 搜索结果表可含评论文章行与真实设备条目并排，那些否则仅按行结构无法与设备区分。

### `static Future<DeviceSearchResult> _fetchNotebookcheckDetail(DeviceSearchResult result)` <a id="_fetchnotebookcheckdetail"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 587 行）。
- **用途：** 获取 Notebookcheck 详情页并从嵌入 JSON-LD `Product` 结构化数据提取其设备图像，保留搜索期间已解析的内联规格。
- **输入：** `result` — `result.sourceUrl!` 必须已设。
- **返回：** `Future<DeviceSearchResult>` — 非 200 响应时 `result` 不变，否则只新设 `imageUrl`（规格原样重传）的 [`withDetail`](#withdetail) 结果。
- **副作用：** 一次到详情 URL 的 HTTP GET，15s 超时。
- **算法：** 1. GET 页面。2. 正则找每个 `<script type="application/ld+json">` 块。3. 对每个，在 `try`/`catch` 内尝试 `jsonDecode` 它（静默跳过非 JSON 或解析失败块）；解码且 `data['@type'] == 'Product'` 时提取 `image`——直接字符串或 `{"url": ...}` 对象——并停止扫描更多块。4. 调用 `result.withDetail(imageUrl: imageUrl, chipset: result.chipset, gpuName: result.gpuName, screenSize: result.screenSize, screenResolutionW: result.screenResolutionW, screenResolutionH: result.screenResolutionH)`——显式重新传已知内联规格，使它们甚至不需要 `withDetail` 的 `?? this.xxx` 回退。
- **用法：** 被 [`fetchDetail`](#fetchdetail) 为 `result.source == 'Notebookcheck'` 调用。
- **备注：** 与 GSMArena 正则抓取详情页不同，这用页面自己的结构化 JSON-LD 数据获取图像——对该单字段对标记变化更稳健，但 Notebookcheck 详情页否则除搜索已解析的外不贡献额外规格字段（芯片组/GPU/屏幕只来自搜索结果行）。
