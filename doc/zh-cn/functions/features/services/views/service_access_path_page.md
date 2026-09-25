# lib/features/services/views/service_access_path_page.dart

[服务与拓扑](../../../../features/services-topology.md#adding-an-access-path) 描述的引导式**添加访问路径**页面。它是 [service_access_patterns.md](../services/service_access_patterns.md) 中 `ServiceAccessDraft` 之上的薄表单：用户先选择源服务和端点，再选择一种访问模式（直连、反向代理、Cloudflare Tunnel、Pangolin、FRP、路由器端口转发、Tailscale Funnel），然后填写该模式所需的少量细节，页面经 `ServiceStorage.addOrUpdateRoute` 保存恰好一个 `ServiceRoute`。它在 1.5.6 中取代了单跳的快速访问对话框。

缺少的部分以内联方式创建并**立即持久化**：「添加端点」立即把端点保存到其服务上（经共享的 [`showServiceEndpointDialog`](service_endpoint_dialog.md)），「新建代理服务…」 / 「新建中继服务…」带模板压入 [`ServiceEditPage`](service_edit_page.md)，并选中它在 `ServiceEditOutcome` 中弹出的服务。之后取消访问路径时，这些内容会保留下来；它们本身就是有效的清单条目。实时预览卡片显示链（`serviceRouteChainPreview`）、车道和访问级别，以及建议性警告——这些警告从不阻塞保存。「高级编辑器」和「自定义 / 多跳」卡片把草稿移交给 [`ServiceRouteEditPage`](service_route_edit_page.md)。

[service_list_page.md](service_list_page.md) 的每个「添加访问方式」入口——应用栏、总览、拓扑卡片、服务的路由组、服务块菜单和拓扑节点面板——以及高级编辑器的「引导式编辑器」操作，都会在根导航器上压入本页。保存或删除后它弹出 `true`，用户直接返回时什么也不弹出。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ServiceAccessPathPage` 构造函数 | 构造函数 | B | 为新路径（`draft`）或保存的路由（`route`）创建页面。 |
| `createState` | 方法（`ServiceAccessPathPage`） | B | 创建页面状态。 |
| `_editing` | getter（`_ServiceAccessPathPageState`） | B | 是否正在编辑保存的路由。 |
| `initState` | 方法（`_ServiceAccessPathPageState`） | B | 创建四个文本控制器并启动 `_load(initial: true)`。 |
| `dispose` | 方法（`_ServiceAccessPathPageState`） | B | 释放控制器。 |
| [`_load`](#load) | 方法（`_ServiceAccessPathPageState`） | A | 加载清单；首次加载时解析起始草稿。 |
| `_syncControllers` | 方法（`_ServiceAccessPathPageState`） | B | 把草稿的文本字段复制进控制器。 |
| `_update` | 方法（`_ServiceAccessPathPageState`） | B | 替换草稿并重建。 |
| `_serviceById` | 方法（`_ServiceAccessPathPageState`） | B | 按 id 查找服务。 |
| `_deviceById` | 方法（`_ServiceAccessPathPageState`） | B | 按 id 查找设备。 |
| [`_withDefaultSourceEndpoint`](#withdefaultsourceendpoint) | 方法（`_ServiceAccessPathPageState`） | A | 选择显而易见时预选源端点。 |
| [`_pickSource`](#picksource) | 方法（`_ServiceAccessPathPageState`） | A | 在面板中选择源服务。 |
| [`_selectPattern`](#selectpattern) | 方法（`_ServiceAccessPathPageState`） | A | 切换模式，并应用默认值和预选。 |
| `_withRelay` | 方法（`_ServiceAccessPathPageState`） | B | 让草稿指向某个中继；FRP 取其默认入口。 |
| `_withSingleProxyCandidate` | 方法（`_ServiceAccessPathPageState`） | B | 恰好存在一个类代理服务时预选代理。 |
| `_withProxy` | 方法（`_ServiceAccessPathPageState`） | B | 让草稿指向某个代理及其默认端点；方法恢复为「推导」。 |
| `_prefillDirectTarget` | 方法（`_ServiceAccessPathPageState`） | B | 用直连访问建议填充空的目标字段，并把它记为 `_autoTarget`。 |
| `_prefillPublicHost` | 方法（`_ServiceAccessPathPageState`） | B | 用中继设备唯一的网络分配填充空的 FRP 公网主机。 |
| `_directSuggestion` | 方法（`_ServiceAccessPathPageState`） | B | 当前源和端点的 `suggestedDirectTarget`。 |
| `_pickProxy` | 方法（`_ServiceAccessPathPageState`） | B | 在面板中选择代理，类代理服务作为推荐排在最前。 |
| `_pickRelay` | 方法（`_ServiceAccessPathPageState`） | B | 在面板中选择中继，该模式的候选作为推荐排在最前。 |
| [`_createService`](#createservice) | 方法（`_ServiceAccessPathPageState`） | A | 从模板以内联方式创建代理或中继服务并选中它。 |
| [`_addEndpointTo`](#addendpointto) | 方法（`_ServiceAccessPathPageState`） | A | 立即把新端点保存到服务上并选中它。 |
| [`_save`](#save) | 方法（`_ServiceAccessPathPageState`） | A | 保存那一条路由，或显示阻塞问题。 |
| `_delete` | 方法（`_ServiceAccessPathPageState`） | B | 确认并删除被编辑的路由；弹出 `true`。 |
| [`_openAdvancedEditor`](#openadvancededitor) | 方法（`_ServiceAccessPathPageState`） | A | 把草稿移交给高级路由编辑器。 |
| `_handedOver` | getter（`_ServiceAccessPathPageState`） | B | 路由是否根本无法读入草稿。 |
| `build` | 方法（组件构建，`_ServiceAccessPathPageState`） | B | 围绕 `_buildBody` 的脚手架，带标题、删除（编辑模式）和保存操作。 |
| [`_buildBody`](#buildbody) | 方法（组件辅助） | A | 单列，或在分栏窗口上为双栏。 |
| `_sectionTitle` | 方法（组件辅助） | B | 带编号的小节标题。 |
| `_buildSourceSection` | 方法（组件辅助） | B | 源服务块，以及带「添加端点」的端点 chip。 |
| `_buildPatternSection` | 方法（组件辅助） | B | 按 `accessPatternColumns` 排成等高行的模式卡片，外加自定义卡片。 |
| [`_buildDetailsSection`](#builddetailssection) | 方法（组件辅助） | A | 所选模式需要的字段。 |
| [`_buildPreviewCard`](#buildpreviewcard) | 方法（组件辅助） | A | 链、车道、访问级别和建议性警告。 |
| [`_draftReferenceWarnings`](#draftreferencewarnings) | 方法（`_ServiceAccessPathPageState`） | A | 与草稿路由相关的引用警告。 |
| `_buildActions` | 方法（组件辅助） | B | 取消、高级编辑器、保存。 |
| `_showServicePicker` | 方法（`_ServiceAccessPathPageState`） | B | 打开 `_ServicePickerSheet` 并返回选中的服务。 |
| `serviceAccessPatternIcon` | 顶层函数 | B | 模式卡片的图标，与路由方法图标一致。 |
| `serviceAccessLaneColor` | 顶层函数 | B | 拓扑的车道颜色（本地为 tertiary、VPN 为 secondary、公网为 primary）。 |
| `_splitTargets` | 顶层函数 | B | 按行或逗号拆分目标字段。 |
| `_ServiceTile` 构造函数 | 构造函数 | B | 显示所选服务或提示选择服务的块。 |
| `build` | 方法（组件构建，`_ServiceTile`） | B | 带图标、名称、设备和端口的卡片；错误文本显示在下方。 |
| `_EndpointChips` 构造函数 | 构造函数 | B | 端点选择 chip 加一个添加 chip。 |
| `build` | 方法（组件构建，`_EndpointChips`） | B | 以 `<prefix>-<endpoint id>` 为键的 chip，可选的「无」chip。 |
| `_PatternCard` 构造函数 | 构造函数 | B | 一张可选择的模式卡片。 |
| `build` | 方法（组件构建，`_PatternCard`） | B | 图标行、标题、描述；选中状态带边框、填充、勾选标记和语义。 |
| `_ServicePickerSheet` 构造函数 | 构造函数 | B | 可搜索的服务选择器面板。 |
| `createState` | 方法（`_ServicePickerSheet`） | B | 创建面板状态。 |
| `dispose` | 方法（`_ServicePickerSheetState`） | B | 释放搜索控制器。 |
| `_deviceName` | 方法（`_ServicePickerSheetState`） | B | 服务的设备名。 |
| `_matches` | 方法（`_ServicePickerSheetState`） | B | 按服务名、设备名和端口做搜索匹配。 |
| [`build`](#pickerbuild) | 方法（组件构建，`_ServicePickerSheetState`） | A | 推荐的服务在前，其余按设备分组。 |
| `_header` | 方法（组件辅助） | B | 分组标题。 |
| `_tile` | 方法（组件辅助） | B | 一行服务，以 `access-pick-<id>` 为键。 |

## 文档

### `Future<void> _load({bool initial = false})` <a id="load"></a>
- **种类：** `_ServiceAccessPathPageState` 的方法
- **来源：** `lib/features/services/views/service_access_path_page.dart`（第 120 行）
- **用途：** 加载服务、路由、设备、网络和网络分配；首次加载时解析页面起始所用的草稿。
- **输入：** `initial` — 只有来自 `initState` 的调用为 true。
- **返回：** `Future<void>`。
- **副作用：** 读取 `ServiceStorage`、`DeviceStorage` 和 `NetworkStorage`；更新状态。
- **算法：**
  1. 加载三个存储并替换清单列表。
  2. 首次加载时：用 `ServiceAccessDraft.fromRoute` 读取 `widget.route`；否则使用 `widget.draft`，再否则使用空草稿。丢弃已不存在的源，预选显而易见的源端点，并把草稿复制进文本字段。读回的路由把可达范围标记为用户自己的选择，因此切换模式不会重置它。
  3. 给定了路由但无法读入草稿时，在该帧之后打开高级编辑器（`_openAdvancedEditor`）；关闭它也会关闭本页。
  4. 否则，在新路径的首次加载时预填直连访问建议（`_prefillDirectTarget`）——这样，从服务的路由组或服务块菜单带着源进来的草稿，打开时地址已经填好，与手动选择源时一样。
- **用法：** `initState`，以及每次内联创建之后，使新端点或新服务可供选择。
- **备注：** 之后的加载不改动草稿；它们只刷新草稿所指向的内容。

### `ServiceAccessDraft _withDefaultSourceEndpoint(ServiceAccessDraft draft)` <a id="withdefaultsourceendpoint"></a>
- **种类：** `_ServiceAccessPathPageState` 的方法
- **来源：** `lib/features/services/views/service_access_path_page.dart`（第 202 行）
- **用途：** 选择显而易见时预选源端点。
- **输入：** `draft`。**返回：** `ServiceAccessDraft`。**副作用：** 无。
- **算法：** 保留已有的选择。否则，恰好有一个端点的源取该端点，有主端点的源取主端点，没有端点的源保持没有端点。
- **用法：** `_load` 和 `_pickSource`。
- **备注：** 有多个端点且没有主端点时由用户选择。

### `Future<void> _pickSource()` <a id="picksource"></a>
- **种类：** `_ServiceAccessPathPageState` 的方法
- **来源：** `lib/features/services/views/service_access_path_page.dart`（第 220 行）
- **用途：** 让用户选择源服务。
- **输入：** 无。**返回：** `Future<void>`。
- **副作用：** 打开选择器面板；更新草稿；可能预填直连目标。
- **算法：** 从所有服务中选择；清除端点并预选显而易见的那个；与新源相同的代理或中继会被清除，因为服务不能把流量转给自己。
- **用法：** 源服务块的 `onTap`。
- **备注：** 无。

### `void _selectPattern(ServiceAccessPattern pattern)` <a id="selectpattern"></a>
- **种类：** `_ServiceAccessPathPageState` 的方法
- **来源：** `lib/features/services/views/service_access_path_page.dart`（第 259 行）
- **用途：** 把草稿切换到另一种访问模式。
- **输入：** `pattern`。**返回：** `void`。**副作用：** 更新草稿和预填字段。
- **算法：**
  1. 切换模式并丢弃中继（它是为另一种模式选择的）；除非新模式是路由器端口转发，否则也丢弃路由器。
  2. 除非用户已选择过可达范围，否则应用 `pattern.defaultReachability`（直连 ⇒ 局域网，其余 ⇒ 公网）。
  3. 离开直连模式时，如果目标字段仍恰好是页面自己填入的建议（`_autoTarget`），就清空它；用户输入或编辑过的文本保留。无论哪种情况，记住的建议都会被遗忘。
  4. `serviceAccessRelaySuggestions` 恰好指出一个服务时预选中继；草稿需要代理且恰好存在一个类代理服务时预选代理。
  5. 在字段为空处预填直连目标和 FRP 公网主机。
- **用法：** 每张模式卡片的 `onTap`。
- **备注：** 代理前缀标志在切换中保留，因此切换回来时会恢复。没有第 3 步的话，为直连访问建议的局域网地址会被当作用户接下来选择的 FRP 或隧道路径的「域名」保存。

### `Future<void> _createService({required String templateId, String? deviceId, required bool asProxy})` <a id="createservice"></a>
- **种类：** `_ServiceAccessPathPageState` 的方法
- **来源：** `lib/features/services/views/service_access_path_page.dart`（第 458 行）
- **用途：** 以内联方式创建代理或中继服务并选中它。
- **输入：** `templateId` — 代理为 `caddy`，否则为该模式的中继模板；`deviceId` — 新服务的起始设备（源所在设备，FRP 和 Pangolin 则为第一台 VPS）；`asProxy`。
- **返回：** `Future<void>`。
- **副作用：** 压入 `ServiceEditPage(deviceId:, template:)`，由它保存服务；重载；更新草稿。
- **算法：** 等待编辑页的 `ServiceEditOutcome`；有 `saved` 时重载，并把新服务连同其默认端点选为代理或中继。
- **用法：** 「新建代理服务…」和「新建中继服务…」。
- **备注：** 用户仍可在编辑页上更改模板的设备、名称和端口。

### `Future<void> _addEndpointTo(ServiceNode service, ServiceAccessDraft Function(ServiceAccessDraft, ServiceEndpoint) onAdded)` <a id="addendpointto"></a>
- **种类：** `_ServiceAccessPathPageState` 的方法
- **来源：** `lib/features/services/views/service_access_path_page.dart`（第 490 行）
- **用途：** 立即给服务添加端点并选中它。
- **输入：** `service`；`onAdded` — 返回选中了新端点的草稿。
- **返回：** `Future<void>`。
- **副作用：** 显示端点对话框；保存服务；重载；更新草稿。
- **算法：** 显示 `showServiceEndpointDialog`（服务没有端点时默认为主端点）；从存储重新读取服务，追加端点，用 `ServiceStorage.addOrUpdateService` 保存；重载并应用 `onAdded`。
- **用法：** 源、代理、中继和 FRP 入口各行的「添加端点」chip。
- **备注：** 保存前重新读取，可避免覆盖在别处做的编辑。

### `Future<void> _save()` <a id="save"></a>
- **种类：** `_ServiceAccessPathPageState` 的方法
- **来源：** `lib/features/services/views/service_access_path_page.dart`（第 516 行）
- **用途：** 把访问路径保存为一条路由并关闭页面。
- **输入：** 无。**返回：** `Future<void>`。
- **副作用：** 持久化路由并弹出 `true`；存在阻塞问题时改为显示这些问题和一条 snackbar。
- **算法：** `serviceAccessDraftIssues`；有任何问题时设置 `_showIssues`，使字段显示各自的错误，然后停止。否则 `ServiceStorage.addOrUpdateRoute(_draft.toRoute(...))` 并弹出。
- **用法：** 应用栏的保存操作和保存按钮。
- **备注：** 建议性警告从不阻塞保存。

### `Future<void> _openAdvancedEditor()` <a id="openadvancededitor"></a>
- **种类：** `_ServiceAccessPathPageState` 的方法
- **来源：** `lib/features/services/views/service_access_path_page.dart`（第 572 行）
- **用途：** 把当前草稿移交给高级路由编辑器。
- **输入：** 无。**返回：** `Future<void>`。
- **副作用：** 压入 `ServiceRouteEditPage`；编辑器保存或删除后弹出 `true`。
- **算法：** 从草稿构建路由；编辑模式下压入 `ServiceRouteEditPage(route: ...)`（保留 id），新路径则压入 `ServiceRouteEditPage(draft: ...)`；它弹出 `true` 时本页也弹出 `true`。仅为移交无法读取的路由而存在的页面随编辑器一同关闭。
- **用法：** 「高级编辑器」按钮和「自定义 / 多跳」卡片。
- **备注：** 编辑器压在本页之上而非替换本页，因此其结果仍会送达打开本页的一方。

### `Widget _buildBody(BuildContext context, AppLocalizations l10n)` <a id="buildbody"></a>
- **种类：** 方法（组件辅助）
- **来源：** `lib/features/services/views/service_access_path_page.dart`（第 640 行）
- **用途：** 把表单布局为单列或双栏。
- **输入：** `context`、`l10n`。**返回：** `Widget`。**副作用：** 无。
- **算法：** 没有 `useDetailTwoPane` 时，是一个 `ListView`（键 `access-single-pane`），依次包含源、模式和细节小节、预览卡片和操作。有它时，是一个 `Row`（键 `access-two-pane`）：宽 `editFormLeftPaneWidth` 的左窗格（pane）放各项选择——源和模式——右窗格放细节、预览和操作。两栏都滚动。
- **用法：** `build`。
- **备注：** 本页推到壳之上，因此宽度就是原始窗口。分栏把决策放在左边，把它们所需的内容放在旁边；若把整个表单放在左边，右窗格就只剩下预览。

### `List<Widget> _buildDetailsSection(BuildContext context, AppLocalizations l10n)` <a id="builddetailssection"></a>
- **种类：** 方法（组件辅助）
- **来源：** `lib/features/services/views/service_access_path_page.dart`（第 840 行）
- **用途：** 构建所选模式需要的字段。
- **输入：** `context`、`l10n`。**返回：** `List<Widget>`。**副作用：** 无。
- **算法：** 总有可达范围 chip（局域网 · VPN · 公网 · 公网（需登录））。然后按模式需要依次是：「先经过反向代理」开关；带端点 chip 和「新建代理服务…」的代理服务块；带端点 chip 的中继服务块（FRP 必填，其他模式可清除）——FRP 时为**入口** chip，默认取中继的主端点——以及「新建中继服务…」；路由器选择器（路由器在前）；公网主机和必填的公网端口。路由器选择器是设置了 `isExpanded` 的下拉框，设备名以省略号截断，因此长名称不会撑破狭窄的窗格。然后是目标字段（端口映射时标为域名）、直连访问建议 chip 和备注。尝试保存过一次之后，阻塞问题显示为字段错误。
- **用法：** `_buildBody`。
- **备注：** 测试驱动的每个组件（widget）都带有键（`access-proxy-switch`、`access-public-port`、`access-targets`、`access-ingress-<id>`、…）。

### `Widget _buildPreviewCard(BuildContext context, AppLocalizations l10n)` <a id="buildpreviewcard"></a>
- **种类：** 方法（组件辅助）
- **来源：** `lib/features/services/views/service_access_path_page.dart`（第 1167 行）
- **用途：** 显示草稿的链、车道、访问级别和建议性警告。
- **输入：** `context`、`l10n`。**返回：** `Widget`。**副作用：** 无。
- **算法：** 构建草稿路由；以 `serviceHopFallbackLabel` 作为回退显示 `serviceRouteChainPreview`，使既没有服务也没有自身标签的跳先按其本地化方法（「直连」、「路由器端口转发」）命名，然后才按其类型命名；一个车道颜色的圆点，带车道和访问级别标签；然后 `_draftReferenceWarnings` 和 `serviceAccessDraftWarnings` 的每条警告各占一行。
- **用法：** `_buildBody`。
- **备注：** 每次 build 都重算——清单很小，而预览必须跟上每次按键。

### `List<ServiceWarning> _draftReferenceWarnings(ServiceRoute route)` <a id="draftreferencewarnings"></a>
- **种类：** `_ServiceAccessPathPageState` 的方法
- **来源：** `lib/features/services/views/service_access_path_page.dart`（第 1247 行）
- **用途：** 找出与草稿路由相关的引用警告。
- **输入：** `route` — 作为路由的草稿。**返回：** `List<ServiceWarning>`。
- **副作用：** 无。
- **算法：** 在保存的路由上运行 `findServiceReferenceWarnings`，用草稿替换它所编辑的那条路由；保留指明草稿路由的警告，以及路由列表中包含它的重复目标警告；丢弃阻塞问题已覆盖的种类——缺少源、缺少跳服务、空路由，以及对目标必填的模式（反向代理和三种隧道）而言，没有 URL 的公网路由。
- **用法：** `_buildPreviewCard`。
- **备注：** 正是它让「最终 URL 重复」在保存前就显现出来；该警告仅为建议，与总览上完全一样。

### `Widget build(BuildContext context)` (`_ServicePickerSheetState`) <a id="pickerbuild"></a>
- **种类：** `_ServicePickerSheetState` 的方法（组件构建）
- **来源：** `lib/features/services/views/service_access_path_page.dart`（第 1711 行）
- **用途：** 渲染可搜索的服务选择器。
- **输入：** `context`。**返回：** 组件树。**副作用：** 无。
- **算法：** 按搜索文本（服务名、设备名、端口）过滤；先按设备、再按名称排序；推荐的服务先显示在自己的标题下，其余在后；没有推荐时其余按设备分组。点击某行会弹出其服务。
- **用法：** `_showServicePicker`。
- **备注：** 以 `sheetInitialSize(窗口高度, preferred: 0.82)` 打开，上限 `sheetMaxSize`，与服务模板选择器相同。
