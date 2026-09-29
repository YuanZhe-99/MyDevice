# lib/features/devices/services/device_search_service.dart

`DeviceSearchService` 从在线数据库获取设备规格，并逐来源报告该次获取是否真的成功。它只负责 HTTP 管道、
来源注册表与来源分发；所有页面标记、wikitext 与技术规格页的解析都放在
[`device_search_parsers.md`](device_search_parsers.md) 中，以便脱离网络测试。结果经由
[`../views/device_search_dialog.md`](../views/device_search_dialog.md) 呈现给用户，由用户勾选要应用哪些字段。

本页据以核对源码的概念性介绍见
[在线搜索与预设](../../../../features/online-search-and-presets.md#device-spec-search--device_search_servicedart)。
`test/device_search_sources_test.dart` 针对保存的固定样本覆盖来源注册表、Apple 产品族匹配和两个公开映射函数；
`tool/check_sources.dart` 与 `tool/test_live.dart` 则访问真实来源。

## 来源

| 来源 | 覆盖范围 | 搜索端点 | 备注 |
|---|---|---|---|
| Apple | 仅 Apple 产品（iPhone、iPad、Mac、Apple Watch、AirPods） | `GET support.apple.com/en-us/docs/<family>` | 仅在 [`appleFamiliesFor`](#applefamiliesfor) 匹配时查询；详情来自该产品的技术规格页。 |
| Notebookcheck | 笔记本、平板、手机、智能手表 | `GET Laptop-Search.8223.0.html?model=` | 设备页带有完整规格表。 |
| PhoneDB | 手机，细到 SKU 级别 | `POST index.php?m=device&s=list`，参数 `search_exp` | 全文匹配较宽松，需要相关性闸门。 |
| Wikipedia | 任何有独立条目的产品（游戏机、掌机等） | MediaWiki API `action=query&list=search` | 后备来源：仅当其他所有来源都一无所获时才查询；详情读取自条目的信息框。 |

这四个来源都登记在同一个**来源注册表** [`_sources`](#_sources) 中。每一项给出来源名称，可以关闭，可以标记为
后备来源，说明自己适用于哪些查询，并提供搜索函数与详情函数。[`search`](#search) 和
[`fetchDetail`](#fetchdetail) 都经由它分发，因此新增一个来源只需一条注册表项。

**GSMArena 已被移除。** 它对每个请求都返回以 HTTP 200 承载的 Cloudflare Turnstile 验证页，纯 HTTP 客户端
无法通过。由于旧代码只检查状态码，随后其行匹配模式失配，于是返回空列表——这与「该设备不存在」无法区分。
正是这种静默失败，才有了下面的结果状态上报机制。

PhoneDB 有两个关键且不显然的端点细节：它的 `filter=` 和 `model=` 查询参数会被**忽略**，无论查询内容如何都
返回站点的「最新设备」列表，因此唯一可用的文本搜索是 `search_exp` 的 POST。而当它没有收录某个型号时，它会
退化为宽松匹配而不是返回空——搜索 `Galaxy Z Fold8` 会得到约 120 条不相关的 Galaxy 手机——这正是每条结果都
要经过 `isRelevant` 的原因。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`DeviceSearchStatus`](#devicesearchstatus) | enum | A | 说明来源为何返回了这样的结果。 |
| `DeviceSourceOutcome` | class | B | 查询单个来源的结果状态。 |
| [`DeviceSourceOutcome`](#devicesourceoutcome-new) | 构造函数 | A | 记录单个来源的响应情况。 |
| [`DeviceSourceOutcome.failed`](#outcome-failed) | getter | A | 把「失败」与「什么也没找到」区分开。 |
| `DeviceSearchResponse` | class | B | 合并后的结果加逐来源状态。 |
| [`DeviceSearchResponse`](#devicesearchresponse-new) | 构造函数 | A | 保存结果与状态。 |
| [`DeviceSearchResponse.failures`](#failures) | getter | A | 列出失败的来源。 |
| [`DeviceSearchResponse.allSourcesFailed`](#allsourcesfailed) | getter | A | 报告没有任何来源成功。 |
| `DeviceSearchResult` | class | B | 来自在线数据库的一条结果。 |
| `DeviceSearchResult` | 构造函数 | B | 按来源搜索步骤解析出的内容创建结果；`detailFetched` 初始为 false。 |
| [`withDetail`](#withdetail) | 方法 | A | 把抓取到的详情字段合并到结果上。 |
| `_Source` | 私有 class | B | 来源注册表所描述的单个来源。 |
| [`_Source`](#_source-new) | 私有构造函数 | A | 为来源注册表描述一个来源。 |
| `_anyQuery` | 私有函数 | B | 通用来源的 `appliesTo`；接受任何查询。 |
| `_SourceResponse` | 私有 class | B | 合并前单个来源的产出。 |
| `_SourceResponse` / `.failed` | 私有构造函数 | B | 构建单个来源的产出；`.failed` 只带状态、没有结果。 |
| `DeviceSearchService` | class | B | 服务本体，仅含静态成员。 |
| [`userAgent`](#useragent) | 静态 const | A | 每个请求都发送的如实客户端名称。 |
| `_timeout` / `_maxResultsPerSource` | 静态 const | B | 15 秒请求超时；每个来源最多 8 条结果。 |
| [`_sources`](#_sources) | 私有静态 final | A | 来源注册表，按结果顺序排列。 |
| [`sourceNames`](#sourcenames) | 静态 getter | A | 列出已启用的来源。 |
| [`headers`](#headers) | 静态方法 | A | 构建每个抓取请求发送的请求头。 |
| [`search`](#search) | 静态方法 | A | 搜索所有已启用且适用的来源。 |
| [`fetchDetail`](#fetchdetail) | 静态方法 | A | 为某条结果获取完整详情页。 |
| [`_classifyError`](#_classifyerror) | 私有静态方法 | A | 归类传输层失败。 |
| [`_searchNotebookcheck`](#_searchnotebookcheck) | 私有静态方法 | A | 搜索 Notebookcheck。 |
| [`_fetchNotebookcheckDetail`](#_fetchnotebookcheckdetail) | 私有静态方法 | A | 读取 Notebookcheck 设备页。 |
| [`_jsonLdImage`](#_jsonldimage) | 私有静态方法 | A | 从 JSON-LD 中提取产品图片 URL。 |
| [`_searchPhonedb`](#_searchphonedb) | 私有静态方法 | A | 搜索 PhoneDB。 |
| [`_fetchPhonedbDetail`](#_fetchphonedbdetail) | 私有静态方法 | A | 读取 PhoneDB 参数表页。 |
| `_appleFamilies` | 私有静态 const | B | 产品词到 Apple 支持文档产品族的映射（`macbook` → `mac` 等）。 |
| [`appleFamiliesFor`](#applefamiliesfor) | 静态方法 | A | 判断查询涉及哪些 Apple 文档产品族。 |
| [`_searchApple`](#_searchapple) | 私有静态方法 | A | 搜索 Apple 支持网站的文档索引。 |
| [`_fetchAppleDetail`](#_fetchappledetail) | 私有静态方法 | A | 读取 Apple 产品的技术规格页。 |
| [`withAppleSpecs`](#withapplespecs) | 静态方法 | A | 把解析后的技术规格页映射到结果上。 |
| `_wikipediaApi` | 私有静态 const | B | 英文维基百科的 MediaWiki API 端点。 |
| [`_searchWikipedia`](#_searchwikipedia) | 私有静态方法 | A | 搜索英文维基百科。 |
| [`_fetchWikipediaDetail`](#_fetchwikipediadetail) | 私有静态方法 | A | 读取维基百科条目的信息框与首图。 |
| [`withWikipediaInfobox`](#withwikipediainfobox) | 静态方法 | A | 把信息框映射到结果上。 |

行数（39）多于 `grep -c 'Purpose:' device_search_service.dart`（28）。28 个 `Purpose:` 块占 27 行，因为
`_SourceResponse` 的两个构造函数共用一行。其余 12 行是带普通 `///` 描述或没有注释、而非 `Purpose:` 块的
声明：枚举、六个类声明，以及五个静态常量与字段（`userAgent`、合为一行的 `_timeout` / `_maxResultsPerSource`、
`_sources`、`_appleFamilies`、`_wikipediaApi`）。按照「每个声明都要出现在表中」的分级规则，它们仍在此列出。

## 文档

### `enum DeviceSearchStatus` <a id="devicesearchstatus"></a>
- **种类：** 顶层枚举。
- **来源：** `lib/features/devices/services/device_search_service.dart`（第 16 行）。
- **用途：** 说明来源为何返回了这样的结果。
- **取值：**
  - `ok` —— 来源作出了响应且页面解析成功。当设备确实不在该数据库中时，`resultCount` 仍可能为 0。
  - `blocked` —— 返回的是机器人验证墙或验证页而不是内容，或者 HTTP 403。
  - `unreachable` —— DNS、套接字、超时，或非 200 且非 403 的状态码。
  - `markupChanged` —— 来源作出了响应，但解析器所依赖的结构一个都不存在，说明抓取逻辑需要更新。对维基百科
    而言，指 JSON 无法解码或缺少 `query.search`。
- **备注：** 关键在于这四者不再可以互相混淆。`unreachable` 时重试有意义，`blocked` 和 `markupChanged` 时
  重试永远没用，而 `ok` 且无结果时重试也没有意义。注意 `ok` 且 `resultCount == 0` 有意**不**算失败——零匹配
  的搜索页通过 `isNotebookcheckSearchPage` / `isPhonedbResultsPage` / `isAppleDocsIndexPage` 识别。

### `const DeviceSourceOutcome({...})` <a id="devicesourceoutcome-new"></a>
- **种类：** `DeviceSourceOutcome` 的构造函数。
- **来源：** 第 43 行。
- **用途：** 记录单个来源对一次查询的响应情况。
- **输入：** `source` 名称、`status` 和 `resultCount`。
- **返回：** 新的 `DeviceSourceOutcome`。
- **副作用：** 无。
- **备注：** 无。

### `bool get failed` <a id="outcome-failed"></a>
- **种类：** `DeviceSourceOutcome` 的 getter。
- **来源：** 第 54 行。
- **用途：** 报告该来源是失败了，还是仅仅什么都没找到。
- **返回：** 除 `ok` 以外的所有状态都返回 `true`。
- **副作用：** 无。
- **备注：** `ok` 且 `resultCount == 0` 不算失败。

### `const DeviceSearchResponse({...})` <a id="devicesearchresponse-new"></a>
- **种类：** `DeviceSearchResponse` 的构造函数。
- **来源：** 第 67 行。
- **用途：** 保存合并后的结果与逐来源状态。
- **输入：** `results`、`outcomes`。
- **副作用：** 无。
- **备注：** 无。

### `List<DeviceSourceOutcome> get failures` <a id="failures"></a>
- **种类：** `DeviceSearchResponse` 的 getter。
- **来源：** 第 74 行。
- **用途：** 列出失败的来源。
- **返回：** 状态不为 `ok` 的那些结果状态。
- **副作用：** 无。
- **备注：** 对话框用它来解释空结果或部分结果。

### `bool get allSourcesFailed` <a id="allsourcesfailed"></a>
- **种类：** `DeviceSearchResponse` 的 getter。
- **来源：** 第 83 行。
- **用途：** 报告是否所有被查询的来源都失败了。
- **返回：** 至少查询过一个来源且无一成功时返回 `true`。
- **副作用：** 无。
- **备注：** 正是它让对话框能说「所有来源都无法访问」而不是「未找到结果」——用户需要靠这个区分来判断重试
  是否有意义。只有真正被查询过的来源才有结果状态：`appliesTo` 拒绝了该查询的来源不会出现，维基百科这个后备
  来源也只在它实际运行时才会出现。

### `DeviceSearchResult withDetail({...})` <a id="withdetail"></a>
- **种类：** `DeviceSearchResult` 的方法。
- **来源：** 第 141 行。
- **用途：** 把新抓取到的详情字段合并到本结果上。
- **输入：** 任意详情字段；省略的字段保持原值。
- **返回：** `detailFetched` 置为 `true` 的新 `DeviceSearchResult`。
- **副作用：** 无。
- **备注：** 每个字段都做了空值合并，因此详情页缺失某字段时，绝不会抹掉已从搜索结果行解析到的值。
  Notebookcheck 的结果行内联携带 GPU、CPU 和屏幕信息；详情页有时完全没有 `Released`（Apple 的页面就是如此），
  这不应清空任何内容。`source`、`sourceUrl`、`name`、`brand`、`model` 和 `thumbnailUrl` 无法在这里修改，
  这就是 [`withWikipediaInfobox`](#withwikipediainfobox) 要先重建结果的原因。

### `const _Source({...})` <a id="_source-new"></a>
- **种类：** `_Source` 的私有构造函数。
- **来源：** 第 203 行。
- **用途：** 为来源注册表描述一个设备搜索来源。
- **输入：** `name` —— 来源名称，也会写入每条结果的 `source`；`enabled`（默认 `true`）；`fallback`（默认
  `false`）；`appliesTo` —— 该来源能否回答某个查询；`search` 与 `detail` —— 该来源的搜索函数与详情函数。
- **返回：** 新的 `_Source` 实例。
- **副作用：** 无。
- **备注：** `enabled: false` 保留代码、解析器和测试，但不再查询该来源——这是给开始拦截或变化到无法修复的
  来源准备的开关。后备来源只在其他所有来源都一无所获时才查询，使覆盖面宽的来源无法用产品线条目淹没精确答案。
  不适用的来源既不被查询也不被上报。`name` 必须与搜索函数写入结果的 `source` 字符串相同，因为
  [`fetchDetail`](#fetchdetail) 靠这个字符串查找详情函数；两者不一致会静默跳过详情获取。

### `static const userAgent` <a id="useragent"></a>
- **种类：** `DeviceSearchService` 的静态 const。
- **来源：** 第 262 行。
- **用途：** 每个请求都发送的用户代理：`MyDevice (+https://github.com/YuanZhe-99/MyDevice)`。
- **备注：** 这是如实的客户端名称，而不是浏览器的。位于 Notebookcheck 前面的 Cloudflare 会以 HTTP 403 拒绝
  经由非 Chrome TLS 握手到达的 Chrome 用户代理——此前伪装的 Chrome 字符串正是 1.6.0 中搜索看起来失效的原因。
  MediaWiki 的 API 政策也要求使用可识别的用户代理。

### `static final List<_Source> _sources` <a id="_sources"></a>
- **种类：** `DeviceSearchService` 的私有静态 final。
- **来源：** 第 265 行。
- **用途：** 来源注册表：所有来源，按结果列出的顺序排列。
- **备注：** 当前各项，均已启用：

  | 名称 | `appliesTo` | 后备 | 搜索 / 详情 |
  |---|---|---|---|
  | `Apple` | `appleFamiliesFor(q).isNotEmpty` | 否 | [`_searchApple`](#_searchapple) / [`_fetchAppleDetail`](#_fetchappledetail) |
  | `Notebookcheck` | `_anyQuery` | 否 | [`_searchNotebookcheck`](#_searchnotebookcheck) / [`_fetchNotebookcheckDetail`](#_fetchnotebookcheckdetail) |
  | `PhoneDB` | `_anyQuery` | 否 | [`_searchPhonedb`](#_searchphonedb) / [`_fetchPhonedbDetail`](#_fetchphonedbdetail) |
  | `Wikipedia` | `_anyQuery` | 是 | [`_searchWikipedia`](#_searchwikipedia) / [`_fetchWikipediaDetail`](#_fetchwikipediadetail) |

  Apple 一项不是 `const`，因为它的 `appliesTo` 是闭包。

### `static List<String> get sourceNames` <a id="sourcenames"></a>
- **种类：** `DeviceSearchService` 的静态 getter。
- **来源：** 第 302 行。
- **用途：** 列出一次搜索可以查询的来源。
- **输入：** 无。
- **返回：** 已启用来源的名称，按结果顺序排列。
- **副作用：** 无。
- **备注：** 供 `test/device_search_sources_test.dart` 和 `tool/test_live.dart` 使用。它列出已启用的来源，
  不论它们是否适用于某个具体查询。

### `static Map<String, String> headers({String accept = 'text/html'})` <a id="headers"></a>
- **种类：** `DeviceSearchService` 的静态方法。
- **来源：** 第 316 行。
- **用途：** 构建每个抓取请求发送的请求头。
- **输入：** `accept` —— `Accept` 头的取值（维基百科请求传入 `application/json`）。
- **返回：** 含 [`userAgent`](#useragent)、accept 与 accept-language 的请求头映射。
- **副作用：** 无。
- **备注：** 集中管理，使用户代理不会在页面抓取与后续请求该页面所发现资源之间发生漂移。

### `static Future<DeviceSearchResponse> search(String query)` <a id="search"></a>
- **种类：** `DeviceSearchService` 的静态方法。
- **来源：** 第 331 行。
- **用途：** 在所有已启用且适用于该查询的来源中搜索设备。
- **输入：** `query` —— 用户输入的搜索文本。
- **返回：** `Future<DeviceSearchResponse>`，含合并结果与每个被查询来源各一条状态。
- **副作用：** 向 [`_sources`](#_sources) 中的来源发起 HTTP 请求。
- **算法：** 1. 当 `AppFlavor.isStore` 或去空白后的查询为空时立即返回空响应。2. 打开一个 `http.Client`。
  3. 运行非后备来源：保留已启用且 `appliesTo` 接受去空白查询的来源，用 `Future.wait` 并发查询，并按注册表顺序
  追加它们的结果与各一条 `DeviceSourceOutcome`。4. 若这一步没有任何结果，以同样方式运行后备来源。
  5. 在 `finally` 中关闭客户端。
- **用法：**
  ```dart
  final response = await DeviceSearchService.search('Galaxy Z Fold8');
  if (response.allSourcesFailed) { /* show why, per source */ }
  ```
- **备注：** 整个扇出共用一个客户端。某个来源失败绝不会妨碍另一个返回结果，因为每个来源函数都自行捕获传输
  错误并以状态形式上报，而不是抛出异常。只要第一步一无所获，后备这一步就会运行——无论其他来源是以 `ok`
  报告无匹配，还是全部失败——因此其他来源被拦截时，维基百科仍然可以作答。

### `static Future<DeviceSearchResult> fetchDetail(DeviceSearchResult result)` <a id="fetchdetail"></a>
- **种类：** `DeviceSearchService` 的静态方法。
- **来源：** 第 378 行。
- **用途：** 为用户选中的结果获取完整详情页。
- **输入：** `result` —— 先前由 [`search`](#search) 返回的一条结果。
- **返回：** `Future<DeviceSearchResult>`，获取成功时带有补充信息。
- **副作用：** 向该结果的来源发起一到两次 HTTP 请求。
- **算法：** 查找 `name` 等于 `result.source` 的已启用注册表项，用一个新客户端调用它的 `detail` 函数，并在
  `finally` 中关闭客户端。
- **备注：** 对商店版构建、没有 `sourceUrl` 的结果、未知或已禁用的来源，以及任何抛出的错误，都原样返回输入。
  注册表取代了原先的 `switch`，因此新来源不再需要在这里单独添加 `case`——但它的搜索函数必须把注册表名称写入
  `source`（见 [`_Source`](#_source-new)）。

### `static DeviceSearchStatus _classifyError(Object error)` <a id="_classifyerror"></a>
- **种类：** 私有静态方法。
- **来源：** 第 404 行。
- **用途：** 归类传输层失败。
- **输入：** `error` —— 抛出的对象。
- **返回：** 对应的 `DeviceSearchStatus`。
- **副作用：** 无。
- **备注：** 目前所有已识别的网络故障与所有未识别错误一律映射为 `unreachable`。分支保持显式书写，是为了将来
  若要作出更细的区分（例如对握手失败区别对待）有一处明确的落点。

### `static Future<_SourceResponse> _searchNotebookcheck(...)` <a id="_searchnotebookcheck"></a>
- **种类：** 私有静态方法。
- **来源：** 第 422 行。
- **用途：** 搜索 Notebookcheck 的设备数据库。
- **输入：** `client`、`query`。
- **返回：** `Future<_SourceResponse>`，含结果与状态。
- **副作用：** 发起一次 HTTP GET。
- **算法：** 1. GET `Laptop-Search.8223.0.html?model=<query>`。2. 把 403 映射为 `blocked`，其他非 200
  映射为 `unreachable`。3. 对响应体运行 `looksBlocked`。4. 匹配结果行（`<tr class="odd|even">`）；若一行都
  没有，则在 `isNotebookcheckSearchPage` 判定页面正常渲染时返回 `ok`，否则返回 `markupChanged`。5. 对每一行
  取出链接与标题，把标题交给 `cleanDeviceName`，若 `isReviewArticle` 或不满足 `isRelevant` 则丢弃，按小写名称
  去重，并解析 `<br/>` 之后的内联规格。6. 结果上限为 8 条。
- **备注：** 使用带连字符的 `Laptop-Search` 路径是有意为之；带下划线的 `Laptop_Search` 会 301 重定向。
  先 `cleanDeviceName` 再 `isReviewArticle` 的顺序，正是那个丢弃全部当代设备的缺陷的修复：Notebookcheck 把
  标准设备页命名为 `<name> - Reviews and Specs`，因此按原始标题过滤会丢掉 `Samsung Galaxy Z Fold8`，却保留了
  标题较短的旧款 `Samsung Galaxy Z Fold7`。

### `static Future<DeviceSearchResult> _fetchNotebookcheckDetail(...)` <a id="_fetchnotebookcheckdetail"></a>
- **种类：** 私有静态方法。
- **来源：** 第 537 行。
- **用途：** 读取 Notebookcheck 设备页，获取完整规格与图片。
- **输入：** `client`、`result`。
- **返回：** `Future<DeviceSearchResult>`。
- **副作用：** 发起一次 HTTP GET。
- **算法：** 用 `parseNotebookcheckSpecs` 解析页面，再映射其标签：

  | 区块标签 | 字段 | 解析函数 |
  |---|---|---|
  | `Processor` | `chipset` | `parseChipName` |
  | `Graphics adapter` | `gpuName` | `parseChipName` |
  | `Memory` | `ram` | `parseCapacity` |
  | `Storage` | `storage` | `parseCapacity` |
  | `Display` | `screenSize`、`screenResolutionW/H` | `parseScreenSize`、`parseResolution` |
  | `Battery` | `battery` | `parseBattery` |
  | `Operating System` | `os` | 原样 |
  | `Released` | `releaseDate` | `parseUsDate` |

- **备注：** 读取规格表正是这次获取的全部意义。旧实现只提取 JSON-LD 图片而丢弃了这张表，因此 RAM、存储、
  电池、操作系统和发布日期从该来源根本没有到达用户。并非每个页面都有全部区块——Apple 的页面就没有
  `Released`——缺失的区块只会让对应字段保持为空。

### `static String? _jsonLdImage(String html)` <a id="_jsonldimage"></a>
- **种类：** 私有静态方法。
- **来源：** 第 575 行。
- **用途：** 从页面的 JSON-LD 区块中提取产品图片 URL。
- **输入：** `html` —— 页面完整标记。
- **返回：** 图片 URL，或 `null`。
- **副作用：** 无。
- **算法：** 遍历 `<script type="application/ld+json">` 区块，在 `try` 中逐个解码，取第一个 `@type` 为
  `Product` 的区块，`image` 既接受带 `url` 的对象也接受裸字符串，最后用 `isLikelyDeviceImage` 过滤。
- **备注：** 一个页面带有多个 JSON-LD 区块，其中包括 `Article` 区块；只有 `Product` 才含设备照片。格式错误的
  区块会被跳过，而不会中断整个扫描。

### `static Future<_SourceResponse> _searchPhonedb(...)` <a id="_searchphonedb"></a>
- **种类：** 私有静态方法。
- **来源：** 第 610 行。
- **用途：** 搜索 PhoneDB 的设备数据库。
- **输入：** `client`、`query`。
- **返回：** `Future<_SourceResponse>`，含结果与状态。
- **副作用：** 发起一次 HTTP POST。
- **算法：** 1. 向 `index.php?m=device&s=list` POST `search_exp=<query>`。2. 把 403 映射为 `blocked`，
  其他非 200 映射为 `unreachable`，并运行 `looksBlocked`。3. 按 `<div class="content_block">` 切分；若没有
  任何区块，则在 `isPhonedbResultsPage` 判定页面正常渲染时返回 `ok`，否则返回 `markupChanged`。4. 对每个
  区块读取锚点的 `title`（其中是**完整**名称；可见链接文本被 `..` 截断），做清洗，应用评测过滤与相关性闸门，
  按清洗后的名称去重，并取出缩略图。5. 上限 8 条。
- **备注：** 按清洗后的名称去重，正是把同一款手机的众多地区与容量 SKU 合并的手段——PhoneDB 会把
  `Galaxy Z Fold7` 的 256GB、512GB 和 1TB 版本在多个地区分别列出——最终收敛为一行。这里的相关性闸门不是可选项：
  没有它，一个未收录的型号会用不相关的手机填满全部 8 个位置。

### `static Future<DeviceSearchResult> _fetchPhonedbDetail(...)` <a id="_fetchphonedbdetail"></a>
- **种类：** 私有静态方法。
- **来源：** 第 701 行。
- **用途：** 读取 PhoneDB 参数表页，获取完整规格。
- **输入：** `client`、`result`。
- **返回：** `Future<DeviceSearchResult>`。
- **副作用：** 发起一次 HTTP GET。
- **算法：** 用 `parsePhonedbSpecs` 解析，再映射：

  | 参数表标签 | 字段 | 解析函数 |
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

- **备注：** PhoneDB 以**毫米**给出对角线尺寸，容量则使用**二进制**单位，因此两者都走做单位换算的解析函数，
  而不是 Notebookcheck 所用的英寸/十进制版本。搜索结果的缩略图被复用为图片，因为参数表页没有更大的产品照片。

### `static Set<String> appleFamiliesFor(String query)` <a id="applefamiliesfor"></a>
- **种类：** `DeviceSearchService` 的静态方法。
- **来源：** 第 751 行。
- **用途：** 判断查询涉及 Apple 支持文档的哪些产品族。
- **输入：** `query` —— 用户输入的搜索文本。
- **返回：** 要读取的 `docs/<family>` 路径段（`iphone`、`ipad`、`mac`、`watch`、`airpods`）；非 Apple 查询时
  为空。
- **副作用：** 无。
- **算法：** 把小写化后的查询切成连续字母串并去重，再逐个经 `_appleFamilies` 映射（`iphone`、`ipad`、
  `mac` / `macbook` / `imac`、`watch`、`airpods`）。只有查询中同时含有 `apple` 一词时，`watch` 才计入。
- **用法：**
  ```dart
  DeviceSearchService.appleFamiliesFor('MacBook Pro 14'); // {'mac'}
  DeviceSearchService.appleFamiliesFor('Apple');          // {}
  DeviceSearchService.appleFamiliesFor('Galaxy Watch 7'); // {}
  ```
- **备注：** 以产品词而不是「Apple」为键，因此「Apple Watch」和「MacBook Pro」都能匹配，而单独的「Apple」不会
  拉取所有索引。由于只看字母，`iPhone16` 仍会匹配 `iphone`。单独的「Watch」不属于 Apple：查询中还须含有
  「Apple」，因此 `Galaxy Watch 7` 返回空集合，Apple 来源根本不会被查询。

### `static Future<_SourceResponse> _searchApple(...)` <a id="_searchapple"></a>
- **种类：** 私有静态方法。
- **来源：** 第 774 行。
- **用途：** 在 Apple 支持文档中搜索 Apple 产品。
- **输入：** `client`、`query`。
- **返回：** `Future<_SourceResponse>`；非 Apple 查询时为空且 `ok`。
- **副作用：** 对每个匹配的产品族依次发起一次 HTTP GET。
- **算法：** 1. 从 [`appleFamiliesFor`](#applefamiliesfor) 取得产品族；没有则返回空的 `ok`。2. 从用于相关性
  判断的查询中去掉「Apple」一词。3. 对每个产品族 GET `support.apple.com/en-us/docs/<family>`；403 记为
  `blocked`，其他非 200 或抛出的错误记为 `unreachable`，未通过 `isAppleDocsIndexPage` 的页面记为
  `markupChanged`——之后都继续处理下一个产品族。4. 用 `parseAppleDocsIndex` 读取页面，去掉每个名称结尾的
  ` Wi-Fi` 或 ` Wi-Fi + Cellular`，丢弃不满足 `isRelevant` 的名称，在每个产品族内按小写名称去重，并以名称比
  查询多出的词元数为每项打分。5. 若什么都没找到且有产品族失败，返回该失败；否则按分数排序（同分按原始索引）并以 `ok` 返回前 8 条。
- **备注：** Apple 没有面向规格的搜索端点，但每个产品族的文档索引都列出了全部型号。结果带有
  `brand: 'Apple'`，以清洗后的名称同时作为 `name` 和 `model`，以产品文档页作为 `sourceUrl`，并使用索引中
  240 px 的缩略图。按多出的词元排序，使查询 `iPhone 16` 时 `iPhone 16` 排在 `iPhone 16 Pro Max` 之前。只有在
  没有任何产品族产出结果时才会上报产品族失败；Dart 的 `List.sort` 不稳定，因此以每个结果的原始索引打破平局，同分名称保持页面顺序。

### `static Future<DeviceSearchResult> _fetchAppleDetail(...)` <a id="_fetchappledetail"></a>
- **种类：** 私有静态方法。
- **来源：** 第 859 行。
- **用途：** 读取 Apple 产品的技术规格页。
- **输入：** `client`、`result`。
- **返回：** `Future<DeviceSearchResult>`。
- **副作用：** 发起两次 HTTP GET：先是产品文档页，再是它的技术规格页。
- **算法：** 1. GET `result.sourceUrl`。2. 用 `findAppleTechSpecsLink` 找到技术规格页链接。3. GET 该页面并用
  `parseAppleTechSpecs` 解析。4. 用 [`withAppleSpecs`](#withapplespecs) 映射。
- **备注：** 任一步出现非 200，或文档页没有技术规格页链接时，原样返回结果；抛出的错误由
  [`fetchDetail`](#fetchdetail) 的 `catch` 接住。

### `static DeviceSearchResult withAppleSpecs(DeviceSearchResult result, AppleTechSpecs specs)` <a id="withapplespecs"></a>
- **种类：** `DeviceSearchService` 的静态方法。
- **来源：** 第 889 行。
- **用途：** 把解析后的 Apple 技术规格页映射到搜索结果上。
- **输入：** `result` —— 选中的结果；`specs` —— 解析后的页面。
- **返回：** 经 [`withDetail`](#withdetail) 补充后的结果。
- **副作用：** 无。
- **算法：** 对读取的每一行替换不换行连字符与不换行空格，再映射经 `appleSection` 找到的各节：

  | 节 | 字段 | 规则 |
  |---|---|---|
  | `Chip` | `chipset` | 第一行匹配 `<name> chip` 的 → `Apple <name>`（`Apple A18`） |
  | `Chip` | `gpuName` | 第一个 `N-core GPU` → `<chipset> GPU (N-core)`；没有 chipset 时不设 |
  | `Memory` | `ram` | 提到 "memory" 的行中的第一个容量 |
  | `Storage`、`Capacity` | `storage` | 第一个容量 |
  | `Display` | `screenSize`、`screenResolutionW/H` | `N-inch` → `N"`；`W-by-H` |
  | `Battery and Power`、`Power and Battery`、`Battery` | `battery` | `N-watt-hour` → `N Wh`，否则取第一个 `parseBattery` 命中 |
  | `Operating System` | `os` | 第一行，仅当不超过 40 个字符 |
  | （页面） | `imageUrl` | 页面的产品渲染图 |

- **备注：** 为测试而公开。芯片名按捆绑预设的写法书写（`Apple A18`、`Apple M4 Pro GPU (16-core)`），使编辑器
  能匹配到预设。Apple 列出多种配置时取基础配置。手机列出的是播放时长而非容量，`parseBattery` 不会读取，因此
  手机没有电池值。Apple 只给出推出年份，这不是发布日期，所以 `releaseDate` 保持未设置。

### `static Future<_SourceResponse> _searchWikipedia(...)` <a id="_searchwikipedia"></a>
- **种类：** 私有静态方法。
- **来源：** 第 993 行。
- **用途：** 在英文维基百科中搜索关于该设备的条目。
- **输入：** `client`、`query`。
- **返回：** `Future<_SourceResponse>`，以条目标题作为结果。
- **副作用：** 向 MediaWiki API（`_wikipediaApi`）发起一次 HTTP GET。
- **算法：** 1. GET `action=query&list=search`，限制为 8 条主命名空间命中。2. 把 403 映射为 `blocked`，其他
  非 200 与抛出的错误映射为 `unreachable`，无法解码的 JSON 或缺少 `query.search` 列表映射为
  `markupChanged`。3. 对每条命中，去掉结尾的消歧义括注（如 `(smartphone)`），并恢复被 MediaWiki 大写掉的
  小写 `i`（`IPhone 16` → `iPhone 16`）。4. 当标题包含每个查询词，或标题至少两个词且每个词都在查询中时保留。
  5. 用 `splitBrandModel` 拆分品牌与型号，并链接到 `en.wikipedia.org/wiki/` 下的条目。
- **备注：** 反向匹配使 `Steam Deck OLED` 能找到 `Steam Deck` 条目；两词下限则防止 `Steam` 这类单词标题匹配
  一切。这里不做评测过滤或去重；MediaWiki 对每个条目只返回一次。

### `static Future<DeviceSearchResult> _fetchWikipediaDetail(...)` <a id="_fetchwikipediadetail"></a>
- **种类：** 私有静态方法。
- **来源：** 第 1070 行。
- **用途：** 读取维基百科条目的信息框与首图。
- **输入：** `client`、`result`。
- **返回：** `Future<DeviceSearchResult>`；条目没有设备信息框时原样返回。
- **副作用：** 向 MediaWiki API 发起两次 HTTP GET。
- **算法：** 1. 从 `sourceUrl` 的最后一个路径段取得标题。2. GET
  `action=parse&prop=wikitext&section=0&redirects=1`——只取导言部分。3. 用 `extractWikiInfobox` 取出信息框；
  若 `isWikiDeviceInfobox` 不接受则停止。4. 在 `try` 中以 `pithumbsize=800` GET `prop=pageimages` 获取页面
  图片。5. 用 [`withWikipediaInfobox`](#withwikipediainfobox) 映射。
- **备注：** 以 800 px 渲染页面图片，可把 SVG 原图变成应用能解码的 PNG。图片获取失败时仍返回规格。设备信息框
  检查能防止重定向到公司条目（`Framework Laptop 13` → 该公司）时把它当作规格读取。

### `static DeviceSearchResult withWikipediaInfobox(...)` <a id="withwikipediainfobox"></a>
- **种类：** `DeviceSearchService` 的静态方法。
- **来源：** 第 1144 行。
- **用途：** 把维基百科信息框映射到搜索结果上。
- **输入：** `result`；来自 `extractWikiInfobox` 的 `infobox`；可选的 `imageUrl`。
- **返回：** 补充后的结果。
- **副作用：** 无。
- **算法：** 用信息框中的品牌重建结果（型号去掉开头的品牌前缀），再经 [`withDetail`](#withdetail) 合并：

  | 信息框参数（按优先级） | 字段 | 解析函数 |
  |---|---|---|
  | `developer`、`brand`、`manufacturer` | `brand` | `wikiField`、`wikiBrand` |
  | `soc`、`system_on_chip`、`cpu`、`processor` | `chipset` | `wikiField`、`parseChipName` |
  | `gpu`、`graphics` | `gpuName` | `wikiField`、`parseChipName` |
  | `memory`、`ram` | `ram` | `wikiField`、`parseCapacity` |
  | `storage` | `storage` | `wikiField`、`parseCapacity` |
  | `display`、`screen` | `screenSize`、`screenResolutionW/H` | `wikiFieldText` 并把 `×` 换成 `x`，再 `parseWikiScreenSize`、`parseResolution` |
  | `battery`、`power` | `battery` | `wikiFieldText`、`parseBattery` |
  | `os`、`operating_system`、`operatingsystem` | `os` | `wikiField` |
  | `released`、`releasedate`、`release_date`、`first_release`、`release`、`introduced` | `releaseDate` | `wikiField`、`parseWikiDate` |

- **备注：** 为测试而公开。产品有多个变体（LCD 款与 OLED 款）时读取列在最前面的那个。厂商优先取 `developer`
  而不是 `manufacturer`，因为后者常常是富士康这样的代工厂。信息框中没有品牌时，保留搜索步骤中
  `splitBrandModel` 的推断。

## 相关

- [`device_search_parsers.md`](device_search_parsers.md) —— 全部页面解析，针对固定样本做单元测试。
- [`../views/device_search_dialog.md`](../views/device_search_dialog.md) —— 两阶段界面与字段勾选。
- [`chip_search_service.md`](chip_search_service.md) —— CPU/GPU 的同类功能。
- [`preset_service.md`](preset_service.md) —— 离线捆绑模板的对应物。
- [在线搜索与预设](../../../../features/online-search-and-presets.md)
