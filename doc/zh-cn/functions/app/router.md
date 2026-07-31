# lib/app/router.dart

定义 `appRouter`，应用的 `GoRouter` 配置：包裹 `ShellScaffold` 的单个 `ShellRoute`，带五个顶层路由（`/devices`、`/services`、`/network`、`/datasets`、`/settings`），匹配 [架构](../../architecture.md) 描述的五个底部标签。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `appRouter` | 顶层 `final` 变量 | B | 应用的 `GoRouter` 实例/路由表。 |

本文件按 `/// Purpose:` 约定有零行：`appRouter` 是普通顶层 `final` 值（`GoRouter` 配置字面量），非函数/方法/构造函数/getter/setter，因此落在 Function Explanation Layer 约定外——与姊妹 MyAnime 仓库的 `app/router.dart` 相同情况。
