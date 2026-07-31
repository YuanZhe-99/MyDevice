# lib/features/services/services/service_template_service.dart

`ServiceTemplateService` 提供静态、手工维护的自托管工具模板目录（Caddy、Gitea、Jellyfin、Pangolin、FRP、Cloudflare Tunnel、Vaultwarden、Nextcloud、Minecraft 等数十个），服务编辑器模板选择器用它预填新 [`ServiceNode`](../models/service.md#servicenode-new) 的名、图标、kind、默认端点/端口和（少数）示例 Docker Compose 文件。为何这仅预填见 [服务与拓扑 — 服务模板](../../../../features/services-topology.md#service-templates)：模板绝不连接任何东西或执行发现，匹配整个功能仅手动清单约束。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`ServiceTemplate`](#servicetemplate-new) | 构造函数 | A | 创建 `ServiceTemplate` 实例。 |
| [`toService`](#servicetemplate-toservice) | 方法（`ServiceTemplate`） | A | 把此模板转换为给定设备的 `ServiceNode`。 |
| [`loadTemplates`](#loadtemplates) | 静态方法（`ServiceTemplateService`） | A | 返回完整内置模板目录。 |
| [`_template`](#_template) | 静态方法（私有，`ServiceTemplateService`） | A | 从紧凑 id/名/图标/kind/端口速记构建 `ServiceTemplate`。 |

行数（4）不匹配 `grep -c 'Purpose:' service_template_service.dart`（3）：[`toService`](#servicetemplate-toservice) 源码完全无 `/// Purpose:` 文档注释（直接读文件确认——其声明上方无任何注释），而其他三个声明各带一个。

## 文档

### `const ServiceTemplate({required this.id, required this.name, required this.icon, required this.kind, this.runtime, this.endpoints = const [], this.tags = const [], this.dockerCompose, this.featured = false})` <a id="servicetemplate-new"></a>
- **种类：** `ServiceTemplate` 的构造函数。
- **来源：** `lib/features/services/services/service_template_service.dart`（第 19 行）。
- **用途：** 持有一个目录条目：把所选模板匹配回 `ServiceNode.templateId` 的 id、显示名/图标、默认 `ServiceKind`/`ServiceRuntime`、默认端点、标签、可选示例 `dockerCompose` 块，以及是否 `featured`（选择器中先显示/置顶）。
- **输入：** `id`、`name`、`icon`、`kind` 必填；`runtime`、`dockerCompose` 可选；`endpoints`/`tags` 默认 `[]`；`featured` 默认 `false`。
- **返回：** 新 `ServiceTemplate`。
- **副作用：** 无。
- **算法：** 平凡字段赋值。
- **用法：**
  ```dart
  ServiceTemplate(
    id: 'jellyfin',
    name: 'Jellyfin',
    icon: 'theaters',
    kind: ServiceKind.media,
    runtime: ServiceRuntime.compose,
    endpoints: [
      ServiceEndpoint(label: 'Web UI', protocol: ServiceProtocol.http, ...),
      ServiceEndpoint(label: 'HTTPS', protocol: ServiceProtocol.https, ...),
    ],
    tags: const ['media', 'video'],
    featured: true,
    dockerCompose: '''services:\n  jellyfin:\n    image: jellyfin/jellyfin\n...''',
  ),
  ```
  （三个目录条目之一——Jellyfin、Caddy、Cloudflare Tunnel (Docker)——对需要多端点或 Compose 示例的模板直接调用此构造函数构建；每个其他目录条目改经 [`_template`](#_template) 速记）
- **备注：** 此构造函数在 `endpoints`/`tags` 为逐条目构建非空列表字面量时不可 `const` 调用（Dart 这里仍允许 `const` 集合字面量，因为每个参数本身是编译期常量），因此约 90 个目录条目每个都是字面量，非运行时构建。

### `ServiceNode toService(String deviceId)` <a id="servicetemplate-toservice"></a>
- **种类：** `ServiceTemplate` 的方法。
- **来源：** `lib/features/services/services/service_template_service.dart`（第 31 行）。
- **用途：** 把此模板转换为附加到给定设备的新鲜 `ServiceNode`，把每个端点复制进新 `ServiceEndpoint`（带自己新鲜自动生成 `id`，因为 `ServiceEndpoint` 构造函数在未传时铸造一个——见 [`service.md`](../models/service.md#serviceendpoint-new)）。
- **输入：** `deviceId` — 结果服务所属的设备。
- **返回：** `templateId` 设为模板 `id` 的新 `ServiceNode`。
- **副作用：** 无（仅构造，无 IO）。
- **算法：** 构建 `ServiceNode`，从模板直接复制 `deviceId`、`name`、`templateId: id`、`icon`、`kind`、`runtime`、`tags` 和 `dockerCompose`，加对 `endpoints` 的列表推导，逐字段重建每个 `ServiceEndpoint`（刻意省略 `id`，使每个实例生成新鲜而非复用模板端点的 id，因为模板端点自己也自动生成从未打算跨服务复用的弃用 id）。
- **用法：** `lib/` 中无任何调用点——搜索仓库 `.toService(` 只找到此声明本身。
- **备注：** 此方法实际是死代码。实际"应用模板"流程（`service_edit_page.dart` 的 `_applyTemplate`）**不**调用 `toService`——它手动把相同逐字段复制直接重新实现进编辑页自己的表单状态字段（`_templateId`、`_nameCtrl`、`_icon`、`_kind`、`_runtime`、`_endpoints`、`_composeCtrl`）而非构造 `ServiceNode` 再读回拆开，因为编辑页需要单独可编辑字段，非完成 `ServiceNode`。`toService` 似乎先于表单基础流程，或为当前 UI 不使用的用例（从模板一步构造 `ServiceNode`）编写。

### `static List<ServiceTemplate> loadTemplates()` <a id="loadtemplates"></a>
- **种类：** `ServiceTemplateService` 的静态方法。
- **来源：** `lib/features/services/services/service_template_service.dart`（第 65 行）。
- **用途：** 返回完整内置模板目录。
- **输入：** 无。
- **返回：** `List<ServiceTemplate>` — 静态 `_templates` 列表（截至本文件约 90 条目），不过滤不排序。
- **副作用：** 无（返回 `static final` 列表引用；无 IO、无网络——目录完全硬编码在本文件，不获取不发现）。
- **算法：** `=> _templates` — 直接返回模块级常量列表。
- **用法：**
  ```dart
  final templates = ServiceTemplateService.loadTemplates().where((template) {
    final matchesKind = _kind == null || template.kind == _kind;
    ...
  }).toList();
  ```
  （来自 `service_edit_page.dart` 的 `_filteredTemplates`，它按 kind 和搜索查询过滤、然后置顶排序 featured；同文件 `_templateName` 也用其把存储 `templateId` 解析回显示名）
- **备注：** 调用方每次调用得到*相同*列表实例（无副本）——本代码库无任何东西修改它，但技术上调用方可，因为 `_templates` 是 `List<ServiceTemplate>`，非不可修改视图。

### `static ServiceTemplate _template(String id, String name, String icon, ServiceKind kind, int? port, {bool featured = false})` <a id="_template"></a>
- **种类：** `ServiceTemplateService` 的私有静态方法。
- **来源：** `lib/features/services/services/service_template_service.dart`（第 439 行）。
- **用途：** 从紧凑速记——id、显示名、图标、`ServiceKind` 和单个默认端口——构建 `ServiceTemplate`，用于只需要一个端点且无 Compose 示例的绝大多数目录条目。
- **输入：** `id`、`name`、`icon`、`kind`、`port`（可空——`null` 意为"无默认端点"，如无固定监听端口的 Cloudflare Tunnel/Tailscale）；可选 `featured`。
- **返回：** 带 `runtime: ServiceRuntime.compose`、`tags: [kind.name]` 和（`port` 非 null 时）单个默认端点的新 `ServiceTemplate`。
- **副作用：** 无。
- **算法：** 1. `port` 为 `null` 时 `endpoints` 为 `[]`。2. 否则构建 `'Default'` 标签、`port == 443` 时 `https` 否则 `http` 的 `protocol`、`transport: tcp`、`scope: lan`、`isPrimary: true` 的一个 `ServiceEndpoint`。3. `dockerCompose` 总是 `_emptyCompose`（`const null`），因此速记模板从不带示例 Compose 文件——只有经完整 [`ServiceTemplate`](#servicetemplate-new) 构造函数直接构建的模板（Jellyfin、Caddy、Cloudflare Tunnel (Docker)）带。
- **用法：**
  ```dart
  _template('gitea', 'Gitea', 'source', ServiceKind.git, 3000, featured: true),
  _template('minecraft', 'Minecraft Server', 'sports_esports', ServiceKind.game, 25565, featured: true),
  _template('tailscale', 'Tailscale', 'vpn_lock', ServiceKind.network, null),
  ```
  （同文件 `_templates` 列表字面量大多数条目）
- **备注：** `port == 443 ? https : http` 推断是唯一猜测而非显式陈述协议的地方——经完整构造函数构建的每个多端点模板改直接陈述每个端点 `protocol`。
