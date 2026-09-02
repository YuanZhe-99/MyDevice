# lib/shared/widgets/shell_scaffold.dart

`ShellScaffold` 是 `go_router` `ShellRoute` 主体：五个标签（设备/服务/网络/数据集/设置）包裹当前激活标签页，在窄于 600 逻辑像素的窗口上渲染为底部 `NavigationBar`，600 及以上渲染为侧边 `NavigationRail`。出现哪一个是 `useNavigationRail` 的仅宽度决策——见 [../../../adaptive-layout.md](../../../adaptive-layout.md#导航放在哪里)——两者都由同一份 `_destinations` 列表构建，因此不会漂移。见 [架构](../../../architecture.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ShellScaffold` 构造函数 | 构造函数 | B | 带其子标签页创建壳脚手架。 |
| [`_currentIndex`](#currentindex) | 方法（`ShellScaffold`） | A | 从当前路由派生所选标签索引。 |
| [`_destinations`](#destinations) | 方法（`ShellScaffold`） | A | 一次性描述五个目的地，含图标。 |
| `build` | 方法（`ShellScaffold`） | B | 组合带 `NavigationBar` 或 `NavigationRail` 的 `Scaffold`。 |
| `_ShellDestination` 构造函数 | 构造函数 | B | 持有一个目的地的线框图标、实心图标和标签。 |

## 文档

### `int _currentIndex(BuildContext context)` <a id="currentindex"></a>
- **种类：** `ShellScaffold` 的方法。
- **来源：** `lib/shared/widgets/shell_scaffold.dart`（第 29 行）。
- **用途：** 基于当前路由路径确定选中哪个导航目的地。
- **输入：** `context` — 为 `GoRouterState.of(context).uri.path` 读取。
- **返回：** `int` — 静态 `_routes` 列表（`/devices`、`/services`、`/network`、`/datasets`、`/settings`）中的索引；无路由前缀匹配时 `0`。
- **副作用：** 无。
- **算法：** 线性扫描 `_routes`，返回当前位置 `startsWith` 的第一条路径索引。
- **用法：** 从 `build` 调用，为当前显示的导航组件设置 `selectedIndex`。
- **备注：** 前缀匹配意味着如 `/devices/...` 下任何子路由仍高亮设备标签。

### `List<_ShellDestination> _destinations(AppLocalizations l10n)` <a id="destinations"></a>
- **种类：** `ShellScaffold` 的方法。
- **来源：** `lib/shared/widgets/shell_scaffold.dart`（第 42 行）。
- **用途：** 一次性描述壳的五个目的地，含图标。
- **输入：** `l10n` — 用于本地化标签。
- **返回：** 与 `_routes` 同序的 `List<_ShellDestination>`。
- **副作用：** 无。
- **用法：** `build` 把列表映射为底栏的 `NavigationDestination` 或导航栏的 `NavigationRailDestination`。
- **备注：** 两种渲染都从此读取，所以一个目的地不可能只出现在其中一个，或两者顺序不同。

`ShellScaffold` 构造函数、`build` 和 `_ShellDestination` 构造函数是 Tier B。`build` 是纯组件组合：读 `MediaQuery.sizeOf(context).width`，低于 `navRailMinWidth` 时返回 `bottomNavigationBar` 为 `NavigationBar` 的 `Scaffold`；达到及以上时返回 body 为 `Row` 的 `Scaffold`——`NavigationRail`（`groupAlignment: 0` 让五个目的地居中而非钉在顶部，`labelType: all`，外包 `SingleChildScrollView` + `ConstrainedBox` + `IntrinsicHeight` 让紧凑高度窗口滚动导航栏而非溢出）、1 dp `VerticalDivider`，以及放在 `Expanded` 里的 child。点击任一导航都调用 `context.go(_routes[index])`。没有任何状态，所以折叠设备时下一帧就在两种渲染间切换，不改变路由。每个标签页自带 `Scaffold`（应用栏、浮动操作按钮），因此页面 body 从不位于底栏之下，也不为它预留内缩。
