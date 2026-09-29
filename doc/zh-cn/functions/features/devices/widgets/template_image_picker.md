# lib/features/devices/widgets/template_image_picker.dart

缩略图选择器：一个模态底部面板，内含可搜索的内置模板缩略图网格，最佳候选缩略图排在前面；当自动匹配落空（设备名称与其模板不同）时，用户可借此为设备挑选手选缩略图。它依赖 [`PresetService`](../services/preset_service.md)——`loadTemplates` 提供目录，[`rankTemplateImageCandidates`](../services/preset_service.md#ranktemplateimagecandidates) 决定顺序——依赖 [`DeviceAvatar`](device_avatar.md) 绘制每个格子，并依赖 [`adaptive_layout.md`](../../../shared/utils/adaptive_layout.md) 的 `sheetInitialSize` / `sheetMaxSize` 决定面板尺寸。唯一调用点是 [`device_edit_page.dart`](../views/device_edit_page.md) 中的 `_chooseThumbnail`，它把结果保存为设备的 `templateImage`。见 [设备 — 图标与图片](../../../../features/devices.md#icon-and-image) 和 [在线搜索与预设 — 设备缩略图](../../../../features/online-search-and-presets.md#device-thumbnails)。按本文档集分层规则，`build()` 方法和私有组件组合辅助方法为 Tier B。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`TemplateImageChoice`](#templateimagechoice)（构造函数） | const 构造函数 | A | 创建模板图片选择实例；包装资产，使关闭面板与「自动」可以区分。 |
| [`showTemplateImagePicker`](#showtemplateimagepicker) | 顶层函数 | A | 让用户为设备手动选择内置缩略图。 |
| `TemplateImagePickerSheet`（构造函数） | const 构造函数 | B | 创建模板图片选择面板实例；设为公开，以便组件测试无需路由即可 pump。 |
| `createState` | 方法（`TemplateImagePickerSheet`） | B | 为此组件创建可变状态对象。 |
| [`initState`](#initstate) | 方法（组件生命周期） | A | 面板打开时对候选缩略图排序一次并建立名称索引。 |
| [`_filtered`](#_filtered) | getter（`_TemplateImagePickerSheetState`） | A | 提供与搜索框匹配的候选缩略图。 |
| `build` | 方法（组件） | B | 构建可搜索的缩略图网格，「自动」为第一个格子。 |
| `_Tile`（构造函数） | const 构造函数 | B | 创建缩略图格子实例。 |
| `build` | 方法（`_Tile`） | B | 构建一个带名称的可选缩略图；当前选择带主色描边。 |

行数（9）与 `grep -c 'Purpose:' template_image_picker.dart`（9）精确匹配。`TemplateImageChoice` 和 `TemplateImagePickerSheet` 类以及 `_namesByImage` 字段带的是普通 `///` 文档注释而非 `Purpose:` 块，不单独成行。

## 文档

### `const TemplateImageChoice(String? asset)` <a id="templateimagechoice"></a>
- **种类：** `TemplateImageChoice`（「用户在缩略图选择器中选中的内容」）的 const 构造函数。
- **来源：** `lib/features/devices/widgets/template_image_picker.dart`（第 19 行）。
- **用途：** 创建模板图片选择实例。
- **输入：** `asset` —— 所选内置缩略图路径，null 表示「自动」（按身份匹配）。
- **返回：** 新的 `TemplateImageChoice`。
- **副作用：** 无。
- **用法：** 由面板的格子弹出：「自动」为 `Navigator.pop(context, const TemplateImageChoice(null))`，缩略图为 `Navigator.pop(context, TemplateImageChoice(t.image))`。
- **备注：** 这层包装使关闭面板（future 结果为 `null`）与选择「自动」（`TemplateImageChoice(null)`）可以区分；调用方在前者时保持设备不变，在后者时清除 `templateImage`。

### `Future<TemplateImageChoice?> showTemplateImagePicker(BuildContext context, {required DeviceCategory category, String? brand, String? model, String? name, String? current})` <a id="showtemplateimagepicker"></a>
- **种类：** 顶层函数。
- **来源：** `lib/features/devices/widgets/template_image_picker.dart`（第 31 行）。
- **用途：** 让用户为设备手动选择内置缩略图。
- **输入：** `context`；`category`、`brand`、`model`、`name` —— 用于对候选缩略图排序并渲染「自动」格子的设备身份；`current` —— 目前已选的缩略图（加描边）。
- **返回：** `Future<TemplateImageChoice?>` —— 所选结果；面板被关闭或加载目录期间 context 已卸载时为 null。
- **副作用：** 加载模板目录（`PresetService.loadTemplates`，首次调用后缓存）；显示可滚动控制的模态底部面板。
- **算法：** await `loadTemplates()`，`context` 已不再挂载时返回 null，然后以 `showModalBottomSheet<TemplateImageChoice>(isScrollControlled: true)` 显示由已加载模板和参数构建的 `TemplateImagePickerSheet`。
- **用法：**
  ```dart
  final choice = await showTemplateImagePicker(
    context,
    category: _category,
    brand: _nonEmpty(_brandCtrl.text),
    model: _nonEmpty(_modelCtrl.text),
    name: _nonEmpty(_nameCtrl.text),
    current: _templateImage,
  );
  ```
  （来自 `lib/features/devices/views/device_edit_page.dart` 中的 `_chooseThumbnail`，第 1128 行，接在 **缩略图** 标签上。）
- **备注：** 候选缩略图按表单中当前输入的内容排序，而非已保存的设备。选择缩略图后，调用方会清除 emoji 和照片，使头像显示该缩略图。

### `void initState()` <a id="initstate"></a>
- **种类：** `_TemplateImagePickerSheetState` 的方法（组件生命周期）。
- **来源：** `lib/features/devices/widgets/template_image_picker.dart`（第 104 行）。
- **用途：** 面板打开时对候选缩略图排序一次。
- **输入：** 无（读取 `widget.templates`、`brand`、`model`、`name`）。
- **返回：** 无。
- **副作用：** 初始化 `_ranked` 和 `_namesByImage`。
- **算法：**
  1. `_ranked = PresetService.rankTemplateImageCandidates(templates, brand:, model:, name:)` —— 每个不同的缩略图一项，精确身份匹配在前，然后是共享词，然后是其余。
  2. 对每个带 `image` 的模板，把其 `name`、`brand` 和 `model` 追加到 `_namesByImage[image]`。
- **用法：** 框架生命周期。
- **备注：** 多个模板可以共用一个缩略图文件；名称索引使搜索某个兄弟型号时仍能找到它借用的文件，尽管 `_ranked` 中只有其中一个。

### `List<DeviceTemplate> get _filtered` <a id="_filtered"></a>
- **种类：** `_TemplateImagePickerSheetState` 的 getter。
- **来源：** `lib/features/devices/widgets/template_image_picker.dart`（第 130 行）。
- **用途：** 提供与搜索框匹配的候选缩略图。
- **输入：** 无（读取 `_query`）。
- **返回：** 按排序顺序的 `List<DeviceTemplate>`；查询为空时是整个 `_ranked`。
- **副作用：** 无。
- **算法：** 把 `_query` 转小写并修剪；保留 `_namesByImage[t.image]` 中任一名称包含该查询（不区分大小写的子串）的已排序模板。
- **用法：** `build`（`final items = _filtered;`），每次按键重新计算。
- **备注：** 「自动」格子不在此列表中；`build` 总是把它放在最前，因此无论输入什么它都排第一。
