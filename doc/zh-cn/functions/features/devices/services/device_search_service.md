# lib/features/devices/services/device_search_service.dart

`DeviceSearchService` 从在线数据库获取设备规格，并逐数据源报告该次获取是否真的成功。它只负责 HTTP 管道与
数据源分发；所有页面解析都放在 [`device_search_parsers.md`](device_search_parsers.md) 中，以便脱离网络测试。
结果经由 [`../views/device_search_dialog.md`](../views/device_search_dialog.md) 呈现给用户，由用户勾选要
应用哪些字段。

本页据以核对源码的概念性介绍见
[在线搜索与预设](../../../../features/online-search-and-presets.md#device-spec-search--device_search_servicedart)。

## Sources

| Source | Covers | Search endpoint | Notes |
|---|---|---|---|
| Notebookcheck | 笔记本、平板、手机、智能手表 | `GET Laptop-Search.8223.0.html?model=` | 设备页带有完整规格表。 |
| PhoneDB | 手机，细到 SKU 级别 | `POST index.php?m=device&s=list`，参数 `search_exp` | 全文匹配较宽松，需要相关性闸门。 |

**GSMArena 已被移除。** 它对每个请求都返回以 HTTP 200 承载的 Cloudflare Turnstile 验证页，纯 HTTP 客户端
无法通过。由于旧代码只检查状态码，随后其行匹配模式失配，于是返回空列表——这与「该设备不存在」无法区分。
正是这种静默失败，才有了下面的结果状态上报机制。

PhoneDB 有两个关键且不显然的端点细节：它的 `filter=` 和 `model=` 查询参数会被**忽略**，无论查询内容如何都
返回站点的「最新设备」列表，因此唯一可用的文本搜索是 `search_exp` 的 POST。而当它没有收录某个型号时，它会
退化为宽松匹配而不是返回空——搜索 `Galaxy Z Fold8` 会得到约 120 条不相关的 Galaxy 手机——这正是每条结果都
要经过 `isRelevant` 的原因。

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `DeviceSearchStatus` | enum | A | 说明数据源为何返回了这样的结果。 |
| `DeviceSourceOutcome` | class | B | 查询单个数据源的结果状态。 |
| [`DeviceSourceOutcome`](#devicesourceoutcome-new) | 构造函数 | A | 记录单个数据源的响应情况。 |
| [`DeviceSourceOutcome.failed`](#outcome-failed) | getter | A | 把「失败」与「什么也没找到」区分开。 |
| `DeviceSearchResponse` | class | B | 合并后的结果加逐数据源状态。 |
| [`DeviceSearchResponse`](#devicesearchresponse-new) | 构造函数 | A | 保存结果与状态。 |
| [`DeviceSearchResponse.failures`](#failures) | getter | A | 列出失败的数据源。 |
| [`DeviceSearchResponse.allSourcesFailed`](#allsourcesfailed) | getter | A | 报告没有任何数据源成功。 |
| `DeviceSearchResult` | class | B | 来自在线数据库的一条结果。 |
| `DeviceSearchResult` | 构造函数 | B | 创建结果实例。 |
| [`withDetail`](#withdetail) | 方法 | A | 把抓取到的详情字段合并到结果上。 |
| `_SourceResponse` | 私有 class | B | 合并前单个数据源的产出。 |
| `_SourceResponse` / `.failed` | 私有构造函数 | B | 构建单个数据源的产出。 |
| `DeviceSearchService` | class | B | 服务本体，仅含静态成员。 |
| `userAgent` / `_timeout` / `_maxResultsPerSource` | 静态 const | B | 共享的请求配置。 |
| [`headers`](#headers) | 静态方法 | A | 构建每个抓取请求发送的请求头。 |
| [`search`](#search) | 静态方法 | A | 搜索所有启用的数据源。 |
| [`fetchDetail`](#fetchdetail) | 静态方法 | A | 为某条结果获取完整详情页。 |
| [`_classifyError`](#_classifyerror) | 私有静态方法 | A | 归类传输层失败。 |
| [`_searchNotebookcheck`](#_searchnotebookcheck) | 私有静态方法 | A | 搜索 Notebookcheck。 |
| [`_fetchNotebookcheckDetail`](#_fetchnotebookcheckdetail) | 私有静态方法 | A | 读取 Notebookcheck 设备页。 |
| [`_jsonLdImage`](#_jsonldimage) | 私有静态方法 | A | 从 JSON-LD 中提取产品图片 URL。 |
| [`_searchPhonedb`](#_searchphonedb) | 私有静态方法 | A | 搜索 PhoneDB。 |
| [`_fetchPhonedbDetail`](#_fetchphonedbdetail) | 私有静态方法 | A | 读取 PhoneDB 参数表页。 |

行数（24）多于 `grep -c 'Purpose:' device_search_service.dart`（15）：枚举、四个类声明、三个普通构造函数
以及三个静态 const 带的是普通 `///` 描述或没有注释，而非完整的 `Purpose:` 块。按照「每个声明都要出现在表中」
的分级规则，它们仍在此列出。

## Documentation

### `enum DeviceSearchStatus`
- **Kind:** 顶层枚举。
- **Source:** `lib/features/devices/services/device_search_service.dart`（第 16 行）。
- **Purpose:** 说明数据源为何返回了这样的结果。
- **Values:**
  - `ok` —— 数据源作出了响应且页面解析成功。当设备确实不在该数据库中时，`resultCount` 仍可能为 0。
  - `blocked` —— 返回的是机器人验证墙或验证页，而不是内容。
  - `unreachable` —— DNS、套接字、超时，或非 200 且非 403 的状态码。
  - `markupChanged` —— 数据源作出了响应，但解析器所依赖的结构一个都不存在，说明抓取逻辑需要更新。
- **Notes:** 关键在于这四者不再可以互相混淆。`unreachable` 时重试有意义，`blocked` 和 `markupChanged` 时
  重试永远没用，而 `ok` 且无结果时重试也没有意义。注意 `ok` 且 `resultCount == 0` 有意**不**算失败——零匹配
  的搜索页通过 `isNotebookcheckSearchPage` / `isPhonedbResultsPage` 识别。

### `const DeviceSourceOutcome({...})` <a id="devicesourceoutcome-new"></a>
- **Kind:** `DeviceSourceOutcome` 的构造函数。
- **Source:** 第 43 行。
- **Purpose:** 记录单个数据源对一次查询的响应情况。
- **Inputs:** `source` 名称、`status` 和 `resultCount`。
- **Returns:** 新的 `DeviceSourceOutcome`。
- **Side effects:** 无。
- **Notes:** 无。

### `bool get failed` <a id="outcome-failed"></a>
- **Kind:** `DeviceSourceOutcome` 的 getter。
- **Source:** 第 54 行。
- **Purpose:** 报告该数据源是失败了，还是仅仅什么都没找到。
- **Returns:** 除 `ok` 以外的所有状态都返回 `true`。
- **Side effects:** 无。
- **Notes:** `ok` 且 `resultCount == 0` 不算失败。

### `const DeviceSearchResponse({...})` <a id="devicesearchresponse-new"></a>
- **Kind:** `DeviceSearchResponse` 的构造函数。
- **Source:** 第 67 行。
- **Purpose:** 保存合并后的结果与逐数据源状态。
- **Inputs:** `results`、`outcomes`。
- **Side effects:** 无。
- **Notes:** 无。

### `List<DeviceSourceOutcome> get failures` <a id="failures"></a>
- **Kind:** `DeviceSearchResponse` 的 getter。
- **Source:** 第 74 行。
- **Purpose:** 列出失败的数据源。
- **Returns:** 状态不为 `ok` 的那些结果状态。
- **Side effects:** 无。
- **Notes:** 对话框用它来解释空结果或部分结果。

### `bool get allSourcesFailed` <a id="allsourcesfailed"></a>
- **Kind:** `DeviceSearchResponse` 的 getter。
- **Source:** 第 83 行。
- **Purpose:** 报告是否所有被查询的数据源都失败了。
- **Returns:** 至少查询过一个数据源且无一成功时返回 `true`。
- **Side effects:** 无。
- **Notes:** 正是它让对话框能说「所有数据源都无法访问」而不是「未找到结果」——用户需要靠这个区分来判断重试
  是否有意义。

### `DeviceSearchResult withDetail({...})` <a id="withdetail"></a>
- **Kind:** `DeviceSearchResult` 的方法。
- **Source:** 第 135 行。
- **Purpose:** 把新抓取到的详情字段合并到本结果上。
- **Inputs:** 任意详情字段；省略的字段保持原值。
- **Returns:** `detailFetched` 置为 `true` 的新 `DeviceSearchResult`。
- **Side effects:** 无。
- **Notes:** 每个字段都做了空值合并，因此详情页缺失某字段时，绝不会抹掉已从搜索结果行解析到的值。
  Notebookcheck 的结果行内联携带 GPU、CPU 和屏幕信息；详情页有时完全没有 `Released`（Apple 的页面就是如此），
  这不应清空任何内容。

### `static Map<String, String> headers({String accept = 'text/html'})` <a id="headers"></a>
- **Kind:** `DeviceSearchService` 的静态方法。
- **Source:** 第 204 行。
- **Purpose:** 构建每个抓取请求发送的请求头。
- **Inputs:** `accept` —— `Accept` 头的取值。
- **Returns:** 含 user agent、accept 与 accept-language 的请求头映射。
- **Side effects:** 无。
- **Notes:** 集中管理，使 user agent 不会在页面抓取与后续请求该页面所发现资源之间发生漂移。

### `static Future<DeviceSearchResponse> search(String query)` <a id="search"></a>
- **Kind:** `DeviceSearchService` 的静态方法。
- **Source:** 第 217 行。
- **Purpose:** 在所有启用的数据源中搜索匹配查询的设备。
- **Inputs:** `query` —— 用户输入的搜索文本。
- **Returns:** `Future<DeviceSearchResponse>`，含合并结果与每个数据源各一条状态。
- **Side effects:** 向 Notebookcheck 和 PhoneDB 发起 HTTP 请求。
- **Algorithm:** 1. 当 `AppFlavor.isStore` 或去空白后的查询为空时立即返回空响应。2. 打开一个 `http.Client`。
  3. 用 `Future.wait` 并发查询两个数据源。4. 拼接结果，并为每个数据源配一条 `DeviceSourceOutcome`。
  5. 在 `finally` 中关闭客户端。
- **Usage:**
  ```dart
  final response = await DeviceSearchService.search('Galaxy Z Fold8');
  if (response.allSourcesFailed) { /* show why, per source */ }
  ```
- **Notes:** 整个扇出共用一个客户端，而不是像以前那样每次调用都用裸的静态 `http.get`。某个数据源失败绝不会
  妨碍另一个返回结果，因为每个数据源函数都自行捕获传输错误并以状态形式上报，而不是抛出异常。

### `static Future<DeviceSearchResult> fetchDetail(DeviceSearchResult result)` <a id="fetchdetail"></a>
- **Kind:** `DeviceSearchService` 的静态方法。
- **Source:** 第 259 行。
- **Purpose:** 为用户选中的结果获取完整详情页。
- **Inputs:** `result` —— 先前由 [`search`](#search) 返回的一条结果。
- **Returns:** `Future<DeviceSearchResult>`，获取成功时带有补充信息。
- **Side effects:** 向该结果的数据源发起一次 HTTP 请求。
- **Notes:** 对商店版构建、没有 `sourceUrl` 的结果、未知数据源，以及任何抛出的错误，都原样返回输入。
  **新增数据源却不在此处添加 `case`，会静默跳过该源的详情获取**——这处分发是唯一必须与 `search` 保持同步的地方。

### `static DeviceSearchStatus _classifyError(Object error)` <a id="_classifyerror"></a>
- **Kind:** 私有静态方法。
- **Source:** 第 288 行。
- **Purpose:** 归类传输层失败。
- **Inputs:** `error` —— 抛出的对象。
- **Returns:** 对应的 `DeviceSearchStatus`。
- **Side effects:** 无。
- **Notes:** 目前所有已识别的网络故障与所有未识别错误一律映射为 `unreachable`。分支保持显式书写，是为了将来
  若要作出更细的区分（例如对握手失败区别对待）有一处明确的落点。

### `static Future<_SourceResponse> _searchNotebookcheck(...)` <a id="_searchnotebookcheck"></a>
- **Kind:** 私有静态方法。
- **Source:** 第 306 行。
- **Purpose:** 搜索 Notebookcheck 的设备数据库。
- **Inputs:** `client`、`query`。
- **Returns:** `Future<_SourceResponse>`，含结果与状态。
- **Side effects:** 发起一次 HTTP GET。
- **Algorithm:** 1. GET `Laptop-Search.8223.0.html?model=<query>`。2. 把 403 映射为 `blocked`，其他非 200
  映射为 `unreachable`。3. 对响应体运行 `looksBlocked`。4. 匹配结果行（`<tr class="odd|even">`）；若一行都
  没有，则在 `isNotebookcheckSearchPage` 判定页面正常渲染时返回 `ok`，否则返回 `markupChanged`。5. 对每一行
  取出链接与标题，把标题交给 `cleanDeviceName`，若 `isReviewArticle` 或不满足 `isRelevant` 则丢弃，按小写名称
  去重，并解析 `<br/>` 之后的内联规格。6. 结果上限为 8 条。
- **Notes:** 使用带连字符的 `Laptop-Search` 路径是有意为之；带下划线的 `Laptop_Search` 会 301 重定向。
  先 `cleanDeviceName` 再 `isReviewArticle` 的顺序，正是那个丢弃全部当代设备的缺陷的修复：Notebookcheck 把
  标准设备页命名为 `<name> - Reviews and Specs`，因此按原始标题过滤会丢掉 `Samsung Galaxy Z Fold8`，却保留了
  标题较短的旧款 `Samsung Galaxy Z Fold7`。

### `static Future<DeviceSearchResult> _fetchNotebookcheckDetail(...)` <a id="_fetchnotebookcheckdetail"></a>
- **Kind:** 私有静态方法。
- **Source:** 第 421 行。
- **Purpose:** 读取 Notebookcheck 设备页，获取完整规格与图片。
- **Inputs:** `client`、`result`。
- **Returns:** `Future<DeviceSearchResult>`。
- **Side effects:** 发起一次 HTTP GET。
- **Algorithm:** 用 `parseNotebookcheckSpecs` 解析页面，再映射其标签：

  | Block label | Field | Parser |
  |---|---|---|
  | `Processor` | `chipset` | `parseChipName` |
  | `Graphics adapter` | `gpuName` | `parseChipName` |
  | `Memory` | `ram` | `parseCapacity` |
  | `Storage` | `storage` | `parseCapacity` |
  | `Display` | `screenSize`、`screenResolutionW/H` | `parseScreenSize`、`parseResolution` |
  | `Battery` | `battery` | `parseBattery` |
  | `Operating System` | `os` | 原样 |
  | `Released` | `releaseDate` | `parseUsDate` |

- **Notes:** 读取规格表正是这次获取的全部意义。旧实现只提取 JSON-LD 图片而丢弃了这张表，因此 RAM、存储、
  电池、操作系统和发布日期从该数据源根本没有到达用户。并非每个页面都有全部区块——Apple 的页面就没有
  `Released`——缺失的区块只会让对应字段保持为空。

### `static String? _jsonLdImage(String html)` <a id="_jsonldimage"></a>
- **Kind:** 私有静态方法。
- **Source:** 第 459 行。
- **Purpose:** 从页面的 JSON-LD 区块中提取产品图片 URL。
- **Inputs:** `html` —— 页面完整标记。
- **Returns:** 图片 URL，或 `null`。
- **Side effects:** 无。
- **Algorithm:** 遍历 `<script type="application/ld+json">` 区块，在 `try` 中逐个解码，取第一个 `@type` 为
  `Product` 的区块，`image` 既接受带 `url` 的对象也接受裸字符串，最后用 `isLikelyDeviceImage` 过滤。
- **Notes:** 一个页面带有多个 JSON-LD 区块，其中包括 `Article` 区块；只有 `Product` 才含设备照片。格式错误的
  区块会被跳过，而不会中断整个扫描。

### `static Future<_SourceResponse> _searchPhonedb(...)` <a id="_searchphonedb"></a>
- **Kind:** 私有静态方法。
- **Source:** 第 494 行。
- **Purpose:** 搜索 PhoneDB 的设备数据库。
- **Inputs:** `client`、`query`。
- **Returns:** `Future<_SourceResponse>`，含结果与状态。
- **Side effects:** 发起一次 HTTP POST。
- **Algorithm:** 1. 向 `index.php?m=device&s=list` POST `search_exp=<query>`。2. 把 403 映射为 `blocked`，
  其他非 200 映射为 `unreachable`，并运行 `looksBlocked`。3. 按 `<div class="content_block">` 切分；若没有
  任何区块，则在 `isPhonedbResultsPage` 判定页面正常渲染时返回 `ok`，否则返回 `markupChanged`。4. 对每个
  区块读取锚点的 `title`（其中是**完整**名称；可见链接文本被 `..` 截断），做清洗，应用评测过滤与相关性闸门，
  按清洗后的名称去重，并取出缩略图。5. 上限 8 条。
- **Notes:** 按清洗后的名称去重，正是把同一款手机的众多地区与容量 SKU 合并的手段——PhoneDB 会把
  `Galaxy Z Fold7` 的 256GB、512GB 和 1TB 版本在多个地区分别列出——最终收敛为一行。这里的相关性闸门不是可选项：
  没有它，一个未收录的型号会用不相关的手机填满全部 8 个位置。

### `static Future<DeviceSearchResult> _fetchPhonedbDetail(...)` <a id="_fetchphonedbdetail"></a>
- **Kind:** 私有静态方法。
- **Source:** 第 585 行。
- **Purpose:** 读取 PhoneDB 参数表页，获取完整规格。
- **Inputs:** `client`、`result`。
- **Returns:** `Future<DeviceSearchResult>`。
- **Side effects:** 发起一次 HTTP GET。
- **Algorithm:** 用 `parsePhonedbSpecs` 解析，再映射：

  | Datasheet label | Field | Parser |
  |---|---|---|
  | `CPU` | `chipset` | `parseChipName` |
  | `Graphical Controller` | `gpuName` | `parseChipName` |
  | `RAM Capacity (converted)` | `ram` | `parseCapacity` |
  | `Non-volatile Memory Capacity (converted)` | `storage` | `parseCapacity` |
  | `Display Diagonal` | `screenSize` | `parseScreenSizeMm` |
  | `Resolution` | `screenResolutionW/H` | `parseResolution` |
  | `Nominal Battery Capacity` | `battery` | `parseBattery` |
  | `Operating System` | `os` | 原样 |
  | `Released` | `releaseDate` | `parseReleaseDate` |

- **Notes:** PhoneDB 以**毫米**给出对角线尺寸，容量则使用**二进制**单位，因此两者都走做单位换算的解析函数，
  而不是 Notebookcheck 所用的英寸/十进制版本。搜索结果的缩略图被复用为图片，因为参数表页没有更大的产品照片。

## Related

- [`device_search_parsers.md`](device_search_parsers.md) —— 全部页面解析，针对固定样本做单元测试。
- [`../views/device_search_dialog.md`](../views/device_search_dialog.md) —— 两阶段界面与字段勾选。
- [`chip_search_service.md`](chip_search_service.md) —— CPU/GPU 的同类功能。
- [`preset_service.md`](preset_service.md) —— 离线捆绑模板的对应物。
- [在线搜索与预设](../../../../features/online-search-and-presets.md)
