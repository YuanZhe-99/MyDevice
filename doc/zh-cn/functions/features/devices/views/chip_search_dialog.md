# lib/features/devices/views/chip_search_dialog.dart

搜索 CPU/GPU 规格的模态对话框 UI，由 `lib/features/devices/services/chip_search_service.dart` 支撑。从 `device_edit_page.dart` 的"在线搜索"操作打开（见 [在线搜索与预设](../../../../features/online-search-and-presets.md) 的商店风格门控要求，调用点 3）并把所选 `CpuInfo`/`GpuInfo` 返回给编辑器。对话框自己无抓取逻辑——它把查询转发给 `ChipSearchService.searchCpu`/`searchGpu`（合并捆绑预设与活 TechPowerUp/AMD/Intel 结果）并渲染返回的任何东西。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`showCpuSearchDialog`](#showcpusearchdialog) | 函数 | A | 打开 CPU 搜索对话框并返回用户挑的 CPU。 |
| [`showGpuSearchDialog`](#showgpusearchdialog) | 函数 | A | 打开 GPU 搜索对话框并返回用户挑的 GPU。 |
| `_ChipSearchDialog`（构造函数） | 构造函数 | B | 为对话框组件存储搜索模式、初始查询和预设。 |
| `createState` | 方法（`_ChipSearchDialog`） | B | 创建对话框可变状态对象。 |
| `initState` | 方法（组件生命周期） | B | 用初始查询播种查询控制器。 |
| `dispose` | 方法（组件生命周期） | B | 释放查询文本控制器。 |
| [`_search`](#_search) | 方法（`_ChipSearchDialogState`） | A | 对 `ChipSearchService` 运行 CPU/GPU 搜索并更新对话框状态。 |
| `_select` | 方法（`_ChipSearchDialogState`） | B | 把所选结果转换为 `CpuInfo`/`GpuInfo` 弹出对话框。 |
| `build` | 方法（组件） | B | 构建对话框壳（页头、搜索栏、结果区）——宽 `dialogMaxWidth`，高 `dialogBodyHeight(窗口 − 键盘, preferred: 480)`。 |
| `_buildResults` | 方法（组件辅助） | B | 渲染搜索结果的加载/错误/空/列表状态。 |
| [`_coresLabel`](#_coreslabel) | 方法（`_ChipSearchDialogState`） | A | 把 CPU 结果的性能/效率核心数格式化为短标签。 |

## 文档

### `Future<CpuInfo?> showCpuSearchDialog(BuildContext context, {String? initialQuery, required List<CpuInfo> presets})` <a id="showcpusearchdialog"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/devices/views/chip_search_dialog.dart`（第 14 行）
- **用途：** 打开让用户搜索 CPU（在线源加捆绑预设）并挑一个的模态对话框。
- **输入：** `context` — 宿主 `BuildContext`；`initialQuery` — 预填搜索框的文本（如已输入设备编辑表单的 CPU 型号）；`presets` — 调用方加载的 `CpuInfo` 预设列表，原样传给 `ChipSearchService.searchCpu` 使预设匹配与活结果并排出现。
- **返回：** `Future<CpuInfo?>` — 所选 `CpuInfo`，对话框无选择关闭时 `null`。
- **副作用：** 经 `showDialog` 显示 `Dialog`；用户搜索后对话框本身触发网络请求。
- **算法：**
  1. 调用 `showDialog<CpuInfo>`，builder 以 `_ChipMode.cpu` 模式构造 `_ChipSearchDialog`，传 `initialQuery` 和 `cpuPresets: presets`（此模式永不用 `gpuPresets`，留空）。
  2. 返回对话框 `Navigator.pop` 调用解析 `showDialog` future 的任何值（见 [`_select`](#_select)）。
- **用法：**
  ```dart
  Future<void> _searchCpuOnline() async {
    final cpu = await showCpuSearchDialog(
      context,
      initialQuery: _cpuModelCtrl.text,
      presets: _cpuPresets,
    );
    if (cpu != null) _applyCpuPreset(cpu);
  }
  ```
  （来自 `lib/features/devices/views/device_edit_page.dart`，第 754 行）
- **备注：** 门控在与底层服务相同的商店风格规则后——见 [在线搜索与预设](../../../../features/online-search-and-presets.md) 了解四个必需门控调用点；此函数自己不检查 `AppFlavor`，触发它的搜索按钮才是商店构建在 `device_edit_page.dart` 中隐藏的东西。

### `Future<GpuInfo?> showGpuSearchDialog(BuildContext context, {String? initialQuery, required List<GpuInfo> presets})` <a id="showgpusearchdialog"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/devices/views/chip_search_dialog.dart`（第 37 行）
- **用途：** 打开让用户搜索 GPU（在线源加捆绑预设）并挑一个的模态对话框。
- **输入：** `context`；`initialQuery` — 预填搜索文本；`presets` — 调用方加载的 `GpuInfo` 预设列表，作为 `gpuPresets` 传入（`cpuPresets` 留空）。
- **返回：** `Future<GpuInfo?>` — 所选 `GpuInfo`，无挑选关闭时 `null`。
- **副作用：** 经 `showDialog` 显示 `Dialog`；搜索后触发网络请求。
- **算法：** 与 [`showCpuSearchDialog`](#showcpusearchdialog) 相同形态，但以 `_ChipMode.gpu` 模式构造 `_ChipSearchDialog`。
- **用法：**
  ```dart
  Future<void> _searchGpuOnline() async {
    final gpu = await showGpuSearchDialog(
      context,
      initialQuery: _gpuModelCtrl.text,
      presets: _gpuPresets,
    );
    if (gpu != null) _applyGpuPreset(gpu);
  }
  ```
  （来自 `lib/features/devices/views/device_edit_page.dart`，第 768 行）
- **备注：** 与 `showCpuSearchDialog` 相同的商店风格门控注意。

### `Future<void> _search()` <a id="_search"></a>
- **种类：** `_ChipSearchDialogState` 的方法
- **来源：** `lib/features/devices/views/chip_search_dialog.dart`（第 115 行）
- **用途：** 对 `ChipSearchService.searchCpu`/`searchGpu` 运行当前查询并把结果加载进对话框状态。
- **输入：** 无（读取 `_queryCtrl.text` 和外围状态的 `widget.mode`/`widget.cpuPresets`/`widget.gpuPresets`）。
- **返回：** `Future<void>`。
- **副作用：** 调用 `setState` 三次（加载开始、成功、空结果带本地化错误），经 `ChipSearchService` 做网络支撑异步调用，并修改 `_results`/`_searching`/`_error`。
- **算法：**
  1. 修剪查询文本；为空立即返回（空操作）。
  2. 设 `_searching = true`、清除 `_error` 并清除 `_results` 显示转圈。
  3. Await `ChipSearchService.searchCpu(query, widget.cpuPresets)` 或按 `widget.mode` 的 `searchGpu(query, widget.gpuPresets)`。
  4. 成功时检查 `mounted`，然后存储结果；结果列表为空时设 `_error` 为本地化 `searchNoResults` 字符串（仍用空结果状态而非独立"无结果"组件）。
  5. 任何抛出异常时检查 `mounted`、停止转圈并把 `e.toString()` 存为 `_error` 供显示。
- **用法：**
  ```dart
  onSubmitted: (_) => _search(),
  ...
  FilledButton(
    onPressed: _searching ? null : _search,
    child: Text(l10n.searchButton),
  ),
  ```
  （来自 `build`，`lib/features/devices/views/chip_search_dialog.dart` 第 216–223 行）
- **备注：** 底层 HTTP 抓取的错误（网络失败、解析错误）作为原始 `e.toString()` 文本浮出给用户而非友好消息——只有"无结果" case 本地化。

### `String _coresLabel(ChipSearchResult r)` <a id="_coreslabel"></a>
- **种类：** `_ChipSearchDialogState` 的方法
- **来源：** `lib/features/devices/views/chip_search_dialog.dart`（第 317 行）
- **用途：** 为 CPU 搜索结果副标题行构建短"P+E 核心"标签。
- **输入：** `r` — `performanceCores`/`efficiencyCores` 各可能存在或缺席的 `ChipSearchResult`。
- **返回：** `String` — 按哪些核心数已知，为 `'{p}P+{e}E'`、`'{p}C'`、`'{e}E'` 或 `''` 之一。
- **副作用：** 无。
- **算法：**
  1. `performanceCores` 和 `efficiencyCores` 都非 null 时格式化为 `'${p}P+${e}E'`（混合架构，如 Intel P/E 核心）。
  2. 否则只 `performanceCores` 已知时格式化为 `'${p}C'`（普通核心数）。
  3. 否则只 `efficiencyCores` 已知时格式化为 `'${e}E'`。
  4. 否则返回 `''`（副标题构建代码只在两者至少一个非 null 时包含此标签，因此空字符串分支正常使用中实际不可达）。
- **用法：**
  ```dart
  if (r.performanceCores != null || r.efficiencyCores != null)
    _coresLabel(r),
  ```
  （来自 `_buildResults`，`lib/features/devices/views/chip_search_dialog.dart` 第 272 行）
- **备注：** 只从 `_buildResults` 的 CPU 副标题构建分支调用；GPU 结果改直接用 `r.architecture`。
