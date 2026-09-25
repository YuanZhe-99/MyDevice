# lib/features/services/views/service_endpoint_dialog.dart

服务编辑页（[service_edit_page.md](service_edit_page.md)）与引导式访问路径页的内联「添加端点」共用的端点编辑对话框（`_ServiceEndpointDialog`）。它编辑一个 `ServiceEndpoint`——标签、协议、传输、端口和端口结束、绑定地址、路径、范围和主标志——并返回结果而不持久化；由调用方决定把端点留在表单里还是立即保存。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`showServiceEndpointDialog`](#showserviceendpointdialog) | 顶层函数 | A | 显示端点对话框并返回用户保存的内容。 |
| `_ServiceEndpointDialog` 构造函数 | 构造函数（`_ServiceEndpointDialog`） | B | 对话框组件（初始端点、默认主标志）。 |
| `createState` | 方法（`_ServiceEndpointDialog`） | B | 创建对话框状态。 |
| `initState` | 方法（`_ServiceEndpointDialogState`） | B | 从初始端点或默认值播种五个控制器和下拉框。 |
| `dispose` | 方法（`_ServiceEndpointDialogState`） | B | 释放控制器——在关闭动画之后。 |
| `_submit` | 方法（`_ServiceEndpointDialogState`） | B | 弹出字段所描述的端点。 |
| `build` | 方法（组件构建，`_ServiceEndpointDialogState`） | B | 端点表单：标签、协议、传输、端口、绑定地址、路径、范围、主标志。 |
| `_emptyToNull` | 顶层函数 | B | 修剪字段值并把空结果转换为 null。 |

## 文档

### `Future<ServiceEndpoint?> showServiceEndpointDialog(BuildContext context, {ServiceEndpoint? initial, required bool defaultPrimary})` <a id="showserviceendpointdialog"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/services/views/service_endpoint_dialog.dart`（第 18 行）
- **用途：** 显示创建或编辑一个 `ServiceEndpoint` 的模态对话框并返回它。
- **输入：** `context`；`initial` — 要编辑的端点，或 null 表示添加新端点；`defaultPrimary` — 新端点开始时是否勾选主复选框。
- **返回：** `Future<ServiceEndpoint?>` — 点保存后构建的端点；用户取消或关闭对话框时为 null。
- **副作用：** 显示对话框。不向存储写入任何内容。
- **算法：**
  1. 用 `showDialog` 显示 `_ServiceEndpointDialog`；它从 `initial`，或从默认值 `http`、`tcp` 和 `lan`，播种文本控制器以及协议 / 传输 / 范围下拉框，并让主复选框初始为 `initial?.isPrimary ?? defaultPrimary`。
  2. 保存时（`_submit`），对话框弹出一个保留 `initial` 的 id 和 `extraJson` 的 `ServiceEndpoint`；空白的标签、绑定地址和路径经 `_emptyToNull` 变为 null，端口用 `int.tryParse` 解析（无法解析的文本变为 null）。
  3. 对话框状态在自己的 `dispose` 中释放其五个控制器，此时路由已经移除。
- **用法：**
  ```dart
  final endpoint = await showServiceEndpointDialog(
    context,
    defaultPrimary: _endpoints.isEmpty,
  );
  if (endpoint != null) setState(() => _endpoints.add(endpoint));
  ```
- **备注：** 1.5.6 中从服务编辑页的私有 `_showEndpointDialog` 移来。有两处变化：「第一个端点默认为主」的决定现在由调用方的 `defaultPrimary` 给出，因为引导式页面会给并不在表单中持有的服务添加端点；对话框也成为独立的有状态组件，因为旧代码在 `showDialog` 返回后立即释放控制器——而此时关闭动画仍在重建字段，这会在调试构建中触发断言。
