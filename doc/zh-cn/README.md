# MyDevice!!!!! 文档

**MyDevice!!!!!**（每个面向用户应用名、安装器元数据、macOS 捆绑名和窗口标题中都五个感叹号）是隐私优先个人设备清单应用。它跟踪详细硬件规格、服务/端口/路由备注、网络管理、数据集组织、地图位置、WebDAV 同步、本地备份、ZIP/Markdown 导出、桌面托盘行为、本地 API 访问和设备生命周期/财务跟踪。

- **许可证：** GPL-3.0
- **平台：** Windows、Android、iOS、macOS（Linux/Web 项目文件存在但非主发布目标）
- **框架：** Flutter（Dart SDK `^3.11.3`）

此树是英语"概念"文档——架构、数据格式和应用如何工作的功能级解释。它补充 [`functions/`](functions/) 下的逐函数参考页（单独、穷举逐源文件索引）和[翻译指南](translation-guide.md)。

**这些文档是代码的权威描述。** 仓库 `AGENTS.md` 刻意限于代理指令——工作流、编写规则、行为契约和发布流程——其他一切指向这里。代码变化时这些页先更新；文档与代码不一致时对照代码验证然后修页。

共享 WebDAV 同步、备份和 ZIP 引擎不在此仓库。它们住在嵌入 `packages/myapps_data` 的 `myapps_data` 包，文档在 `packages/myapps_data/doc/en-us/`。

## 内容

### 核心概念

- [架构](architecture.md) — 应用壳、路由、状态管理、主题、本地化、仓库布局。
- [自适应布局](adaptive-layout.md) — 布局何时可在折叠屏、平板或桌面窗口上分栏、导航放在哪里、能容纳多少列，以及规则为何是宽高比测试而非宽度断点。
- [数据格式](data-formats.md) — 每个持久化模型字段、`extraJson` 未知字段保留模式和完整持久化数据清单。
- [WebDAV 同步](sync.md) — 9 步逐记录三方同步流程、重试/心跳策略、图像同步和已知限制。
- [备份与恢复](backup-restore.md) — 备份格式 v2、blob 去重/GC、恢复安全规则、ZIP 导出/导入、Markdown 导出。
- [平台说明](platform-notes.md) — Windows/macOS/iOS/Android 注意、桌面本地 API 服务器、系统托盘、启动时启动。
- [CI/CD](ci-cd.md) — CI 作业和工作流注意、构建/验证命令集和全新克隆（子模块）步骤。
- [版本历史](version-history.md) — 逐发布摘要。改变看起来奇怪的行为前值得查看；几个条目记录刻意安全修复。

### 功能区

- [设备](features/devices.md) — 设备模型、生命周期/财务跟踪、财务总览图、头像渲染、级联删除规则。
- [网络](features/networks.md) — `Network` / `NetworkDevice`、网络类型、复合键赋值身份。
- [数据集](features/datasets.md) — `DataSet` / `DataSetStorageLink`、存储槽索引链接和重映射。
- [服务与拓扑](features/services-topology.md) — 手动服务清单、路由/跳、拓扑图视图、FRP 风格建模、模板。
- [在线搜索与预设](features/online-search-and-presets.md) — 设备/芯片在线搜索、商店风格门控、捆绑预设。
- [地图](features/map.md) — 只读设备地图和全屏位置选择器。

### 算法

- [三方合并](algorithms/three-way-merge.md) — 泛型 `mergeRecords<T>` 引擎和 `NetworkDevice` 的复合键 `mergeAssignments` 变体。
- [服务拓扑布局](algorithms/service-topology-layout.md) — 拓扑图背后的语义分层布局和正交边路由算法。

### 完整示例

- [同步演练](examples/sync-walkthrough.md) — 覆盖自动解决、真实冲突和 `NetworkDevice` 复合键合并的双设备同步场景。
- [服务拓扑演练](examples/service-topology-walkthrough.md) — 把反向代理后的服务建模在 FRP 隧道后到公共域。

### 其他

- [翻译指南](translation-guide.md) — （未来）`doc/zh-cn/` 翻译遍的过程备注。不属此英语遍。
- [函数索引](functions/) — 逐源文件声明参考（单独、穷举层；此处不重复）。
