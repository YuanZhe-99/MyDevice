# lib/features/services/services/service_template_service.dart

`ServiceTemplateService` supplies the static, hand-maintained catalog of self-hosted-tool
templates (Caddy, Gitea, Jellyfin, Pangolin, FRP, Cloudflare Tunnel, Vaultwarden,
Nextcloud, Minecraft, and dozens more) that the service editor's template picker offers
to prefill a new [`ServiceNode`](../models/service.md#servicenode-new)'s name, icon, kind,
default endpoint/port, and (for a few) an example Docker Compose file. See
[Services and Topology](../../../../features/services-topology.md#service-templates) for
why this is prefill-only: templates never connect to anything or perform discovery,
matching the manual-inventory-only constraint on the whole feature.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`ServiceTemplate`](#servicetemplate-new) | constructor | A | Create a `ServiceTemplate` instance. |
| [`toService`](#servicetemplate-toservice) | method (`ServiceTemplate`) | A | Convert this template into a `ServiceNode` for a given device. |
| [`loadTemplates`](#loadtemplates) | static method (`ServiceTemplateService`) | A | Return the full built-in template catalog. |
| [`_template`](#_template) | static method (private, `ServiceTemplateService`) | A | Build a `ServiceTemplate` from a compact id/name/icon/kind/port shorthand. |

All four documented declarations have a matching `/// Purpose:` comment in the source.

## Documentation

### `const ServiceTemplate({required this.id, required this.name, required this.icon, required this.kind, this.runtime, this.endpoints = const [], this.tags = const [], this.dockerCompose, this.featured = false})` <a id="servicetemplate-new"></a>
- **Kind:** constructor of `ServiceTemplate`.
- **Source:** `lib/features/services/services/service_template_service.dart` (line 19).
- **Purpose:** Hold one catalog entry: the id used to match a chosen template back to
  `ServiceNode.templateId`, display name/icon, default `ServiceKind`/`ServiceRuntime`,
  default endpoints, tags, an optional example `dockerCompose` block, and whether it's
  `featured` (shown first/pinned in the picker).
- **Inputs:** `id`, `name`, `icon`, `kind` required; `runtime`, `dockerCompose` optional;
  `endpoints`/`tags` default to `[]`; `featured` defaults to `false`.
- **Returns:** A new `ServiceTemplate`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment.
- **Usage:**
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
  (catalog entries with specialized endpoint lists or Compose examples are built directly;
  the remaining one-endpoint entries use the [`_template`](#_template) shorthand)
- **Notes:** Catalog entries are initialized as static literals when the library loads.

### `ServiceNode toService(String deviceId)` <a id="servicetemplate-toservice"></a>
- **Kind:** method of `ServiceTemplate`.
- **Source:** `lib/features/services/services/service_template_service.dart` (line 36).
- **Purpose:** Convert this template into a fresh `ServiceNode` attached to a given
  device, copying every endpoint into a new `ServiceEndpoint` (with its own fresh
  auto-generated `id`, since `ServiceEndpoint`'s constructor mints one when none is
  passed — see
  [`../models/service.md#serviceendpoint-new`](../models/service.md#serviceendpoint-new)).
- **Inputs:** `deviceId` — the device the resulting service belongs to.
- **Returns:** A new `ServiceNode` with `templateId` set to this template's `id`.
- **Side effects:** None (construction only, no I/O).
- **Algorithm:** Build a `ServiceNode` copying `deviceId`, `name`, `templateId: id`,
  `icon`, `kind`, `runtime`, `tags`, and `dockerCompose` straight from the template, and a
  list comprehension over `endpoints` that re-constructs each `ServiceEndpoint` field by
  field (deliberately omitting `id`, so a fresh one is generated per instance rather than
  reusing the template's endpoint's id, since the template endpoints themselves also
  auto-generate throwaway ids that were never meant to be reused across services).
- **Usage:** No call site exists anywhere in `lib/` — grepping the repo for `.toService(`
  finds only this declaration itself.
- **Notes:** This method is effectively dead code. The actual "apply a template" flow
  (`service_edit_page.dart`'s `_applyTemplate`) does **not** call `toService` — it
  manually re-implements the same field-by-field copy directly into the edit page's own
  form-state fields (`_templateId`, `_nameCtrl`, `_icon`, `_kind`, `_runtime`,
  `_endpoints`, `_composeCtrl`) instead of constructing a `ServiceNode` and reading it
  back apart, because the edit page needs individually editable fields, not a finished
  `ServiceNode`. `toService` appears to predate that form-based flow, or to have been
  written for a use case (constructing a `ServiceNode` in one step from a template) that
  the current UI doesn't exercise.

### `static List<ServiceTemplate> loadTemplates()` <a id="loadtemplates"></a>
- **Kind:** static method of `ServiceTemplateService`.
- **Source:** `lib/features/services/services/service_template_service.dart` (line 70).
- **Purpose:** Return the full built-in template catalog.
- **Inputs:** None.
- **Returns:** `List<ServiceTemplate>` — the static `_templates` list (~90 entries as of
  this file), unfiltered and unsorted.
- **Side effects:** None (returns a reference to a `static final` list; no I/O, no
  network — the catalog is entirely hardcoded in this file, not fetched or discovered).
- **Algorithm:** `=> _templates` — direct return of the module-level constant list.
- **Usage:**
  ```dart
  final templates = ServiceTemplateService.loadTemplates().where((template) {
    final matchesKind = _kind == null || template.kind == _kind;
    ...
  }).toList();
  ```
  (from `service_edit_page.dart`'s `_filteredTemplates`, which filters by kind and a
  search query, then sorts featured-first; also used by `_templateName` in the same file
  to resolve a stored `templateId` back to a display name)
- **Notes:** Callers get the *same* list instance back every call (no copy) — nothing in
  this codebase mutates it, but a caller technically could, since `_templates` is
  `List<ServiceTemplate>`, not an unmodifiable view.

### `static ServiceTemplate _template(String id, String name, String icon, ServiceKind kind, int? port, {bool featured = false, ServiceProtocol protocol = ServiceProtocol.http, ServiceTransport transport = ServiceTransport.tcp, ServiceRuntime? runtime = ServiceRuntime.compose, int? portEnd, String? path})` <a id="_template"></a>
- **Kind:** private static method of `ServiceTemplateService`.
- **Source:** `lib/features/services/services/service_template_service.dart` (line 560).
- **Purpose:** Build a `ServiceTemplate` from a compact shorthand — an id, display name,
  icon, `ServiceKind`, and a single default port, with explicit protocol, transport, and
  runtime overrides for non-HTTP and host-managed services.
- **Inputs:** `id`, `name`, `icon`, `kind`, `port` (nullable — `null` means "no default
  endpoint", e.g. Cloudflare Tunnel/Tailscale which have no fixed listening port);
  optional `featured`, `protocol`, `transport`, `runtime`, `portEnd`, and `path` (defaulting
  to HTTP/TCP/Compose; `runtime: null` leaves the deployment method unspecified).
- **Returns:** A new `ServiceTemplate` with `tags: [kind.name]` and (when `port` is
  non-null) one endpoint. Port 443 upgrades the default HTTP protocol to HTTPS; an explicit
  protocol override is retained.
- **Side effects:** None.
- **Algorithm:** 1. If `port` is `null`, `endpoints` is `[]`. 2. Otherwise, build one
  `ServiceEndpoint` labeled `'Default'` using the supplied transport and protocol, with
  the default HTTP protocol upgraded to HTTPS at port 443; set `scope: lan` and
  `isPrimary: true`. 3. `dockerCompose` is always `_emptyCompose` (`null`); entries needing
  multiple endpoints or Compose examples use direct constructor calls.
- **Usage:**
  ```dart
  _template('gitea', 'Gitea', 'source', ServiceKind.git, 3000, featured: true),
  _template('minecraft', 'Minecraft Server', 'sports_esports', ServiceKind.game, 25565, featured: true),
  _template('tailscale', 'Tailscale', 'vpn_lock', ServiceKind.network, null),
  ```
  (the majority of entries in the `_templates` list literal in this same file)
- **Notes:** Protocol, transport, and runtime exceptions are stated at each affected
  catalog entry; the defaults suit the common HTTP-over-TCP Compose deployment.

## Catalog audit notes

The catalog keeps endpoint protocol separate from transport. Non-HTTP defaults identify
database TCP, SSH/VNC, RDP TCP/UDP, VPN UDP, SMB TCP, and NFS TCP/UDP. The displayed
Sunshine host retains the historical `moonlight` ID so existing records continue to resolve.
AdGuard Home records 3000/TCP for initial setup, 80/TCP for its web interface, and 53/TCP+UDP
for DNS. OpenCode uses its documented `serve` port 4096; FRP uses TCP on 7000; Portainer's
9443 endpoint is HTTPS. Jellyfin omits optional HTTPS port 8920 because its Compose example
does not enable it. Runtime stays unset for platform-dependent SSH/RDP/VNC, NanoKVM USB
Gateway, and SteamCMD; LuCI is a router app. SteamCMD has no single game-server port.
Vaultwarden Admin uses `/admin` on the same web endpoint. Cloudflare Compose injects the
token once through `TUNNEL_TOKEN`.

### Verification references

- [Sunshine Docker port mappings](https://docs.lizardbyte.dev/projects/sunshine/latest/md_DOCKER__README.html)
- [AdGuard Home ports and Docker setup](https://adguard-dns.io/kb/adguard-home/docker/)
- [Jellyfin networking](https://jellyfin.org/docs/general/networking/)
- [Microsoft RDP ports](https://learn.microsoft.com/en-us/troubleshoot/windows-server/remote/ports-used-by-rds)
- [Portainer HTTPS port 9443](https://docs.portainer.io/faqs/troubleshooting/access-and-authentication/client-sent-an-http-request-to-an-https-server)
- [OpenCode server port](https://opencode.ai/docs/server/)
- [FRP server default port](https://github.com/fatedier/frp/blob/dev/conf/frps_full_example.toml)
- [WireGuard Docker port mapping](https://docs.linuxserver.io/images/docker-wireguard/)
- [PostgreSQL protocol and port](https://www.postgresql.org/docs/current/protocol.html)
- [SMB over TCP port 445](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/direct-hosting-of-smb-over-tcpip)
- [Linux NFS server listeners](https://docs.kernel.org/5.16/admin-guide/nfs/nfsd-admin-interfaces.html)
- [Valheim dedicated-server ports](https://valheim.com/support/a-guide-to-dedicated-servers/)
- [Factorio multiplayer transport](https://wiki.factorio.com/Multiplayer)
- [Cloudflare Tunnel token environment variable](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/)
