# lib/features/network/views/network_edit_page.dart

单个 [`Network`](../models/network.md#network-new) 的增/改表单——名、类型下拉、子网/网关/DNS/备注字段。经一个构造函数参数为"添加"（`network: null`）和"编辑"（`network: existing`）复用，匹配本应用每个其他功能编辑页形态。经 [`NetworkStorage.addOrUpdateNetwork`](../services/network_storage.md#addorupdatenetwork) 保存。本页编辑的模型见 [网络](../../../../features/networks.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `NetworkEditPage`（构造函数） | 构造函数 | B | 创建页面组件（可选 `network` 供编辑）。 |
| `createState` | 方法（`NetworkEditPage`） | B | 创建页面可变状态对象。 |
| `_isEditing` | getter（`_NetworkEditPageState`） | B | 返回是否传入了既有 `Network`。 |
| `initState` | 方法（组件生命周期） | B | 从 `widget.network` 播种文本控制器和类型下拉。 |
| `dispose` | 方法（组件生命周期） | B | 释放五个文本控制器。 |
| `_nonEmpty` | 方法（`_NetworkEditPageState`） | B | 修剪字段文本，空白时返回 `null`。 |
| `_typeLabel` | 方法（`_NetworkEditPageState`） | B | 把 `NetworkType` 映射到其本地化标签。 |
| [`_save`](#save) | 方法（`_NetworkEditPageState`） | A | 验证表单、构建 `Network`、持久化并弹出。 |
| `build` | 方法（组件） | B | 构建脚手架：名/类型/子网/网关/DNS/备注表单字段。 |

行数（9）与 `grep -c 'Purpose:' network_edit_page.dart`（9）精确匹配。

## 文档

### `Future<void> _save()` <a id="save"></a>
- **种类：** `_NetworkEditPageState` 的方法。
- **来源：** `lib/features/network/views/network_edit_page.dart`（第 102 行）。
- **用途：** 验证表单、从当前字段值构建 `Network`、持久化并关闭页面。
- **输入：** 无（读取表单 `TextEditingController` 和 `_type`）。
- **返回：** `Future<void>`。
- **副作用：** 调用 `NetworkStorage.addOrUpdateNetwork`（写 `network_data.json`）；调用 `AutoSyncService.instance.notifySaved()`；仍挂载时弹出页面。
- **算法：** 1. 经 `_formKey` 验证表单；无效提前返回。2. 把 DNS 字段原始文本按任何逗号/分号/空白运行（`RegExp(r'[,;\s]+')`）拆分为非空服务器字符串列表，字段空白时 `[]`。3. 构造 `Network`，复用 `widget.network?.id`（编辑保留身份，添加铸造新 UUID——见 [`Network`](../models/network.md#network-new)），修剪 `name`，并把 `subnet`/`gateway`/`notes` 经 [`_nonEmpty`](#save) 传递使空白字段持久化为 `null` 而非空字符串。4. Await `NetworkStorage.addOrUpdateNetwork(network)`。5. 调用 `AutoSyncService.instance.notifySaved()`（在 `save()` 已内部做的通知之外——见 [`network_storage.md#save`](../services/network_storage.md)）。6. 组件仍挂载时弹出导航器。
- **用法：** 在 `build` 中接为应用栏保存 `TextButton.onPressed`。
- **备注：** DNS 拆分正则接受逗号、分号*或*空白作为可互换分隔符，因此相同服务器的逗号分隔列表和纯空格分隔列表解析为相同 `List<String>`。`_nonEmpty`（见上面 Tier B 行）正是把空白子网/网关/备注字段变成持久化 `Network` 中 `null` 而非空字符串的东西——这重要，因为 [`Network.toJson`](../models/network.md#network-tojson) 从写出的 JSON 完全省略 `null` 字段，但仍会写空字符串字段。
