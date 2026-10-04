# lib/features/devices/services/preset_service.dart

## 硬件列表（1.9.0）

`DeviceTemplate` 增加可选 `gpus`/`displays`。解析接受 GPU 字符串或对象及屏幕对象。
转换设备时携带全部条目并生成新 ID，精确 GPU 预设补充参数，保留模板类型/角色及
旧字段默认值。

`PresetService` 从 `assets/presets/*.json` 经 `rootBundle.loadString()` 加载应用捆绑预设数据——CPU、GPU、品牌和完整设备模板——首次使用时惰性解析并缓存每个文件。它依赖 [`device.md`](../models/device.md) 的 `CpuInfo`/`GpuInfo`/`StorageInfo`/`Device` 作为其解析进的形态，其 `BrandEntry`/`DeviceTemplate` 模型类自己定义在本文件。本页对照源码验证的捆绑预设概念总览见 [在线搜索与预设 — 捆绑预设](../../../../features/online-search-and-presets.md#bundled-presets---presetservicedart)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `PresetService._` | 私有构造函数 | B | 阻止实例化；`PresetService` 仅静态。 |
| [`loadCpus`](#loadcpus) | 静态方法 | A | 加载并缓存捆绑 CPU 预设列表。 |
| [`loadGpus`](#loadgpus) | 静态方法 | A | 加载并缓存捆绑 GPU 预设列表。 |
| [`loadBrands`](#loadbrands) | 静态方法 | A | 加载并缓存捆绑品牌列表。 |
| [`loadTemplates`](#loadtemplates) | 静态方法 | A | 加载并缓存捆绑设备模板列表。 |
| `cachedTemplates` | 静态 getter | B | 模板列表已加载时返回它，否则返回 null，使组件可以同步匹配。 |
| [`findTemplateImage`](#findtemplateimage) | 静态方法 | A | 加载模板并返回设备身份所匹配的缩略图。 |
| [`matchTemplateImage`](#matchtemplateimage) | 静态方法 | A | 通过规范化相等把设备身份匹配到模板缩略图。 |
| [`isTemplateImage`](#istemplateimage) | 静态方法 | A | 判断资源路径是否仍是内置缩略图之一。 |
| [`rankTemplateImageCandidates`](#ranktemplateimagecandidates) | 静态方法 | A | 按与设备的契合程度排序所有内置缩略图（每个不同 `image` 一个）。 |
| `_tokens` | 私有静态方法 | B | 把身份字符串拆分为小写字母/数字词元。 |
| `_identityKey` | 私有静态方法 | B | 转为小写并去除非字母数字字符，形成比较键。 |
| [`BrandEntry`](#brandentry-new) | 构造函数 | A | 创建 `BrandEntry` 实例。 |
| [`BrandEntry.fromJson`](#brandentry-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `BrandEntry`。 |
| [`DeviceTemplate`](#devicetemplate-new) | 构造函数 | A | 创建 `DeviceTemplate` 实例。 |
| [`DeviceTemplate._asString`](#_asstring) | 私有静态方法 | A | 把模板 `cpu`/`gpu` JSON 值（字符串或对象）强制为普通字符串。 |
| [`DeviceTemplate._asCpuInfo`](#_ascpuinfo) | 私有静态方法 | A | 保留对象形态 `cpu` 中型号以外的详细信息。 |
| [`DeviceTemplate.fromJson`](#devicetemplate-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `DeviceTemplate`。 |
| [`DeviceTemplate.toDevice`](#todevice) | 方法（`DeviceTemplate`） | A | 把此模板转换为新 `Device`，可选从预设填充完整 CPU/GPU 详情。 |

行数（19）与 `grep -c 'Purpose:' preset_service.dart`（19）精确匹配。`DeviceTemplate.fromJson`
此前没有 `/// Purpose:` 块；它在 1.5.8 开始解析 `image` 时补上了该块。

## 文档

### `static Future<List<CpuInfo>> loadCpus()` <a id="loadcpus"></a>
- **种类：** `PresetService` 的静态方法。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 25 行）。
- **用途：** 加载捆绑 CPU 预设列表，只解析一次 `assets/presets/cpus.json` 并在后续调用复用解析结果。
- **输入：** 无。
- **返回：** `Future<List<CpuInfo>>`。
- **副作用：** 只在首次调用经 `rootBundle.loadString()` 读取 `assets/presets/cpus.json`；填充静态 `_cpus` 缓存字段。
- **算法：** 1. `_cpus` 已填充时立即返回它（无 IO）。2. 否则加载并 `jsonDecode` 资产、把其 `cpus` 数组每个条目经 `CpuInfo.fromJson` 映射（见 [`device.md#cpuinfo-fromjson`](../models/device.md)）、把结果列表缓存进 `_cpus` 并返回。
- **用法：**
  ```dart
  final cpus = await PresetService.loadCpus();
  ```
  （来自 `device_edit_page.dart` 的 `_loadPresets()`，和 `device_list_page.dart` 的 `_addFromTemplate()` 调用 [`toDevice`](#todevice) 前再次）
- **备注：** 缓存是进程生命周期且绝不过期——捆绑 JSON 资产只随应用更新/重装变化，因此应用运行时无需重读。重复调用（如多次打开设备编辑器）首次后实际免费。

### `static Future<List<GpuInfo>> loadGpus()` <a id="loadgpus"></a>
- **种类：** `PresetService` 的静态方法。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 41 行）。
- **用途：** 加载捆绑 GPU 预设列表，只解析一次 `assets/presets/gpus.json`。
- **输入：** 无。
- **返回：** `Future<List<GpuInfo>>`。
- **副作用：** 首次调用读取 `assets/presets/gpus.json`；填充 `_gpus`。
- **算法：** 与 [`loadCpus`](#loadcpus) 相同缓存-然后-加载-然后-解析形态，读取 `gpus` 数组并经 `GpuInfo.fromJson` 映射。
- **用法：** 与 `loadCpus` 相同调用模式，来自相同两个调用点。
- **备注：** 与 `loadCpus` 相同进程生命周期缓存行为。

### `static Future<List<BrandEntry>> loadBrands()` <a id="loadbrands"></a>
- **种类：** `PresetService` 的静态方法。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 57 行）。
- **用途：** 加载捆绑品牌列表，只解析一次 `assets/presets/brands.json`。
- **输入：** 无。
- **返回：** `Future<List<BrandEntry>>`。
- **副作用：** 首次调用读取 `assets/presets/brands.json`；填充 `_brands`。
- **算法：** 相同缓存-然后-加载-然后-解析形态，读取 `brands` 数组并经 [`BrandEntry.fromJson`](#brandentry-fromjson) 映射。
- **用法：**
  ```dart
  final brands = await PresetService.loadBrands();
  ```
  （来自 `device_edit_page.dart` 的 `_loadPresets()`，供给品牌自动补全字段）
- **备注：** 与 `loadCpus` 相同进程生命周期缓存行为。

### `static Future<List<DeviceTemplate>> loadTemplates()` <a id="loadtemplates"></a>
- **种类：** `PresetService` 的静态方法。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 73 行）。
- **用途：** 加载捆绑完整设备模板列表，只解析一次 `assets/presets/device_templates.json`。
- **输入：** 无。
- **返回：** `Future<List<DeviceTemplate>>`。
- **副作用：** 首次调用读取 `assets/presets/device_templates.json`；填充 `_templates`。
- **算法：** 相同缓存-然后-加载模式，但资产根直接是 JSON *数组*（非包在 `cpus`/`gpus`/`brands` 那样的命名键中），经 [`DeviceTemplate.fromJson`](#devicetemplate-fromjson) 映射。
- **用法：**
  ```dart
  final templates = await PresetService.loadTemplates();
  ```
  （来自 `device_list_page.dart` 的 `_addFromTemplate()`，填充模板选择器底部面板）
- **备注：** 与 `loadCpus` 相同进程生命周期缓存行为。注意与其他三个 `loadXxx` 方法不同的 JSON 根形态——普通数组而非 `{"templates": [...]}`——这是真实、源码确认的不对称，非要在文档中"修复"的不一致。

### `static Future<String?> findTemplateImage({String? brand, String? model, String? name})` <a id="findtemplateimage"></a>
- **种类：** `PresetService` 的静态方法。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 101 行）。
- **用途：** 返回设备所匹配模板的内置缩略图。
- **输入：** 设备的 `brand`、`model` 和 `name`。
- **返回：** 模板的 `image` 资源路径，或 null。
- **副作用：** 首次使用时加载并缓存模板目录（经
  [`loadTemplates`](#loadtemplates)）。
- **算法：** 先 `loadTemplates()`，再 [`matchTemplateImage`](#matchtemplateimage)。
- **用法：** 作为便捷入口保留；自 1.6.1 起 `lib/` 中已没有调用方——
  `DeviceAvatar` 现在自己等待 `loadTemplates()`，并经其 `_resolveTemplate` 解析（先手选缩略图，再
  [`matchTemplateImage`](#matchtemplateimage)）。
- **备注：** 只用于显示。匹配到的路径绝不写入设备，因此缩略图出现之前添加的设备也能获得缩略图。
  用户手选的缩略图则不同：它存储在设备的 `templateImage` 字段中。

### `static String? matchTemplateImage(List<DeviceTemplate> templates, {String? brand, String? model, String? name})` <a id="matchtemplateimage"></a>
- **种类：** `PresetService` 的静态方法。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 125 行）。
- **用途：** 把设备身份匹配到模板缩略图。
- **输入：** `templates`；设备的 `brand`、`model`、`name`。
- **返回：** 第一个匹配模板的 `image`，或 null。
- **副作用：** 无。
- **算法：** 只有带 `image` 的模板参与匹配。键先转为小写并去除所有非字母数字字符（`_identityKey`），
  再按以下顺序比较是否**相等**：
  1. 设备品牌+型号 = 模板品牌+型号（仅当设备有型号时）；
  2. 设备名称 = 模板名称；
  3. 设备品牌+型号 = 模板名称。
- **用法：** `PresetService.matchTemplateImage(templates, brand: 'Apple', model: 'iPhone 15 Pro')`。
- **备注：** 比较的是相等而非包含，因此 `iPhone 15` 绝不会占用 `iPhone 15 Pro` 的照片，
  单独的 `iPhone` 不匹配任何模板。`iPad Pro 13" (M4)` 与 `ipad pro 13 m4` 比较结果相等。

### `static bool isTemplateImage(List<DeviceTemplate> templates, String asset)` <a id="istemplateimage"></a>
- **种类：** `PresetService` 的静态方法。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 164 行）。
- **用途：** 判断资源路径是否是内置缩略图之一。
- **输入：** `templates` —— 目录；`asset` —— 存储的 `templateImage`。
- **返回：** 有模板的 `image` 恰好等于该路径时为 true。
- **副作用：** 无。
- **算法：** `templates.any((t) => t.image == asset)`。
- **用法：** `DeviceAvatar._resolveTemplate` 在显示设备的手选 `templateImage` 前先检查它。
- **备注：** 手选的缩略图可能在后续版本中被改名或删除；此时头像回退到自动匹配，而不是显示损坏的图像。

### `static List<DeviceTemplate> rankTemplateImageCandidates(List<DeviceTemplate> templates, {String? brand, String? model, String? name})` <a id="ranktemplateimagecandidates"></a>
- **种类：** `PresetService` 的静态方法。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 179 行）。
- **用途：** 按与设备的契合程度排序所有内置缩略图。
- **输入：** 要排序的 `templates`；设备的 `brand`、`model` 和 `name`。
- **返回：** 每个不同 `image` 对应一个模板，最佳候选在前。
- **副作用：** 无。
- **算法：** 1. 用 [`matchTemplateImage`](#matchtemplateimage) 计算精确命中。2. 经 `_tokens`（小写字母/数字串）由设备品牌、型号和名称构建所需词元集合。3. 按目录顺序遍历模板，跳过没有 `image` 的模板以及 `image` 已出现过的后续模板。4. 以模板自身品牌/型号/名称词元与所需集合交集的大小计分；精确命中计 `1 << 20`。5. 按分数降序排序，同分按目录顺序。
- **用法：** [`template_image_picker.dart`](../widgets/template_image_picker.md) 中的手选缩略图选择器为正在编辑的设备排序整个目录，使最接近的候选缩略图排在前面。
- **备注：** 列表总是完整的——不过滤任何项——因为最终由用户选择；与自动匹配不同，这里有意采用模糊匹配。多个同系列模板常共用一个文件；按目录顺序的第一个代表它。

### `const BrandEntry({required this.name, this.logo})` <a id="brandentry-new"></a>
- **种类：** `BrandEntry` 的构造函数。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 248 行）。
- **用途：** 持有一个捆绑品牌的显示名和可选 logo 资产引用。
- **输入：** `name`（必填）；可选 `logo`。
- **返回：** 新 `BrandEntry` 实例。
- **副作用：** 无。
- **算法：** 平凡字段赋值。
- **用法：** 只由 [`BrandEntry.fromJson`](#brandentry-fromjson) 构造。
- **备注：** 无。

### `factory BrandEntry.fromJson(Map<String, dynamic> json)` <a id="brandentry-fromjson"></a>
- **种类：** `BrandEntry` 的工厂构造函数。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 255 行）。
- **用途：** 从解码 `brands.json` 数组解析一个品牌条目。
- **输入：** `json`。
- **返回：** `name` 必填、`logo` 可选的新 `BrandEntry`。
- **副作用：** 无（`json['name']` 缺失/非字符串时抛）。
- **算法：** 直接字段提取：`name` 为必填 `String`，`logo` 为可选 `String?`。
- **用法：** 被 [`loadBrands`](#loadbrands) 为 `brands` 数组每个条目调用。
- **备注：** 与设备/CPU/GPU 模型不同，`BrandEntry` 无 `toJson`/`extraJson`——它是只读捆绑预设，绝不持久化或合并，因此无往返要保留的东西。

### `const DeviceTemplate({required this.name, required this.category, ...})` <a id="devicetemplate-new"></a>
- **种类：** `DeviceTemplate` 的构造函数。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 294 行）。
- **用途：** 持有一个捆绑完整设备模板的字段（名、类别、品牌/型号、cpu/gpu 型号字符串、ram、存储列表、屏幕、电池、操作系统、发布日期，以及可选的 `image` 缩略图资源）。
- **输入：** `name`、`category` 必填；所有其他字段可选，`storage` 默认 `[]`。
- **返回：** 新 `DeviceTemplate` 实例。
- **副作用：** 无。
- **算法：** 带默认的平凡字段赋值。
- **用法：** 只由 [`DeviceTemplate.fromJson`](#devicetemplate-fromjson) 构造。
- **备注：** 这里 `cpu`/`gpu` 是普通型号名字符串，非完整 `CpuInfo`/`GpuInfo`——完整详情只在稍后 [`toDevice`](#todevice) 中把这些字符串对照加载预设匹配时解析。

### `static String? DeviceTemplate._asString(dynamic value)` <a id="_asstring"></a>
- **种类：** `DeviceTemplate` 的私有静态方法。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 321 行）。
- **用途：** 规范化模板 `cpu`/`gpu` JSON 字段——可能存为普通字符串或带 `model` 键的对象——为普通字符串。
- **输入：** `value` — `cpu` 或 `gpu` 的原始解码 JSON 值。
- **返回：** `String?` — 字符串本身、`value` 是映射时 `value['model']`、任何其他形态 `null`。
- **副作用：** 无。
- **算法：** `if (value is String) return value; if (value is Map<String, dynamic>) return value['model'] as String?; return null.`
- **用法：** 被 [`DeviceTemplate.fromJson`](#devicetemplate-fromjson) 为 `cpu` 和 `gpu` 字段调用两次。
- **备注：** 存在为容忍 `device_templates.json` 中 `cpu`/`gpu` 的两种编写形态——裸型号名字符串或小对象——无需两个单独 JSON 模式。

### `factory DeviceTemplate.fromJson(Map<String, dynamic> json)` <a id="devicetemplate-fromjson"></a>
- **种类：** `DeviceTemplate` 的工厂构造函数。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 347 行）。
- **用途：** 从解码 `device_templates.json` 数组解析一个设备模板。
- **输入：** `json`。
- **返回：** 新 `DeviceTemplate`；`storage` 缺席默认 `[]`；`releaseDate` 只在存在时经 `DateTime.parse` 解析。
- **副作用：** 无。
- **算法：** 直接字段提取；`category` 经 `DeviceCategory.fromJson`；`cpu`/`gpu` 经 [`_asString`](#_asstring)；`storage` 存在时经 `StorageInfo.fromJson` 映射；可选的 `image` 字符串原样复制。
- **用法：** 被 [`loadTemplates`](#loadtemplates) 为顶层 JSON 数组每个元素调用。
- **备注：** 这里不检查 `image`；其位置与像素规则由 `tool/validate_json.dart` 强制执行。

### `static CpuInfo? DeviceTemplate._asCpuInfo(dynamic value)` <a id="_ascpuinfo"></a>
- **种类：** `DeviceTemplate` 的私有静态方法。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 337 行）。
- **用途：** 保留对象形态 `cpu` 中型号名以外的详细信息。
- **输入：** `value` —— 原始的 `cpu` JSON 值。
- **返回：** 模板写成对象时返回 `CpuInfo`，否则返回 null。
- **副作用：** 无。
- **备注：** 14 个 VPS 模板在 `cpu` 内写有 `architecture` 和 `performanceCores`。[`_asString`](#_asstring) 只保留 `['model']`，因此在本方法出现之前，其余信息在解析阶段就被丢弃——而 `toDevice` 的精确匹配预设查找同样无法找回它们，因为 `Intel Xeon`、`Ampere Altra` 这类名称有意不收入 `cpus.json`。这些已写入的数据根本没有到达界面。

### `Device DeviceTemplate.toDevice({List<CpuInfo>? cpuPresets, List<GpuInfo>? gpuPresets, int storageIndex = 0})` <a id="todevice"></a>
- **种类：** `DeviceTemplate` 的方法。
- **来源：** `lib/features/devices/services/preset_service.dart`（第 390 行）。
- **用途：** 把此模板转换为新 `Device`，预填所有模板字段并可选对照加载预设匹配把普通 `cpu`/`gpu` 型号名字符串升级为完整 `CpuInfo`/`GpuInfo` 详情。
- **输入：** 可选 `cpuPresets`/`gpuPresets` —— 典型为 [`loadCpus`](#loadcpus)/[`loadGpus`](#loadgpus) 的列表；以及 `storageIndex`，用于在模板提供的多个容量中作出选择。
- **返回：** 新 `Device`（经 `Device` 构造函数的新鲜 `id`/`modifiedAt`——见 [`device.md#device-new`](../models/device.md)），携带由 `storageIndex` 指定并被夹取到合法范围内的那一个容量。
- **副作用：** 无。
- **算法：** 1. 以 `CpuInfo(model: cpu)`/`GpuInfo(model: gpu)` 作为回退开始。2. `cpu`/`cpuPresets` 都存在时找 `model` 精确等于 `cpu` 的预设，找到则用；随后若模板带有非空的 `cpuDetail`，则以它为准。3. 对 GPU，先试精确 `model` 匹配；无则回退*前缀*匹配（`model!.startsWith(gpu!)`）——这处理带核心数后缀如 "(10-core)"、不会精确匹配模板裸型号字符串的 GPU 预设。4. 用所有模板字段加解析 `cpuInfo`/`gpuInfo`，并以模板的 `image` 作为设备的 `templateImage`，构造并返回 `Device`。
- **用法：**
  ```dart
  final device = choice.template.toDevice(
    cpuPresets: cpus,
    gpuPresets: gpus,
    storageIndex: choice.storageIndex,
  );
  ```
  （来自 `device_list_page.dart` 的 `_addFromTemplate()`，用户从底部面板挑选模板后——若是多容量模板，还要再挑一个容量）
- **备注：** `storageIndex` 之所以存在，是因为本方法此前硬编码 `storage.first`，导致每个多容量模板都塌缩为其最小容量且无从选择——列出 512 GB 到 4 TB 的 MacBook Pro 模板永远只产出 512 GB。索引采用夹取而非范围校验，因此过时的调用方也不会抛异常。`cpuDetail` 优先于预设查找，是因为 VPS 模板为 `Intel Xeon`、`Ampere Altra` 这类有意不收入 `cpus.json` 的芯片写入了 `architecture` 与核心数，预设查找根本无从找回。模板的缩略图作为 `templateImage` 携带，使设备在用户改名后仍保留它（自动匹配会丢失它）。

模板选择器图标优先使用模板自带的 `image` 缩略图，并以完整尺寸显示，因为它已经圆内安全。
没有缩略图时使用内置 `brands.json` 目录，按品牌名称进行不区分大小写的精确匹配，
包括已有的路由器和 VPS 提供商标志。`TemplateIcon` 将完整透明 SVG 放在边长为头像直径
64% 的正方形内，圆形边界不会裁剪图标。单色品牌标志跟随主题前景色；CloudCone 保留原生透明 PNG 的颜色；没有资源的品牌
保留类别图标。此选择器显示不修改设备的用户自选表情或图像；由模板创建的设备唯一获得的缩略图是其
`templateImage`（见 [`toDevice`](#todevice)）。
