# lib/features/services/views/service_route_edit_page.dart

实现 [服务与拓扑 — 快速访问路由创建 vs 高级编辑器](../../../../features/services-topology.md#quick-access-route-creation-vs-the-advanced-editor) 描述的**高级多跳路由编辑器**的 Flutter 视图——与默认快速访问路由创建流程相反，本页让用户从源服务端点到一个或多个最终目标构建/重排任意有序 `ServiceRouteHop` 列表。它经 `ServiceStorage.load`/`addOrUpdateRoute`/`deleteRoute`（`lib/features/services/services/service_storage.dart`）读写 `ServiceRoute` 记录，并把路由命名和多目标解析委托给 `service_analysis.dart` 辅助（`serviceRouteGeneratedName`、`serviceRouteAccessTargets`、`serviceRouteExtraJsonWithTargets`、`compactAccessTargetLabel`）——路由名内部生成并对用户隐藏，匹配概念文档面向用户描述属于 `notes` 的陈述。页面从 `lib/features/services/views/service_list_page.dart` 压入。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ServiceRouteEditPage` 构造函数 | 构造函数（`ServiceRouteEditPage`） | B | 创建服务路由编辑页实例（可选预绑定既有路由/源服务）。 |
| `createState` | 方法（`ServiceRouteEditPage`） | B | 为此组件创建可变状态对象。 |
| [`_editing`](#editing) | getter（`_ServiceRouteEditPageState`） | B | 报告页面是编辑既有路由还是创建新的。 |
| `initState` | 方法（`_ServiceRouteEditPageState`） | B | 从既有路由（或默认）播种控制器/字段并启动服务加载。 |
| `dispose` | 方法（`_ServiceRouteEditPageState`） | B | 释放最终 URL 和备注文本控制器。 |
| [`_load`](#load) | 方法（`_ServiceRouteEditPageState`） | A | 加载所有服务并默认源服务/端点选择。 |
| `_selectedSource` | getter（`_ServiceRouteEditPageState`） | B | 按 id 查找当前所选源 `ServiceNode`。 |
| `_selectedEndpoint` | getter（`_ServiceRouteEditPageState`） | B | 按 id 查找当前所选源 `ServiceEndpoint`。 |
| [`_save`](#save) | 方法（`_ServiceRouteEditPageState`） | A | 验证表单、构建 `ServiceRoute`（带生成名和解析目标）、持久化并关闭页面。 |
| [`_delete`](#delete) | 方法（`_ServiceRouteEditPageState`） | A | 确认并删除被编辑路由。 |
| `_addHop` | 方法（`_ServiceRouteEditPageState`） | B | 打开跳对话框并把结果追加进跳列表。 |
| `_editHop` | 方法（`_ServiceRouteEditPageState`） | B | 打开带既有跳预填的跳对话框并原地替换。 |
| [`_showHopDialog`](#showhopdialog) | 方法（`_ServiceRouteEditPageState`） | A | 显示一个 `ServiceRouteHop` 的增/改模态对话框并构建结果。 |
| `build` | 方法（组件构建，`_ServiceRouteEditPageState`） | B | 围绕 `_buildFormBody` 渲染脚手架（保存/删除操作）。 |
| `_buildFormBody` | 方法（组件辅助） | B | 在同一个 `Form` 内选择布局：两半合一的单个 `ListView`，或——`useDetailTwoPane` 通过时——一个 `Row`：`editFormLeftPaneWidth` 宽的可滚动源窗格加右侧跳列表 `ListView`。两栏都滚动。 |
| `_buildSourceFields` | 方法（组件辅助） | B | 源/端点选择器、访问级别、目标字段和预览卡片——从 `build` 原样抽出。 |
| `_buildHopFields` | 方法（组件辅助） | B | 跳列表、备注和保存按钮——从 `build` 原样抽出。 |
| [`_hopTitle`](#hoptitle) | 方法（`_ServiceRouteEditPageState`） | A | 计算一跳显示标题，偏好其链接服务名、然后标签、然后主机、然后跳类型。 |
| [`_hopSubtitle`](#hopsubtitle) | 方法（`_ServiceRouteEditPageState`） | A | 组合一跳多部分副标题行（类型、方法、端点、主机/scheme/端口/路径、备注）。 |
| `_hopEndpoint` | 方法（`_ServiceRouteEditPageState`） | B | 查找跳引用的 `ServiceEndpoint`（如有）。 |
| `_moveHop` | 方法（`_ServiceRouteEditPageState`） | B | 把一跳从一个索引移到另一个重排跳列表。 |
| [`_routePreview`](#routepreview) | 方法（`_ServiceRouteEditPageState`） | A | 构建跳列表上方显示的人类可读"源 -> 跳 -> ... -> 目标"预览字符串。 |
| [`_splitTargets`](#splittargets) | 顶层函数 | A | 把多行/逗号分隔最终 URL 文本字段解析为单独目标字符串列表。 |
| `_emptyToNull` | 顶层函数 | B | 修剪字符串并把空结果转换为 `null`。 |

## 文档

### `bool get _editing` <a id="editing"></a>
- **种类：** `_ServiceRouteEditPageState` 的 getter
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 44 行）
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
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 85 行，从 `initState` 第 65 行调用）
- **用途：** 加载所有服务（供源服务下拉和跳服务选择器）并在尚未设置时默认所选源服务/端点。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `ServiceStorage.load()`（本地文件系统 IO）；调用 `setState` 填充 `_services`、默认 `_sourceServiceId`/`_sourceEndpointId` 并清除 `_loading`。
- **算法：**
  1. Await `ServiceStorage.load()`。
  2. await 期间组件卸载则退出。
  3. `setState`：把 `data.services` 存进 `_services`；`_sourceServiceId` 仍未设时默认第一个加载服务 id（`??=`）；`_sourceEndpointId` 仍未设时默认新解析源服务第一端点 id；清除 `_loading`。
- **用法：**
  ```dart
  @override
  void initState() {
    super.initState();
    ...
    _load();
  }
  ```
- **备注：** 端点默认在源服务默认应用后解析（都在相同 `setState` 回调内），因此未提供 `widget.sourceService` 时全新路由默认"第一服务、该服务第一端点"。

### `Future<void> _save()` <a id="save"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 125 行）
- **用途：** 验证表单、从当前草稿状态组装 `ServiceRoute`（带内部生成名和解析目标列表）、持久化并关闭页面。
- **输入：** 无（读取表单/控制器/字段状态）。
- **返回：** `Future<void>`。
- **副作用：** 调用 `ServiceStorage.addOrUpdateRoute`（本地文件系统 IO）；成功时带结果 `true` 弹出路由。
- **算法：**
  1. 运行表单验证；无效提前返回。`_sourceServiceId` 为 null 提前返回。
  2. 经 [`_splitTargets`](#splittargets) 把最终 URL 文本字段解析为 `targets` 列表。
  3. 构建 `ServiceRoute`，复用 `existing?.id` 做原地编辑。路由 `name` 经 `serviceRouteGeneratedName(sourceName: ..., hops: _hops, targets: targets)` 生成——绝不由用户输入。`finalUrl` 设为 `targets.firstOrNull`（只第一目标，为向后兼容）。`extraJson` 经 `serviceRouteExtraJsonWithTargets(existing?.extraJson ?? const {}, targets)` 重建，它存储完整目标列表（分组公共目标，按 [服务与拓扑](../../../../features/services-topology.md)）。
  4. Await `ServiceStorage.addOrUpdateRoute(route)`。
  5. 仍挂载时带 `true` 弹出页面。
- **用法：**
  ```dart
  IconButton(icon: const Icon(Icons.save), onPressed: _save),
  ```
- **备注：** 与 `service_edit_page.dart` 的 `_save` 不同，此方法对本文件可见目标/名称输入无字段级 `Form` 验证器——唯一显式守卫是 `_sourceServiceId == null`；路由命名和目标列表记账完全委托 `service_analysis.dart` 辅助而非这里内联实现。

### `Future<void> _delete()` <a id="delete"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 158 行）
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
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 210 行）
- **用途：** 显示创建或编辑一个 `ServiceRouteHop`（类型、方法、可选链接服务/端点、标签、scheme/主机/端口/路径、备注）的模态对话框并返回结果对象。
- **输入：** `initial` — 编辑预填的既有 `ServiceRouteHop`，或 `null` 创建新的。
- **返回：** `Future<ServiceRouteHop?>` — 点保存时构建跳，取消/关闭时 `null`。
- **副作用：** 经 `showDialog` 显示 `AlertDialog`；对话框关闭后释放六个本地文本控制器。
- **算法：**
  1. 从 `initial`（或空白/默认：`ServiceRouteHopType.manual`、无方法、无链接服务/端点）播种本地控制器/状态。
  2. 构建 `StatefulBuilder` 支撑、带跳类型下拉、可选路由方法下拉、其 `onChanged` 也把 `endpointId` 重置为新选服务第一端点的"链接服务"下拉（`null` = 手动/自由形式跳）、条件端点下拉（只在链接服务时显示）和自由形式标签/scheme/端口/主机/路径/备注字段的 `AlertDialog`。
  3. 保存时用对话框状态构建新 `ServiceRouteHop` 弹出：文本字段经 `_emptyToNull`；`port` 用 `int.tryParse` 解析；`serviceId`/`endpointId`/`method` 原样取；`extraJson` 从 `initial` 带过。
  4. 无论结果都释放六个本地控制器，然后返回对话框结果。
- **用法：**
  ```dart
  Future<void> _addHop() async {
    final hop = await _showHopDialog();
    if (hop != null) setState(() => _hops.add(hop));
  }
  ```
- **备注：** 选不同链接服务把 `endpointId` 重置为该服务第一端点（无则 `null`）而非留下先前选择的过期端点 id；跳可同时混链接服务/端点与自由形式 `label`/`scheme`/`host`/`port`/`path` 字段——对话框不强制它们互斥。

### `String _hopTitle(ServiceRouteHop hop)` <a id="hoptitle"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 603 行）
- **用途：** 挑跳可用最佳显示标题：可解析时链接服务名，否则跳自己标签，否则其主机，否则其类型名。
- **输入：** `hop` — 要标题的 `ServiceRouteHop`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：**
  1. `hop.serviceId` 已设时在 `_services` 查找；找到返回该服务 `name`。
  2. 否则 `hop.label` 已设且非空返回它。
  3. 否则 `hop.host` 已设且非空返回它。
  4. 否则回退 `hop.type.name`（如 `manual`、`reverseProxy`）。
- **用法：**
  ```dart
  title: Text(_hopTitle(_hops[i])),
  ```
  并在 [`_routePreview`](#routepreview) 内复用：`..._hops.map(_hopTitle),`
- **备注：** 链接服务此后从存储删除的跳静默落入标签/主机/类型回退链而非报错，因为 `.where(...).firstOrNull` 查找简单无返回。

### `String _hopSubtitle(ServiceRouteHop hop)` <a id="hopsubtitle"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 618 行）
- **用途：** 构建跳列表卡片次要详情行，组合其类型、方法、链接端点（如有）、自由形式主机/scheme/端口/路径和备注。
- **输入：** `hop` — 要描述的 `ServiceRouteHop`。
- **返回：** `String` — 部分用 `' · '` 连接，省略任何空/null 部分。
- **副作用：** 无（调用姊妹 `_hopEndpoint` 查找）。
- **算法：**
  1. 经 `_hopEndpoint(hop)` 解析跳链接端点。
  2. 组装候选字符串列表：`hop.type.name`；`hop.method?.name`；解析端点时 `'<protocol>/<portText>'`；`hop.host` 已设时只从存在部分构建的格式化 `scheme://host:port/path` 字符串；`hop.notes`。
  3. 过滤到非 null、非空字符串并用 `' · '` 连接。
- **用法：**
  ```dart
  subtitle: Text(_hopSubtitle(_hops[i])),
  ```
- **备注：** 基于主机的字符串独立于链接端点字符串构建，因此两者都填充时跳可同时显示端点摘要和单独主机/scheme/端口/路径摘要。

### `String _routePreview()` <a id="routepreview"></a>
- **种类：** `_ServiceRouteEditPageState` 的方法
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 660 行）
- **用途：** 构建跳列表上方卡片显示的单行"源 -> 跳 -> ... -> 目标"预览，反映当前草稿的完整路由链。
- **输入：** 无（读取 `_selectedSource`、`_selectedEndpoint`、`_hops` 和最终 URL 文本字段）。
- **返回：** `String` — 箭头连接链，尚无可显示时 `'-'`。
- **副作用：** 无。
- **算法：**
  1. 用源开始部分列表：选了源服务时，也选带端口源端点时用 `'<name> <portText>'`，否则只服务名。
  2. 追加每个跳标题（经 [`_hopTitle`](#hoptitle)，按顺序）。
  3. 追加最终 URL 字段每个解析目标（经 [`_splitTargets`](#splittargets)），各经 `compactAccessTargetLabel`（来自 `service_analysis.dart`）渲染。
  4. 用 `' -> '` 连接所有部分，组合列表为空时返回 `'-'`。
- **用法：**
  ```dart
  Text(_routePreview()),
  ```
- **备注：** 这每次 `build()` 重算（最终 URL 字段 `onChanged` 调用裸 `setState(() {})`），因此预览总是反映未保存编辑，含尚未持久化的跳。

### `List<String> _splitTargets(String value)` <a id="splittargets"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/services/views/service_route_edit_page.dart`（第 680 行）
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
  用于 [`_save`](#save) 构建 `finalUrl` 和 `extraJson` 分组目标负载两者，和 [`_routePreview`](#routepreview) 渲染目标链。
- **备注：** 这是 [服务与拓扑](../../../../features/services-topology.md) 描述"分组公共目标"功能的解析侧——单条路由可为相同访问路径列出几个域/URL，在一个文本字段每行一个或逗号分隔输入。
