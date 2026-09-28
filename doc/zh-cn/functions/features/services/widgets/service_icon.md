# `lib/features/services/widgets/service_icon.dart`

服务图标键到 Material `IconData` 的共享回退映射。显示品牌图案的服务视图使用
`ServiceAvatar`；当图标键未知或没有品牌素材时，此函数提供通用图标。拓扑模块会导入并重新导出
该函数，供现有基于图标的画布使用，因为 SVG 组件不适合拓扑节点现有的绘制接口。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`iconForServiceIcon`](#iconforserviceicon) | 顶层函数 | B | 将服务图标键映射到 Material 图标，未知时回退为 `Icons.dns`。 |

## 文档

### `IconData iconForServiceIcon(String? icon)` <a id="iconforserviceicon"></a>
- **种类：** 顶层函数。
- **源码：** `lib/features/services/widgets/service_icon.dart`。
- **用途：** 将服务保存的图标名称解析为对应的 Material 图标。
- **输入：** `icon` —— 服务或模板图标键，可以为 null。
- **返回：** `IconData` —— 映射后的图标；键未知或缺失时为 `Icons.dns`。
- **副作用：** 无。
- **算法：** 通过 switch 将已知保存名称映射到 Flutter Material 图标，默认使用 `Icons.dns`。
- **用法：** `ServiceAvatar` 将其用作通用回退；`iconForService` 和拓扑代码也会调用它。
- **备注：** 已接受的图标键应与现有服务模板数据及已保存的服务记录保持一致。
