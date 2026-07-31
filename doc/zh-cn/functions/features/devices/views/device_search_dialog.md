# lib/features/devices/views/device_search_dialog.dart

两阶段模态对话框，用于在线找设备并把所选字段导入编辑表单。由 `lib/features/devices/services/device_search_service.dart`（GSMArena / Notebookcheck 抓取，门控于 `AppFlavor.isStore`——见 [在线搜索与预设](../../../../features/online-search-and-presets.md)）和 `lib/shared/services/image_service.dart` 支撑下载匹配设备照片。从 `device_edit_page.dart`（用表单当前值预填，使预览能逐字段显示"当前 vs 获取"）和 `device_list_page.dart` 的搜索 FAB（无当前值打开，供给全新 `DeviceEditPage`）两者打开。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`showDeviceSearchDialog`](#showdevicesearchdialog) | 函数 | A | 打开设备搜索对话框并返回用户选择应用的字段映射。 |
| `_SearchDialog`（构造函数） | 构造函数 | B | 为对话框组件存储初始查询和所有"当前值"字段。 |
| `createState` | 方法（`_SearchDialog`） | B | 创建对话框可变状态对象。 |
| `initState` | 方法（组件生命周期） | B | 用初始查询播种查询控制器。 |
| `dispose` | 方法（组件生命周期） | B | 释放查询文本控制器。 |
| [`_search`](#_search) | 方法（`_SearchDialogState`） | A | 对 `DeviceSearchService` 运行设备搜索并更新对话框状态。 |
| [`_selectResult`](#_selectresult) | 方法（`_SearchDialogState`） | A | 为所选搜索结果获取完整详情并进入预览阶段。 |
| [`_initToggles`](#_inittoggles) | 方法（`_SearchDialogState`） | A | 基于结果有什么为每个可导入字段设置默认复选框状态。 |
| [`_fetchImage`](#_fetchimage) | 方法（`_SearchDialogState`） | A | 下载匹配设备照片并暂存为获取图像。 |
| [`_apply`](#_apply) | 方法（`_SearchDialogState`） | A | 从勾选切换组装要返回调用方的字段名 → 值映射。 |
| `build` | 方法（组件） | B | 构建对话框壳并在搜索/预览阶段间切换。 |
| `_buildSearchView` | 方法（组件辅助） | B | 渲染搜索阶段（页头、搜索栏、结果列表）。 |
| `_buildSearchResults` | 方法（组件辅助） | B | 渲染搜索结果的加载/错误/空/列表状态。 |
| `_buildPreviewView` | 方法（组件辅助） | B | 渲染预览阶段（来源徽章、字段列表、应用/取消按钮）。 |
| `_buildFieldList` | 方法（组件辅助） | B | 渲染每个可导入字段一个复选框行，加图像小节。 |
| `_imageColumn` | 方法（组件辅助） | B | 渲染含图像预览的带标签列。 |
| `_imagePreviewFrame` | 方法（组件辅助） | B | 把子组件包进圆形带边框图像预览框。 |
| `_fieldTile` | 方法（组件辅助） | B | 渲染一个字段复选框块，带当前/获取值文本。 |
| `_buildHeader` | 方法（组件辅助） | B | 渲染对话框标题行，带可选返回按钮。 |

行数说明：对此文件 `grep -c 'Purpose:'` 返回 18，比上面 19 行少一个。差异是 `showDeviceSearchDialog` 本身——其文档注释（第 10–11 行）是不带本文件每个其他声明使用的 `Purpose:` 标签的普通 `/// Shows the device search dialog. ...` 注释，因此不匹配 grep 模式，虽然它是真实、已文档化顶层函数并按"每个声明得一行"规则包含于此。

## 文档

### `Future<Map<String, dynamic>?> showDeviceSearchDialog(BuildContext context, {String? initialQuery, String? currentBrand, String? currentModel, String? currentChipset, String? currentGpu, String? currentRam, String? currentStorage, String? currentScreenSize, int? currentScreenResW, int? currentScreenResH, String? currentBattery, String? currentOs, DateTime? currentReleaseDate, String? currentImagePath})` <a id="showdevicesearchdialog"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/devices/views/device_search_dialog.dart`（第 12 行）
- **用途：** 打开两阶段设备搜索/预览对话框并返回用户选择导入的字段子集。
- **输入：** `initialQuery` — 预填搜索框的文本；`currentXxx` 参数是每个字段的编辑表单既有值，纯用于预览阶段"当前 vs 获取"比较的显示（不影响搜索行为）。都可选——列表页调用点（`showDeviceSearchDialog(context)`）一个都不传。
- **返回：** `Future<Map<String, dynamic>?>` — 按字段名键控（`brand`、`model`、`chipset`、`gpuName`、`ram`、`storage`、`screenSize`、`screenResolutionW`/`screenResolutionH`、`battery`、`os`、`releaseDate`、`image`）、只含用户勾选字段的映射，对话框被关闭时 `null`。
- **副作用：** 经 `showDialog` 显示 `Dialog`；对话框随后随用户交互触发网络请求（搜索、详情获取、图像下载）。
- **算法：**
  1. 调用 `showDialog<Map<String, dynamic>>`，builder 构造 `_SearchDialog`，原样转发每个参数。
  2. 返回 `Navigator.pop` 解析对话框 future 的任何值——映射如何构建见 [`_apply`](#_apply)。
- **用法：**
  ```dart
  final result = await showDeviceSearchDialog(
    context,
    initialQuery: query,
    currentBrand: _nonEmpty(_brandCtrl.text),
    currentModel: _nonEmpty(_modelCtrl.text),
    currentChipset: _nonEmpty(_cpuModelCtrl.text),
    currentGpu: _nonEmpty(_gpuModelCtrl.text),
    currentRam: _combineValueUnit(_ramCtrl.text, _ramUnit),
    ...
  );
  ```
  （来自 `lib/features/devices/views/device_edit_page.dart`，第 816 行——编辑既有设备）和无当前值上下文的 `final result = await showDeviceSearchDialog(context);`（来自 `lib/features/devices/views/device_list_page.dart`，第 230 行——添加全新设备）。
- **备注：** 此函数自己不执行 `AppFlavor` 检查；按 [在线搜索与预设](../../../../features/online-search-and-presets.md)，通往这里的在线搜索入口点（`device_list_page.dart` 的 FAB、`device_edit_page.dart` 的搜索操作）才是商店构建隐藏的东西。

### `Future<void> _search()` <a id="_search"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/devices/views/device_search_dialog.dart`（第 144 行）
- **用途：** 对 `DeviceSearchService.search` 运行当前查询并把结果加载进对话框状态。
- **输入：** 无（读取 `_queryController.text`）。
- **返回：** `Future<void>`。
- **副作用：** 三个 `setState` 调用（开始、成功、失败）；跨 GSMArena 和 Notebookcheck 执行网络支撑搜索。
- **算法：**
  1. 修剪查询；为空立即返回。
  2. 设 `_searching = true`、清除 `_error` 和 `_results`。
  3. Await `DeviceSearchService.search(query)`。
  4. 成功时检查 `mounted`、存储结果，列表为空时设 `_error` 为本地化 `searchNoResults` 字符串。
  5. 异常时检查 `mounted`、停止转圈并把 `e.toString()` 存为 `_error`。
- **用法：** 接到 `_buildSearchView` 中搜索栏 `onSubmitted` 和"搜索"`FilledButton`（`lib/features/devices/views/device_search_dialog.dart`，第 357–364 行）。
- **备注：** 与 `chip_search_dialog.dart` 的 `_ChipSearchDialogState._search` 相同模式——除空结果集外任何东西的原始异常文本显示给用户。

### `Future<void> _selectResult(DeviceSearchResult result)` <a id="_selectresult"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/devices/views/device_search_dialog.dart`（第 178 行）
- **用途：** 为点击搜索结果切换到预览阶段并获取其完整详情页。
- **输入：** `result` — 用户点击结果列表的 `DeviceSearchResult`（典型为 `DeviceSearchService.search` 的仅摘要结果）。
- **返回：** `Future<void>`。
- **副作用：** `setState` 立即进入 `_Phase.preview`（显示加载状态），然后详情获取解析后另一个 `setState`；经 `DeviceSearchService.fetchDetail` 做网络请求。
- **算法：**
  1. 立即设 `_selected = result`、`_phase = _Phase.preview`、`_fetchingDetail = true` 并清除任何先前获取图像状态和切换。
  2. Await `DeviceSearchService.fetchDetail(result)` 获取完整填充结果（详情页比搜索结果摘要带更多字段）。
  3. 成功时检查 `mounted`、用详情结果替换 `_selected`、清除加载标志并在详情结果上调用 [`_initToggles`](#_inittoggles)。
  4. 失败时检查 `mounted`、清除加载标志并改在原始（仅摘要）`result` 上调用 `_initToggles`——使预览仍显示摘要已有任何字段，而非失败整个流程。
- **用法：** `_buildSearchResults` 中的 `onTap: () => _selectResult(r),`（`lib/features/devices/views/device_search_dialog.dart`，第 427 行）。
- **备注：** 失败详情获取被静默吞掉（无错误消息显示）——用户只看到比成功获取会提供的更少字段切换/可用的预览。

### `void _initToggles(DeviceSearchResult r)` <a id="_inittoggles"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/devices/views/device_search_dialog.dart`（第 210 行）
- **用途：** 基于搜索结果实际有哪些字段设置每个字段导入复选框的默认勾选/未勾选状态。
- **输入：** `r` — 要检查的 `DeviceSearchResult`（摘要或详情）。
- **返回：** `None`。
- **副作用：** 填充 `_toggles`（`Map<String, bool>`）；自己不调用 `setState`（调用方把它包进自己的 `setState`）。
- **算法：** 对 `brand`、`model`、`chipset`、`gpuName`、`ram`、`storage`、`screenSize`、`battery`、`os` 各：字段是非空字符串时设 `_toggles[key] = true`。对 `screenResolutionW`/`releaseDate`（非字符串字段），检查非 null 而非非空。唯一例外是 `image`：`r.imageUrl != null` 时 `_toggles['image']` 设为 `false`——图像复选框存在但从**未勾选**开始，因为获取它是单独、显式用户操作（见 [`_fetchImage`](#_fetchimage)）。结果缺席的任何字段完全无 `_toggles` 条目（因此下游 `_toggles[key] ?? false` 把它当作未勾选，且 `_buildFieldList` 不渲染该字段块）。
- **用法：** 从 [`_selectResult`](#_selectresult) 两个分支调用——成功（`_initToggles(detail)`）和失败（`_initToggles(result)`）。
- **备注：** 图像字段是唯一存在却默认关闭的，这是刻意的（下载照片是用户应选择加入的网络成本，不像已是详情响应一部分获取的文本字段）。

### `Future<void> _fetchImage()` <a id="_fetchimage"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/devices/views/device_search_dialog.dart`（第 230 行）
- **用途：** 把所选结果的 `imageUrl` 下载到本地存储并暂存为预览的"获取"图像候选。
- **输入：** 无（读取 `_selected?.imageUrl`）。
- **返回：** `Future<void>`。
- **副作用：** 围绕网络下载（`ImageService.saveImageFromUrl`）和文件解析（`ImageService.resolve`）的 `setState`；错误时经 `ScaffoldMessenger` 显示 `SnackBar`。
- **算法：**
  1. `_selected?.imageUrl` 为 null 时立即返回。
  2. 设 `_fetchingImage = true`。
  3. Await `ImageService.saveImageFromUrl(_selected!.imageUrl!)`，它下载图像并返回本地路径（保存失败 `null`）。
  4. 有路径返回且组件仍挂载时 await `ImageService.resolve(path)` 获取 `File`，然后设 `_fetchedImagePath`、`_imagePreview = FileImage(file)`、`_toggles['image'] = true`（现在有获取图像自动勾选框）并清除加载标志。
  5. `path` 为 null 时只清除加载标志（无暂存图像，复选框保持未勾选）。
  6. 任何抛出异常时清除加载标志并在 `SnackBar` 显示异常文本。
- **用法：** `_buildFieldList` 中"获取图像"`TextButton.icon` 的 `onPressed: _fetchImage,`（`lib/features/devices/views/device_search_dialog.dart`，第 596 行），只在 `_fetchedImagePath == null` 且尚未获取时显示。
- **备注：** 与 `_search`/`_selectResult` 不同，这里失败经 `SnackBar` 而非内联错误文本浮出，因为预览对话框其余部分无论如何保持可用。

### `void _apply()` <a id="_apply"></a>
- **种类：** `_SearchDialogState` 的方法
- **来源：** `lib/features/devices/views/device_search_dialog.dart`（第 261 行）
- **用途：** 为每个勾选切换构建字段名 → 值映射并带它关闭对话框。
- **输入：** 无（读取 `_selected`、`_toggles`、`_fetchedImagePath`）。
- **返回：** `void`。
- **副作用：** `Navigator.of(context).pop(result)`——关闭对话框并解析 `showDeviceSearchDialog` future。
- **算法：**
  1. `_selected` 为 null 时立即返回（无可应用）。
  2. 对 `brand`、`model`、`chipset` → `chipset`、`gpuName` → `gpuName`（切换中键 `'gpu'` 映射到结果键 `'gpuName'`）、`ram`、`storage`、`screenSize`、`battery`、`os`、`releaseDate` 各：对应切换为 `true` 且源字段非 null 时按其结果字段名加入输出映射。
  3. `resolution` 特殊处理：切换勾选时独立添加 `screenResolutionW` 和 `screenResolutionH` **两者**（各只在结果上非 null 时）——单个切换因此可加至多两个映射键。
  4. `image` 只在切换勾选**且** `_fetchedImagePath != null`（即用户必须既勾选框又成功运行 `_fetchImage`）时添加，用本地文件路径作为值（非远程 URL）。
  5. 带组装映射弹出对话框。
- **用法：** `_buildPreviewView` 中的 `onPressed: _toggles.values.any((v) => v) && !_fetchingDetail ? _apply : null,`（`lib/features/devices/views/device_search_dialog.dart`，第 490–492 行）——除非至少一个切换勾选且详情获取已完成，否则应用按钮禁用。
- **备注：** GPU 的切换键（`'gpu'`）刻意不同于输出映射键（`'gpuName'`）和结果字段名（`r.gpuName`）——扩展字段列表时这容易漏，因为每个其他字段切换键和输出键用相同字符串。
