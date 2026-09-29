# lib/features/devices/services/device_search_parsers.dart

在线设备搜索各来源共用的纯解析辅助函数。本文件中的所有内容都不涉及网络、也没有副作用，因此可以针对
`test/fixtures/` 下保存的固定样本（fixture）做单元测试，无需访问远程主机。被抓取的页面标记是搜索功能中
最脆弱的部分，所以解析逻辑与 [`device_search_service.md`](device_search_service.md) 中的 HTTP 管道分开，
后者是本文件在 `lib/` 中唯一的调用方。

本文件按关注点分组：实体与标签处理、名称、相关性、取值、Notebookcheck 与 PhoneDB 页面读取函数、Apple 支持
网站读取函数（文档索引、技术规格页），以及维基百科读取函数（信息框 wikitext、日期）。

拆分的原因是：此前的设计把每个解析函数都作为服务内部的私有静态成员，导致它们全部无法测试。本页据以核对源码的
概念性介绍见
[在线搜索与预设](../../../../features/online-search-and-presets.md#device-spec-search--device_search_servicedart)，
基于固定样本的测试见 `test/device_search_parser_test.dart`（Notebookcheck、PhoneDB）和
`test/device_search_sources_test.dart`（Apple、维基百科）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `_namedEntities` | 私有 const map | B | 抓取的来源中出现的具名 HTML 实体。 |
| [`decodeEntities`](#decodeentities) | 函数 | A | 解码具名和数字形式的 HTML 实体。 |
| [`stripHtml`](#striphtml) | 函数 | A | 将 HTML 片段化简为可见文本。 |
| [`looksBlocked`](#looksblocked) | 函数 | A | 识别以机器人验证页替代正文内容的情况。 |
| [`splitBrandModel`](#splitbrandmodel) | 函数 | A | 把设备名拆分为品牌与型号。 |
| [`cleanDeviceName`](#cleandevicename) | 函数 | A | 把抓取到的标题规范化为纯设备名。 |
| [`isReviewArticle`](#isreviewarticle) | 函数 | A | 判断标题是评测文章而非设备条目。 |
| [`tokenize`](#tokenize) | 函数 | A | 把字符串切分为可比较的小写词元。 |
| [`relevanceScore`](#relevancescore) | 函数 | A | 为结果与查询的匹配程度打分。 |
| [`isRelevant`](#isrelevant) | 函数 | A | 过滤掉并未回应查询的结果。 |
| [`parseCapacity`](#parsecapacity) | 函数 | A | 读取单个存储或内存容量。 |
| [`parseMemory`](#parsememory) | 函数 | A | 拆分存储与内存合写的字符串。 |
| [`parseScreenSize`](#parsescreensize) | 函数 | A | 读取以英寸表示的屏幕对角线尺寸。 |
| [`parseScreenSizeMm`](#parsescreensizemm) | 函数 | A | 读取以毫米表示的屏幕对角线尺寸。 |
| [`parseResolution`](#parseresolution) | 函数 | A | 读取像素分辨率。 |
| [`parseBattery`](#parsebattery) | 函数 | A | 读取以 mAh 或 Wh 表示的电池容量。 |
| [`parseMonth`](#parsemonth) | 函数 | A | 把英文月份名或缩写映射为月份数字。 |
| [`parseReleaseDate`](#parsereleasedate) | 函数 | A | 读取年份在前、带月份名的日期。 |
| [`parseUsDate`](#parseusdate) | 函数 | A | 读取美式数字日期 `MM/DD/YYYY`。 |
| [`parseChipName`](#parsechipname) | 函数 | A | 取芯片规格字符串的首个组成部分。 |
| [`isLikelyDeviceImage`](#islikelydeviceimage) | 函数 | A | 判断图片 URL 是否为设备照片。 |
| [`isNotebookcheckSearchPage`](#isnotebookchecksearchpage) | 函数 | A | 确认响应确实是 Notebookcheck 的搜索页。 |
| [`isPhonedbResultsPage`](#isphonedbresultspage) | 函数 | A | 确认响应确实是 phonedb 的结果页。 |
| [`parseNotebookcheckSpecs`](#parsenotebookcheckspecs) | 函数 | A | 读取 Notebookcheck 设备页的规格表。 |
| [`parsePhonedbSpecs`](#parsephonedbspecs) | 函数 | A | 读取 phonedb 设备页的参数表行。 |
| `AppleDocsEntry` | typedef（记录） | B | Apple 支持文档索引上的一个产品链接：`name`、`url`、`thumbnailUrl`。 |
| [`parseAppleDocsIndex`](#parseappledocsindex) | 函数 | A | 读取 Apple 支持文档索引页上的产品链接。 |
| [`isAppleDocsIndexPage`](#isappledocsindexpage) | 函数 | A | 识别 Apple 支持文档索引页。 |
| [`findAppleTechSpecsLink`](#findappletechspecslink) | 函数 | A | 在 Apple 产品文档页上找到技术规格页链接。 |
| `AppleTechSpecs` | typedef（记录） | B | 应用从技术规格页读取的部分：`title`、`imageUrl`、`yearIntroduced`、`sections`。 |
| [`parseAppleTechSpecs`](#parseappletechspecs) | 函数 | A | 把 Apple 技术规格页拆分为带标题的节。 |
| [`appleSection`](#applesection) | 函数 | A | 按标题前缀选取技术规格页中的一节。 |
| [`extractWikiInfobox`](#extractwikiinfobox) | 函数 | A | 从 wikitext 中取出页面第一个信息框的参数。 |
| [`wikiValueItems`](#wikivalueitems) | 函数 | A | 把原始信息框取值转成纯文本条目。 |
| [`wikiField`](#wikifield) | 函数 | A | 读取第一个存在的信息框参数的首个条目。 |
| [`wikiFieldText`](#wikifieldtext) | 函数 | A | 读取第一个存在的信息框参数的全部条目。 |
| [`parseWikiScreenSize`](#parsewikiscreensize) | 函数 | A | 从信息框文本中读取以英寸表示的屏幕对角线尺寸。 |
| [`wikiBrand`](#wikibrand) | 函数 | A | 把信息框中的厂商字段化简为品牌名。 |
| [`isWikiDeviceInfobox`](#iswikideviceinfobox) | 函数 | A | 区分设备信息框与公司或人物信息框。 |
| [`parseWikiDate`](#parsewikidate) | 函数 | A | 从信息框文本中读取发布日期。 |

行数（40）比 `grep -c 'Purpose:' device_search_parsers.dart`（37）多三行：私有的 `_namedEntities` const 以及
两个记录 typedef `AppleDocsEntry` 和 `AppleTechSpecs` 带的是普通 `///` 描述而非完整的 `Purpose:` 块，因为它们
是数据形态而不是行为。按照「每个声明都要出现在表中」的分级规则，它们仍然在此列出。

## 文档

### `String decodeEntities(String input)` <a id="decodeentities"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/devices/services/device_search_parsers.dart`（第 41 行）。
- **用途：** 把具名和数字形式的 HTML 实体替换为它们所表示的字符。
- **输入：** `input` —— 可能含有实体的原始文本。
- **返回：** 完成实体解码的 `String`。
- **副作用：** 无。
- **算法：** 对 `&(#x?[0-9a-fA-F]+|[a-zA-Z]+);` 执行一次 `replaceAllMapped`。数字形式按十进制或
  十六进制解析，并对 Unicode 上限做范围校验；具名形式在 `_namedEntities` 中查表。无法识别的内容原样返回。
- **备注：** 只解码一遍很关键：反复解码会把 `&amp;nbsp;` 变成空格，而不是来源实际写下的字面量 `&nbsp;`。
  对未知实体原样返回是相对旧行为的有意改动——旧实现会**删除**每一个实体，这正是 `12&nbsp;GB` 会塌缩成
  `12GB`、`AT&amp;T` 会变成 `ATT` 的原因。

### `String stripHtml(String html)` <a id="striphtml"></a>
- **种类：** 顶层函数。
- **来源：** 第 61 行。
- **用途：** 把 HTML 片段化简为可见文本。
- **输入：** `html` —— 可能含有标签和实体的片段。
- **返回：** 去除标签、解码实体并合并连续空白后的文本。
- **副作用：** 无。
- **算法：** 把每个 `<[^>]*>` 替换为一个空格，执行 [`decodeEntities`](#decodeentities)，把 `\s+`
  合并为单个空格，再去除首尾空白。
- **备注：** 标签被替换为空格而不是空字符串，因此 `<b>Intel</b><i>Core</i>` 读作 `Intel Core` 而不是
  `IntelCore`。

### `bool looksBlocked(String body)` <a id="looksblocked"></a>
- **种类：** 顶层函数。
- **来源：** 第 74 行。
- **用途：** 识别以机器人验证墙或中间页替代正文内容的情况。
- **输入：** `body` —— 已解码的响应体。
- **返回：** 当响应体看起来是验证页时返回 `true`。
- **副作用：** 无。
- **算法：** 对验证页特征串做大小写不敏感的子串扫描（`challenges.cloudflare.com`、`turnstile`、
  `cf-chl`、`__cf_chl`、`just a moment`、`verify you are human`、`navigator.webdriver` 等）。
- **备注：** 这类页面是以 **HTTP 200** 返回的，因此仅检查状态码无法发现它们。这正是 GSMArena 长期表现为
  「无结果」而不是「来源被拦截」的失败模式。`test/fixtures/cloudflare_challenge.html` 是一份真实抓取的样本。

### `(String?, String?) splitBrandModel(String name)` <a id="splitbrandmodel"></a>
- **种类：** 顶层函数。
- **来源：** 第 99 行。
- **用途：** 把完整设备名拆分为品牌与其余的型号部分。
- **输入：** `name` —— 完整设备名，例如 `Samsung Galaxy Z Fold8`。
- **返回：** `(brand, model)` 记录；当名称中没有空格时 `model` 为 `null`。
- **副作用：** 无。
- **算法：** 先比对一份短的多词品牌列表，再回退到按第一个空格拆分。
- **备注：** 多词列表的存在是因为：单纯按第一个空格拆分会把 `Raspberry Pi` 或 `Google Cloud` 的一半留在
  型号字段里。

### `String cleanDeviceName(String raw)` <a id="cleandevicename"></a>
- **种类：** 顶层函数。
- **来源：** 第 127 行。
- **用途：** 把抓取到的结果标题规范化为纯设备名。
- **输入：** `raw` —— 各来源各自格式的标题。
- **返回：** 去掉来源模板文字与 SKU 噪声后的名称。
- **副作用：** 无。
- **算法：** 依次剥离：Notebookcheck 的 `- Reviews and Specs` 后缀、结尾的 ` specs`、phonedb 结尾的
  代号（如 `(Samsung Q7)`）、phonedb 的 OEM 料号（如 `SM-F9660`）、地区/SIM/网络/版本限定词，以及结尾的
  容量。最后合并空白。
- **用法：**
  ```dart
  cleanDeviceName('Samsung Galaxy Z Fold8 - Reviews and Specs');
  // 'Samsung Galaxy Z Fold8'
  ```
- **备注：** 本函数必须在 [`isReviewArticle`](#isreviewarticle) **之前**运行。Notebookcheck 把其标准设备页
  命名为 `<name> - Reviews and Specs`，因此直接过滤原始标题会丢弃最新的设备，却保留了恰好标题较短的旧设备。

### `bool isReviewArticle(String name)` <a id="isreviewarticle"></a>
- **种类：** 顶层函数。
- **来源：** 第 166 行。
- **用途：** 判断结果标题是编辑撰写的文章而不是一台设备。
- **输入：** `name` —— 已经过 [`cleanDeviceName`](#cleandevicename) 处理的标题。
- **返回：** 当标题读起来是评测、对比、跑分或上手时返回 `true`。
- **副作用：** 无。
- **算法：** 先排除短于 3 或长于 80 个字符的名称，再匹配覆盖 `review(s)`、`comparison`、`versus`、
  `vs`、`benchmark`、`hands-on`、`unboxing` 和 `test:` 的词边界模式。
- **备注：** 把 Notebookcheck 的原始标题传入这里是缺陷而非风格选择——参见
  [`cleanDeviceName`](#cleandevicename)。

### `List<String> tokenize(String value)` <a id="tokenize"></a>
- **种类：** 顶层函数。
- **来源：** 第 184 行。
- **用途：** 把字符串切分为可比较的小写词元。
- **输入：** `value` —— 任意名称或查询串。
- **返回：** 长度至少为 2 的字母数字词元。
- **副作用：** 无。
- **备注：** 丢弃单字符，使 `Galaxy Z Fold8` 中的 `Z` 无法主导打分；保留 `17` 这类双字符词元，因为它们
  承载了型号世代信息。服务也会直接统计词元数，用于为 Apple 结果排序，以及要求维基百科标题至少有两个词。

### `double relevanceScore(String query, String candidate)` <a id="relevancescore"></a>
- **种类：** 顶层函数。
- **来源：** 第 197 行。
- **用途：** 为结果名称与查询的匹配程度打分。
- **输入：** `query` —— 用户输入的内容；`candidate` —— 某条结果的名称。
- **返回：** 候选项中出现的查询词元占比，取值 `0.0` 至 `1.0`。
- **副作用：** 无。
- **备注：** 查询为空时返回 `0.0`，使调用方不会发生除零。

### `bool isRelevant(String query, String candidate, {double threshold = 1.0})` <a id="isrelevant"></a>
- **种类：** 顶层函数。
- **来源：** 第 212 行。
- **用途：** 过滤掉并未真正回应查询的结果。
- **输入：** `query`、`candidate`，以及可选的 `threshold`。
- **返回：** 当候选项得分达到或超过阈值时返回 `true`。
- **副作用：** 无。
- **备注：** phonedb 需要这道闸门：对于它并未收录的型号，它会以宽松的全文匹配作答——搜索
  `Galaxy Z Fold8` 会返回 120 条不相关的 Galaxy 手机。没有这道闸门，这些结果会被当作命中项展示。默认阈值
  `1.0` 要求每个查询词元都出现在结果名称中。

### `String? parseCapacity(String? raw)` <a id="parsecapacity"></a>
- **种类：** 顶层函数。
- **来源：** 第 224 行。
- **用途：** 从规格字符串中读取单个存储或内存容量。
- **输入：** `raw` —— 形如 `12 GB , LPDDR5x` 或 `256 GB UFS 4.0 Flash` 的文本。
- **返回：** 规范化的 `"<value> <unit>"` 字符串，或 `null`。
- **副作用：** 无。
- **备注：** 接受 phonedb 使用的二进制单位（`GiB`、`TiB`）并归一化为应用其他各处存储所用的十进制写法，
  因此 `12 GiB RAM` 会变成 `12 GB`。

### `(String? ram, String? storage) parseMemory(String? raw)` <a id="parsememory"></a>
- **种类：** 顶层函数。
- **来源：** 第 241 行。
- **用途：** 把存储与内存合写的字符串拆成两个容量。
- **输入：** `raw` —— 形如 `256GB 12GB RAM` 或 `8GB RAM` 的文本。
- **返回：** `(ram, storage)` 记录；任一侧都可能为 `null`。
- **副作用：** 无。
- **备注：** 只读取以逗号分隔的第一个变体，因为这些来源会列出所有 SKU，而应用只记录单一配置。

### `String? parseScreenSize(String? raw)` <a id="parsescreensize"></a>
- **种类：** 顶层函数。
- **来源：** 第 272 行。
- **用途：** 读取以英寸表示的屏幕对角线尺寸。
- **输入：** `raw` —— 形如 `7.60 inch 4:3, 2448 x 1848 pixel` 或 `6.80"` 的文本。
- **返回：** 格式化为 `7.60"` 的对角线尺寸，或 `null`。
- **副作用：** 无。
- **备注：** 同时接受 `inches`、`inch` 和裸的 `"`，因此两个来源可以共用一个函数解析。

### `String? parseScreenSizeMm(String? raw)` <a id="parsescreensizemm"></a>
- **种类：** 顶层函数。
- **来源：** 第 287 行。
- **用途：** 读取以毫米表示的屏幕对角线尺寸并换算为英寸。
- **输入：** `raw` —— 形如 `159.3 mm` 的文本。
- **返回：** 换算为英寸并格式化为 `6.27"` 的尺寸，或 `null`。
- **副作用：** 无。
- **备注：** phonedb 的 `Display Diagonal` 只以毫米给出，因此这是从该来源获取屏幕尺寸的唯一途径。
  非正值返回 `null` 而不是 `0.00"`。

### `(int?, int?) parseResolution(String? raw)` <a id="parseresolution"></a>
- **种类：** 顶层函数。
- **来源：** 第 302 行。
- **用途：** 读取像素分辨率。
- **输入：** `raw` —— 形如 `2448 x 1848 pixel` 或 `1080x2340` 的文本。
- **返回：** `(width, height)` 记录，或 `(null, null)`。
- **副作用：** 无。
- **算法：** 优先采用后面跟着 `pixel` 的数值；否则回退到任意每侧 3 至 5 位数字的 `NNN x NNN`。
- **备注：** 对 `pixel` 的优先处理与位数下限，可避免把开头的画面比例或刷新率误读为分辨率。

### `String? parseBattery(String? raw)` <a id="parsebattery"></a>
- **种类：** 顶层函数。
- **来源：** 第 323 行。
- **用途：** 读取以 mAh 或 Wh 表示的电池容量。
- **输入：** `raw` —— 形如 `4800 mAh Lithium-Ion, ...` 或 `100 Wh` 的文本。
- **返回：** 规范化的 `"4800 mAh"` / `"100 Wh"` 字符串，或 `null`。
- **副作用：** 无。
- **备注：** 先尝试 mAh，因为手机页面会同时给出两种单位。

### `int? parseMonth(String m)` <a id="parsemonth"></a>
- **种类：** 顶层函数。
- **来源：** 第 337 行。
- **用途：** 把英文月份名或缩写映射为月份数字。
- **输入：** `m` —— 月份名，例如 `September` 或 `Sep`。
- **返回：** `1` 至 `12`，无法识别时返回 `null`。
- **副作用：** 无。
- **备注：** 按前三个字母匹配，正是这一点让 phonedb 的 `2026 Mar 12` 能被解析；此前只收录全称的表对它
  返回 `null`。

### `DateTime? parseReleaseDate(String? raw)` <a id="parsereleasedate"></a>
- **种类：** 顶层函数。
- **来源：** 第 362 行。
- **用途：** 读取年份在前、带月份名的发布日期。
- **输入：** `raw` —— 形如 `2026 Mar 12` 或 `Released 2024, September 20` 的文本。
- **返回：** 解析出的日期，或 `null`。
- **副作用：** 无。
- **备注：** 没有日期部分时回退为当月一号，使只给到月份的来源仍能产出可用日期。

### `DateTime? parseUsDate(String? raw)` <a id="parseusdate"></a>
- **种类：** 顶层函数。
- **来源：** 第 386 行。
- **用途：** 读取写成美式数字格式的发布日期。
- **输入：** `raw` —— 形如 `07/22/2026` 的文本。
- **返回：** 解析出的日期，或 `null`。
- **副作用：** 无。
- **备注：** Notebookcheck 的 `Released` 采用 `MM/DD/YYYY`。月和日都做了范围校验，因此若页面改用
  `DD/MM/YYYY`，结果是 `null` 而不是一个悄然出错的日期。

### `String? parseChipName(String? raw)` <a id="parsechipname"></a>
- **种类：** 顶层函数。
- **来源：** 第 402 行。
- **用途：** 取以逗号分隔的芯片规格字符串的首个组成部分。
- **输入：** `raw` —— 形如 `Qualcomm Snapdragon 8 Elite Gen 5 for Galaxy 8c/8t, 2 x 4.7 GHz ...` 的文本。
- **返回：** 去掉结尾核心/线程数后的首个组成部分。
- **副作用：** 无。
- **备注：** 两个来源都会在芯片名之后附加频率与核心信息；应用把这些存放在 `CpuInfo` 的专用字段里，
  而不是型号字符串中。

### `bool isLikelyDeviceImage(String url)` <a id="islikelydeviceimage"></a>
- **种类：** 顶层函数。
- **来源：** 第 419 行。
- **用途：** 判断图片 URL 是设备照片而不是广告。
- **输入：** `url` —— 绝对或协议相对的图片 URL。
- **返回：** 当 URL 看起来是真实设备图像时返回 `true`。
- **副作用：** 无。
- **算法：** 先排除已知的广告/推广/追踪特征串，再要求具备真实的图片扩展名。
- **备注：** 排除规则有意优先于接受规则，因此以 `banner.png` 形式提供的广告仍会被过滤掉。

### `bool isNotebookcheckSearchPage(String html)` <a id="isnotebookchecksearchpage"></a>
- **种类：** 顶层函数。
- **来源：** 第 449 行。
- **用途：** 确认响应确实是 Notebookcheck 的设备搜索页。
- **输入：** `html` —— 完整的响应体。
- **返回：** 搜索页正常渲染时返回 `true`，无论是否有匹配结果。
- **副作用：** 无。
- **备注：** 零匹配的查询会渲染出**没有**结果表格的搜索页。缺少这项检查，调用方就无法把它与页面结构变化区分开，
  于是对每一台未收录的设备都会报告 `markupChanged`——这正是把「无结果」与「已损坏」混为一谈的老问题，也是
  GSMArena 故障被长期掩盖的原因。`test/fixtures/notebookcheck_no_results.html` 固定了这一情形。

### `bool isPhonedbResultsPage(String html)` <a id="isphonedbresultspage"></a>
- **种类：** 顶层函数。
- **来源：** 第 459 行。
- **用途：** 确认响应确实是 phonedb 的搜索结果页。
- **输入：** `html` —— 完整的响应体。
- **返回：** 结果页正常渲染时返回 `true`，无论是否有匹配结果。
- **副作用：** 无。
- **备注：** 即使匹配数为零，phonedb 也会写出匹配计数（`0 results match`），因此该短语是页面本身完好的可靠标志。
  `test/fixtures/phonedb_no_results.html` 固定了这一情形。

### `Map<String, String> parseNotebookcheckSpecs(String html)` <a id="parsenotebookcheckspecs"></a>
- **种类：** 顶层函数。
- **来源：** 第 477 行。
- **用途：** 读取 Notebookcheck 设备页中「标签/值」形式的规格表。
- **输入：** `html` —— 详情页的完整标记。
- **返回：** 规格标签到可见值的映射；没有任何匹配时为空。
- **副作用：** 无。
- **算法：** 按字面量 `<div class="specs">` 标签块切分。对每个分片，取到第一个 `</div>` 为止作为标签，
  再取从该处到下一个 `<div class="specs_element">` 之间的全部内容（上限 4000 字符），交给
  [`stripHtml`](#striphtml) 处理。同一标签以首次出现为准。
- **用法：**
  ```dart
  final specs = parseNotebookcheckSpecs(html);
  final ram = parseCapacity(specs['Memory']);
  ```
- **备注：** 必须同时兼容两种标记形态。多数值位于 `div.specs_details` 内，而其中又**嵌套**了
  `div.specs_indicator`，因此匹配闭合的 `</div></div>` 会把 `Memory` 和 `Storage` 从中间截断，丢失
  indicator 之后的全部内容。`Released` 则完全没有外层容器，值直接跟在标签之后。在两个标签之间整体去除标签
  即可同时覆盖这两种情况。返回空映射意味着页面标记发生了变化，调用方必须如实报告，而不能当作「一台没有规格的
  设备」。

### `Map<String, String> parsePhonedbSpecs(String html)` <a id="parsephonedbspecs"></a>
- **种类：** 顶层函数。
- **来源：** 第 509 行。
- **用途：** 读取 phonedb 设备页中「标签/值」形式的参数表行。
- **输入：** `html` —— 详情页的完整标记。
- **返回：** 参数标签到可见值的映射；没有任何匹配时为空。
- **副作用：** 无。
- **算法：** 用惰性的 dot-all 模式匹配 `<td><strong>label</strong>…</td><td>value</td>`，并对两侧都做
  去标签处理。
- **备注：** 同一标签以首次出现为准，因为页面会在其对比表尾部重复某些标签。与 Notebookcheck 的读取函数一样，
  返回空映射意味着页面标记发生了变化。

### `List<AppleDocsEntry> parseAppleDocsIndex(String html, String family)` <a id="parseappledocsindex"></a>
- **种类：** 顶层函数。
- **来源：** 第 538 行。
- **用途：** 读取 Apple 支持文档索引页上的产品链接。
- **输入：** `html` —— 形如 `support.apple.com/en-us/docs/iphone` 的页面；`family` —— `docs/` 之后的路径段
  （`iphone`、`mac` 等）。
- **返回：** 每个产品一条 `AppleDocsEntry`，按页面顺序，无重复。
- **副作用：** 无。
- **算法：** 匹配每个 `<a ...>` 标签，再在其属性内检查以 `product` 开头的 `class` 和形如
  `https://support.apple.com/<locale>/docs/<family>/<id>` 的 `href`。跳过已见过的 URL 以及没有 `<div class="product-name">` 的锚点。名称经
  [`stripHtml`](#striphtml) 处理；第一个 `<img>` 的地址经 [`decodeEntities`](#decodeentities) 处理，并把
  `size=120x120` 放大为 `size=240x240`。
- **备注：** ID 是数字，较老的产品则是 `pl293` 这样的字母数字。由于在每个标签内分别匹配各属性，属性顺序无关紧要。
  没有产品链接的页面得到空列表，调用方借助
  [`isAppleDocsIndexPage`](#isappledocsindexpage) 将其与页面结构变化区分开。`test/fixtures/apple_docs_index.html`
  固定了这一情形。

### `bool isAppleDocsIndexPage(String html)` <a id="isappledocsindexpage"></a>
- **种类：** 顶层函数。
- **来源：** 第 576 行。
- **用途：** 识别 Apple 支持文档索引页。
- **输入：** `html` —— 完整的响应体。
- **返回：** 页面带有产品网格（`class="product-name"`）时返回 `true`。
- **副作用：** 无。
- **备注：** 把「没有匹配的产品」与页面结构变化区分开，作用与 Notebookcheck 的
  [`isNotebookcheckSearchPage`](#isnotebookchecksearchpage) 相同。

### `String? findAppleTechSpecsLink(String html)` <a id="findappletechspecslink"></a>
- **种类：** 顶层函数。
- **来源：** 第 583 行。
- **用途：** 在 Apple 产品文档页上找到「Tech Specs」链接。
- **输入：** `html` —— 形如 `support.apple.com/en-us/docs/iphone/301045` 的页面。
- **返回：** 技术规格页的绝对 URL，或 `null`。
- **副作用：** 无。
- **算法：** 扫描每个 `<a ...>` 起始标签，查找 `link-text="tech specs"`（不区分大小写），返回其 `href`；
  对以根路径开头的相对地址补上 `https://support.apple.com`。
- **备注：** 该链接带有 `data-ss-analytics-link-text="tech specs"` 标记；不依赖其可见文本。
  `test/fixtures/apple_docs_page.html` 固定了这一情形。

### `AppleTechSpecs parseAppleTechSpecs(String html)` <a id="parseappletechspecs"></a>
- **种类：** 顶层函数。
- **来源：** 第 611 行。
- **用途：** 把 Apple 技术规格页拆分为带标题的节。
- **输入：** `html` —— 形如 `support.apple.com/en-us/121029` 的页面。
- **返回：** `AppleTechSpecs` 记录：去掉 ` - Tech Specs` 的 `<h1>` 标题、产品渲染图、推出年份，以及每个 `<h3>`
  标题到其列表项与段落文本的映射，按顺序排列。
- **副作用：** 无。
- **算法：** 1. 标题取第一个 `<h1>`。2. 图片取第一个 `cdsassets.apple.com` 上的 `.png`、`.jpg` 或 `.jpeg`。
  3. 年份取去标签后页面文本中的 `Year introduced: YYYY`。4. 按 `<h3` 切分；每一段中，标题是到 `</h3>` 为止、
  去掉 `<sup>` 脚注标记的文本，正文延续到下一个 `<div class="gb-group`（或下一个标题）。5. 正文中每个 `<li>`
  或 `<p>` 去掉 `<sup>` 并去标签后成为一行；空行被丢弃。同一标题以第一节为准。
- **备注：** 去掉脚注正是 `Capacity<sup>1</sup>` 能以 `Capacity` 被找到的原因。Apple 提供的渲染图是透明或白色
  背景。`test/fixtures/apple_specs_iphone.html` 与 `apple_specs_mac.html` 固定了两条产品线。

### `List<String> appleSection(AppleTechSpecs specs, List<String> names)` <a id="applesection"></a>
- **种类：** 顶层函数。
- **来源：** 第 666 行。
- **用途：** 选取标题以给定名称之一开头的第一节的各行。
- **输入：** `specs`；按优先级排列的 `names`，比较时不区分大小写。
- **返回：** 该节的各行，或空列表。
- **副作用：** 无。
- **备注：** 优先级先看 `names` 的顺序，再看页面顺序。Apple 在不同产品线上的标题措辞略有不同（Mac 上是
  「Battery and Power」，iPhone 上是「Power and Battery」），因此调用方会传入每一种写法；前缀匹配也能容纳结尾的
  附加说明。

### `Map<String, String>? extractWikiInfobox(String wikitext)` <a id="extractwikiinfobox"></a>
- **种类：** 顶层函数。
- **来源：** 第 686 行。
- **用途：** 从 wikitext 中取出页面第一个信息框的参数。
- **输入：** `wikitext` —— 条目的导言部分。
- **返回：** 小写参数名到其原始取值的映射；页面没有信息框或其花括号始终未闭合时为 `null`。
- **副作用：** 无。
- **算法：** 1. 查找第一个 `{{infobox`（不区分大小写）。2. 向后扫描并计数 `{{` 与 `}}`，找到匹配的闭合处。
  3. 仅在 `{{ }}` 与 `[[ ]]` 的嵌套深度都为零时按 `|` 切分正文。4. 跳过第一段（模板名）；其余每段在第一个 `=`
  处拆开，键做小写并去空白，每个键保留第一个非空取值。
- **备注：** 深度计数使取值中的带竖线链接或列表模板不会让该取值提前结束。取值保持为原始 wikitext；由
  [`wikiValueItems`](#wikivalueitems) 转为文本。`test/fixtures/wikipedia_steam_deck.json` 与
  `wikipedia_company.json` 分别固定了设备条目与公司条目。

### `List<String> wikiValueItems(String raw)` <a id="wikivalueitems"></a>
- **种类：** 顶层函数。
- **来源：** 第 753 行。
- **用途：** 把原始信息框取值转成纯文本条目。
- **输入：** `raw` —— 形如 `{{ubl|'''LCD:''' 16 GB [[LPDDR5]]|...}}` 的 wikitext。
- **返回：** 按顺序排列的可见条目（每个列表项或每行一条），去掉了引用、注释、标记以及 `LCD:` 这类变体标签。
- **副作用：** 无。
- **算法：** 1. 去掉注释、`<ref>` 标签和 `[[File:...]]` / `[[Image:...]]`；把链接替换为其显示文字。
  2. 由内向外解析模板，最多 30 轮：

  | 模板 | 变为 |
  |---|---|
  | 列表模板（`ubl`、`plainlist`、`flatlist`、`hlist` 等） | 每个位置参数一个条目 |
  | `nowrap`、`nobr`、`small`、`abbr` 等 | 第一个位置参数 |
  | `nbsp`、`!` / `br`、`break` | 一个空格 / 一个换行 |
  | `convert`、`cvt` | `<value> <unit>` |
  | `start date...`、`release date...`、`dts` | `YYYY-MM-DD`，缺失的月或日记为 `01` |
  | `vgrelease`、`video game release` | 每个日期一行（每隔一个参数） |
  | 其他任何模板 | 丢弃 |

  3. 把外部链接展开为其显示文字，去掉粗体/斜体引号，去掉千位分隔符，并把 `<br>` 变为换行。4. 逐行去标签、
  去掉开头的列表标记和简短的 `Label:` 前缀；保留非空行。
- **备注：** 先解析链接，是因为模板内的带竖线链接在切分模板参数时会从竖线处被截断。去掉千位分隔符，使
  `4,400 mAh` 不会被读成 `400 mAh`。未知模板（价格、图标、「当前版本」辅助模板）被丢弃而不是去猜测。模板的
  具名参数（`df=yes`）会被忽略。

### `String? wikiField(Map<String, String> infobox, List<String> keys)` <a id="wikifield"></a>
- **种类：** 顶层函数。
- **来源：** 第 847 行。
- **用途：** 读取第一个存在的信息框参数的首个取值。
- **输入：** `infobox`；按优先级排列的 `keys`。
- **返回：** [`wikiValueItems`](#wikivalueitems) 的第一个纯文本条目，或 `null`。
- **副作用：** 无。
- **备注：** 不同信息框对同一事物的命名不同（`soc`、`system_on_chip`、`cpu`），因此调用方会传入它接受的每一种
  拼写。某个键的取值产不出条目时，会继续尝试下一个键。

### `String? wikiFieldText(Map<String, String> infobox, List<String> keys)` <a id="wikifieldtext"></a>
- **种类：** 顶层函数。
- **来源：** 第 863 行。
- **用途：** 读取第一个存在的信息框参数的全部条目。
- **输入：** `infobox`；按优先级排列的 `keys`。
- **返回：** 以 `, ` 连接的条目，或 `null`。
- **副作用：** 无。
- **备注：** 用于有用部分不在第一个条目的取值——例如依次列出面板类型、尺寸、分辨率的显示屏。

### `String? parseWikiScreenSize(String? raw)` <a id="parsewikiscreensize"></a>
- **种类：** 顶层函数。
- **来源：** 第 879 行。
- **用途：** 从信息框文本中读取以英寸表示的屏幕对角线尺寸。
- **输入：** `raw` —— 形如 `6.1 in`、`7.9-in LCD` 或 `7", 1280×800` 的文本。
- **返回：** 格式化为 `7.9"` 的对角线尺寸，或 `null`。
- **副作用：** 无。
- **备注：** 维基百科把单位缩写为 `in`，而 [`parseScreenSize`](#parsescreensize) 不接受它，因为在其他来源中
  `in` 是普通单词。

### `String? wikiBrand(String? raw)` <a id="wikibrand"></a>
- **种类：** 顶层函数。
- **来源：** 第 893 行。
- **用途：** 把信息框中的厂商字段化简为品牌名。
- **输入：** `raw` —— 形如 `Valve Corporation` 或 `Samsung Electronics` 的文本。
- **返回：** 去掉公司后缀后的第一个厂商，或 `null`。
- **副作用：** 无。
- **算法：** 取第一个 `/` 或第一个后面不跟 `Ltd` 的逗号之前的文本（因此 `Co., Ltd.` 中的逗号不会切分），再反复去掉结尾后缀，
  直到不再有后缀（`Corporation`、`Corp.`、`Inc.`、`Electronics`、`Co., Ltd.`、单独的 `Co.`、`Ltd.`、`Limited`、
  `Company`、`Computer`、`Technology`、`Group`、`Holdings`）。结果为空时返回 `null`。
- **备注：** 后缀会叠加，因此 `Samsung Electronics Co., Ltd.` 会变成 `Samsung`；`Nintendo / Foxconn` 这样的厂商
  列表只保留第一个厂商。

### `bool isWikiDeviceInfobox(Map<String, String> infobox)` <a id="iswikideviceinfobox"></a>
- **种类：** 顶层函数。
- **来源：** 第 922 行。
- **用途：** 判断信息框描述的是设备，而不是公司、人物或产品线。
- **输入：** `infobox`。
- **返回：** 带有 `cpu`、`soc`、`system_on_chip`、`processor`、`memory`、`storage` 或 `display` 中至少一个时
  返回 `true`。
- **副作用：** 无。
- **备注：** 「Framework Laptop 13」这样的重定向会落到公司条目上，其 `Infobox company` 不能被当作规格读取。

### `DateTime? parseWikiDate(String? raw)` <a id="parsewikidate"></a>
- **种类：** 顶层函数。
- **来源：** 第 938 行。
- **用途：** 从信息框文本中读取发布日期。
- **输入：** `raw` —— 形如 `2024-09-20`、`February 25, 2022` 或 `25 February 2022` 的文本。
- **返回：** 找到的第一个日期，或 `null`。
- **副作用：** 无。
- **算法：** 依次尝试：`YYYY-MM-DD`（[`wikiValueItems`](#wikivalueitems) 对日期模板的输出）、`Month D, YYYY`、
  `D Month YYYY`，以及 `Month YYYY`（当月一号）。月份名经 [`parseMonth`](#parsemonth) 处理。
- **备注：** 单独的年份会被忽略；仅有年份不构成发布日期。ISO 日期的月份不在 1–12 或日不在 1–31
  时返回 `null`，而不会像 `DateTime` 那样顺延到下个月。

## 相关

- [`device_search_service.md`](device_search_service.md) —— 唯一的调用方；负责 HTTP、来源分发与结果状态上报。
- [`preset_service.md`](preset_service.md) —— 在线搜索的离线对应物。
- [在线搜索与预设](../../../../features/online-search-and-presets.md)
