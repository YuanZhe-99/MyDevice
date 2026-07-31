# lib/features/services/views/service_edit_page.dart

创建/编辑单个 `ServiceNode` 的 Flutter 视图（[服务与拓扑](../../../../features/services-topology.md) 描述的手动服务清单条目）。它托管增/改表单（名、设备、kind、runtime、state、端点列表、备注、Docker Compose 文本）加从 `service_template_service.dart` 模板预填字段的底部面板模板选择器（`_ServiceTemplatePicker`）——匹配仅手动清单约束（模板只预填；绝不执行发现）。持久化经 `ServiceStorage.addOrUpdateService`/`deleteService`（`lib/features/services/services/service_storage.dart`）；设备选择列表来自过滤到 `device.isInService` 的 `DeviceStorage.load()`。页面从 `lib/features/services/views/service_list_page.dart` 压入。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ServiceEditPage` 构造函数 | 构造函数（`ServiceEditPage`） | B | 创建服务编辑页实例（可选预绑定既有服务/设备）。 |
| `createState` | 方法（`ServiceEditPage`） | B | 为此组件创建可变状态对象。 |
| [`_editing`](#editing) | getter（`_ServiceEditPageState`） | B | 报告页面是编辑既有服务还是创建新的。 |
| `initState` | 方法（`_ServiceEditPageState`） | B | 从既有服务（或默认）播种控制器/字段并启动设备加载。 |
| `dispose` | 方法（`_ServiceEditPageState`） | B | 释放四个文本控制器。 |
| [`_loadDevices`](#loaddevices) | 方法（`_ServiceEditPageState`） | A | 加载设备列表、限制到服务合格设备并挑默认。 |
| [`_applyTemplate`](#applytemplate) | 方法（`_ServiceEditPageState`） | A | 把所选 `ServiceTemplate` 的字段/端点/Compose 文本应用到草稿服务。 |
| `_templateName` | 方法（`_ServiceEditPageState`） | B | 为选择器按钮标签把模板 id 解析为其显示名。 |
| `_pickTemplate` | 方法（`_ServiceEditPageState`） | B | 打开模板选择器底部面板并应用所选模板。 |
| [`_save`](#save) | 方法（`_ServiceEditPageState`） | A | 验证表单、构建 `ServiceNode`、持久化并关闭页面。 |
| [`_delete`](#delete) | 方法（`_ServiceEditPageState`） | A | 确认并删除被编辑服务。 |
| `_copyCompose` | 方法（`_ServiceEditPageState`） | B | 把 Docker Compose 文本字段复制到剪贴板并显示 snackbar。 |
| `_addEndpoint` | 方法（`_ServiceEditPageState`） | B | 打开端点对话框并把结果追加进端点列表。 |
| `_editEndpoint` | 方法（`_ServiceEditPageState`） | B | 打开带既有端点预填的端点对话框并原地替换。 |
| [`_showEndpointDialog`](#showendpointdialog) | 方法（`_ServiceEditPageState`） | A | 显示一个 `ServiceEndpoint` 的增/改模态对话框并构建结果。 |
| `build` | 方法（组件构建，`_ServiceEditPageState`） | B | 渲染服务编辑表单（字段、端点卡片、Compose 编辑器、保存/删除操作）。 |
| `_emptyToNull` | 顶层函数 | B | 修剪字符串并把空结果转换为 `null`。 |
| `_ServiceTemplatePicker` 构造函数 | 构造函数（`_ServiceTemplatePicker`） | B | 创建服务模板选择器实例。 |
| `createState` | 方法（`_ServiceTemplatePicker`） | B | 为模板选择器组件创建可变状态对象。 |
| `dispose` | 方法（`_ServiceTemplatePickerState`） | B | 释放搜索文本控制器。 |
| [`_filteredTemplates`](#filteredtemplates) | getter（`_ServiceTemplatePickerState`） | A | 按所选 kind/搜索查询过滤模板并排序（featured 先，然后 kind，然后名）。 |
| `build` | 方法（组件构建，`_ServiceTemplatePickerState`） | B | 渲染可拖拽模板选择器面板（搜索字段、kind chips、模板列表）。 |

## 文档

### `bool get _editing` <a id="editing"></a>
- **种类：** `_ServiceEditPageState` 的 getter
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 53 行）
- **用途：** 报告 `widget.service` 是否非 null，即页面是编辑既有服务还是创建新的。
- **输入：** 无。
- **返回：** `bool` — `widget.service != null` 时 `true`。
- **副作用：** 无。
- **算法：** 单表达式：`widget.service != null`。
- **用法：**
  ```dart
  title: Text(_editing ? l10n.editService : l10n.addService),
  ```
- **备注：** 也门控应用栏删除操作按钮。

### `Future<void> _loadDevices()` <a id="loaddevices"></a>
- **种类：** `_ServiceEditPageState` 的方法
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 97 行，从 `initState` 第 75 行调用）
- **用途：** 加载所有已知设备并把设备选择器限制到为服务功能标记的设备，默认选择。
- **输入：** 无（经既有 `_deviceId` 间接读取 `widget.service`/`widget.deviceId`）。
- **返回：** `Future<void>`。
- **副作用：** 调用 `DeviceStorage.load()`（本地文件系统 IO）；调用 `setState` 填充 `_devices`、默认 `_deviceId` 并清除 `_loading`。
- **算法：**
  1. Await `DeviceStorage.load()`。
  2. await 期间组件卸载则退出。
  3. 把加载设备过滤到 `device.isInService` 为 true 的。
  4. `setState`：把过滤列表存进 `_devices`；`_deviceId` 仍未设时默认第一个合格设备 id（`??=`）；清除 `_loading`。
- **用法：**
  ```dart
  @override
  void initState() {
    super.initState();
    ...
    _loadDevices();
  }
  ```
- **备注：** 未标记 `isInService` 的设备即使服务已引用它们（如经 `widget.deviceId`）也从选择器排除；`if (!mounted) return` 守卫避免释放后 `setState`。

### `void _applyTemplate(ServiceTemplate template)` <a id="applytemplate"></a>
- **种类：** `_ServiceEditPageState` 的方法
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 113 行）
- **用途：** 把所选服务模板的名、图标、kind、runtime、端点和（存在时）Docker Compose 文本复制进当前草稿，替换端点列表。
- **输入：** `template` — 选择器中选的 `ServiceTemplate`（来自 `service_template_service.dart`）。
- **返回：** `void`。
- **副作用：** 调用 `setState`；覆盖 `_nameCtrl.text`、`_iconCtrl.text` 和（条件）`_composeCtrl.text`；完全替换 `_endpoints`。
- **算法：**
  1. 记录 `_templateId = template.id`。
  2. 从模板覆盖名字段和图标（存储 `_icon` 和其文本控制器两者）。
  3. 复制 `template.kind` 和 `template.runtime`。
  4. 把 `_endpoints` 重建为从 `template.endpoints` 逐字段克隆的新鲜 `ServiceEndpoint` 对象列表（新实例，非模板自己对象）。
  5. 模板 `dockerCompose` 非空时用其覆盖 `_composeCtrl.text`；否则用户已输入任何东西保持不动。
- **用法：**
  ```dart
  Future<void> _pickTemplate() async {
    final template = await showModalBottomSheet<ServiceTemplate>(...);
    if (template != null) _applyTemplate(template);
  }
  ```
- **备注：** 应用模板总是整体替换端点列表（不与手动添加端点合并）；Compose 文本只在模板实际提供一个时覆盖，因此切换到无 Compose 备注的模板保留既有文本。

### `Future<void> _save()` <a id="save"></a>
- **种类：** `_ServiceEditPageState` 的方法
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 174 行）
- **用途：** 验证表单、从当前草稿状态组装 `ServiceNode`、持久化并关闭页面。
- **输入：** 无（读取表单/控制器/字段状态）。
- **返回：** `Future<void>`。
- **副作用：** 调用 `ServiceStorage.addOrUpdateService`（本地文件系统 IO）；成功时带结果 `true` 弹出路由。
- **算法：**
  1. 运行表单验证（`_formKey.currentState!.validate()`）；无效提前返回。
  2. 未选设备（`_deviceId == null`）提前返回。
  3. 构建 `ServiceNode`，复用 `existing?.id`（使编辑原地更新而非创建新记录）、`existing?.tags` 和 `existing?.extraJson` 不变；名/kind/runtime/state/端点来自当前草稿字段；经 `_emptyToNull` 转换备注和 Compose 文本，使空白文本存为 `null` 而非空字符串。
  4. Await `ServiceStorage.addOrUpdateService(service)`。
  5. 仍挂载时带 `true` 弹出页面，信号调用方（`service_list_page.dart`）数据已变。
- **用法：**
  ```dart
  IconButton(icon: const Icon(Icons.save), onPressed: _save),
  ```
- **备注：** 只有名字段有表单验证器（`serviceNameRequired`）；设备选择手动检查而非经 `Form` 验证链。端点列表内容这里不再验证——每个端点验证在经 `_showEndpointDialog` 添加/编辑时发生。

### `Future<void> _delete()` <a id="delete"></a>
- **种类：** `_ServiceEditPageState` 的方法
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 202 行）
- **用途：** 让用户确认，然后删除被编辑服务。
- **输入：** 无（用 `widget.service`）。
- **返回：** `Future<void>`。
- **副作用：** 显示确认 `AlertDialog`；确认时调用 `ServiceStorage.deleteService`（本地文件系统 IO）并带 `true` 弹出页面。
- **算法：**
  1. `widget.service` 为 null 提前返回（无可删除——删除按钮只在 `_editing` 时显示，因此这是防御守卫）。
  2. 显示要求确认删除命名服务的 `AlertDialog`，取消/删除操作返回 `false`/`true`。
  3. 用户确认时 await `ServiceStorage.deleteService(service.id)`，仍挂载时带 `true` 弹出页面。
- **用法：**
  ```dart
  if (_editing)
    IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
  ```
- **备注：** 这里删除只移除 `ServiceNode` 记录本身；引用此服务端点的任何 `ServiceRoute` 不由此方法清理（超出本文件范围）。

### `Future<ServiceEndpoint?> _showEndpointDialog({ServiceEndpoint? initial})` <a id="showendpointdialog"></a>
- **种类：** `_ServiceEditPageState` 的方法
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 269 行）
- **用途：** 显示创建或编辑一个 `ServiceEndpoint`（标签、协议、传输、端口/端口结束、绑定地址、路径、范围、主标志）的模态对话框并返回结果对象。
- **输入：** `initial` — 编辑预填的既有 `ServiceEndpoint`，或 `null` 创建新的。
- **返回：** `Future<ServiceEndpoint?>` — 用户点保存时构建端点，取消/关闭时 `null`。
- **副作用：** 经 `showDialog` 显示 `AlertDialog`；对话框关闭后释放其本地文本控制器。
- **算法：**
  1. 从 `initial` 播种本地 `TextEditingController` 和下拉状态（`protocol`、`transport`、`scope`），或默认（`ServiceProtocol.http`、`ServiceTransport.tcp`、`ServiceScope.lan`）。
  2. 默认 `primary` 为 `initial?.isPrimary`，或——全新端点——这将是 `_endpoints` 第一个端点时 `true`（`_endpoints.isEmpty`），使添加的第一个端点自动标记主。
  3. 构建 `StatefulBuilder` 支撑、带标签、协议、传输、端口/端口结束（数字）、绑定地址、路径、范围和主复选框字段的 `AlertDialog`，各经 `setDialogState` 更新本地对话框状态。
  4. 保存时用当前对话框状态构建新 `ServiceEndpoint` 弹出：`label`/`bindAddress`/`path` 经 `_emptyToNull`；`port`/`portEnd` 用 `int.tryParse` 解析（无效/空文本变 `null`）；`extraJson` 从 `initial` 原样带过。
  5. 无论结果都释放全部五个本地控制器，然后返回对话框结果。
- **用法：**
  ```dart
  Future<void> _addEndpoint() async {
    final endpoint = await _showEndpointDialog();
    if (endpoint != null) setState(() => _endpoints.add(endpoint));
  }
  ```
- **备注：** 端口字段接受自由形式文本并在不可解析输入上静默回退 `null`（坏端口不显示内联错误）；"第一端点默认主"规则只在添加全新端点（`initial == null`）时适用，不在编辑时。

### `List<ServiceTemplate> get _filteredTemplates` <a id="filteredtemplates"></a>
- **种类：** `_ServiceTemplatePickerState` 的 getter
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 702 行）
- **用途：** 计算选择器中要显示的模板列表，按所选 kind 和搜索文本过滤，featured 模板先排序。
- **输入：** 无（读取 `_searchCtrl.text` 和 `_kind`）。
- **返回：** `List<ServiceTemplate>`。
- **副作用：** 无（调用纯读内置模板目录的 `ServiceTemplateService.loadTemplates()`）。
- **算法：**
  1. 小写并修剪搜索查询。
  2. 加载所有模板并保留 `_kind` 未设或匹配 `template.kind` **且**查询为空或匹配模板名、id 或任何标签（不区分大小写）的。
  3. 排序过滤列表：featured 模板（`template.featured`）排在非 featured 前；平局按 `kind.index`、然后不区分大小写名。
- **用法：**
  ```dart
  itemCount: _filteredTemplates.length + 1,
  itemBuilder: (context, index) {
    ...
    final template = _filteredTemplates[index - 1];
  ```
- **备注：** 此 getter 每次访问重新过滤并排序（含列表每个 `itemBuilder` 调用），鉴于 [服务与拓扑 — 服务模板](../../../../features/services-topology.md#service-templates) 描述的小内存模板目录可接受。
