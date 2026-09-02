# lib/shared/utils/detail_layout.dart

详情页与编辑页在 [`adaptive_layout.md`](adaptive_layout.md) 的全应用规则之上需要的助手：决定页面是否分栏的页面命名委托、其固定左窗格的宽度，以及让设备编辑页左窗格不滚动就放得下的头像尺寸（其背后三个常量 `deviceEditLeftPaneFieldBudget`、`deviceEditAvatarMinSize` 和 `deviceEditAvatarMaxSize` 在源码中记录）。与它 import 的模块一样，本模块只依赖 `dart:core`，所以每个助手都由 `test/detail_layout_test.dart` 在无组件树下覆盖；渲染后的页面由 `test/device_detail_layout_ui_test.dart`、`test/network_detail_layout_ui_test.dart` 和 `test/device_edit_two_pane_ui_test.dart` 覆盖。推理见 [../../../adaptive-layout.md](../../../adaptive-layout.md#详情页双栏)。

使用方：`device_detail_page.dart`、`network_detail_page.dart` 和 `device_edit_page.dart`。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`useDetailTwoPane`](#usedetailtwopane) | 顶层函数 | A | 报告详情页是否应使用双栏布局。 |
| [`detailLeftPaneWidth`](#detailleftpanewidth) | 顶层函数 | A | 返回详情页固定左窗格的宽度。 |
| [`editAvatarSize`](#editavatarsize) | 顶层函数 | A | 返回设备编辑页左窗格的头像尺寸。 |

## 文档

### `bool useDetailTwoPane(double width, double height)` <a id="usedetailtwopane"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/detail_layout.dart`。
- **用途：** 报告详情页是否应使用双栏布局。
- **输入：** `width`、`height` — 视口逻辑像素尺寸，来自 `MediaQuery.sizeOf`。
- **返回：** `bool` — 恰为 `canSplitLayout(width, height)`。
- **副作用：** 无。
- **用法：** 两个详情页的 `_buildBody`。
- **备注：** 一行委托，让页面用自己的词汇命名这个决策；`test/detail_layout_test.dart` 断言它在每个命名视口上仍与 `canSplitLayout` 一致，委托不会悄悄漂移。

### `double detailLeftPaneWidth(double totalWidth)` <a id="detailleftpanewidth"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/detail_layout.dart`。
- **用途：** 返回详情页固定左窗格的宽度。
- **输入：** `totalWidth` — 页面 body 的宽度，即原始窗口，因为详情页推到壳之上、旁边没有导航栏。
- **返回：** `double` — `(totalWidth × 0.36).clamp(260, 420)`。
- **副作用：** 无。
- **用法：** 两个详情页的 `LayoutBuilder`，为左窗格外的 `SizedBox` 定宽。
- **备注：** 按比例，因为一代折叠屏展开后跨越约 672 到 954 逻辑像素；钳制让窗格在窄端仍可用（600 dp 下限时 260，右侧留 339），在桌面窗口上不至于铺张。

### `double editAvatarSize(double paneWidth, double paneHeight)` <a id="editavatarsize"></a>
- **种类：** 顶层函数。
- **来源：** `lib/shared/utils/detail_layout.dart`。
- **用途：** 返回设备编辑页左窗格的头像尺寸。
- **输入：** `paneWidth`、`paneHeight` — 左窗格的逻辑像素尺寸。
- **返回：** `double` — `(paneHeight − 318).clamp(56, 160)`，再不宽于 `paneWidth − 32`。
- **副作用：** 无。
- **用法：** `_DeviceEditPageState._buildFormBody`，在左窗格的 `LayoutBuilder` 内。
- **备注：** 这就是让左窗格不滚动的关键：头像取 `deviceEditLeftPaneFieldBudget` 之后剩余的高度，列按构造就放得下。在 480 dp 分栏下限（扣应用栏后 424）头像为 106；Z Fold 8 横屏达到 160 上限；`test/detail_layout_test.dart` 循环 480 到 1200 的每个窗口高度断言列放得下。
