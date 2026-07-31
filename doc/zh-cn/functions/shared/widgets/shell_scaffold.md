# lib/shared/widgets/shell_scaffold.dart

`ShellScaffold` 是 `go_router` `ShellRoute` 主体：带五个标签（设备/服务/网络/数据集/设置）的持久底部 `NavigationBar`，包裹当前激活标签页。见 [架构](../../../architecture.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ShellScaffold` 构造函数 | 构造函数 | B | 带其子标签页创建壳脚手架。 |
| [`_currentIndex`](#currentindex) | 方法（`ShellScaffold`） | A | 从当前路由派生所选标签索引。 |
| `build` | 方法（`ShellScaffold`） | B | 组合 `Scaffold`/`NavigationBar`。 |

## 文档

### `int _currentIndex(BuildContext context)` <a id="currentindex"></a>
- **种类：** `ShellScaffold` 的方法。
- **来源：** `lib/shared/widgets/shell_scaffold.dart`（第 29 行）。
- **用途：** 基于当前路由路径确定选中哪个底部导航标签。
- **输入：** `context` — 为 `GoRouterState.of(context).uri.path` 读取。
- **返回：** `int` — 静态 `_routes` 列表（`/devices`、`/services`、`/network`、`/datasets`、`/settings`）中的索引；无路由前缀匹配时 `0`。
- **副作用：** 无。
- **算法：** 线性扫描 `_routes`，返回当前位置 `startsWith` 的第一条路径索引。
- **用法：** 从 `build` 调用设置 `NavigationBar.selectedIndex`。
- **备注：** 前缀匹配意味着如 `/devices/...`（设备详情页）下任何子路由仍高亮设备标签。

`ShellScaffold` 构造函数和 `build` 是 Tier B：构造函数是平凡 `const` 组件构造函数，`build` 是纯组件组合（带目的地用 `AppLocalizations` 本地化标签的 `NavigationBar` 的 `Scaffold`），除点击时调用 `_currentIndex` 和 `context.go(_routes[index])` 外无逻辑。
