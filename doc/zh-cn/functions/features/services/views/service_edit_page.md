# lib/features/services/views/service_edit_page.dart

创建/编辑单个 `ServiceNode` 的 Flutter 视图（[服务与拓扑](../../../../features/services-topology.md) 描述的手动服务清单条目）。它托管增/改表单（名、设备、kind、runtime、state、端点列表、备注、Docker Compose 文本）加从 `service_template_service.dart` 模板预填字段的底部面板模板选择器（`_ServiceTemplatePicker`）——匹配仅手动清单约束（模板只预填；绝不执行发现）。持久化经 `ServiceStorage.addOrUpdateService`/`deleteService`（`lib/features/services/services/service_storage.dart`）；设备选择列表来自过滤到 `device.isInService` 的 `DeviceStorage.load()`。页面从 `lib/features/services/views/service_list_page.dart` 压入，也会——带 `template` 和 `deviceId`——从引导式访问路径流程的"新建中继服务…"操作压入。它在保存后（携带保存的节点）或删除后弹出 `ServiceEditOutcome`，用户直接返回时什么也不弹出。它打开的端点对话框是共享的 `showServiceEndpointDialog`（[service_endpoint_dialog.md](service_endpoint_dialog.md)）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`ServiceEditOutcome` 构造函数](#serviceeditoutcome-new) | 构造函数（`ServiceEditOutcome`） | A | 页面弹出的结果：保存的服务，或已删除标志。 |
| `ServiceEditPage` 构造函数 | 构造函数（`ServiceEditPage`） | B | 创建服务编辑页实例（可选预绑定既有服务、设备，或——对新服务——模板）。 |
| `createState` | 方法（`ServiceEditPage`） | B | 为此组件创建可变状态对象。 |
| [`_editing`](#editing) | getter（`_ServiceEditPageState`） | B | 报告页面是编辑既有服务还是创建新的。 |
| `initState` | 方法（`_ServiceEditPageState`） | B | 从既有服务（或默认值，新服务随后再经 `_assignTemplate` 应用 `widget.template`）播种控制器/字段并启动设备加载。 |
| `dispose` | 方法（`_ServiceEditPageState`） | B | 释放四个文本控制器。 |
| [`_loadDevices`](#loaddevices) | 方法（`_ServiceEditPageState`） | A | 加载设备列表、限制到服务合格设备并挑默认。 |
| `_applyTemplate` | 方法（`_ServiceEditPageState`） | B | 应用选中的模板：用 `setState` 包裹 `_assignTemplate`。 |
| [`_assignTemplate`](#assigntemplate) | 方法（`_ServiceEditPageState`） | A | 把 `ServiceTemplate` 的字段/端点/Compose 文本复制到草稿服务，不触发重建。 |
| `_templateName` | 方法（`_ServiceEditPageState`） | B | 为选择器按钮标签把模板 id 解析为其显示名。 |
| `_pickTemplate` | 方法（`_ServiceEditPageState`） | B | 打开模板选择器底部面板并应用所选模板。 |
| [`_save`](#save) | 方法（`_ServiceEditPageState`） | A | 验证表单、构建 `ServiceNode`、持久化并把它放进 `ServiceEditOutcome` 弹出。 |
| [`_delete`](#delete) | 方法（`_ServiceEditPageState`） | A | 确认并删除被编辑服务；弹出 `ServiceEditOutcome(deleted: true)`。 |
| `_copyCompose` | 方法（`_ServiceEditPageState`） | B | 把 Docker Compose 文本字段复制到剪贴板并显示 snackbar。 |
| `_addEndpoint` | 方法（`_ServiceEditPageState`） | B | 打开 `showServiceEndpointDialog`（是第一个端点时默认为主端点）并追加结果。 |
| `_editEndpoint` | 方法（`_ServiceEditPageState`） | B | 打开带既有端点预填的 `showServiceEndpointDialog` 并原地替换。 |
| `build` | 方法（组件构建，`_ServiceEditPageState`） | B | 围绕 `_buildFormBody` 渲染脚手架（保存/删除操作）。 |
| `_buildFormBody` | 方法（组件辅助） | B | 在同一个 `Form` 内选择布局：两半合一的单个 `ListView`，或——`useDetailTwoPane` 通过时——一个 `Row`：`editFormLeftPaneWidth` 宽的可滚动身份窗格加右侧细节 `ListView`。两栏都滚动。 |
| `_buildIdentityFields` | 方法（组件辅助） | B | 名称、设备、模板按钮、图标 + 种类、图标名、运行时、状态——从 `build` 原样抽出。 |
| `_buildDetailFields` | 方法（组件辅助） | B | 端点卡片、备注、Compose 编辑器和保存按钮——从 `build` 原样抽出。 |
| `_emptyToNull` | 顶层函数 | B | 修剪字符串并把空结果转换为 `null`。 |
| `_ServiceTemplatePicker` 构造函数 | 构造函数（`_ServiceTemplatePicker`） | B | 创建服务模板选择器实例。 |
| `createState` | 方法（`_ServiceTemplatePicker`） | B | 为模板选择器组件创建可变状态对象。 |
| `dispose` | 方法（`_ServiceTemplatePickerState`） | B | 释放搜索文本控制器。 |
| [`_filteredTemplates`](#filteredtemplates) | getter（`_ServiceTemplatePickerState`） | A | 按所选 kind/搜索查询过滤模板并排序（featured 先，然后 kind，然后名）。 |
| `build` | 方法（组件构建，`_ServiceTemplatePickerState`） | B | 渲染可拖拽模板选择器面板（搜索字段、kind chips、模板列表）；以 `sheetInitialSize(窗口高度, preferred: 0.82)` 打开，上限 `sheetMaxSize`。 |

## 文档

### `bool get _editing` <a id="editing"></a>
- **种类：** `_ServiceEditPageState` 的 getter
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 84 行）
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
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 130 行，从 `initState` 第 108 行调用）
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

### `const ServiceEditOutcome({this.saved, this.deleted = false})` <a id="serviceeditoutcome-new"></a>
- **种类：** `ServiceEditOutcome` 的构造函数
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 31 行）
- **用途：** 描述编辑页做了什么，作为它弹出的值。
- **输入：** `saved` — 保存后的服务；`deleted` — 删除后为 true。
- **返回：** 新 `ServiceEditOutcome`。
- **副作用：** 无。
- **算法：** 普通字段赋值；页面恰好设置两者之一。
- **用法：**
  ```dart
  final result = await Navigator.of(context, rootNavigator: true)
      .push<ServiceEditOutcome>(
        MaterialPageRoute(builder: (_) => ServiceEditPage(service: service)),
      );
  if (result != null) _load();
  ```
- **备注：** 取代了 1.5.6 之前页面弹出的裸 `true`。只需重载的调用方仅检查结果是否非 null；引导式访问路径页读取 `saved`，以选中它刚内联创建的中继或代理服务。

### `void _assignTemplate(ServiceTemplate template)` <a id="assigntemplate"></a>
- **种类：** `_ServiceEditPageState` 的方法
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 158 行）
- **用途：** 把所选服务模板的名、图标、kind、runtime、端点和（存在时）Docker Compose 文本复制进当前草稿，替换端点列表。
- **输入：** `template` — 选择器中选的 `ServiceTemplate`（来自 `service_template_service.dart`），或作为 `widget.template` 传入的模板。
- **返回：** `void`。
- **副作用：** 覆盖 `_nameCtrl.text`、`_iconCtrl.text` 和（条件）`_composeCtrl.text`；完全替换 `_endpoints`。不触发重建：`_applyTemplate` 把它包在 `setState` 里，`initState` 则在首次构建前直接调用它。
- **算法：**
  1. 记录 `_templateId = template.id`。
  2. 从模板覆盖名字段和图标（存储 `_icon` 和其文本控制器两者）。
  3. 复制 `template.kind` 和 `template.runtime`。
  4. 把 `_endpoints` 重建为从 `template.endpoints` 逐字段克隆的新鲜 `ServiceEndpoint` 对象列表（新实例，非模板自己对象）。
  5. 模板 `dockerCompose` 非空时用其覆盖 `_composeCtrl.text`；否则用户已输入任何东西保持不动。
- **用法：**
  ```dart
  void _applyTemplate(ServiceTemplate template) {
    setState(() => _assignTemplate(template));
  }
  ```
- **备注：** 应用模板总是整体替换端点列表（不与手动添加端点合并）；Compose 文本只在模板实际提供一个时覆盖，因此切换到无 Compose 备注的模板保留既有文本。

### `Future<void> _save()` <a id="save"></a>
- **种类：** `_ServiceEditPageState` 的方法
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 217 行）
- **用途：** 验证表单、从当前草稿状态组装 `ServiceNode`、持久化并关闭页面。
- **输入：** 无（读取表单/控制器/字段状态）。
- **返回：** `Future<void>`。
- **副作用：** 调用 `ServiceStorage.addOrUpdateService`（本地文件系统 IO）；成功时以 `ServiceEditOutcome(saved: service)` 弹出路由。
- **算法：**
  1. 运行表单验证（`_formKey.currentState!.validate()`）；无效提前返回。
  2. 未选设备（`_deviceId == null`）提前返回。
  3. 构建 `ServiceNode`，复用 `existing?.id`（使编辑原地更新而非创建新记录）、`existing?.tags` 和 `existing?.extraJson` 不变；名/kind/runtime/state/端点来自当前草稿字段；经 `_emptyToNull` 转换备注和 Compose 文本，使空白文本存为 `null` 而非空字符串。
  4. Await `ServiceStorage.addOrUpdateService(service)`。
  5. 仍挂载时以 `ServiceEditOutcome(saved: service)` 弹出页面，使调用方既得知数据已变，也得知保存了什么。
- **用法：**
  ```dart
  IconButton(icon: const Icon(Icons.save), onPressed: _save),
  ```
- **备注：** 只有名字段有表单验证器（`serviceNameRequired`）；设备选择手动检查而非经 `Form` 验证链。端点列表内容这里不再验证——每个端点在添加或编辑时由 `showServiceEndpointDialog` 构建。

### `Future<void> _delete()` <a id="delete"></a>
- **种类：** `_ServiceEditPageState` 的方法
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 245 行）
- **用途：** 让用户确认，然后删除被编辑服务。
- **输入：** 无（用 `widget.service`）。
- **返回：** `Future<void>`。
- **副作用：** 显示确认 `AlertDialog`；确认时调用 `ServiceStorage.deleteService`（本地文件系统 IO）并以 `ServiceEditOutcome(deleted: true)` 弹出页面。
- **算法：**
  1. `widget.service` 为 null 提前返回（无可删除——删除按钮只在 `_editing` 时显示，因此这是防御守卫）。
  2. 显示要求确认删除命名服务的 `AlertDialog`，取消/删除操作返回 `false`/`true`。
  3. 用户确认时 await `ServiceStorage.deleteService(service.id)`，仍挂载时以 `ServiceEditOutcome(deleted: true)` 弹出页面。
- **用法：**
  ```dart
  if (_editing)
    IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
  ```
- **备注：** 这里删除只移除 `ServiceNode` 记录本身；引用此服务端点的任何 `ServiceRoute` 不由此方法清理（超出本文件范围）。

### `List<ServiceTemplate> get _filteredTemplates` <a id="filteredtemplates"></a>
- **种类：** `_ServiceTemplatePickerState` 的 getter
- **来源：** `lib/features/services/views/service_edit_page.dart`（第 624 行）
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
