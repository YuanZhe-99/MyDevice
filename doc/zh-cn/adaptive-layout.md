# 自适应布局

这是全应用范围的规则，决定**布局何时可以分栏**——在折叠屏内屏、平板或桌面窗口上拆成窗格（pane）或多列——以及一旦允许，**能容纳多少列**。第二条更窄的规则决定**导航放在哪里**。它们全部位于 [`lib/shared/utils/adaptive_layout.dart`](functions/shared/utils/adaptive_layout.md)，该模块刻意只 import `dart:core`，因此每个决策无需组件（widget）树即可直接单元测试。

这些约定是 MyAnime 在 1.5.2 – 1.5.6 发布中推导出来的，此处原样采用，让同一台设备在本系列每个应用中得到相同答案。数字离开推理毫无价值，所以推理写在这里。

在 1.5.0 之前 MyDevice 没有任何规则：每一页都是固定单列，仅有的三处宽度决策是散落在三个文件里的内联字面量（`>= 520`、`< 680` 和一个 150 dp 的指标网格）。**组件文件里出现数字宽度比较就是 bug**——数字属于这里，页面只调用具名谓词。

## 何时分栏

以下**三个条件全部**成立时分栏：

| 常量 | 值 | 含义 |
|---|---|---|
| `splitMinWidth` | `600.0` | Material 的 *medium* 宽度类别；Android 的 `sw600dp`。 |
| `splitMinHeight` | `480.0` | compact/medium 高度边界。 |
| `splitMinAspect` | `0.82` | 宽除以高。 |

```dart
bool canSplitLayout(double width, double height) {
  if (width < splitMinWidth) return false;
  if (height < splitMinHeight) return false;
  if (height <= 0) return false;
  return width / height >= splitMinAspect;
}
```

每个条件都有其存在理由，且没有任何一个单独足够。

### 宽高比测试是承重的那一个

**这就是它不是普通宽度断点的原因，而 Galaxy Z Fold 8 是它必须存在的原因。**
Fold 8 展开是 4:3 的*横向*面板（2448 × 1848 px），竖持时为 3:4——**相对其高度而言，比它取代的近方形 Fold 7 更窄**，尽管更新，而 Fold 8 Ultra 走了相反方向。一代设备展开后跨越约 672 到 954 逻辑像素，同一台设备在同一宽度需要两个不同答案。

像素数是权威；逻辑像素取决于密度桶和三星用户可调的**显示尺寸**设置，因此给出合理区间。

| 设备 | 内屏，px | 竖屏 W:H | 竖屏 W，dp | 竖屏 | 横屏 |
|---|---|---|---|---|---|
| Galaxy Z Fold 5 | 1812 × 2176 | 0.83 | 659–690 | 分栏 | 分栏 |
| Galaxy Z Fold 6 | 1856 × 2160 | 0.86 | 675–707 | 分栏 | 分栏 |
| Galaxy Z Fold 7 | 1968 × 2184 | 0.90 | 716–750 | 分栏 | 分栏 |
| **Galaxy Z Fold 8** | **2448 × 1848（4:3 横向）** | **0.755** | **672–704** | **单列** | **分栏** |
| Galaxy Z Fold 8 Ultra | 2256 × 2504 | 0.90 | 820–859 | 分栏 | 分栏 |
| Pixel 9 / 10 Pro Fold | 2076 × 2152 | 0.96 | 755–791 | 分栏 | 分栏 |

`0.82` 位于 Fold 8 竖屏 `0.755` 与 Fold 7 / Fold 8 Ultra 竖屏 `0.90` 之间空隙的中部附近，两侧各约 9% 余量。除非有设备落入该空隙，否则保持此常量不变；改动它是全应用行为变化。

### 宽度下限

每块展开面板即便在密度区间较密一端也至少超出 600 dp 59 dp，而每块折叠外屏都远低于它：Z Fold 7 / 8 Ultra 约 360 dp，Z Fold 8 约 356–416 dp，Pixel 10 Pro Fold 约 411 dp。该下限不指名设备就把「展开」和「外屏」分开。

### 高度下限

仅有宽高比测试会放行*宽而矮*的视口。没有该下限，横持的折叠态 Z Fold 8 外屏（约 657 × 416 dp）和横持的普通手机（约 915 × 412 dp）都会分成两个局促窗格。Google 独立给出了相同建议：手机或打开的翻盖机横持时窗口宽度通常是 medium 而高度是 compact，双栏布局在那里不实用。

### 值得知道的后果

规则关乎**形状而非设备类别**，因此 4:3 平板竖屏（768 × 1024 → 0.75）和 16:10 平板竖屏（0.625）同样保持单列，与 Fold 8 竖屏完全一样。两者横屏都分栏。若有人报告「我的平板竖屏不分栏」，那正是规则在起作用。

## 多少列

一旦允许分栏，列数来自内容实际获得的宽度和每列最小宽度：

```dart
int columnCapacity(
  double contentWidth, {
  required double minItemWidth,
  double gap = listTileGap,          // 12
  int maxColumns = listMaxColumns,   // 4
}) => ((contentWidth + gap) / (minItemWidth + gap))
        .floor()
        .clamp(1, maxColumns);
```

这是 Google 为信息流布局推荐的自适应最小宽度做法——在空间允许下放入尽可能多的、不小于最小宽度的列——而非按断点硬编码列数。分子里加一个间距，让算式只为列*之间*的间距付费，而非每列之后都付一次。每个调用方带来自己内容所需的最小值，常量的文档注释写明数字来源：

| 调用方 | 最小值 | 间距 | 上限 | 数字来源 |
|---|---|---|---|---|
| 服务概览指标卡（`serviceMetricColumns`） | `150` | 12 | 4 | 16 dp 内边距里一个图标、一个 headline 尺寸计数和两行标签。与被替换的内联规则算术完全等价，所以没有任何视口的列数改变。 |
| 财务摘要指标（`financeSummaryColumns`） | `160` | 16 | 3，**下限 2** | `titleLarge` 金额在标签之前约占 120 dp。下限防止卡片在外屏上退化成一行一个指标——它从未如此。第三列在 512 dp 出现，而旧内联规则要求 520——这是间距算式只为两个间距付费而非三个。 |

四个**列表**也取多列，先过分栏规则、再看容量。每种 tile 带自己的最小值：

| 列表 | 最小值 | 从内容宽度扣除的内边距 | 数字来源 |
|---|---|---|---|
| 设备（`deviceTileMinWidth`） | `320` | 32（卡片两侧各 16 dp 外边距） | 带内边距行里的 `Card`：tile 内边距 32、头像 40、间距 16、尾部 chevron 24（或菜单 48）加 16——约 152 的铺装。168 保住二十字名称一行、“类别 · 品牌 · 日均成本”两行副标题。 |
| 网络（`networkTileMinWidth`） | `300` | 16（列表 8 dp 内边距） | 同样铺装，但副标题是单行“类型 · 子网”，约二十五字 ~175 dp，所以更窄也放得下。 |
| 数据集（`dataSetTileMinWidth`） | `320` | 16 | 裸 `ListTile`：32 + 34 dp emoji + 16 + 24 + 16 = 122。副标题最多四行存储信息不能折行，否则第四行被省略号吞掉一台设备。 |
| 服务——设备 / 链路 / 端口视图（`serviceCardMinWidth`） | `320` | 16 | 链路卡三行摘要；设备卡与端口卡内嵌带 48 dp 尾部菜单的 tile。概览是异构滚动流（指标网格、拓扑卡、警告、链路组、tile），保持单列。 |

`listColumnCount` 把门控与容量合并：`canSplitLayout` 为假时一列，否则用户偏好为 `listColumnsAuto` 时取容量，否则取钳到容量的偏好。钳制而非拒绝，让桌面上设好的偏好带到折叠手机上仍能存活、展开时再回来。每个列表把自己的偏好存在 `storage_config.json`（`deviceListColumns`、`networkListColumns`、`dataSetListColumns`、`serviceListColumns`），设备本地，因为窗口尺寸是设备属性而非账号属性；默认值从文件删除而非写成零。应用栏的列数控件在容量为一时隐藏——而非禁用——所以手机或外屏永远不会显示一个什么也做不了的控件；重排模式与服务概览也隐藏它。

内容宽度是 `shellContentWidth(screenWidth)` 减表中的内边距，因为这五页是壳内的页面——见[下文](#门控量屏幕容量量内容框)。

| 视口 | 分栏 | 设备（−32，320） | 网络（−16，300） | 数据集 / 服务（−16，320） |
|---|---|---|---|---|
| Z Fold 8 横屏 933 × 704 | 是 | 2 | 2 | 2 |
| Z Fold 8 竖屏 704 × 933 | 否 | 1 | 1 | 1 |
| Z Fold 8 Ultra 954 × 859 / 859 × 954 | 是 | 2 / 2 | 2 / 2 | 2 / 2 |
| Pixel 10 Pro Fold 820 × 791 / 791 × 820 | 是 | 2 / 2 | 2 / 2 | 2 / 2 |
| Z Fold 7 832 × 750 / 750 × 832 | 是 | 2 / **1** | 2 / 2 | 2 / 2 |
| Z Fold 6 675 × 786 · Z Fold 5 659 × 791 | 是 | 1 / 1 | 1 / 1 | 1 / 1 |
| 平板 1024 × 768 | 是 | 2 | **3** | 2 |
| 平板 768 × 1024 | 否 | 1 | 1 | 1 |
| 手机横屏 915 × 412 | 否 | 1 | 1 | 1 |
| 桌面 1600 × 900 | 是 | 4 | 4 | 4 |

两个格子值得一句话。Z Fold 7 竖屏给设备列表 750 − 81 − 32 = 637，比两个 320 dp tile 加间距所需的 652 少三，所以保持一列，而旁边的数据集列表（653）得到两列——这是规则在边界处起作用，不是 bug。平板横屏给网络列表三列，因为其 tile 最小值是 300：1024 − 81 − 16 = 927 超过 3 × 300 + 2 × 12 = 924。

tile **先从左到右、再从上到下**排列，每行是一个由 `Expanded` 格子组成的 `Row` 而非 `GridView`，所以设备列表保住 `ListView.builder` 的虚拟化，服务视图的卡片仍是同一滚动视图的 children。最后一行不满时用空格子补齐，让剩余 tile 保持宽度。见 [`functions/shared/widgets/adaptive_tile_grid.md`](functions/shared/widgets/adaptive_tile_grid.md)。

**手势随列数变化。** 一列时设备与数据集 tile 保留滑动操作（右滑编辑、左滑删除；数据集仅删除）。多列时在一个窄格子内水平拖动含义不明，所以去掉 `Dismissible`，尾部 chevron 变成携带同样操作的菜单——服务 tile 早已使用的那种尾部菜单。两页的删除都没有其他入口，所以菜单是保住删除的关键。重排模式始终渲染单列，因为 `ReorderableListView` 要求一项一个子组件。

## 导航放在哪里

**第二条规则，且刻意更窄**：

```dart
bool useNavigationRail(double screenWidth) => screenWidth >= navRailMinWidth; // 600.0
```

超过它，壳在侧边渲染 `NavigationRail`；低于它，则是一直以来的底部 `NavigationBar`。两者都由 [`shell_scaffold.dart`](functions/shared/widgets/shell_scaffold.md) 里的同一份目的地列表构建，因此不可能漂移。导航栏（NavigationRail）把目的地居中（`groupAlignment: 0`）而非采用默认的顶部对齐：顶部对齐是为了坐在前导菜单按钮或 FAB 之下，而这里两者都没有，五个目的地钉在 704 dp 高的栏顶部会让整个下半部空着。导航栏放在滚动视图里，紧凑高度的窗口不会让它溢出。

**这是刻意的仅宽度判断，绝不能经由 `canSplitLayout`。** 导航栏不是分栏。它用宽度——只要测试通过就充裕——换取高度——并不充裕。它帮助最大的场景恰恰是分栏规则拒绝的那个：横持的普通手机 915 × 412，底栏花掉 19% 的高度做导航，而 915 逻辑像素的宽度闲置。分栏规则同样拒绝的 Z Fold 8 竖屏，出于同一理由得到导航栏。

一个后果贯穿应用其余部分：只要导航栏显示，`shellContentWidth(screenWidth)` 就减去 `navRailWidth`（81 = 80 dp 导航栏加 1 dp 分割线），壳内每个容量都从它测量，绝不用原始屏幕宽度：四个列表的列数，以及服务概览的拓扑卡片动作行。

**刻意未从 MyAnime 移植：底栏避让。** MyAnime 的滚动页为底栏预留 80 dp，有导航栏时降到 16。MyDevice 不需要。它的壳 `Scaffold` 持有底栏，每个标签页自带 `Scaffold` 装应用栏和浮动操作按钮，页面 body 从一开始就不在底栏之下。设备列表预留的 `bottom: 80` 是给它三个叠放浮动操作按钮的避让，导航栏不会移除它们——不要通过导航规则去「修」它。

刻意不做：1240 dp 以上的 `NavigationDrawer`。导航栏在此直到 extra-large 都正确，第三种导航模式不值其成本。

## 门控量屏幕，容量量内容框

`canSplitLayout` 和 `useNavigationRail` 读 `MediaQuery.sizeOf(context)`——整个屏幕。容量和窗格宽度读内容实际获得的：`shellContentWidth(screenWidth)` 减页面自身内边距，或 `LayoutBuilder` 的 `constraints.maxWidth`。这种不对称是刻意的，出于两个独立理由：

- 对 `Scaffold` body 测量分栏决策会从高度中减掉应用栏并抬高比值，把 Z Fold 8 竖屏读成 `0.80` 而非 `0.755`，在阈值下几乎不留余量。
- 门控问的是窗口的*形状*，导航栏不改变它。容量问的是剩下多少空间，导航栏很大程度上改变它。

## 推入页测量原始窗口

只有五个标签页住在 `ShellRoute` 里。其他每一页——设备与网络详情、每个编辑页、财务总览、地图、设置子页——都用 `Navigator.of(context, rootNavigator: true)` 推到**根**导航器上，在壳之上。它旁边没有导航栏、底下没有底栏，所以 `constraints.maxWidth` *就是*整个宽度。把这类页面的宽度经过 `shellContentWidth` 会悄悄丢掉 81 dp。财务总览的摘要卡是第一个带规则的此类页面；它只读自己的 `LayoutBuilder`。

## 对话框从窗口推导高度

两个在线搜索对话框（`device_search_dialog.dart`、`chip_search_dialog.dart`）曾固定为 560 和 480 dp 高，无宽度上限，水平内缩 12 dp。在平板上它们拉到窗口全宽；在横持手机（915 × 412）或横持折叠态 Z Fold 8 外屏（657 × 416）上比窗口还高。现在它们取 `dialogBodyHeight(availableHeight, preferred: 560 | 480)`，上下各留 `dialogInsetVertical`（40），不超过首选高度，也不低于 `dialogMinBodyHeight`（240——一个头部、一个查询框和两行结果）。`availableHeight` 是窗口减软键盘内缩。宽度封顶在 `dialogMaxWidth`（560，Material 对话框最大值）；服务页的快捷访问路由对话框用同一常量。

| 窗口 | 设备搜索 | 芯片搜索 |
|---|---|---|
| Z Fold 8 横屏，704 高 | 560（不变） | 480（不变） |
| 手机横屏，412 高 | 332 | 332 |
| Z Fold 8 外屏横屏，416 高 | 336 | 336 |
| 低于 320 高 | 240（下限） | 240（下限） |

在 412 dp 窗口上叠加软键盘时连下限都会溢出；接受此限制，而不把对话框缩到不可用。

## 折叠与展开

`android/app/src/main/AndroidManifest.xml` 在 activity 的 `configChanges` 中声明了 `screenLayout|screenSize|smallestScreenSize|density`（Flutter 模板原本就有），因此折叠或展开会调整窗口大小**而不重启 activity**。所有读 `MediaQuery.sizeOf` 的地方在下一帧重新求值，这就是「设备展开时自动切换」所需的全部——无生命周期工作，无需保存恢复状态。

## 这些规则用在哪里

| 调用点 | 规则 | 备注 |
|---|---|---|
| `shell_scaffold.dart` | `useNavigationRail` | 仅宽度；见上文。 |
| `device_list_page.dart`、`network_list_page.dart`、`dataset_list_page.dart` | `listColumnCount` | 分栏规则，再按各 tile 最小值算容量，再钳制已存偏好。内容宽度是 `shellContentWidth` 减页面内边距。 |
| `service_list_page.dart`（设备 / 链路 / 端口视图） | `listColumnCount` | 同上，以 `serviceCardMinWidth` 计；一个偏好服务三个视图，概览保持单列。 |
| `service_list_page.dart`（概览指标网格） | `serviceMetricColumns` | 仅宽度，来自概览列表的 `LayoutBuilder`。 |
| `service_list_page.dart`（拓扑卡片头部） | `useTopologyActionsRow` | 仅宽度。值就是卡片在 1.5.0 之前内联使用的 680；卡片现在拿到的是扣除导航栏后的宽度，所以 Pixel 10 Pro Fold 竖屏把动作堆叠到标题下，而以前是并排。 |
| `service_list_page.dart`（快捷访问路由对话框） | `dialogMaxWidth` | 常量，不是规则。 |
| `device_finance_overview_page.dart`（摘要卡） | `financeSummaryColumns` | 仅宽度，下限 2。推到壳外：测量自己的 `LayoutBuilder`。 |
| `device_search_dialog.dart`、`chip_search_dialog.dart` | `dialogBodyHeight`、`dialogMaxWidth` | 高度来自窗口减键盘。 |
| `_ServiceTopologyPage` / `_ServiceTopologyView` | 无需 | 已是 `LayoutBuilder` 驱动的全幅 `InteractiveViewer`；布局缓存以视口宽度为键。 |
| `device_map_page.dart`、`map_picker_page.dart` | 无需 | 全幅地图填满给它的任何空间；选点器的搜索行已是按钮旁的 `Expanded` 输入框。 |

其余每一页仍是固定单列，已排期：详情页与财务总览图表行在 1.5.2，设备编辑页在 1.5.3，其余编辑页与底部表单在 1.5.4，设置家族在 1.5.5。在 1.5.4 之前 `lib/` 里还剩一个硬编码数量：`device_edit_page.dart` 里 emoji 选择器的 `crossAxisCount: 8`，是数量而非比较，列在此处让「没有内联宽度决策」的说法保持诚实。

## 与 Google 指南的分歧

Google 的自适应布局指南说窗口尺寸类别「明确不由设备屏幕尺寸决定」且「不用于 *isTablet* 类逻辑」，并指导应用按可用宽度而非宽高比决策。本应用**刻意在一点上分歧**：宽高比测试。这不是疏忽。仅凭宽度无法让 Fold 8 在两个方向得到两个不同答案，而那种行为——横屏分栏、竖屏原单列——正是该规则存在要满足的需求。

其余全部与 Google 一致：宽度和高度下限是它的断点，列容量是它的信息流指南，medium 宽度及以上的导航栏是它的原话推荐。

## 测试

- `test/adaptive_layout_test.dart` — 门控、导航栏规则、内容宽度、容量与行数算术、四个列表的列数与偏好钳制、两条概览规则、财务下限和对话框高度，钉在上表每台设备的真实逻辑像素几何上，注释里写设备名，回归时报出它会弄坏的设备。它还断言 `serviceMetricColumns` 与被替换的内联算术仍一致。
- `test/list_columns_prefs_test.dart` — 四个列数偏好各自独立往返，默认值不写入文件而是缺席，非法值读作自动。
- `test/list_columns_ui_test.dart`、`test/list_columns_more_ui_test.dart`、`test/service_columns_ui_test.dart` — 针对种子存储目录，在 Z Fold 8 横竖、Pixel 9 横竖和平板上渲染设备、网络、数据集与服务列表：列数、隐藏的控件、存下的选择、钳制、滑动或菜单的切换，以及分组页头。
- `test/shell_nav_ui_test.dart` — 在 Pixel 9 横竖、Z Fold 8 横竖和桌面窗口渲染壳：出现哪种导航、导航栏携带同样五个目的地、点击可导航。
- `test/dialog_layout_ui_test.dart` — 两个搜索对话框在五种窗口尺寸打开，断言对话框不超出窗口且遵守宽度上限。

`flutter_test` 把默认字体的每个字形渲染成全角方块，把拉丁标签宽度夸大到真实值的约 2.5 倍。因此这里的组件测试以简体中文（`Locale('zh')`）运行，中文字形本来就是方块，测到的是真实生产布局而非字体假象。保持如此；把语言区域「修」回英文的测试会报出生产中不存在的溢出。
