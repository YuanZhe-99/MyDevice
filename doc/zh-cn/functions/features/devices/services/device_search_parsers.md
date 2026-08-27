# lib/features/devices/services/device_search_parsers.dart

在线设备搜索各数据源共用的纯解析辅助函数。本文件中的所有内容都不涉及网络、也没有副作用，因此可以针对
`test/fixtures/` 下保存的固定样本（fixture）做单元测试，无需访问远程主机。被抓取的页面标记是搜索功能中
最脆弱的部分，所以解析逻辑与 [`device_search_service.md`](device_search_service.md) 中的 HTTP 管道分开，
后者是本文件唯一的调用方。

拆分的原因是：此前的设计把每个解析函数都作为服务内部的私有静态成员，导致它们全部无法测试。本页据以核对源码的
概念性介绍见
[在线搜索与预设](../../../../features/online-search-and-presets.md#device-spec-search--device_search_servicedart)，
基于固定样本的测试见 `test/device_search_parser_test.dart`。

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `_namedEntities` | 私有 const map | B | 抓取的数据源中出现的具名 HTML 实体。 |
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
| [`parseNotebookcheckSpecs`](#parsenotebookcheckspecs) | 函数 | A | 读取 Notebookcheck 设备页的规格表。 |
| [`parsePhonedbSpecs`](#parsephonedbspecs) | 函数 | A | 读取 phonedb 设备页的参数表行。 |

行数（23）比 `grep -c 'Purpose:' device_search_parsers.dart`（22）多一行：私有的 `_namedEntities` const
带的是普通 `///` 描述而非完整的 `Purpose:` 块，因为它是数据而不是行为。按照「每个声明都要出现在表中」的
分级规则，它仍然在此列出。

## Documentation

### `String decodeEntities(String input)` <a id="decodeentities"></a>
- **Kind:** 顶层函数。
- **Source:** `lib/features/devices/services/device_search_parsers.dart`（第 41 行）。
- **Purpose:** 把具名和数字形式的 HTML 实体替换为它们所表示的字符。
- **Inputs:** `input` —— 可能含有实体的原始文本。
- **Returns:** 完成实体解码的 `String`。
- **Side effects:** 无。
- **Algorithm:** 对 `&(#x?[0-9a-fA-F]+|[a-zA-Z]+);` 执行一次 `replaceAllMapped`。数字形式按十进制或
  十六进制解析，并对 Unicode 上限做范围校验；具名形式在 `_namedEntities` 中查表。无法识别的内容原样返回。
- **Notes:** 只解码一遍很关键：反复解码会把 `&amp;nbsp;` 变成空格，而不是数据源实际写下的字面量 `&nbsp;`。
  对未知实体原样返回是相对旧行为的有意改动——旧实现会**删除**每一个实体，这正是 `12&nbsp;GB` 会塌缩成
  `12GB`、`AT&amp;T` 会变成 `ATT` 的原因。

### `String stripHtml(String html)` <a id="striphtml"></a>
- **Kind:** 顶层函数。
- **Source:** 第 61 行。
- **Purpose:** 把 HTML 片段化简为可见文本。
- **Inputs:** `html` —— 可能含有标签和实体的片段。
- **Returns:** 去除标签、解码实体并合并连续空白后的文本。
- **Side effects:** 无。
- **Algorithm:** 把每个 `<[^>]*>` 替换为一个空格，执行 [`decodeEntities`](#decodeentities)，把 `\s+`
  合并为单个空格，再去除首尾空白。
- **Notes:** 标签被替换为空格而不是空字符串，因此 `<b>Intel</b><i>Core</i>` 读作 `Intel Core` 而不是
  `IntelCore`。

### `bool looksBlocked(String body)` <a id="looksblocked"></a>
- **Kind:** 顶层函数。
- **Source:** 第 74 行。
- **Purpose:** 识别以机器人验证墙或中间页替代正文内容的情况。
- **Inputs:** `body` —— 已解码的响应体。
- **Returns:** 当响应体看起来是验证页时返回 `true`。
- **Side effects:** 无。
- **Algorithm:** 对验证页特征串做大小写不敏感的子串扫描（`challenges.cloudflare.com`、`turnstile`、
  `cf-chl`、`__cf_chl`、`just a moment`、`verify you are human`、`navigator.webdriver` 等）。
- **Notes:** 这类页面是以 **HTTP 200** 返回的，因此仅检查状态码无法发现它们。这正是 GSMArena 长期表现为
  「无结果」而不是「数据源被拦截」的失败模式。`test/fixtures/cloudflare_challenge.html` 是一份真实抓取的样本。

### `(String?, String?) splitBrandModel(String name)` <a id="splitbrandmodel"></a>
- **Kind:** 顶层函数。
- **Source:** 第 99 行。
- **Purpose:** 把完整设备名拆分为品牌与其余的型号部分。
- **Inputs:** `name` —— 完整设备名，例如 `Samsung Galaxy Z Fold8`。
- **Returns:** `(brand, model)` 记录；当名称中没有空格时 `model` 为 `null`。
- **Side effects:** 无。
- **Algorithm:** 先比对一份短的多词品牌列表，再回退到按第一个空格拆分。
- **Notes:** 多词列表的存在是因为：单纯按第一个空格拆分会把 `Raspberry Pi` 或 `Google Cloud` 的一半留在
  型号字段里。

### `String cleanDeviceName(String raw)` <a id="cleandevicename"></a>
- **Kind:** 顶层函数。
- **Source:** 第 127 行。
- **Purpose:** 把抓取到的结果标题规范化为纯设备名。
- **Inputs:** `raw` —— 各数据源各自格式的标题。
- **Returns:** 去掉数据源模板文字与 SKU 噪声后的名称。
- **Side effects:** 无。
- **Algorithm:** 依次剥离：Notebookcheck 的 `- Reviews and Specs` 后缀、结尾的 ` specs`、phonedb 结尾的
  代号（如 `(Samsung Q7)`）、phonedb 的 OEM 料号（如 `SM-F9660`）、地区/SIM/网络/版本限定词，以及结尾的
  容量。最后合并空白。
- **Usage:**
  ```dart
  cleanDeviceName('Samsung Galaxy Z Fold8 - Reviews and Specs');
  // 'Samsung Galaxy Z Fold8'
  ```
- **Notes:** 本函数必须在 [`isReviewArticle`](#isreviewarticle) **之前**运行。Notebookcheck 把其标准设备页
  命名为 `<name> - Reviews and Specs`，因此直接过滤原始标题会丢弃最新的设备，却保留了恰好标题较短的旧设备。

### `bool isReviewArticle(String name)` <a id="isreviewarticle"></a>
- **Kind:** 顶层函数。
- **Source:** 第 163 行。
- **Purpose:** 判断结果标题是编辑撰写的文章而不是一台设备。
- **Inputs:** `name` —— 已经过 [`cleanDeviceName`](#cleandevicename) 处理的标题。
- **Returns:** 当标题读起来是评测、对比、跑分或上手时返回 `true`。
- **Side effects:** 无。
- **Algorithm:** 先排除短于 3 或长于 80 个字符的名称，再匹配覆盖 `review(s)`、`comparison`、`versus`、
  `vs`、`benchmark`、`hands-on`、`unboxing` 和 `test:` 的词边界模式。
- **Notes:** 把 Notebookcheck 的原始标题传入这里是缺陷而非风格选择——参见
  [`cleanDeviceName`](#cleandevicename)。

### `List<String> tokenize(String value)` <a id="tokenize"></a>
- **Kind:** 顶层函数。
- **Source:** 第 181 行。
- **Purpose:** 把字符串切分为可比较的小写词元。
- **Inputs:** `value` —— 任意名称或查询串。
- **Returns:** 长度至少为 2 的字母数字词元。
- **Side effects:** 无。
- **Notes:** 丢弃单字符，使 `Galaxy Z Fold8` 中的 `Z` 无法主导打分；保留 `17` 这类双字符词元，因为它们
  承载了型号世代信息。

### `double relevanceScore(String query, String candidate)` <a id="relevancescore"></a>
- **Kind:** 顶层函数。
- **Source:** 第 194 行。
- **Purpose:** 为结果名称与查询的匹配程度打分。
- **Inputs:** `query` —— 用户输入的内容；`candidate` —— 某条结果的名称。
- **Returns:** 候选项中出现的查询词元占比，取值 `0.0` 至 `1.0`。
- **Side effects:** 无。
- **Notes:** 查询为空时返回 `0.0`，使调用方不会发生除零。

### `bool isRelevant(String query, String candidate, {double threshold = 1.0})` <a id="isrelevant"></a>
- **Kind:** 顶层函数。
- **Source:** 第 209 行。
- **Purpose:** 过滤掉并未真正回应查询的结果。
- **Inputs:** `query`、`candidate`，以及可选的 `threshold`。
- **Returns:** 当候选项得分达到或超过阈值时返回 `true`。
- **Side effects:** 无。
- **Notes:** phonedb 需要这道闸门：对于它并未收录的型号，它会以宽松的全文匹配作答——搜索
  `Galaxy Z Fold8` 会返回 120 条不相关的 Galaxy 手机。没有这道闸门，这些结果会被当作命中项展示。默认阈值
  `1.0` 要求每个查询词元都出现在结果名称中。

### `String? parseCapacity(String? raw)` <a id="parsecapacity"></a>
- **Kind:** 顶层函数。
- **Source:** 第 221 行。
- **Purpose:** 从规格字符串中读取单个存储或内存容量。
- **Inputs:** `raw` —— 形如 `12 GB , LPDDR5x` 或 `256 GB UFS 4.0 Flash` 的文本。
- **Returns:** 规范化的 `"<value> <unit>"` 字符串，或 `null`。
- **Side effects:** 无。
- **Notes:** 接受 phonedb 使用的二进制单位（`GiB`、`TiB`）并归一化为应用其他各处存储所用的十进制写法，
  因此 `12 GiB RAM` 会变成 `12 GB`。

### `(String? ram, String? storage) parseMemory(String? raw)` <a id="parsememory"></a>
- **Kind:** 顶层函数。
- **Source:** 第 238 行。
- **Purpose:** 把存储与内存合写的字符串拆成两个容量。
- **Inputs:** `raw` —— 形如 `256GB 12GB RAM` 或 `8GB RAM` 的文本。
- **Returns:** `(ram, storage)` 记录；任一侧都可能为 `null`。
- **Side effects:** 无。
- **Notes:** 只读取以逗号分隔的第一个变体，因为这些数据源会列出所有 SKU，而应用只记录单一配置。

### `String? parseScreenSize(String? raw)` <a id="parsescreensize"></a>
- **Kind:** 顶层函数。
- **Source:** 第 269 行。
- **Purpose:** 读取以英寸表示的屏幕对角线尺寸。
- **Inputs:** `raw` —— 形如 `7.60 inch 4:3, 2448 x 1848 pixel` 或 `6.80"` 的文本。
- **Returns:** 格式化为 `7.60"` 的对角线尺寸，或 `null`。
- **Side effects:** 无。
- **Notes:** 同时接受 `inches`、`inch` 和裸的 `"`，因此两个数据源可以共用一个函数解析。

### `String? parseScreenSizeMm(String? raw)` <a id="parsescreensizemm"></a>
- **Kind:** 顶层函数。
- **Source:** 第 284 行。
- **Purpose:** 读取以毫米表示的屏幕对角线尺寸并换算为英寸。
- **Inputs:** `raw` —— 形如 `159.3 mm` 的文本。
- **Returns:** 换算为英寸并格式化为 `6.27"` 的尺寸，或 `null`。
- **Side effects:** 无。
- **Notes:** phonedb 的 `Display Diagonal` 只以毫米给出，因此这是从该数据源获取屏幕尺寸的唯一途径。
  非正值返回 `null` 而不是 `0.00"`。

### `(int?, int?) parseResolution(String? raw)` <a id="parseresolution"></a>
- **Kind:** 顶层函数。
- **Source:** 第 299 行。
- **Purpose:** 读取像素分辨率。
- **Inputs:** `raw` —— 形如 `2448 x 1848 pixel` 或 `1080x2340` 的文本。
- **Returns:** `(width, height)` 记录，或 `(null, null)`。
- **Side effects:** 无。
- **Algorithm:** 优先采用后面跟着 `pixel` 的数值；否则回退到任意每侧 3 至 5 位数字的 `NNN x NNN`。
- **Notes:** 对 `pixel` 的优先处理与位数下限，可避免把开头的画面比例或刷新率误读为分辨率。

### `String? parseBattery(String? raw)` <a id="parsebattery"></a>
- **Kind:** 顶层函数。
- **Source:** 第 320 行。
- **Purpose:** 读取以 mAh 或 Wh 表示的电池容量。
- **Inputs:** `raw` —— 形如 `4800 mAh Lithium-Ion, ...` 或 `100 Wh` 的文本。
- **Returns:** 规范化的 `"4800 mAh"` / `"100 Wh"` 字符串，或 `null`。
- **Side effects:** 无。
- **Notes:** 先尝试 mAh，因为手机页面会同时给出两种单位。

### `int? parseMonth(String m)` <a id="parsemonth"></a>
- **Kind:** 顶层函数。
- **Source:** 第 334 行。
- **Purpose:** 把英文月份名或缩写映射为月份数字。
- **Inputs:** `m` —— 月份名，例如 `September` 或 `Sep`。
- **Returns:** `1` 至 `12`，无法识别时返回 `null`。
- **Side effects:** 无。
- **Notes:** 按前三个字母匹配，正是这一点让 phonedb 的 `2026 Mar 12` 能被解析；此前只收录全称的表对它
  返回 `null`。

### `DateTime? parseReleaseDate(String? raw)` <a id="parsereleasedate"></a>
- **Kind:** 顶层函数。
- **Source:** 第 359 行。
- **Purpose:** 读取年份在前、带月份名的发布日期。
- **Inputs:** `raw` —— 形如 `2026 Mar 12` 或 `Released 2024, September 20` 的文本。
- **Returns:** 解析出的日期，或 `null`。
- **Side effects:** 无。
- **Notes:** 没有日期部分时回退为当月一号，使只给到月份的数据源仍能产出可用日期。

### `DateTime? parseUsDate(String? raw)` <a id="parseusdate"></a>
- **Kind:** 顶层函数。
- **Source:** 第 383 行。
- **Purpose:** 读取写成美式数字格式的发布日期。
- **Inputs:** `raw` —— 形如 `07/22/2026` 的文本。
- **Returns:** 解析出的日期，或 `null`。
- **Side effects:** 无。
- **Notes:** Notebookcheck 的 `Released` 采用 `MM/DD/YYYY`。月和日都做了范围校验，因此若页面改用
  `DD/MM/YYYY`，结果是 `null` 而不是一个悄然出错的日期。

### `String? parseChipName(String? raw)` <a id="parsechipname"></a>
- **Kind:** 顶层函数。
- **Source:** 第 399 行。
- **Purpose:** 取以逗号分隔的芯片规格字符串的首个组成部分。
- **Inputs:** `raw` —— 形如 `Qualcomm Snapdragon 8 Elite Gen 5 for Galaxy 8c/8t, 2 x 4.7 GHz ...` 的文本。
- **Returns:** 去掉结尾核心/线程数后的首个组成部分。
- **Side effects:** 无。
- **Notes:** 两个数据源都会在芯片名之后附加频率与核心信息；应用把这些存放在 `CpuInfo` 的专用字段里，
  而不是型号字符串中。

### `bool isLikelyDeviceImage(String url)` <a id="islikelydeviceimage"></a>
- **Kind:** 顶层函数。
- **Source:** 第 416 行。
- **Purpose:** 判断图片 URL 是设备照片而不是广告。
- **Inputs:** `url` —— 绝对或协议相对的图片 URL。
- **Returns:** 当 URL 看起来是真实设备图像时返回 `true`。
- **Side effects:** 无。
- **Algorithm:** 先排除已知的广告/推广/追踪特征串，再要求具备真实的图片扩展名。
- **Notes:** 排除规则有意优先于接受规则，因此以 `banner.png` 形式提供的广告仍会被过滤掉。

### `Map<String, String> parseNotebookcheckSpecs(String html)` <a id="parsenotebookcheckspecs"></a>
- **Kind:** 顶层函数。
- **Source:** 第 450 行。
- **Purpose:** 读取 Notebookcheck 设备页中「标签/值」形式的规格表。
- **Inputs:** `html` —— 详情页的完整标记。
- **Returns:** 规格标签到可见值的映射；没有任何匹配时为空。
- **Side effects:** 无。
- **Algorithm:** 按字面量 `<div class="specs">` 标签块切分。对每个分片，取到第一个 `</div>` 为止作为标签，
  再取从该处到下一个 `<div class="specs_element">` 之间的全部内容（上限 4000 字符），交给
  [`stripHtml`](#striphtml) 处理。同一标签以首次出现为准。
- **Usage:**
  ```dart
  final specs = parseNotebookcheckSpecs(html);
  final ram = parseCapacity(specs['Memory']);
  ```
- **Notes:** 必须同时兼容两种标记形态。多数值位于 `div.specs_details` 内，而其中又**嵌套**了
  `div.specs_indicator`，因此匹配闭合的 `</div></div>` 会把 `Memory` 和 `Storage` 从中间截断，丢失
  indicator 之后的全部内容。`Released` 则完全没有外层容器，值直接跟在标签之后。在两个标签之间整体去除标签
  即可同时覆盖这两种情况。返回空映射意味着页面标记发生了变化，调用方必须如实报告，而不能当作「一台没有规格的
  设备」。

### `Map<String, String> parsePhonedbSpecs(String html)` <a id="parsephonedbspecs"></a>
- **Kind:** 顶层函数。
- **Source:** 第 482 行。
- **Purpose:** 读取 phonedb 设备页中「标签/值」形式的参数表行。
- **Inputs:** `html` —— 详情页的完整标记。
- **Returns:** 参数标签到可见值的映射；没有任何匹配时为空。
- **Side effects:** 无。
- **Algorithm:** 用惰性的 dot-all 模式匹配 `<td><strong>label</strong>…</td><td>value</td>`，并对两侧都做
  去标签处理。
- **Notes:** 同一标签以首次出现为准，因为页面会在其对比表尾部重复某些标签。与 Notebookcheck 的读取函数一样，
  返回空映射意味着页面标记发生了变化。

## Related

- [`device_search_service.md`](device_search_service.md) —— 唯一的调用方；负责 HTTP、数据源分发与结果状态上报。
- [`preset_service.md`](preset_service.md) —— 在线搜索的离线对应物。
- [在线搜索与预设](../../../../features/online-search-and-presets.md)
