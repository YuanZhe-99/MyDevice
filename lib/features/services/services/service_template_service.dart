import '../models/service.dart';

class ServiceTemplate {
  final String id;
  final String name;
  final String icon;
  final ServiceKind kind;
  final ServiceRuntime? runtime;
  final List<ServiceEndpoint> endpoints;
  final List<String> tags;
  final String? dockerCompose;
  final bool featured;

  /// Purpose: Create a service template instance.
  /// Inputs: Template identity, display fields, defaults, and optional Compose example.
  /// Returns: A new `ServiceTemplate` instance.
  /// Side effects: None.
  /// Notes: None.
  const ServiceTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.kind,
    this.runtime,
    this.endpoints = const [],
    this.tags = const [],
    this.dockerCompose,
    this.featured = false,
  });

  /// Purpose: Convert this template into a fresh service instance for one device.
  /// Inputs: `deviceId`.
  /// Returns: A new `ServiceNode` with independent endpoint identities.
  /// Side effects: None.
  /// Notes: Endpoint IDs are regenerated so separate services never share endpoint IDs.
  ServiceNode toService(String deviceId) => ServiceNode(
    deviceId: deviceId,
    name: name,
    templateId: id,
    icon: icon,
    kind: kind,
    runtime: runtime,
    endpoints: [
      for (final endpoint in endpoints)
        ServiceEndpoint(
          label: endpoint.label,
          protocol: endpoint.protocol,
          transport: endpoint.transport,
          bindAddress: endpoint.bindAddress,
          port: endpoint.port,
          portEnd: endpoint.portEnd,
          path: endpoint.path,
          networkId: endpoint.networkId,
          scope: endpoint.scope,
          isPrimary: endpoint.isPrimary,
          notes: endpoint.notes,
        ),
    ],
    tags: tags,
    dockerCompose: dockerCompose,
  );
}

class ServiceTemplateService {
  /// Purpose: Return the built-in service template catalog.
  /// Inputs: None.
  /// Returns: `List<ServiceTemplate>`.
  /// Side effects: None.
  /// Notes: Returns the shared catalog list instance.
  static List<ServiceTemplate> loadTemplates() => _templates;

  static const _emptyCompose = null;

  static final _templates = <ServiceTemplate>[
    _template(
      'code-server',
      'Code Server',
      'code',
      ServiceKind.dev,
      8080,
      featured: true,
    ),
    _template(
      'opencode',
      'OpenCode',
      'terminal',
      ServiceKind.ai,
      4096,
      featured: true,
      runtime: null,
    ),
    ServiceTemplate(
      id: 'moonlight', // Stable ID retained for existing service records.
      name: 'Sunshine',
      icon: 'sports_esports',
      kind: ServiceKind.media,
      runtime: null,
      endpoints: [
        ServiceEndpoint(
          label: 'HTTP',
          protocol: ServiceProtocol.http,
          transport: ServiceTransport.tcp,
          port: 47989,
          scope: ServiceScope.lan,
        ),
        ServiceEndpoint(
          label: 'HTTPS API',
          protocol: ServiceProtocol.https,
          transport: ServiceTransport.tcp,
          port: 47984,
          scope: ServiceScope.lan,
        ),
        ServiceEndpoint(
          label: 'Web UI',
          protocol: ServiceProtocol.https,
          transport: ServiceTransport.tcp,
          port: 47990,
          scope: ServiceScope.lan,
          isPrimary: true,
        ),
        ServiceEndpoint(
          label: 'RTSP',
          protocol: ServiceProtocol.rtsp,
          transport: ServiceTransport.tcp,
          port: 48010,
          scope: ServiceScope.lan,
        ),
        ServiceEndpoint(
          label: 'Streaming',
          protocol: ServiceProtocol.udp,
          transport: ServiceTransport.udp,
          port: 47998,
          portEnd: 48000,
          scope: ServiceScope.lan,
        ),
      ],
      tags: const ['media', 'game-streaming'],
      featured: true,
    ),
    _template('termix', 'Termix', 'terminal', ServiceKind.dev, 8080),
    _template('sharelatex', 'ShareLaTeX', 'edit_document', ServiceKind.dev, 80),
    _template(
      'gitea',
      'Gitea',
      'source',
      ServiceKind.git,
      3000,
      featured: true,
    ),
    _template(
      'gitea-large-repo',
      'Gitea - Large Repo',
      'source',
      ServiceKind.git,
      3000,
    ),
    _template(
      'file-browser',
      'File Browser',
      'folder',
      ServiceKind.storage,
      8080,
      featured: true,
    ),
    _template(
      'nanokvm-usb-gateway',
      'NanoKVM USB Gateway',
      'keyboard_alt',
      ServiceKind.network,
      80,
      runtime: null,
    ),
    _template(
      'nextcloud',
      'Nextcloud',
      'cloud',
      ServiceKind.storage,
      80,
      featured: true,
    ),
    _template(
      'vaultwarden',
      'Vaultwarden',
      'password',
      ServiceKind.web,
      80,
      featured: true,
    ),
    _template('astrbot', 'AstrBot', 'smart_toy', ServiceKind.ai, 6185),
    ServiceTemplate(
      id: 'jellyfin',
      name: 'Jellyfin',
      icon: 'theaters',
      kind: ServiceKind.media,
      runtime: ServiceRuntime.compose,
      endpoints: [
        ServiceEndpoint(
          label: 'Web UI',
          protocol: ServiceProtocol.http,
          transport: ServiceTransport.tcp,
          port: 8096,
          scope: ServiceScope.lan,
          isPrimary: true,
        ),
      ],
      tags: const ['media', 'video'],
      featured: true,
      dockerCompose: '''services:
  jellyfin:
    image: jellyfin/jellyfin
    container_name: jellyfin
    ports:
      - "8096:8096"
    volumes:
      - ./config:/config
      - ./cache:/cache
      - ./media:/media
    restart: unless-stopped''',
    ),
    _template(
      'wordpress',
      'WordPress',
      'article',
      ServiceKind.web,
      80,
      featured: true,
    ),
    _template(
      'pangolin',
      'Pangolin',
      'hub',
      ServiceKind.tunnel,
      443,
      featured: true,
    ),
    _template('ariang', 'AriaNg', 'download', ServiceKind.web, 80),
    _template(
      'luci',
      'LuCI',
      'router',
      ServiceKind.network,
      80,
      runtime: ServiceRuntime.routerApp,
    ),
    ServiceTemplate(
      id: 'adguard-home',
      name: 'AdGuard Home',
      icon: 'shield',
      kind: ServiceKind.network,
      runtime: ServiceRuntime.compose,
      endpoints: [
        ServiceEndpoint(
          label: 'Initial setup UI',
          protocol: ServiceProtocol.http,
          transport: ServiceTransport.tcp,
          port: 3000,
          scope: ServiceScope.lan,
        ),
        ServiceEndpoint(
          label: 'Web UI',
          protocol: ServiceProtocol.http,
          transport: ServiceTransport.tcp,
          port: 80,
          scope: ServiceScope.lan,
          isPrimary: true,
        ),
        ServiceEndpoint(
          label: 'DNS',
          protocol: ServiceProtocol.udp,
          transport: ServiceTransport.tcpUdp,
          port: 53,
          scope: ServiceScope.lan,
        ),
      ],
      tags: const ['dns', 'network'],
    ),
    ServiceTemplate(
      id: 'caddy',
      name: 'Caddy',
      icon: 'alt_route',
      kind: ServiceKind.reverseProxy,
      runtime: ServiceRuntime.compose,
      endpoints: [
        ServiceEndpoint(
          label: 'HTTP',
          protocol: ServiceProtocol.http,
          transport: ServiceTransport.tcp,
          port: 80,
          scope: ServiceScope.lan,
        ),
        ServiceEndpoint(
          label: 'HTTPS',
          protocol: ServiceProtocol.https,
          transport: ServiceTransport.tcp,
          port: 443,
          scope: ServiceScope.lan,
          isPrimary: true,
        ),
      ],
      tags: const ['proxy'],
      featured: true,
      dockerCompose: '''services:
  caddy:
    image: caddy:latest
    container_name: caddy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./data:/data
      - ./config:/config
    restart: unless-stopped''',
    ),
    _template(
      'frp',
      'FRP',
      'swap_horiz',
      ServiceKind.tunnel,
      7000,
      featured: true,
      protocol: ServiceProtocol.tcp,
      runtime: null,
    ),
    _template(
      'cloudflare-tunnel',
      'Cloudflare Tunnel',
      'cloud_sync',
      ServiceKind.tunnel,
      null,
      featured: true,
      runtime: null,
    ),
    ServiceTemplate(
      id: 'cloudflare-tunnel-compose',
      name: 'Cloudflare Tunnel (Docker)',
      icon: 'cloud_sync',
      kind: ServiceKind.tunnel,
      runtime: ServiceRuntime.compose,
      tags: const ['tunnel', 'cloudflare'],
      dockerCompose: '''services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    command: tunnel --no-autoupdate run
    environment:
      TUNNEL_TOKEN: \${TUNNEL_TOKEN}
    restart: unless-stopped''',
    ),
    _template('nginx', 'Nginx', 'alt_route', ServiceKind.reverseProxy, 80),
    _template('traefik', 'Traefik', 'alt_route', ServiceKind.reverseProxy, 80),
    _template(
      'portainer',
      'Portainer',
      'deployed_code',
      ServiceKind.dev,
      9443,
      protocol: ServiceProtocol.https,
    ),
    _template(
      'home-assistant',
      'Home Assistant',
      'home',
      ServiceKind.web,
      8123,
    ),
    _template('immich', 'Immich', 'photo_library', ServiceKind.media, 2283),
    _template('plex', 'Plex', 'movie', ServiceKind.media, 32400),
    _template('qbittorrent', 'qBittorrent', 'download', ServiceKind.web, 8080),
    _template('syncthing', 'Syncthing', 'sync', ServiceKind.storage, 8384),
    _template('minio', 'MinIO', 'inventory_2', ServiceKind.storage, 9001),
    _template(
      'postgresql',
      'PostgreSQL',
      'database',
      ServiceKind.database,
      5432,
      protocol: ServiceProtocol.tcp,
    ),
    _template(
      'mysql',
      'MySQL/MariaDB',
      'database',
      ServiceKind.database,
      3306,
      protocol: ServiceProtocol.tcp,
    ),
    _template(
      'redis',
      'Redis',
      'database',
      ServiceKind.database,
      6379,
      protocol: ServiceProtocol.tcp,
    ),
    _template('grafana', 'Grafana', 'monitoring', ServiceKind.monitoring, 3000),
    _template(
      'prometheus',
      'Prometheus',
      'monitoring',
      ServiceKind.monitoring,
      9090,
    ),
    _template(
      'uptime-kuma',
      'Uptime Kuma',
      'monitor_heart',
      ServiceKind.monitoring,
      3001,
    ),
    _template('open-webui', 'Open WebUI', 'smart_toy', ServiceKind.ai, 8080),
    _template('ollama', 'Ollama', 'memory', ServiceKind.ai, 11434),
    _template('jupyterlab', 'JupyterLab', 'science', ServiceKind.dev, 8888),
    _template(
      'ssh',
      'SSH',
      'terminal',
      ServiceKind.network,
      22,
      protocol: ServiceProtocol.ssh,
      runtime: null,
    ),
    _template(
      'rdp',
      'RDP',
      'desktop_windows',
      ServiceKind.network,
      3389,
      protocol: ServiceProtocol.tcp,
      transport: ServiceTransport.tcpUdp,
      runtime: null,
    ),
    _template(
      'vnc',
      'VNC',
      'desktop_windows',
      ServiceKind.network,
      5900,
      protocol: ServiceProtocol.vnc,
      runtime: null,
    ),
    _template(
      'wireguard',
      'WireGuard',
      'vpn_lock',
      ServiceKind.network,
      51820,
      protocol: ServiceProtocol.udp,
      transport: ServiceTransport.udp,
      runtime: null,
    ),
    _template('tailscale', 'Tailscale', 'vpn_lock', ServiceKind.network, null),
    _template('headscale', 'Headscale', 'vpn_lock', ServiceKind.network, 8080),
    _template(
      'zerotier',
      'ZeroTier',
      'vpn_lock',
      ServiceKind.network,
      9993,
      protocol: ServiceProtocol.udp,
      transport: ServiceTransport.udp,
      runtime: null,
    ),
    _template(
      'samba',
      'Samba',
      'folder_shared',
      ServiceKind.storage,
      445,
      protocol: ServiceProtocol.tcp,
      runtime: null,
    ),
    _template(
      'nfs',
      'NFS',
      'folder_shared',
      ServiceKind.storage,
      2049,
      protocol: ServiceProtocol.tcp,
      transport: ServiceTransport.tcpUdp,
      runtime: null,
    ),
    _template('webdav', 'WebDAV', 'cloud', ServiceKind.storage, 80),
    _template(
      'minecraft',
      'Minecraft Server',
      'sports_esports',
      ServiceKind.game,
      25565,
      featured: true,
      protocol: ServiceProtocol.minecraft,
    ),
    _template(
      'palworld',
      'Palworld Server',
      'sports_esports',
      ServiceKind.game,
      8211,
      protocol: ServiceProtocol.udp,
      transport: ServiceTransport.udp,
    ),
    _template(
      'factorio',
      'Factorio Server',
      'sports_esports',
      ServiceKind.game,
      34197,
      protocol: ServiceProtocol.udp,
      transport: ServiceTransport.udp,
    ),
    _template(
      'valheim',
      'Valheim Server',
      'sports_esports',
      ServiceKind.game,
      2456,
      protocol: ServiceProtocol.udp,
      transport: ServiceTransport.udp,
      portEnd: 2457,
    ),
    _template(
      'terraria',
      'Terraria Server',
      'sports_esports',
      ServiceKind.game,
      7777,
      protocol: ServiceProtocol.tcp,
    ),
    _template(
      'filebrowser-https',
      'File Browser HTTPS',
      'folder',
      ServiceKind.storage,
      443,
    ),
    _template('aria2', 'aria2 RPC', 'download', ServiceKind.web, 6800),
    _template('jellyseerr', 'Jellyseerr', 'theaters', ServiceKind.media, 5055),
    _template('sonarr', 'Sonarr', 'movie', ServiceKind.media, 8989),
    _template('radarr', 'Radarr', 'movie', ServiceKind.media, 7878),
    _template('lidarr', 'Lidarr', 'music_note', ServiceKind.media, 8686),
    _template('prowlarr', 'Prowlarr', 'search', ServiceKind.media, 9696),
    _template('navidrome', 'Navidrome', 'music_note', ServiceKind.media, 4533),
    _template('calibre-web', 'Calibre-Web', 'menu_book', ServiceKind.web, 8083),
    _template(
      'paperless-ngx',
      'Paperless-ngx',
      'article',
      ServiceKind.web,
      8000,
    ),
    _template(
      'actual-budget',
      'Actual Budget',
      'payments',
      ServiceKind.web,
      5006,
    ),
    _template('memos', 'Memos', 'sticky_note_2', ServiceKind.web, 5230),
    _template(
      'vaultwarden-admin',
      'Vaultwarden Admin',
      'password',
      ServiceKind.web,
      80,
      path: '/admin',
    ),
    _template('forgejo', 'Forgejo', 'source', ServiceKind.git, 3000),
    _template('gitlab', 'GitLab', 'source', ServiceKind.git, 80),
    _template(
      'drone',
      'Drone CI',
      'precision_manufacturing',
      ServiceKind.dev,
      80,
    ),
    _template(
      'jenkins',
      'Jenkins',
      'precision_manufacturing',
      ServiceKind.dev,
      8080,
    ),
    _template('miniflux', 'Miniflux', 'rss_feed', ServiceKind.web, 8080),
    _template('searxng', 'SearXNG', 'search', ServiceKind.web, 8080),
    _template('openproject', 'OpenProject', 'fact_check', ServiceKind.web, 80),
    _template('kanboard', 'Kanboard', 'view_kanban', ServiceKind.web, 80),
    _template('outline', 'Outline', 'edit_document', ServiceKind.web, 3000),
    _template(
      'minecraft-bedrock',
      'Minecraft Bedrock Server',
      'sports_esports',
      ServiceKind.game,
      19132,
      protocol: ServiceProtocol.minecraft,
      transport: ServiceTransport.udp,
    ),
    _template(
      'steamcmd',
      'SteamCMD Server',
      'sports_esports',
      ServiceKind.game,
      null,
      runtime: null,
    ),
  ];

  /// Purpose: Construct a catalog template with one optional endpoint.
  /// Inputs: Identity, display fields, endpoint defaults, and optional runtime metadata.
  /// Returns: A `ServiceTemplate` with the specified endpoint defaults.
  /// Side effects: None.
  /// Notes: A null port creates no endpoint; a null runtime leaves deployment method unspecified.
  static ServiceTemplate _template(
    String id,
    String name,
    String icon,
    ServiceKind kind,
    int? port, {
    bool featured = false,
    ServiceProtocol protocol = ServiceProtocol.http,
    ServiceTransport transport = ServiceTransport.tcp,
    ServiceRuntime? runtime = ServiceRuntime.compose,
    int? portEnd,
    String? path,
  }) {
    return ServiceTemplate(
      id: id,
      name: name,
      icon: icon,
      kind: kind,
      runtime: runtime,
      endpoints: port == null
          ? const []
          : [
              ServiceEndpoint(
                label: 'Default',
                protocol: protocol == ServiceProtocol.http && port == 443
                    ? ServiceProtocol.https
                    : protocol,
                transport: transport,
                port: port,
                portEnd: portEnd,
                path: path,
                scope: ServiceScope.lan,
                isPrimary: true,
              ),
            ],
      tags: [kind.name],
      dockerCompose: _emptyCompose,
      featured: featured,
    );
  }
}
