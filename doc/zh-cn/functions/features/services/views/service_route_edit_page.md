# lib/features/services/views/service_route_edit_page.dart

实现 [服务与拓扑 — 添加访问路径](../../../../features/services-topology.md#adding-an-access-path) 描述的**高级多跳路由编辑器**的 Flutter 视图——与引导式访问路径页（[`service_access_path_page.md`](service_access_path_page.md)）不同，本页让用户从源服务端点到一个或多个最终目标构建/重排任意有序 `ServiceRouteHop` 列表。它接受引导式页面移交过来的未保存路由（`draft:`），通过其**拓扑车道**下拉框写入或清除路由的拓扑车道覆盖，并在表单符合某种访问模式时提供**引导式编辑器**。它经 `ServiceStorage.load`/`addOrUpdateRoute`/`deleteRoute`（`lib/features/services/services/service_storage.dart`）读写 `ServiceRoute` 记录，并把路由命名和多目标解析委托给 `service_analysis.dart` 辅助（`serviceRouteGeneratedName`、`serviceRouteAccessTargets`、`serviceRouteExtraJsonWithTargets`、`serviceRouteExtraJsonWithAccessLane`）——路由名内部生成并对用户隐藏，匹配概念文档面向用户描述属于 `notes` 的陈述。跳类型、路由方法和访问级别经 [service_labels.md](../services/service_labels.md) 中的本地化辅助（`serviceHopTypeLabel`、`serviceRouteMethodUiLabel`、`serviceAccessLevelLabel`）显示，而非原始枚举名；保存的值仍是枚举本身，不变。页面从 `lib/features/services/views/service_list_page.dart` 压入——拓扑的节点详情也经其 `onEditRoute` 回调由它压入——另外也在引导式页面移交时压入。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ServiceRouteEditPage` 构造函数 | 构造函数（`ServiceRouteEditPage`） | B | 创建服务路由编辑页实例（可选预绑定既有路由、源服务或未保存的 `draft` 路由）。 |
| `createState` | 方法（`ServiceRouteEditPage`） | B | 为此组件创建可变状态对象。 |
| [`_editing`](#editing) | getter（`_ServiceRouteEditPageState`） | B | 报告页面是编辑既有路由还是创建新的。 |
| `initState` | 方法（`_ServiceRouteEditPageState`） | B | 从 `widget.route ?? widget.draft`（或默认）播种控制器/字段——以及车道覆盖——并启动服务加载。 |
| `dispose` | 方法（`_ServiceRouteEditPageState`） | B | 释放最终 URL 和备注文本控制器。 |
| [`_load`](#load) | 方法（`_ServiceRouteEditPageState`） | A | 加载所有服务，丢弃已不存在的源或端点，并默认选择。 |
| `_selectedSource` | getter（`_ServiceRouteEditPageState`） | B | 按 id 查找当前所选源 `ServiceNode`。 |
| `_selectedEndpoint` | getter（`_ServiceRouteEditPageState`） | B | 按 id 查找当前所选源 `ServiceEndpoint`。 |
| [`_save`](#save) | 方法（`_ServiceRouteEditPageState`） | A | 验证表单、持久化 `_buildRoute()` 并关闭页面。 |
| [`_buildRoute`](#buildroute) | 方法（`_ServiceRouteEditPageState`） | A | 构建表单描述的路由（生成名、目标、车道覆盖）。 |
| [`_openGuidedEditor`](#openguidededitor) | 方法（`_ServiceRouteEditPageState`） | A | 把表单状态移交给引导式访问路径页。 |
| [`_delete`](#delete) | 方法（`_ServiceRouteEditPageState`） | A | 确认并删除被编辑路由。 |
| `_addHop` | 方法（`_ServiceRouteEditPageState`） | B | 打开跳对话框并把结果追加进跳列表。 |
| `_editHop` | 方法（`_ServiceRouteEditPageState`） | B | 打开带既有跳预填的跳对话框并原地替换。 |
| [`_showHopDialog`](#showhopdialog) | 方法（`_ServiceRouteEditPageState`） | A | 显示 `_ServiceRouteHopDialog` 并返回它弹出的跳。 |
| `build` | 方法（组件构建，`_ServiceRouteEditPageState`） | B | 围绕 `_buildFormBody` 渲染脚手架（保存/删除操作）。 |
| `_buildFormBody` | 方法（组件辅助） | B | 在同一个 `Form` 内选择布局：两半合一的单个 `ListView`，或——`useDetailTwoPane` 通过时——一个 `Row`：`editFormLeftPaneWidth` 宽的可滚动源窗格加右侧跳列表 `ListView`。两栏都滚动。 |
| `_buildSourceFields` | 方法（组件辅助） | B | 源/端点选择器、访问级别（本地化标签）、拓扑车道下拉框、目标字段，以及带引导式编辑器操作的预览卡片。 |
| `_buildHopFields` | 方法（组件辅助） | B | 跳列表、备注和保存按钮——从 `build` 原样抽出。 |
| [`_hopTitle`](#hoptitle) | 方法（`_ServiceRouteEditPageState`） | A | 计算一跳显示标题，偏好其链接服务名、然后标签、然后主机、然后本地化跳类型。 |
| [`_hopSubtitle`](#hopsubtitle) | 方法（`_ServiceRouteEditPageState`） | A | 组合一跳多部分副标题行（本地化类型和方法、端点、主机/scheme/端口/路径、备注）。 |
| `_hopEndpoint` | 方法（`_ServiceRouteEditPageState`） | B | 查找跳引用的 `ServiceEndpoint`（如有）。 |
| `_moveHop` | 方法（`_ServiceRouteEditPageState`） | B | 把一跳从一个索引移到另一个重排跳列表。 |
| [`_routePreview`](#routepreview) | 方法（`_ServiceRouteEditPageState`） | A | 经 `serviceRouteChainPreview` 构建人类可读的「源 -> 跳 -> ... -> 目标」预览字符串。 |
| [`_splitTargets`](#splittargets) | 顶层函数 | A | 把多行/逗号分隔最终 URL 文本字段解析为单独目标字符串列表。 |
| `_emptyToNull` | 顶层函数 | B | 修剪字符串并把空结果转换为 `null`。 |
| `_ServiceRouteHopDialog` 构造函数 | 构造函数（`_ServiceRouteHopDialog`） | B | 跳编辑对话框（初始跳、服务）。 |
| `createState` | 方法（`_ServiceRouteHopDialog`） | B | 创建对话框状态。 |
| `initState` | 方法（`_ServiceRouteHopDialogState`） | B | 从初始跳播种六个控制器以及类型/方法/服务/端点。 |
| `dispose` | 方法（`_ServiceRouteHopDialogState`） | B | 释放控制器——在关闭动画之后。 |
| `_submit` | 方法（`_ServiceRouteHopDialogState`） | B | 弹出字段所描述的跳，保留初始 id 和 `extraJson`。 |
| [`build`](#hopdialogbuild) | 方法（组件构建，`_ServiceRouteHopDialogState`） | A | 跳表单；悬空的服务/端点 id 仍可选择。 |

## 文档

### `bool get _editing` <a id="editing"></a>
- **种类：** `_ServiceRouteEditPageState` 的 getter
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 59 行）
- **用途：** 报告 `widget.route` 是否非 null，即页面是编辑既有路由还是创建新的。
- **输入：** 无。
- **返回：** `bool` — `widget.route != null` 时 `true`。
- **副作用：** 无。
- **算法：** 单表达式：`widget.route != null`。
- **用法：**
  ```dart
  title: Text(_editing ? l10n.editServiceRoute : l10n.addServiceRoute),
  ```
- **备注：** 也门控应用栏删除操作按钮。

### `Future<void> _load()` <a id="load"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 101 行，从 `initState` 调用）
- **用途：** 加载所有服务（供源服务下拉和跳服务选择器）并使源选择有效。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `ServiceStorage.load()`（本地文件系统 IO）；调用 `setState` 填充 `_services`、修正 `_sourceServiceId`/`_sourceEndpointId` 并清除 `_loading`。
- **算法：**
  1. Await `ServiceStorage.load()`。
  2. await 期间组件卸载则退出。
  3. `setState`：存储 `data.services`；所选源不在其中时（未选择、已删除的服务，或没有源的草稿的空 id），回退到第一个服务并清除端点；清除源没有的端点 id；然后把未设置的端点默认为源的第一个端点；清除 `_loading`。
- **用法：**
  ```dart
  @override
  void initState() {
    super.initState();
    ...
    _load();
  }
  ```
- **备注：** 这些修正使源和端点下拉框的 `initialValue` 始终在其条目之中——下拉框会对此断言；1.5.6 之前，源服务已被删除的路由会触发该断言。

### `Future<void> _save()` <a id="save"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 147 行）
- **用途：** 验证表单、持久化它描述的路由并关闭页面。
- **输入：** 无（读取表单/控制器/字段状态）。
- **返回：** `Future<void>`。
- **副作用：** 调用 `ServiceStorage.addOrUpdateRoute`（本地文件系统 IO）；成功时带结果 `true` 弹出路由。
- **算法：**
  1. 运行表单验证；无效提前返回。`_sourceServiceId` 为 null 提前返回。
  2. Await `ServiceStorage.addOrUpdateRoute(_buildRoute())`。
  3. 仍挂载时带 `true` 弹出页面。
- **用法：**
  ```dart
  IconButton(icon: const Icon(Icons.save), onPressed: _save),
  ```
- **备注：** 唯一显式守卫是 `_sourceServiceId == null`；路由命名、目标记账和车道覆盖都在 [`_buildRoute`](#buildroute) 中。

### `ServiceRoute _buildRoute()` <a id="buildroute"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 162 行）
- **用途：** 构建表单当前描述的路由。
- **输入：** 无（读取表单/控制器/字段状态）。
- **返回：** `ServiceRoute`。
- **副作用：** 无。
- **算法：** 解析目标字段（[`_splitTargets`](#splittargets)）；编辑时保留 `widget.route` 的 id（草稿保存为新路由）；用 `serviceRouteGeneratedName` 生成名称；把 `finalUrl` 设为第一个目标；从路由或草稿自身的映射经 `serviceRouteExtraJsonWithTargets` 重建 `extraJson`，再以车道下拉框的值经 `serviceRouteExtraJsonWithAccessLane` 处理（*自动* = null，移除覆盖）。
- **用法：** `_save`、`_routePreview`，以及决定是否提供引导式编辑器的检查。
- **备注：** 未知的源变为空 id，`ServiceAccessDraft.fromRoute` 会拒绝它，因此选定源之前引导式操作一直隐藏。

### `Future<void> _openGuidedEditor()` <a id="openguidededitor"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 193 行）
- **用途：** 以当前表单状态打开引导式访问路径页。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 压入 [`ServiceAccessPathPage`](service_access_path_page.md)；它保存或删除后本页弹出 `true`。
- **算法：** 构建路由；用 `ServiceAccessDraft.fromRoute` 读取它（不符合任何模式时返回）；编辑时以 `route:` 压入页面，使 id 得以保留，否则以草稿压入；它弹出 `true` 时，本页也弹出 `true`。
- **用法：** 预览卡片中的「引导式编辑器」按钮，只在表单符合某种模式时显示。
- **备注：** 压在本页之上而非替换本页，因此结果仍会送达打开编辑器的一方。

### `Future<void> _delete()` <a id="delete"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 212 行）
- **用途：** 让用户确认，然后删除被编辑路由。
- **输入：** 无（用 `widget.route`）。
- **返回：** `Future<void>`。
- **副作用：** 显示确认 `AlertDialog`；确认时调用 `ServiceStorage.deleteRoute`（本地文件系统 IO）并带 `true` 弹出页面。
- **算法：**
  1. `widget.route` 为 null 提前返回（防御——删除按钮只在 `_editing` 时显示）。
  2. 显示按名确认删除路由、取消/删除操作返回 `false`/`true` 的 `AlertDialog`。
  3. 确认时 await `ServiceStorage.deleteRoute(route.id)`，仍挂载时带 `true` 弹出页面。
- **用法：**
  ```dart
  if (_editing)
    IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
  ```
- **备注：** 除 `service_edit_page.dart` 的 `_delete` 镜像行为外无。

### `Future<ServiceRouteHop?> _showHopDialog({ServiceRouteHop? initial})` <a id="showhopdialog"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 265 行）
- **用途：** 显示跳编辑对话框并返回它弹出的跳。
- **输入：** `initial` — 要编辑的既有 `ServiceRouteHop`，或 `null` 创建新的。
- **返回：** `Future<ServiceRouteHop?>` — 点保存时构建跳，取消/关闭时 `null`。
- **副作用：** 经 `showDialog` 显示 `_ServiceRouteHopDialog`。
- **算法：** `showDialog(builder: (_) => _ServiceRouteHopDialog(initial: initial, services: _services))`。
- **用法：**
  ```dart
  Future<void> _addHop() async {
    final hop = await _showHopDialog();
    if (hop != null) setState(() => _hops.add(hop));
  }
  ```
- **备注：** 1.5.6 之前对话框内联构建，其六个文本控制器在 `showDialog` 返回后立即释放——而此时对话框的退出动画仍在重建字段，这会在调试构建中触发断言。现在由对话框组件自己持有并释放它们。

### `Widget build(BuildContext context)` (`_ServiceRouteHopDialogState`) <a id="hopdialogbuild"></a>
- **种类：** `_ServiceRouteHopDialogState` 的方法（组件构建）
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 733 行）
- **用途：** 渲染跳表单。
- **输入：** `context`。**返回：** 组件树。**副作用：** 无。
- **算法：** 一个 `AlertDialog`，包含跳类型下拉框（`serviceHopTypeLabel`）、可选的路由方法下拉框（`serviceRouteMethodUiLabel`）、链接服务下拉框（`null` = 手动跳；选择服务会把端点重置为其第一个端点）、链接了服务时的端点下拉框，以及标签、scheme、端口、主机、路径和备注字段。保存时运行 `_submit`。
- **用法：** 由 `_showHopDialog` 构建。
- **备注：** 清单中已不存在的服务或端点 id 仍以其原始 id 的形式可选，因此打开这样的跳既不会触发断言，也不会静默丢弃引用。下拉框设置了 `isExpanded`，因此过长的产品名或服务名以省略号截断，而不会撑破手机宽度的对话框。跳可以同时带链接服务和自由形式字段；对话框不强制二者互斥。

### `String _hopTitle(ServiceRouteHop hop)` <a id="hoptitle"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 557 行）
- **用途：** 挑跳可用最佳显示标题：可解析时链接服务名，否则跳自己标签，否则其主机，否则其本地化类型标签。
- **输入：** `hop` — 要标题的 `ServiceRouteHop`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：**
  1. `hop.serviceId` 已设时在 `_services` 查找；找到返回该服务 `name`。
  2. 否则 `hop.label` 已设且非空返回它。
  3. 否则 `hop.host` 已设且非空返回它。
  4. 否则回退 `serviceHopTypeLabel(l10n, hop.type)`（如英语下的 "Manual"、"Reverse proxy"）。
- **用法：**
  ```dart
  title: Text(_hopTitle(_hops[i])),
  ```
  （跳列表卡片的标题；自 1.5.6 起预览经 `serviceRouteChainPreview` 为跳命名——见 [`_routePreview`](#routepreview)）
- **备注：** 链接服务此后从存储删除的跳静默落入标签/主机/类型回退链而非报错，因为 `.where(...).firstOrNull` 查找简单无返回。

### `String _hopSubtitle(ServiceRouteHop hop)` <a id="hopsubtitle"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 572 行）
- **用途：** 构建跳列表卡片次要详情行，组合其类型、方法、链接端点（如有）、自由形式主机/scheme/端口/路径和备注。
- **输入：** `hop` — 要描述的 `ServiceRouteHop`。
- **返回：** `String` — 部分用 `' · '` 连接，省略任何空/null 部分。
- **副作用：** 无（调用姊妹 `_hopEndpoint` 查找）。
- **算法：**
  1. 经 `_hopEndpoint(hop)` 解析跳链接端点。
  2. 组装候选字符串列表：`serviceHopTypeLabel(l10n, hop.type)`；已设时经 `serviceRouteMethodUiLabel` 的方法；解析端点时 `'<protocol>/<portText>'`；`hop.host` 已设时只从存在部分构建的格式化 `scheme://host:port/path` 字符串；`hop.notes`。
  3. 过滤到非 null、非空字符串并用 `' · '` 连接。
- **用法：**
  ```dart
  subtitle: Text(_hopSubtitle(_hops[i])),
  ```
- **备注：** 基于主机的字符串独立于链接端点字符串构建，因此两者都填充时跳可同时显示端点摘要和单独主机/scheme/端口/路径摘要。

### `String _routePreview()` <a id="routepreview"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 616 行）
- **用途：** 构建跳列表上方卡片显示的单行「源 -> 跳 -> ... -> 目标」预览。
- **输入：** 无（经 `_buildRoute` 读取表单）。
- **返回：** `String` — 箭头连接链，尚无可显示时 `'-'`。
- **副作用：** 无。
- **算法：** `serviceRouteChainPreview(_buildRoute(), services: _services, hopFallback: (hop) => serviceHopFallbackLabel(l10n, hop))`——见 [`service_analysis.md`](../services/service_analysis.md#serviceroutechainpreview)。
- **用法：**
  ```dart
  Text(_routePreview()),
  ```
- **备注：** 自 1.5.6 起与引导式页面共用，使两种编辑器用相同的措辞描述路由；端口映射跳还会显示其公网主机和端口。每次 `build()` 都重算，因此预览总是反映未保存的编辑。

### `List<String> _splitTargets(String value)` <a id="splittargets"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 906 行）
- **用途：** 把最终 URL/目标字段原始文本解析为干净单独目标字符串列表，支持每行一个目标或逗号分隔目标。
- **输入：** `value` — `_finalUrlCtrl` 原始文本。
- **返回：** `List<String>` — 修剪、非空目标，原始顺序。
- **副作用：** 无。
- **算法：**
  1. 按正则 `[\n,]+`（一个或多个换行和/或逗号，使连续分隔符坍缩而非产生空条目）拆分 `value`。
  2. 修剪每个结果块。
  3. 丢弃修剪后为空的任何块。
- **用法：**
  ```dart
  final targets = _splitTargets(_finalUrlCtrl.text);
  ```
  用于 [`_buildRoute`](#buildroute) 构建 `finalUrl` 和 `extraJson` 分组目标负载两者，因此 [`_save`](#save) 和 [`_routePreview`](#routepreview) 都从它返回的路由读取解析后的目标。
- **备注：** 这是 [服务与拓扑](../../../../features/services-topology.md) 描述"分组公共目标"功能的解析侧——单条路由可为相同访问路径列出几个域/URL，在一个文本字段每行一个或逗号分隔输入。
