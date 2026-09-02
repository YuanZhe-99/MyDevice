# lib/features/network/views/network_detail_page.dart

单个 [`Network`](../models/network.md#network-new) 的详情屏：其信息卡片、可排序/分组的已分配设备列表（[`NetworkDevice`](../models/network.md#networkdevice-new)）、那些设备的地图视图（经 [`DeviceMapPage`](../../../shared/views/device_map_page.md)），和由 [`NetworkStorage`](../services/network_storage.md) 支撑的赋值增/改/移除流程。编辑/配置对话框直接构造 `NetworkDevice` 值而非经 `copyWith`。`NetworkDevice` 为何无 `id`/`modifiedAt`、这对 [`setAssignment`](../services/network_storage.md#setassignment) 如何匹配既有赋值（按 `(networkId, deviceId)` 对，非 id）意味着什么见 [网络](../../../../features/networks.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `NetworkDetailPage`（构造函数） | 构造函数 | B | 创建页面组件（必填 `networkId`）。 |
| `createState` | 方法（`NetworkDetailPage`） | B | 创建页面可变状态对象。 |
| [`initState`](#initstate) | 方法（组件生命周期） | A | 启动加载排序偏好，然后网络/设备/赋值数据。 |
| [`_loadSortPrefs`](#loadsortprefs) | 方法（`_NetworkDetailPageState`） | A | 从设备存储配置加载持久化排序模式/方向/分组/退出优先标志。 |
| [`_saveSortPrefs`](#savesortprefs) | 方法（`_NetworkDetailPageState`） | A | 把那四个排序相关标志持久化到设备存储配置。 |
| [`_compareIp`](#compareip) | 方法（`_NetworkDetailPageState`） | A | 逐八位组数字比较两个点分四组 IP 字符串。 |
| [`_sortedAssignments`](#sortedassignments) | getter（`_NetworkDetailPageState`） | A | 按当前排序模式、方向、分组和退出优先设置排序/分组/重排 `_assignments`。 |
| `_categoryLabel` | 方法（`_NetworkDetailPageState`） | B | 把 `DeviceCategory` 映射到其本地化标签。 |
| `_sortModeLabel` | 方法（`_NetworkDetailPageState`） | B | 把 `NetworkDeviceSortMode` 映射到其本地化标签。 |
| [`_load`](#load) | 方法（`_NetworkDetailPageState`） | A | 从存储重载网络、其赋值和完整设备列表。 |
| `_findDevice` | 方法（`_NetworkDetailPageState`） | B | 在加载设备列表按 id 查找设备。 |
| `_typeLabel` | 方法（`_NetworkDetailPageState`） | B | 把 `NetworkType` 映射到其本地化标签。 |
| `_addressModeLabel` | 方法（`_NetworkDetailPageState`） | B | 把 `AddressMode` 映射到其本地化标签。 |
| [`_deleteNetwork`](#deletenetwork) | 方法（`_NetworkDetailPageState`） | A | 确认并接受时删除此网络并弹出。 |
| [`_addDevice`](#adddevice) | 方法（`_NetworkDetailPageState`） | A | 挑未分配设备、配置其赋值并持久化。 |
| [`_editAssignment`](#editassignment) | 方法（`_NetworkDetailPageState`） | A | 为既有赋值重新打开赋值配置对话框并持久化变更。 |
| [`_removeAssignment`](#removeassignment) | 方法（`_NetworkDetailPageState`） | A | 确认并接受时从此网络移除设备赋值。 |
| [`_showAssignmentDialog`](#showassignmentdialog) | 方法（`_NetworkDetailPageState`） | A | 为一个赋值显示地址模式/IP/主机名/退出节点配置对话框。 |
| `build` | 方法（组件） | B | 围绕 `_buildBody` 构建脚手架：应用栏（地图/编辑/删除操作）。 |
| `_buildBody` | 方法（组件辅助） | B | 选择布局：单个 `ListView`（信息卡，然后设备页头与列表），除非 `useDetailTwoPane` 通过——此时是一个 `Row`：`detailLeftPaneWidth` 宽的可滚动信息卡加右侧设备 children 的 `ListView`。 |
| `_buildInfoCard` | 方法（组件辅助） | B | 网络信息卡片（类型 logo、类型、子网、网关、DNS、备注），从 `build` 原样抽出。 |
| `_buildDevicesChildren` | 方法（组件辅助） | B | 设备页头行加分配列表或其空态卡片，从 `build` 原样抽出。 |
| `_buildDeviceList` | 方法（组件辅助） | B | 构建设备卡片列表，分组开启时插入类别页头。 |
| `_buildDeviceCard` | 方法（组件辅助） | B | 渲染一个赋值的卡片（设备名、模式/IP/主机名/退出节点副标题、编辑/移除菜单）。 |
| `_infoRow` | 方法（组件辅助） | B | 在网络信息卡片渲染一个标签/值行。 |
| `_DevicePicker`（构造函数） | 构造函数 | B | 为选择器面板存储未分配设备列表。 |
| `_DevicePicker.build` | 方法（组件） | B | 渲染要挑选设备的底部面板列表。 |

行数（24）与 `grep -c 'Purpose:' network_detail_page.dart`（24）精确匹配。

## 文档

### `void initState()` <a id="initstate"></a>
- **种类：** `_NetworkDetailPageState` 的方法（组件生命周期覆盖）。
- **来源：** `lib/features/network/views/network_detail_page.dart`（第 48 行）。
- **用途：** 启动初始偏好加载，然后网络/赋值/设备数据加载。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 启动异步加载链。
- **算法：** 调用 `super.initState()`，然后链 `_loadSortPrefs().then((_) => _load())`。
- **用法：** `_NetworkDetailPageState` 首次插入树时由 Flutter 框架自动调用；无直接调用点。
- **备注：** 与本应用列表页不同，本页无 `dispose()` 覆盖且不向 `AutoSyncService` 注册本地数据变更通知——它只在自身增/改/删/移除操作后（见下面每个方法）和 `build` 中从编辑网络压入返回后显式重载。

### `Future<void> _loadSortPrefs()` <a id="loadsortprefs"></a>
- **种类：** `_NetworkDetailPageState` 的方法。
- **来源：** `lib/features/network/views/network_detail_page.dart`（第 59 行）。
- **用途：** 从设备存储配置加载持久化排序模式、排序方向、类别分组标志和退出节点优先标志，回退默认。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `DeviceStorage.readConfig()` 读取配置；调用 `setState`。
- **算法：** 读取配置映射；把 `'netDetailSortMode'` 对照 `NetworkDeviceSortMode.values` 按 `.name` 解析 `_sortMode`（默认 `deviceOrder`）；从 `'netDetailSortAscending'`/`'netDetailGroupByCategory'`/`'netDetailExitFirst'` 解析 `_sortAscending`/`_groupByCategory`/`_exitNodeFirst`（都默认 `false`）；经一次 `setState` 应用全部四个。
- **用法：** [`initState`](#initstate) 构造后链接。
- **备注：** 这四个配置键（`netDetailSortMode`、`netDetailSortAscending`、`netDetailGroupByCategory`、`netDetailExitFirst`）不同于 `NetworkListPage` 的 `networkSortMode`/`networkSortAscending`——网络列表和每个网络的设备列表独立排序。

### `Future<void> _saveSortPrefs()` <a id="savesortprefs"></a>
- **种类：** `_NetworkDetailPageState` 的方法。
- **来源：** `lib/features/network/views/network_detail_page.dart`（第 82 行）。
- **用途：** 把当前排序模式、方向、分组标志和退出优先标志持久化回设备存储配置。
- **输入：** 无（读取四个对应状态字段）。
- **返回：** `Future<void>`。
- **副作用：** 经 `DeviceStorage.readConfig()`/`writeConfig()` 读取然后写配置。
- **算法：** 读取既有配置映射、覆盖全部四个键、写回整个映射。
- **用法：** 从 `build` 中排序菜单 `onSelected` 处理器调用，每个切换修改其状态字段后。
- **备注：** 无。

### `int _compareIp(String? a, String? b)` <a id="compareip"></a>
- **种类：** `_NetworkDetailPageState` 的方法。
- **来源：** `lib/features/network/views/network_detail_page.dart`（第 96 行）。
- **用途：** 数字（逐八位组）而非字典序比较两个点分四组 IP 地址字符串，使单数字末八位组的地址在同前缀下正确排在双数字末八位组前（普通字符串比较会弄反）。
- **输入：** `a`、`b` — 可空 IP 字符串。
- **返回：** `int` — 标准比较器契约；无论哪侧 null，null 总是排最后。
- **副作用：** 无。
- **算法：** 1. 两者都 `null` 返回 `0`。2. 只有 `a` 为 `null` 返回 `1`（排后）；只有 `b` 为 `null` 返回 `-1`。3. 把每个字符串按 `'.'` 拆分并对每个部分 `int.tryParse(s) ?? 0`（格式错误八位组降级为 `0` 而非抛）。4. 至多前 4 部分成对比较，返回第一个非零比较。5. 所有比较部分相等时回退对原始字符串的普通字符串 `compareTo`（少于 4 个点分部分、或数字八位组相同地址的打破平局）。
- **用法：** 用作 [`_sortedAssignments`](#sortedassignments) 内 `NetworkDeviceSortMode.ip` case 的比较器：`(a, b) => _compareIp(a.ipAddress, b.ipAddress)`。
- **备注：** 格式错误八位组（非数字）静默变为 `0` 供比较，而非当作"无效"——这可比直觉把格式错误地址放得更早，但绝不抛。

### `List<NetworkDevice> get _sortedAssignments` <a id="sortedassignments"></a>
- **种类：** `_NetworkDetailPageState` 的 getter。
- **来源：** `lib/features/network/views/network_detail_page.dart`（第 114 行）。
- **用途：** 产生最终显示赋值列表：按活动 `NetworkDeviceSortMode` 和方向排序、可选按设备类别分组、可选把退出节点赋值拉到前面。
- **输入：** 无（读取 `_assignments`、`_sortMode`、`_sortAscending`、`_groupByCategory`、`_exitNodeFirst`、`_allDevices`）。
- **返回：** `List<NetworkDevice>` — 新列表；`_assignments` 本身绝不被修改。
- **副作用：** 无。
- **算法：** 1. 把 `_assignments` 复制进 `list`。2. 经对 `_sortMode` 的 `switch` 构建 `comparator`：`deviceOrder` 比较每个赋值设备在 `_allDevices` 中的索引；`alphabetical` 不区分大小写比较设备名（设备缺失回退原始 `deviceId`）；`ip` 委托 [`_compareIp`](#compareip)。3. 包装比较器尊重 `_sortAscending`（升序时交换参数顺序）。4. `_groupByCategory` 时：先按每个赋值设备的 `DeviceCategory.index` 排序（缺失设备默认 `DeviceCategory.other`），每类别组内回退有效比较器。否则直接按有效比较器排序整个列表。5. `_exitNodeFirst` 时：把（已排序）列表分区为 `isExitNode == true` 和 `false`，先连接退出——这在主排序/分组*后*发生，因此退出节点作为整块拉到前面，不打扰步骤 2–4 在每个分区内建立的相对顺序。
- **用法：** `_buildDeviceList` 顶部读取（本文件，第 641 行）：`final sorted = _sortedAssignments;`。
- **备注：** 退出节点优先分区最后应用且独立于分组——同时开启 `_groupByCategory` 和 `_exitNodeFirst` 仍显示每个退出节点在每非退出节点前，类别页头也不例外（即 `_exitNodeFirst` 实际在列表最顶层覆盖严格类别分组）。

### `Future<void> _load()` <a id="load"></a>
- **种类：** `_NetworkDetailPageState` 的方法。
- **来源：** `lib/features/network/views/network_detail_page.dart`（第 199 行）。
- **用途：** 重载此网络自己的记录、其设备赋值和完整设备列表（把赋值 `deviceId` 解析为名/类别需要）。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 经 `NetworkStorage.load()` 和 `DeviceStorage.load()` 读取；`setState` 更新 `_network`、`_assignments`、`_allDevices`。
- **算法：** Await 两个加载、未挂载提前返回，然后设：`_network` 为 `netData.networks` 中 `id == widget.networkId` 的条目（网络在别处被删时 `null`）；`_assignments` 为 `netData.assignments` 中 `networkId == widget.networkId` 的每个条目；`_allDevices` 为完整设备列表。
- **用法：** 从 [`initState`](#initstate)（偏好加载后）和本文件每个增/改/删/移除操作后调用。
- **备注：** `_network` 解析为 `null` 时（网络被删，如经同步从另一设备、本页打开时），`build` 无限显示加载转圈而非错误状态——无显式"网络未找到" UI 路径。

### `Future<void> _deleteNetwork()` <a id="deletenetwork"></a>
- **种类：** `_NetworkDetailPageState` 的方法。
- **来源：** `lib/features/network/views/network_detail_page.dart`（第 258 行）。
- **用途：** 显示确认对话框，确认时删除此网络并离开页面。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 显示 `AlertDialog`；确认时调用 `NetworkStorage.deleteNetwork(widget.networkId)`、`AutoSyncService.instance.notifySaved()` 并弹出页面。
- **算法：** 1. 显示带取消/删除的 `AlertDialog`，await `bool?`。2. `true` 时：await `NetworkStorage.deleteNetwork`（它也级联删除每个引用此网络的赋值——见 [`network_storage.md#deletenetwork`](../services/network_storage.md)）、调用 `notifySaved()`，仍挂载时弹出。
- **用法：** 接到应用栏删除 `IconButton.onPressed`。
- **备注：** 无。

### `Future<void> _addDevice()` <a id="adddevice"></a>
- **种类：** `_NetworkDetailPageState` 的方法。
- **来源：** `lib/features/network/views/network_detail_page.dart`（第 289 行）。
- **用途：** 让用户挑在用、尚未分配的设备，配置其地址模式/IP/主机名/退出节点标志，并持久化新赋值。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 显示模态底部面板（`_DevicePicker`，本文件）和（挑了设备时）赋值配置对话框；调用 `NetworkStorage.setAssignment`、`AutoSyncService.instance.notifySaved()` 并重载。
- **算法：** 1. 计算 `available` — 每个 `isInService` 且（按 `deviceId`）不在 `_assignments` 的设备。2. `available` 为空时立即返回（完全无 UI 显示——那种 case 下 FAB/按钮点击静默空操作）。3. 在模态底部面板显示 `_DevicePicker`，await 挑的 `Device?`；`null` 或未挂载返回。4. 显示带新鲜 `NetworkDevice(networkId: widget.networkId, deviceId: device.id)`（默认 `dhcp`、无 IP/主机名、非退出节点）播种的 [`_showAssignmentDialog`](#showassignmentdialog)，await 配置 `NetworkDevice?`。5. 非 null 时：await `NetworkStorage.setAssignment(result)`、调用 `notifySaved()` 并重载。
- **用法：** 接到 `build` 设备页头行"Add device"`TextButton.icon.onPressed`。
- **备注：** 因为 `available` 排除退役/出售设备（`isInService` 检查），离开服务的设备即使其历史赋值（如有）可能仍来自此前也不在这里提供——匹配 [设备 — 退役/出售/删除的级联规则](../../../../features/devices.md#cascade-rules-on-retiresell-delete) 的级联规则，那里离开服务实际经 `DeviceStorage` 自己清理移除任何既有赋值。

### `Future<void> _editAssignment(NetworkDevice assignment)` <a id="editassignment"></a>
- **种类：** `_NetworkDetailPageState` 的方法。
- **来源：** `lib/features/network/views/network_detail_page.dart`（第 320 行）。
- **用途：** 用既有赋值值预填重新打开赋值配置对话框，并持久化任何变更。
- **输入：** `assignment` — 要编辑的既有 `NetworkDevice`。
- **返回：** `Future<void>`。
- **副作用：** 显示 [`_showAssignmentDialog`](#showassignmentdialog)；有结果返回时调用 `NetworkStorage.setAssignment`、`AutoSyncService.instance.notifySaved()` 并重载。
- **算法：** Await `_showAssignmentDialog(l10n, assignment)`；结果非 null 时 await `NetworkStorage.setAssignment(result)`（按 `(networkId, deviceId)` 对匹配并替换——见 [`network_storage.md#setassignment`](../services/network_storage.md)）、调用 `notifySaved()` 并重载。
- **用法：** 从 `_buildDeviceCard`（本文件，第 674 行）每卡片 `PopupMenuButton` 的 `'edit'` 项选择。
- **备注：** 因为 `NetworkDevice` 无 `id`，这里"编辑"赋值实际是"用新构造的替换匹配此 `(networkId, deviceId)` 对的赋值"——见 [网络 — 复合键身份及其原因](../../../../features/networks.md#composite-key-identity--and-why)。

### `Future<void> _removeAssignment(NetworkDevice assignment)` <a id="removeassignment"></a>
- **种类：** `_NetworkDetailPageState` 的方法。
- **来源：** `lib/features/network/views/network_detail_page.dart`（第 335 行）。
- **用途：** 显示确认对话框，确认时从此网络移除设备赋值。
- **输入：** `assignment` — 要移除的 `NetworkDevice`。
- **返回：** `Future<void>`。
- **副作用：** 显示 `AlertDialog`；确认时调用 `NetworkStorage.removeAssignment`、`AutoSyncService.instance.notifySaved()` 并重载。
- **算法：** 1. 显示带取消/删除的 `AlertDialog`，await `bool?`。2. `true` 时：await `NetworkStorage.removeAssignment(assignment.networkId, assignment.deviceId)`、调用 `notifySaved()` 并重载。
- **用法：** 从 `_buildDeviceCard` 每卡片 `PopupMenuButton` 的 `'remove'` 项选择。
- **备注：** 无。

### `Future<NetworkDevice?> _showAssignmentDialog(AppLocalizations l10n, NetworkDevice initial)` <a id="showassignmentdialog"></a>
- **种类：** `_NetworkDetailPageState` 的方法。
- **来源：** `lib/features/network/views/network_detail_page.dart`（第 369 行）。
- **用途：** 显示配置一个赋值地址模式、IP 地址、主机名和退出节点标志、从 `initial` 播种的模态对话框。
- **输入：** `l10n`；`initial` — 播种对话框字段的 `NetworkDevice`（"添加"为新鲜未保存实例，"编辑"为既有）。
- **返回：** `Future<NetworkDevice?>` — 用户保存时配置的 `NetworkDevice`，取消时 `null`。
- **副作用：** 显示 `StatefulBuilder` 支撑、带本地对话框状态（`mode`、两个 `TextEditingController`、`isExit`）的 `AlertDialog`，该状态直到按保存才写回页面自己的状态。
- **算法：** 1. 从 `initial` 播种本地对话框状态。2. 构建含 `DropdownButtonFormField<AddressMode>`、两个 `TextField`（IP、主机名）和 `CheckboxListTile`（退出节点）、全部接到 `setDialogState` 使对话框独立于其后页面重建的 `AlertDialog`。3. 取消无值弹出。4. 保存读取修剪 IP/主机名文本（空字符串变 `null`）并带从 `initial.networkId`/`initial.deviceId`（身份字段绝不变）、对话框 `mode`/`ip`/`hostname`/`isExit` 和 `initial.extraJson`（原样保留）构建的新 `NetworkDevice` 弹出。
- **用法：** 被 [`_addDevice`](#adddevice)（带新鲜 `NetworkDevice`）和 [`_editAssignment`](#editassignment)（带既有）两者调用。
- **备注：** 此对话框直接构造返回 `NetworkDevice` 而非经 `NetworkDevice.copyWith`——每个字段（含 `copyWith` 甚至不暴露为参数的 `networkId`/`deviceId`）都显式传。
