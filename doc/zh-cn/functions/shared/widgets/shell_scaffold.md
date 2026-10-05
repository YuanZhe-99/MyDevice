# lib/shared/widgets/shell_scaffold.dart

P2：本文件将导航绘制交给 `MyAppsNavigationShell`。
下文的悬浮底栏和条目实现在 MyApps-UI 中，应用只保留路由、过滤和回调。
见 [../../../shared-ui.md](../../../shared-ui.md)。

`ShellScaffold` 是 `go_router` `ShellRoute` 主体：五个标签（设备/服务/网络/数据集/设置）包裹当前激活标签页，在窄于 600 逻辑像素的窗口上渲染为底部栏，600 及以上渲染为侧边 `NavigationRail`。出现哪一个是 `useNavigationRail` 的仅宽度决策——见 [../../../adaptive-layout.md](../../../adaptive-layout.md#where-navigation-lives)——但导航栏位置设置（1.7.1）可以保留底栏。两者都由同一份 `_destinations` 列表构建，因此不会漂移。见 [架构](../../../architecture.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ShellScaffold` 构造函数 | 构造函数 | B | 带其子标签页创建壳脚手架。 |
| [`_currentIndex`](#currentindex) | 方法（`ShellScaffold`） | A | 从当前路由派生所选标签索引。 |
| [`_destinations`](#destinations) | 方法（`ShellScaffold`） | A | 一次性描述五个目的地，含图标。 |
| `build` | 方法（`ShellScaffold`） | B | 组合带 Expressive 栏、经典栏或导航栏的 `Scaffold`。 |
| `_ShellDestination` 构造函数 | 构造函数 | B | 持有一个目的地的线框图标、实心图标和标签。 |

## 文档

### `int _currentIndex(BuildContext context)` <a id="currentindex"></a>
- **种类：** `ShellScaffold` 的方法。
- **来源：** `lib/shared/widgets/shell_scaffold.dart`。
- **用途：** 基于当前路由路径确定选中哪个导航目的地。
- **输入：** `context` — 为 `GoRouterState.of(context).uri.path` 读取。
- **返回：** `int` — 静态 `_routes` 列表（`/devices`、`/services`、`/network`、`/datasets`、`/settings`）中的索引；无路由前缀匹配时 `0`。
- **副作用：** 无。
- **算法：** 线性扫描 `_routes`，返回当前位置 `startsWith` 的第一条路径索引。
- **用法：** 从 `build` 调用，为当前显示的导航组件设置 `selectedIndex`。
- **备注：** 前缀匹配意味着如 `/devices/...` 下任何子路由仍高亮设备标签。

### `List<_ShellDestination> _destinations(AppLocalizations l10n)` <a id="destinations"></a>
- **种类：** `ShellScaffold` 的方法。
- **来源：** `lib/shared/widgets/shell_scaffold.dart`。
- **用途：** 一次性描述壳的五个目的地，含图标。
- **输入：** `l10n` — 用于本地化标签。
- **返回：** 与 `_routes` 同序的 `List<_ShellDestination>`。
- **副作用：** 无。
- **用法：** `build` 把列表映射为底栏的 `_ExpressiveNavItem` 或 `NavigationDestination`，或导航栏的 `NavigationRailDestination`。
- **备注：** 所有渲染都从此读取，所以一个目的地不可能只出现在其中一个，或两者顺序不同。

## `build`（Tier B）

`ShellScaffold` 是 `ConsumerWidget`（`build(BuildContext context, WidgetRef ref)`）。它用 `select` 监视三个设置：`uiStyle == AppUiStyle.expressive`、`navPlacement` 和 `navRailOnRight`（后两者自 1.7.1 起）。纯组件组合：

- `wide = useNavigationRail(width)`；`showRail = switch (placement) { bottom => false, sideOnWide => wide, side => true }`，两种风格相同。`bottom`（默认）在任何窗口都用底栏，`sideOnWide` 在宽窗口用导航栏，`side` 在任何宽度都用导航栏（手机上不推荐）。
- **无导航栏、Expressive：** `Scaffold(extendBody: true, body: ..., bottomNavigationBar: _ExpressiveNavBar)`。`extendBody` 让页面绘制到悬浮栏**后面**，Scaffold 把栏高作为 `MediaQuery.padding.bottom` 报告给页面。页面自己的 `Scaffold` 是按 `viewPadding`（而不是 `padding`）放置浮动操作按钮的，所以 body 外包一层 `Builder`，把 `viewPadding.bottom` 提高到 `max(viewPadding.bottom, padding.bottom)`；否则浮动按钮会落在栏后面。显式传了 `padding` 的滚动视图必须自己加上栏高——见 [`adaptive_layout.md`](../utils/adaptive_layout.md) 中的 `navBarAwarePadding`。
- **无导航栏、Material 3：** `bottomNavigationBar` 为经典通栏 `NavigationBar`，无 `extendBody`。
- **导航栏：** 一个 `Row`，含 `NavigationRail`（`groupAlignment: 0`，`labelType: all`，外包 `SingleChildScrollView` + `ConstrainedBox` + `IntrinsicHeight` 让紧凑高度窗口滚动导航栏而非溢出）、1 dp `VerticalDivider`，以及放在 `Expanded` 里的 child。两种风格下，导航栏默认在左侧，设置 `navRailOnRight` 时在最右。

点击任一导航都调用 `context.go(_routes[index])`。没有任何状态，所以折叠设备时下一帧就在两种渲染间切换，不改变路由。

## `_ExpressiveNavBar` <a id="expressivenavbar"></a>

取代 1.7.0 的 `_FloatingNavBar`（它把原版 `NavigationBar` 包在通宽的岛里）。1.7.1 的栏是仿照 Material 3 Expressive 悬浮导航的**紧凑**胶囊：`Material`，`StadiumBorder`，`surfaceContainer` 颜色，阴影高度 3，宽度贴合内容（不再撑满），居中放在最小边距 16/0/16/12 的 `SafeArea` 内，内边距 8，项间距 4 dp。极窄屏幕上由 `FittedBox(fit: scaleDown)` 缩小而不是溢出。它带有 `ValueKey('floatingNavBarIsland')`，测试据此区分它与经典栏。用于窄窗口，开启宽屏设置后也用于宽窗口。

## `_ExpressiveNavItem` <a id="expressivenavitem"></a>

**选中**的目的地在 `secondaryContainer` 胶囊内横排显示实心图标和文字（高 48，左右各 20 dp，`labelLarge`）；其余只显示线框图标（内边距 16 dp），并带 `Tooltip` 与 `Semantics` 标签，因为文字被隐藏了。宽度（`AnimatedSize`）和颜色（`AnimatedContainer`）以 250 ms 动画过渡。它是带 `StadiumBorder` 水波纹的 `InkWell`。
