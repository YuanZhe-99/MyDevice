# lib/features/services/services/service_template_service.dart

`ServiceTemplateService` 提供静态、手工维护的自托管工具模板目录（Caddy、Gitea、Jellyfin、Pangolin、FRP、Cloudflare Tunnel、Vaultwarden、Nextcloud、Minecraft 等数十个），服务编辑器模板选择器用它预填新 [`ServiceNode`](../models/service.md#servicenode-new) 的名、图标、kind、默认端点/端口和（少数）示例 Docker Compose 文件。为何这仅预填见 [服务与拓扑 — 服务模板](../../../../features/services-topology.md#service-templates)：模板绝不连接任何东西或执行发现，匹配整个功能仅手动清单约束。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`ServiceTemplate`](#servicetemplate-new) | 构造函数 | A | 创建 `ServiceTemplate` 实例。 |
| [`toService`](#servicetemplate-toservice) | 方法（`ServiceTemplate`） | A | 把此模板转换为给定设备的 `ServiceNode`。 |
| [`loadTemplates`](#loadtemplates) | 静态方法（`ServiceTemplateService`） | A | 返回完整内置模板目录。 |
| [`_template`](#_template) | 静态方法（私有，`ServiceTemplateService`） | A | 从紧凑 id/名/图标/kind/端口速记构建 `ServiceTemplate`。 |

源码中的四个已记录声明现在均有对应的 `/// Purpose:` 注释。

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
    ],
    tags: const ['media', 'video'],
    featured: true,
    dockerCompose: '''services:\n  jellyfin:\n    image: jellyfin/jellyfin\n...''',
  ),
  ```
  （需要专用端点列表或 Compose 示例的目录项直接调用此构造函数；其余单端点条目使用 [`_template`](#_template) 速记）
- **备注：** 目录条目在库加载时作为静态字面量初始化。

### `ServiceNode toService(String deviceId)` <a id="servicetemplate-toservice"></a>
- **种类：** `ServiceTemplate` 的方法。
- **来源：** `lib/features/services/services/service_template_service.dart`（第 36 行）。
- **用途：** 把此模板转换为附加到给定设备的新鲜 `ServiceNode`，把每个端点复制进新 `ServiceEndpoint`（带自己新鲜自动生成 `id`，因为 `ServiceEndpoint` 构造函数在未传时铸造一个——见 [`service.md`](../models/service.md#serviceendpoint-new)）。
- **输入：** `deviceId` — 结果服务所属的设备。
- **返回：** `templateId` 设为模板 `id` 的新 `ServiceNode`。
- **副作用：** 无（仅构造，无 IO）。
- **算法：** 构建 `ServiceNode`，从模板直接复制 `deviceId`、`name`、`templateId: id`、`icon`、`kind`、`runtime`、`tags` 和 `dockerCompose`，加对 `endpoints` 的列表推导，逐字段重建每个 `ServiceEndpoint`（刻意省略 `id`，使每个实例生成新鲜而非复用模板端点的 id，因为模板端点自己也自动生成从未打算跨服务复用的弃用 id）。
- **用法：** `lib/` 中无任何调用点——搜索仓库 `.toService(` 只找到此声明本身。
- **备注：** 此方法实际是死代码。实际"应用模板"流程（`service_edit_page.dart` 的 `_applyTemplate`）**不**调用 `toService`——它手动把相同逐字段复制直接重新实现进编辑页自己的表单状态字段（`_templateId`、`_nameCtrl`、`_icon`、`_kind`、`_runtime`、`_endpoints`、`_composeCtrl`）而非构造 `ServiceNode` 再读回拆开，因为编辑页需要单独可编辑字段，非完成 `ServiceNode`。`toService` 似乎先于表单基础流程，或为当前 UI 不使用的用例（从模板一步构造 `ServiceNode`）编写。

### `static List<ServiceTemplate> loadTemplates()` <a id="loadtemplates"></a>
- **种类：** `ServiceTemplateService` 的静态方法。
- **来源：** `lib/features/services/services/service_template_service.dart`（第 70 行）。
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

### `static ServiceTemplate _template(String id, String name, String icon, ServiceKind kind, int? port, {bool featured = false, ServiceProtocol protocol = ServiceProtocol.http, ServiceTransport transport = ServiceTransport.tcp, ServiceRuntime? runtime = ServiceRuntime.compose, int? portEnd, String? path})` <a id="_template"></a>
- **种类：** `ServiceTemplateService` 的私有静态方法。
- **来源：** `lib/features/services/services/service_template_service.dart`（第 560 行）。
- **用途：** 从 id、显示名、图标、`ServiceKind` 和单个默认端口的紧凑速记构建 `ServiceTemplate`，并允许为非 HTTP 与主机管理服务明确指定协议、传输和 runtime。
- **输入：** `id`、`name`、`icon`、`kind`、`port`（可空——`null` 意为"无默认端点"，如无固定监听端口的 Cloudflare Tunnel/Tailscale）；可选 `featured`、`protocol`、`transport`、`runtime`、`portEnd`、`path`（默认 HTTP/TCP/Compose；`runtime: null` 表示不预设部署方式）。
- **返回：** 带 `tags: [kind.name]` 且（`port` 非 null 时）带一个端点的新 `ServiceTemplate`。端口 443 会把默认 HTTP 协议升级为 HTTPS；显式协议设置保持原值。
- **副作用：** 无。
- **算法：** 1. `port` 为 `null` 时 `endpoints` 为 `[]`。2. 否则构建一个标签为 `'Default'` 的 `ServiceEndpoint`，使用指定的传输和协议；若端口为 443 且协议仍是默认 HTTP，则改为 HTTPS；并设 `scope: lan`、`isPrimary: true`。3. `dockerCompose` 总是 `_emptyCompose`（`null`）；需要多个端点或 Compose 示例的条目直接调用构造函数。
- **用法：**
  ```dart
  _template('gitea', 'Gitea', 'source', ServiceKind.git, 3000, featured: true),
  _template('minecraft', 'Minecraft Server', 'sports_esports', ServiceKind.game, 25565, featured: true),
  _template('tailscale', 'Tailscale', 'vpn_lock', ServiceKind.network, null),
  ```
  （同文件 `_templates` 列表字面量大多数条目）
- **备注：** 受影响的目录项会显式给出协议、传输和 runtime；默认值适用于常见的 HTTP/TCP Compose 部署。

## 目录审计说明

目录项将端点协议与传输分开。非 HTTP 默认值标明数据库 TCP、SSH/VNC、RDP TCP/UDP、VPN UDP、SMB TCP，以及 NFS TCP/UDP。显示名为 Sunshine 的主机模板保留历史 `moonlight` ID，使已有记录仍可识别。AdGuard Home 记录初始设置 3000/TCP、Web 界面 80/TCP 和 DNS 53/TCP+UDP。OpenCode 使用文档中的 `serve` 默认端口 4096；FRP 使用 TCP 7000；Portainer 的 9443 端点使用 HTTPS。Jellyfin 移除可选的 HTTPS 端口 8920，因为 Compose 示例未启用它。平台相关的 SSH/RDP/VNC、NanoKVM USB Gateway 和 SteamCMD 不预设 runtime；LuCI 标记为路由器应用。SteamCMD 没有统一的游戏服务器端口。Vaultwarden Admin 使用同一 Web 端点的 `/admin` 路径。Cloudflare Compose 只通过 `TUNNEL_TOKEN` 注入令牌。

### 核验资料

- [Sunshine Docker 端口映射](https://docs.lizardbyte.dev/projects/sunshine/latest/md_DOCKER__README.html)
- [AdGuard Home 端口与 Docker 设置](https://adguard-dns.io/kb/adguard-home/docker/)
- [Jellyfin 网络配置](https://jellyfin.org/docs/general/networking/)
- [Microsoft RDP 端口](https://learn.microsoft.com/en-us/troubleshoot/windows-server/remote/ports-used-by-rds)
- [Portainer HTTPS 端口 9443](https://docs.portainer.io/faqs/troubleshooting/access-and-authentication/client-sent-an-http-request-to-an-https-server)
- [OpenCode 服务端口](https://opencode.ai/docs/server/)
- [FRP 默认服务端口](https://github.com/fatedier/frp/blob/dev/conf/frps_full_example.toml)
- [WireGuard Docker 端口映射](https://docs.linuxserver.io/images/docker-wireguard/)
- [PostgreSQL 协议与端口](https://www.postgresql.org/docs/current/protocol.html)
- [SMB TCP 445](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/direct-hosting-of-smb-over-tcpip)
- [Linux NFS 服务端监听端口](https://docs.kernel.org/5.16/admin-guide/nfs/nfsd-admin-interfaces.html)
- [Valheim 专用服务器端口](https://valheim.com/support/a-guide-to-dedicated-servers/)
- [Factorio 多人游戏传输协议](https://wiki.factorio.com/Multiplayer)
- [Cloudflare Tunnel 环境变量令牌](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/)
