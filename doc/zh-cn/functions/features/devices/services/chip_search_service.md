# lib/features/devices/services/chip_search_service.dart

`ChipSearchService` 先搜索捆绑 CPU/GPU 预设，然后——仅 full 风格构建——并行查询 TechPowerUp、AMD 官方站和 Intel 官方站，用 Startpage 作为 URL 发现代理（此服务不发出任何搜索引擎提供 API 调用；它抓取 Startpage 自己的结果页）。概念总览见 [在线搜索与预设 — 芯片规格搜索](../../../../features/online-search-and-presets.md#chip-spec-search---chip_search_servicedart)，`ChipSearchResult.toCpuInfo`/`toGpuInfo` 产生的 `CpuInfo`/`GpuInfo` 形态见 [`device.md`](../models/device.md)。

**商店风格门控**：与 [`device_search_service.md`](device_search_service.md) 的提前返回模式不同，这里两个公共入口点 [`searchCpu`](#searchcpu) 和 [`searchGpu`](#searchgpu) 无论风格总是运行其本地 `presets` 搜索——只有*在线*部分包在 `if (AppFlavor.isFull) { ... }` 中，源码直接确认。这是 `AGENTS.md` Build Flavors 小节要求的四个门控检查之一（`AppFlavor` 见 [架构](../../../../architecture.md#appflavor)）；其他三个是 [`device_search_service.md`](device_search_service.md) 的提前返回和本文件外两个 UI 调用点（`device_edit_page.dart` 的三个在线搜索按钮、`device_list_page.dart` 的在线搜索 FAB），不在此批重新验证。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`ChipSearchResult`](#chipsearchresult-new) | 构造函数 | A | 创建 `ChipSearchResult` 实例。 |
| [`toCpuInfo`](#tocpuinfo) | 方法（`ChipSearchResult`） | A | 把此结果转换为 `CpuInfo`。 |
| [`toGpuInfo`](#togpuinfo) | 方法（`ChipSearchResult`） | A | 把此结果转换为 `GpuInfo`。 |
| [`searchCpu`](#searchcpu) | 静态方法 | A | 搜索捆绑 CPU 预设，然后（仅 full 风格）并行 TechPowerUp/AMD/Intel。 |
| [`searchGpu`](#searchgpu) | 静态方法 | A | 搜索捆绑 GPU 预设，然后（仅 full 风格）并行 TechPowerUp/AMD。 |
| [`_findTechPowerUpUrl`](#_findtechpowerupurl) | 静态方法（私有） | A | 经 Startpage 搜索发现 TechPowerUp 规格页 URL。 |
| [`_searchTechPowerUpCpu`](#_searchtechpowerupcpu) | 静态方法（私有） | A | 抓取 TechPowerUp CPU 规格页的 `th`/`td` 表。 |
| [`_searchTechPowerUpGpu`](#_searchtechpowerupgpu) | 静态方法（私有） | A | 抓取 TechPowerUp GPU 规格页的 `og:title`/`og:description` 元标签。 |
| [`_findAmdUrl`](#_findamdurl) | 静态方法（私有） | A | 经 Startpage 搜索发现 AMD 官方产品页 URL。 |
| [`_parseAmdSpecs`](#_parseamdspecs) | 静态方法（私有） | A | 解析 AMD 的 `dt`/`dd` 规格对，截断嵌入工具提示文本。 |
| [`_searchAmdCpu`](#_searchamdcpu) | 静态方法（私有） | A | 抓取 AMD CPU 产品页，门控于 AMD/Ryzen/EPYC/Athlon/Threadripper 关键词。 |
| [`_searchAmdGpu`](#_searchamdgpu) | 静态方法（私有） | A | 抓取 AMD GPU 产品页，门控于 AMD/Radeon/RX 关键词。 |
| [`_searchIntelCpu`](#_searchintelcpu) | 静态方法（私有） | A | 从 Intel 产品页 URL 段派生 CPU 规格（页面本身返回 403）。 |

行数（13）不匹配 `grep -c 'Purpose:' chip_search_service.dart`（10）：[`_parseAmdSpecs`](#_parseamdspecs) 有普通单行文档注释无 `/// Purpose:` 块，[`_searchAmdCpu`](#_searchamdcpu)/[`_searchAmdGpu`](#_searchamdgpu) 完全无文档注释——文件每个其他声明都有完整 `/// Purpose:` 块。

## 文档

### `const ChipSearchResult({required this.source, this.sourceUrl, this.model, this.architecture, this.frequency, this.performanceCores, this.efficiencyCores, this.threads, this.cache})` <a id="chipsearchresult-new"></a>
- **种类：** `ChipSearchResult` 的构造函数。
- **来源：** `lib/features/devices/services/chip_search_service.dart`（第 27 行）。
- **用途：** 持有一个 CPU 或 GPU 搜索结果——其来源（`'preset'`/`'TechPowerUp'`/`'AMD'`/`'Intel'`）、可选来源 URL 和适用的任何规格字段（GPU 结果只填充 `model`/`architecture`）。
- **输入：** `source` 必填；所有规格字段可选。
- **返回：** 新 `ChipSearchResult`。
- **副作用：** 无。
- **算法：** 平凡字段赋值。
- **用法：** 由本文件每个搜索方法构造（预设匹配、TechPowerUp、AMD、Intel）；被芯片搜索对话框经 [`toCpuInfo`](#tocpuinfo)/[`toGpuInfo`](#togpuinfo) 消费。
- **备注：** 同一类建模 CPU 和 GPU 结果两者——GPU 搜索简单让 `frequency`/`performanceCores`/`efficiencyCores`/`threads`/`cache` 未设。

### `CpuInfo toCpuInfo()` <a id="tocpuinfo"></a>
- **种类：** `ChipSearchResult` 的方法。
- **来源：** `lib/features/devices/services/chip_search_service.dart`（第 44 行）。
- **用途：** 把此芯片搜索结果转换为要附加到 `Device` 的 `CpuInfo`。
- **输入：** 无。
- **返回：** 每个字段按名直接复制过去的 `CpuInfo`（见 [`device.md`](../models/device.md)）。
- **副作用：** 无。
- **算法：** 直接字段到字段构造。
- **用法：**
  ```dart
  Navigator.of(context).pop(result.toCpuInfo());
  ```
  （来自 `chip_search_dialog.dart`，用户挑 CPU 搜索结果时）
- **备注：** `source`/`sourceUrl` 被丢弃——`CpuInfo` 无规格来自哪里的字段。

### `GpuInfo toGpuInfo()` <a id="togpuinfo"></a>
- **种类：** `ChipSearchResult` 的方法。
- **来源：** `lib/features/devices/services/chip_search_service.dart`（第 59 行）。
- **用途：** 把此芯片搜索结果转换为要附加到 `Device` 的 `GpuInfo`。
- **输入：** 无。
- **返回：** 只复制 `model`/`architecture`（其仅有两个字段）的 `GpuInfo`。
- **副作用：** 无。
- **算法：** `GpuInfo(model: model, architecture: architecture)`。
- **用法：**
  ```dart
  Navigator.of(context).pop(result.toGpuInfo());
  ```
  （来自 `chip_search_dialog.dart`，用户挑 GPU 搜索结果时）
- **备注：** 此结果碰巧带的任何仅 CPU 字段（GPU 搜索不应有）静默忽略，非错误。

### `static Future<List<ChipSearchResult>> searchCpu(String query, List<CpuInfo> presets)` <a id="searchcpu"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/chip_search_service.dart`（第 83 行）。
- **用途：** 按子串匹配搜索捆绑 CPU 预设，然后——full 风格构建——也并行查询 TechPowerUp/AMD/Intel，对已找到预设去重在线结果。
- **输入：** `query`；`presets` — 典型来自 `PresetService.loadCpus()`（见 [`preset_service.md`](preset_service.md)）。
- **返回：** `Future<List<ChipSearchResult>>` — 先预设匹配，然后任何不同在线匹配追加。
- **副作用：** `AppFlavor.isFull` 时三个并发 HTTP 请求（经 Startpage/TechPowerUp/AMD/Intel）；否则无。
- **算法：** 1. 不区分大小写子串匹配 `query` 对照每个预设 `model`，为每个命中构建 `source: 'preset'` 的 `ChipSearchResult`。2. `AppFlavor.isFull` 时：经 `Future.wait` 并发运行 `_searchTechPowerUpCpu`/`_searchAmdCpu`/`_searchIntelCpu`，各包在 `.catchError((_) => null)`。3. 跟踪已见小写 model（从预设匹配开始）；对每个小写 `model` 尚未存在的非 null 在线结果，追加它并记录其 model 为已见。
- **用法：** 设备编辑期间用户搜索 CPU 时从 `chip_search_dialog.dart` 调用。
- **备注：** 去重只按小写精确 `model` 字符串匹配——model 字符串与预设稍有不同的在线结果（如额外空白、后缀）被当作不同并与预设匹配并排包含，不与之合并。

### `static Future<List<ChipSearchResult>> searchGpu(String query, List<GpuInfo> presets)` <a id="searchgpu"></a>
- **种类：** 静态方法。
- **来源：** `lib/features/devices/services/chip_search_service.dart`（第 136 行）。
- **用途：** 按子串匹配搜索捆绑 GPU 预设，然后——full 风格构建——也并行查询 TechPowerUp/AMD（无 Intel GPU 源），对预设去重。
- **输入：** `query`；`presets` — 典型来自 `PresetService.loadGpus()`。
- **返回：** `Future<List<ChipSearchResult>>`。
- **副作用：** `AppFlavor.isFull` 时两个并发 HTTP 请求；否则无。
- **算法：** 与 [`searchCpu`](#searchcpu) 相同形态：先预设子串匹配，然后（仅 full 风格）并发 `_searchTechPowerUpGpu`/`_searchAmdGpu`，按小写 `model` 去重。
- **用法：** 用户搜索 GPU 时从 `chip_search_dialog.dart` 调用。
- **备注：** 只有两个在线源（本文件无 Intel GPU 搜索），不同于 `searchCpu` 的三个。

### `static Future<String?> _findTechPowerUpUrl(String query, String section)` <a id="_findtechpowerupurl"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/chip_search_service.dart`（第 183 行）。
- **用途：** 用带 `site:techpowerup.com/<section>` 过滤器的 Startpage 搜索为查询发现 TechPowerUp 规格页 URL。
- **输入：** `query`；`section` — `'cpu-specs'` 或 `'gpu-specs'`。
- **返回：** `Future<String?>` — 第一个匹配 URL，无找到/非 200 响应时 `null`。
- **副作用：** 一次到 `startpage.com/sp/search` 的 HTTP POST，15s 超时。
- **算法：** 把搜索查询（`"$query site:techpowerup.com/$section"`）POST 到 Startpage；在响应体正则匹配第一个 `https://www.techpowerup.com/$section/....c\d+` URL。
- **用法：** 被 [`_searchTechPowerUpCpu`](#_searchtechpowerupcpu) 和 [`_searchTechPowerUpGpu`](#_searchtechpowerupgpu) 两者调用。
- **备注：** 完全依赖 Startpage 自己的结果页 HTML 以纯文本含目标 URL——不用 Startpage API，这是抓取公共搜索结果页。

### `static Future<ChipSearchResult?> _searchTechPowerUpCpu(String query)` <a id="_searchtechpowerupcpu"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/chip_search_service.dart`（第 214 行）。
- **用途：** 找到并把 TechPowerUp CPU 规格页的 `th`/`td` 表抓取进 `ChipSearchResult`。
- **输入：** `query`。
- **返回：** `Future<ChipSearchResult?>` — 无 URL 找到、非 200 响应或解析规格表为空时 `null`。
- **副作用：** 两个 HTTP 请求：Startpage 查找（经 [`_findTechPowerUpUrl`](#_findtechpowerupurl)）和规格页 GET，15s 超时。
- **算法：** 1. 解析规格 URL。2. GET 它。3. 正则迭代每个 `<th>...</th><td>...</td>` 对进 `specs` 映射（键/值都去标签并折叠空白）。4. `<title>` 的型号名，剥离尾部 `" Specs"` 后缀。5. `specs['Codename']` 的架构，存在时 `specs['Generation']` 覆盖。6. 频率：`specs['Frequency']` 的基础时钟；同时存在非 `'N/A'` 的 `'Turbo Clock'` 时格式化为 `"$base (boost $turbo)"`。7. 核心/线程：`specs['# of Cores']`/`specs['# of Threads']` 解析为 `int`；然后存在混合架构键 `'Performance Cores'`/`'Efficiency Cores'` 时它们*覆盖*普通核心数（正则提取前导数字运行，因为那些字段值含额外描述文本）。8. 缓存：对 `Cache L2`/`Cache L3` 存在的任何，用 `' / '` 连接 `'L2 <l2>'`/`'L3 <l3>'`。
- **用法：** 被 [`searchCpu`](#searchcpu)（仅 full 风格）经 `Future.wait` 调用。
- **备注：** 混合 P/E 核心覆盖（步骤 7）意味着同时有普通 `'# of Cores'` 和 `'Performance Cores'`/`'Efficiency Cores'` 键的 CPU 报告混合细分而非扁平计数——这对 TechPowerUp 两者都发布的现代混合架构 CPU 重要。

### `static Future<ChipSearchResult?> _searchTechPowerUpGpu(String query)` <a id="_searchtechpowerupgpu"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/chip_search_service.dart`（第 327 行）。
- **用途：** 找到 TechPowerUp GPU 规格页并从其 `og:title`/`og:description` Open Graph 元标签（而非 HTML 规格表）提取型号/架构。
- **输入：** `query`。
- **返回：** `Future<ChipSearchResult?>` — 无 URL 找到、非 200 响应或任一元标签缺失时 `null`。
- **副作用：** 两个 HTTP 请求（URL 发现 + 规格页 GET）。
- **算法：** 1. 经 [`_findTechPowerUpUrl`](#_findtechpowerupurl)（`section: 'gpu-specs'`）解析 GPU 规格 URL。2. GET 它。3. 正则提取 `og:title`（型号，剥离尾部 `" Specs"` 后缀）和 `og:description`（逗号分隔规格摘要）。4. 取描述第一个逗号分隔部分作为芯片名；存在时剥离已知厂商前缀（`'NVIDIA '`、`'AMD '`、`'Intel '`、`'Apple '`、`'Qualcomm '`），用剩余作为 `architecture`。
- **用法：** 被 [`searchGpu`](#searchgpu)（仅 full 风格）经 `Future.wait` 调用。
- **备注：** 用元标签而非 `_searchTechPowerUpCpu` 用的 `th`/`td` 表——TechPowerUp 的 GPU 规格页不像 CPU 页那样表结构，因此此方法只提取 `model`/`architecture`，非频率/核心/缓存。

### `static Future<String?> _findAmdUrl(String query, String category)` <a id="_findamdurl"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/chip_search_service.dart`（第 396 行）。
- **用途：** 经 Startpage 为查询发现 AMD 官方产品页 URL，过滤到 `amd.com/en/products/<category>`。
- **输入：** `query`；`category` — `'processors'` 或 `'graphics'`。
- **返回：** `Future<String?>` — 第一个匹配、非反斜杠终止 URL，或 `null`。
- **副作用：** 一次到 Startpage 的 HTTP POST，15s 超时。
- **算法：** 把 `"$query specifications site:amd.com/en/products/$category"` POST 到 Startpage；正则匹配每个 `https://www.amd.com/en/products/....html` URL，过滤掉任何以字面反斜杠结尾的（标记转义伪影），返回第一个幸存者。
- **用法：** 被 [`_searchAmdCpu`](#_searchamdcpu) 和 [`_searchAmdGpu`](#_searchamdgpu) 两者调用。
- **备注：** 尾反斜杠过滤器存在正为拒绝 Startpage 结果 HTML 转义某些 URL 方式造成的畸形匹配——没有它，截断/损坏 URL 会被当作有效返回。

### `static Map<String, String> _parseAmdSpecs(String html)` <a id="_parseamdspecs"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/chip_search_service.dart`（第 420 行）。
- **用途：** 把 AMD 产品页的 `<dt>`/`<dd>` 规格标签/值对解析进映射，截断嵌入标签内的已知工具提示文本。
- **输入：** `html`。
- **返回：** `Map<String, String>` — 无对匹配时为空。
- **副作用：** 无。
- **算法：** 1. 正则迭代每个 `<dt>...</dt>\s*<dd>...</dd>` 对，键和值都去标签并折叠空白。2. 任一侧清洗后为空时跳过该对。3. 对键，扫描已知工具提示起始标记固定列表（`' Max boost '`、`' Represents '`、`' Boost Clock Frequency '`、`" 'Game Frequency'"`、`' AMD\`s product warranty'`、`' EPYC-'`、`' All-core boost'`）并在第一个找到处截断键——AMD 的 `<dt>` 元素在无分隔标记的实际标签后直接嵌入解释工具提示文本。
- **用法：** 被 [`_searchAmdCpu`](#_searchamdcpu) 和 [`_searchAmdGpu`](#_searchamdgpu) 两者调用。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释块——只有普通单行 `/// Parse AMD DT/DD spec pairs, cleaning tooltip noise.` 注释（见声明表上方行数说明）。工具提示标记列表是检查 AMD 实际标记发现的手工精选固定集合——AMD 稍后引入的新工具提示措辞在更新此列表前不会被剥离。

### `static Future<ChipSearchResult?> _searchAmdCpu(String query)` <a id="_searchamdcpu"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/chip_search_service.dart`（第 459 行）。
- **用途：** 抓取 AMD CPU 产品页获取规格细节，但只在查询本身看起来像 AMD CPU 时（避免对显然非 AMD 的查询浪费 Startpage/AMD 往返）。
- **输入：** `query`。
- **返回：** `Future<ChipSearchResult?>` — 查询不匹配 AMD-CPU 关键词门、无产品 URL 找到、页面获取失败或解析规格映射为空时 `null`。
- **副作用：** 至多两个 HTTP 请求（URL 发现 + 产品页 GET，20s 超时）。
- **算法：** 1. 门：小写 `query` 必须含 `'amd'`、`'ryzen'`、`'epyc'`、`'athlon'`、`'threadripper'` 至少一个，否则立即返回 `null`（完全无网络调用）。2. 经 [`_findAmdUrl`](#_findamdurl)（`category: 'processors'`）解析产品 URL。3. GET 它；经 [`_parseAmdSpecs`](#_parseamdspecs) 解析规格。4. `specs['Name']` 的 `model`；`specs['Processor Architecture']` 的 `architecture`，回退 `specs['Former Codename']`。5. 频率：`specs['Base Clock']` 的基础；同时存在加速时钟（`specs['Max. Boost Clock']`）时格式化 `"$base (boost $boost)"`；只存在加速（无基础）时单独用加速。6. 核心/线程：对 `specs['# of CPU Cores']`/`specs['# of Threads']` `int.tryParse`。7. 缓存：从 `specs['L2 Cache']`/`specs['L3 Cache']` 与 TechPowerUp 缓存字段相同的 `'L2 <l2>' / 'L3 <l3>'` 连接模式。
- **用法：** 被 [`searchCpu`](#searchcpu)（仅 full 风格）经 `Future.wait` 调用，包在 `.catchError((_) => null)`。
- **备注：** 此声明源码完全无文档注释。关键词门（步骤 1）是三个在线 CPU 源中唯一在发任何网络请求前按查询内容预过滤的——TechPowerUp 和 Intel 的搜索无论查询文本总是尝试网络调用。

### `static Future<ChipSearchResult?> _searchAmdGpu(String query)` <a id="_searchamdgpu"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/chip_search_service.dart`（第 525 行）。
- **用途：** 抓取 AMD GPU 产品页获取规格细节，门控于查询中 AMD/Radeon/RX 关键词。
- **输入：** `query`。
- **返回：** `Future<ChipSearchResult?>` — 关键词门失败、无 URL 找到、获取失败或规格为空时 `null`。
- **副作用：** 至多两个 HTTP 请求（产品页 GET 20s 超时）。
- **算法：** 1. 门：小写 `query` 必须含 `'amd'`、`'radeon'` 或 `'rx '`（注意 `'rx '` 尾随空格），否则立即返回 `null`。2. 经 [`_findAmdUrl`](#_findamdurl)（`category: 'graphics'`）解析产品 URL。3. GET 它；经 [`_parseAmdSpecs`](#_parseamdspecs) 解析。4. `specs['Name']` 的 `model`；`specs['GPU Architecture']` 的 `architecture`，回退 `specs['Series']`（如 `"Radeon RX 7000 Series"`），因为 AMD GPU 页不持续暴露专用架构字段。
- **用法：** 被 [`searchGpu`](#searchgpu)（仅 full 风格）经 `Future.wait` 调用，包在 `.catchError((_) => null)`。
- **备注：** 此声明源码完全无文档注释。`'rx '` 关键词（带尾随空格）刻意比裸 `'rx'` 子串匹配更窄，大概为避免含 "rx" 的无关词误报。

### `static Future<ChipSearchResult?> _searchIntelCpu(String query)` <a id="_searchintelcpu"></a>
- **种类：** 私有静态方法。
- **来源：** `lib/features/devices/services/chip_search_service.dart`（第 568 行）。
- **用途：** 从经 Startpage 发现的 Intel 产品页 URL 段派生 CPU 型号/缓存/频率——实际 Intel 页本身返回 HTTP 403 且从不获取，因此所有数据只来自解析 URL 路径段。
- **输入：** `query`。
- **返回：** `Future<ChipSearchResult?>` — 关键词门失败、Startpage 请求失败或响应中无匹配 Intel 规格 URL 模式时 `null`。
- **副作用：** 一次到 Startpage 的 HTTP POST，15s 超时。绝不向 `intel.com` 本身发请求。
- **算法：** 1. 门：小写 `query` 必须含 `'intel'`、`'core'`、`'xeon'`、`'celeron'`、`'pentium'` 之一，否则返回 `null`。2. 把 `"$query specifications site:intel.com/content/www/us/en/products/sku"` POST 到 Startpage。3. 正则匹配形态 `.../products/sku/<id>/<slug>/specifications.html` 的 Intel 规格 URL，捕获完整 URL 和 `<slug>`。4. 从 slug 派生型号名：从 `-<N>m-cache` 起剥离一切、按 `-` 拆分、把字面 token `'intel'` 映射为 `'Intel'`、`'processor'` 映射为 `''`（丢弃）、丢弃空 token、用空格连接；然后经不区分大小写正则替换大写已知产品线 token（`core`/`ultra`/`xeon`/`celeron`/`pentium`）；然后把形态 `i<digit><3+ digits><optional letters>` 的型号号重新格式化为 `i<digit>-<digits><UPPERCASE letters>`（如 `"i52520m"` → `"i5-2520M"`）。5. 从 slug 提取 `cache`（`<N>m-cache` → `"<N> MB"`）。6. 从 slug 提取 `frequency`（`up-to-<N>-<M>-ghz` → `"Up to <N>.<M> GHz"`）。
- **用法：** 被 [`searchCpu`](#searchcpu)（仅 full 风格）经 `Future.wait` 调用，包在 `.catchError((_) => null)`。
- **备注：** 因为 Intel 自己的页 403，返回结果中 `sourceUrl` 仍指向真实（从本应用不可达）Intel 规格页——它纯粹"供用户参考"提供（按此文件类级文档注释），非本应用能再次成功获取的链接。型号号重新格式化正则（`i<digit><digits><letters>` → 连字符）源码显式注释为"best effort"——它可能对非为其设计的 slug 形态误触发。
