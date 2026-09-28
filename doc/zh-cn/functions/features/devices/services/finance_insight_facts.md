# lib/features/devices/services/finance_insight_facts.dart

财务总览端侧 AI 洞察卡片背后的纯事实构建器，1.6.0 新增。`buildDeviceFinanceInsightFacts` 把 [财务总览](../views/device_finance_overview_page.md) 已持有的设备转为 [`InsightFacts`](../../ai/services/insight_prompts.md)：设备与生命周期计数、总持有成本与总日均成本、按分类的成本、服役中日均成本最高的设备、按计费周期拆分的周期性成本、已退役与已售出的设备及其转售总额，以及服役中最老的设备。总额使用与设备列表财务卡片相同的 `Device` getter（[`device.md`](../models/device.md#totalcost)），按 `now` 求值，金额以默认货币取整到整数单位。卡片本身是 [`AiInsightCard`](../../ai/widgets/ai_insight_card.md)，事实由 [`AiInsightStore`](../../ai/services/insight_service.md) 计算指纹。见 [端侧 AI — 每张卡片获得什么](../../../../on-device-ai.md#what-each-card-is-given)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `financeInsightMaxNames` | 顶层 `const int` | B | 一条事实行最多列出多少个具名设备（或分类）（3）。 |
| `financeInsightMaxCategories` | 顶层 `const int` | B | 按分类成本行最多列出多少个分类（5）。 |
| `deviceFinanceInsightSlots` | 顶层 `const List<InsightSlot>` | B | 卡片的四个槽位，完整事实与回退事实共用，使各小节对两者都适用。 |
| `_money` | 顶层函数（私有） | B | 把金额格式化为 `<整数单位> <货币>`。 |
| [`buildDeviceFinanceInsightFacts`](#builddevicefinanceinsightfacts) | 顶层函数 | A | 构建设备财务卡片的事实。 |

`grep -c 'Purpose:' lib/features/devices/services/finance_insight_facts.dart` 报告 2，与 `_money` 和 `buildDeviceFinanceInsightFacts` 匹配。

**对账：** 5 行对应 2 个 `Purpose:` 块。多出的三行是真实的顶层常量——`financeInsightMaxNames`、`financeInsightMaxCategories` 和 `deviceFinanceInsightSlots`——各自带普通 `///` 描述但没有 `Purpose:` 块。槽位依次为：`costSummary`（总体成本与日均成本概况）、`costAdvice`（一条关于设备支出的实用建议）、`recurringSummary`（总结周期性成本）和 `reviewDevice`（一个值得复查的设备或分类，例如可退役或出售）。

## 文档

### `InsightFacts? buildDeviceFinanceInsightFacts({required DateTime now, required List<Device> devices, required String defaultCurrency, bool includeNames = true})` <a id="builddevicefinanceinsightfacts"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/devices/services/finance_insight_facts.dart`（第 47 行）
- **用途：** 构建设备财务卡片的事实。
- **输入：** `now`——本地时间；`devices`——页面的设备；`defaultCurrency`——所有金额使用的货币代码；`includeNames`——为 false 时生成只列分类的更朴素回退（默认 true）。
- **返回：** `InsightFacts?`，带 `module: deviceFinance`、四个 `deviceFinanceInsightSlots` 和引用词——没有任何设备带财务数据（`hasFinancialData`）时为 null。
- **副作用：** 无。
- **算法：**
  1. 保留带财务数据的设备；没有时返回 null。引用词以货币代码开始。局部函数 `label(d)` 在 `includeNames` 为 false 时返回分类名；否则返回截到 30 个码点的设备名称（[`clipTitle`](../../ai/services/insight_prompts.md#cliptitle)，并加入引用词），后接括号中的分类。
  2. `- Today:`、`- Currency:`、`- Devices:`（全部设备数、带成本数据的数量，以及服役中 / 已退役 / 已售出计数）、`- Total cost of ownership to date:`（`totalCost(asOf: now)` 之和）和 `- Total daily cost:`（`averageDailyCost(asOf: now)` 之和，两位小数，`<货币> per day`）。
  3. `- Cost by category:`——只计正的单设备总额，与资产分布图规则相同；分类按总额排序，至多 `financeInsightMaxCategories` 个，各带设备数。
  4. `- Highest daily-cost devices in service:`——日均成本为正的服役中设备，从高到低，至多 `financeInsightMaxNames` 个，每个为 `label` 加日均成本。
  5. `- Recurring costs on devices in service:`——`none`，或条目数与设备数、按数量排列的种类、按月计费与按年计费的总额（`price.convertedAmount`）以及合计年额（`monthly × 12 + yearly`）。
  6. `- Retired or sold:`——已退役数、已售出数、带转售价格的已售出设备数和转售总额（`soldPrice.convertedAmount`）。
  7. `- Oldest devices in service:`——带购买日期的服役中设备，从最老开始，至多 `financeInsightMaxNames` 个，每个为 `label`、`since <date>` 及其 `serviceDays`。
  8. 返回 `InsightFacts(module: InsightModule.deviceFinance, lines, slots: deviceFinanceInsightSlots, quotedTerms)`。
- **用法：**
  ```dart
  InsightFacts? facts({required bool names}) =>
      buildDeviceFinanceInsightFacts(
        now: now,
        devices: widget.devices,
        defaultCurrency: widget.defaultCurrency,
        includeNames: names,
      );
  ```
  （`lib/features/devices/views/device_finance_overview_page.dart`，`build`，第 123 行：完整事实为 `facts(names: true)`，`fallbackFacts` 为 `facts(names: false)`；由 `test/insight_facts_test.dart` 的 `device finance facts` 组覆盖。）
- **备注：** 只发送默认货币的汇总值、分类与种类的枚举名，以及（`includeNames` 时）设备名称。构建器从不读取序列号、备注、位置、品牌或型号、存储序列号或周期性成本的名称。货币代码总被列为引用词，因为指令要求模型用它书写金额；否则带几个金额的简短中文或日文句子会因代码的拉丁字母而通不过文字系统检查。取整到整数单位使指纹不随微小汇率变化而变；`now` 经 `- Today:` 和每个 `asOf: now` 总额进入事实，因此卡片会在午夜重新生成。
