import 'package:flutter/material.dart';

import '../../../shared/widgets/template_icon.dart';
import '../models/service.dart';
import '../services/service_template_service.dart';
import 'service_icon.dart';

/// A template's brand mark, preserving explicitly customized service icons.
class ServiceAvatar extends StatelessWidget {
  final String? templateId;
  final String? icon;
  final double size;

  /// Purpose: Configure an avatar for a service or template preview.
  /// Inputs: `templateId`, stored Material `icon`, and avatar `size`.
  /// Returns: A new `ServiceAvatar`.
  /// Side effects: None.
  /// Notes: Unknown templates and customized icon names use Material icons.
  const ServiceAvatar({super.key, this.templateId, this.icon, this.size = 40});

  /// Purpose: Display an existing service using its template and icon metadata.
  /// Inputs: `service` and optional `size`.
  /// Returns: A new `ServiceAvatar`.
  /// Side effects: None.
  /// Notes: Does not modify the service or its persisted icon.
  ServiceAvatar.fromService(ServiceNode service, {super.key, this.size = 40})
    : templateId = service.templateId,
      icon = service.icon;

  /// Purpose: Resolve a brand asset only when the template's icon is unchanged.
  /// Inputs: `context`.
  /// Returns: A contained brand avatar or the service's Material icon.
  /// Side effects: Loads a bundled image through TemplateIcon.
  /// Notes: Legacy services acquire logos without a data migration.
  @override
  Widget build(BuildContext context) {
    final template = ServiceTemplateService.loadTemplates()
        .where((entry) => entry.id == templateId)
        .firstOrNull;
    final asset = template != null && (icon == null || icon == template.icon)
        ? serviceTemplateIconAssets[templateId]
        : null;
    return TemplateIcon(
      asset: asset,
      fallback: iconForServiceIcon(icon ?? template?.icon),
      size: size,
      foregroundColor: _monochromeAssets.contains(asset)
          ? Theme.of(context).colorScheme.onSurface
          : null,
    );
  }
}

// These marks have one foreground colour; tinting preserves dark-theme contrast.
const _monochromeAssets = {
  'assets/service_icons/coder.svg',
  'assets/service_icons/vaultwarden.svg',
  'assets/service_icons/ollama.svg',
  'assets/service_icons/tailscale.svg',
  'assets/service_icons/miniflux.svg',
  'assets/service_icons/outline.svg',
  'assets/service_icons/open-webui.svg',
  'assets/service_icons/actual-budget.svg',
  'assets/service_icons/openproject.svg',
  'assets/service_icons/portainer.svg',
  'assets/service_icons/sipeed.svg',
  'assets/service_icons/zerotier.svg',
};

/// Bundled assets keyed by stable template IDs; variants share their brand mark.
const serviceTemplateIconAssets = <String, String>{
  'code-server': 'assets/service_icons/coder.svg',
  'opencode': 'assets/service_icons/opencode.svg',
  'moonlight': 'assets/service_icons/sunshine.svg',
  'termix': 'assets/service_icons/termix.svg',
  'sharelatex': 'assets/service_icons/overleaf.svg',
  'gitea': 'assets/service_icons/gitea.svg',
  'gitea-large-repo': 'assets/service_icons/gitea.svg',
  'file-browser': 'assets/service_icons/filebrowser.svg',
  'filebrowser-https': 'assets/service_icons/filebrowser.svg',
  'nextcloud': 'assets/service_icons/nextcloud.svg',
  'vaultwarden': 'assets/service_icons/vaultwarden.svg',
  'vaultwarden-admin': 'assets/service_icons/vaultwarden.svg',
  'astrbot': 'assets/service_icons/astrbot.svg',
  'jellyfin': 'assets/service_icons/jellyfin.svg',
  'wordpress': 'assets/service_icons/wordpress.svg',
  'pangolin': 'assets/service_icons/pangolin.svg',
  'luci': 'assets/service_icons/openwrt.svg',
  'adguard-home': 'assets/service_icons/adguard-home.svg',
  'caddy': 'assets/service_icons/caddy.svg',
  'frp': 'assets/service_icons/frp.svg',
  'cloudflare-tunnel': 'assets/service_icons/cloudflared.svg',
  'cloudflare-tunnel-compose': 'assets/service_icons/cloudflared.svg',
  'nginx': 'assets/service_icons/nginx.svg',
  'traefik': 'assets/service_icons/traefik.svg',
  'portainer': 'assets/service_icons/portainer.svg',
  'home-assistant': 'assets/service_icons/home-assistant.svg',
  'immich': 'assets/service_icons/immich.svg',
  'plex': 'assets/service_icons/plex.svg',
  'qbittorrent': 'assets/service_icons/qbittorrent.svg',
  'syncthing': 'assets/service_icons/syncthing.svg',
  'minio': 'assets/service_icons/minio.svg',
  'postgresql': 'assets/service_icons/postgresql.svg',
  'mysql': 'assets/service_icons/mariadb.svg',
  'redis': 'assets/service_icons/redis.svg',
  'grafana': 'assets/service_icons/grafana.svg',
  'prometheus': 'assets/service_icons/prometheus.svg',
  'uptime-kuma': 'assets/service_icons/uptime-kuma.svg',
  'open-webui': 'assets/service_icons/open-webui.svg',
  'ollama': 'assets/service_icons/ollama.svg',
  'jupyterlab': 'assets/service_icons/jupyter.svg',
  'wireguard': 'assets/service_icons/wireguard.svg',
  'tailscale': 'assets/service_icons/tailscale.svg',
  'headscale': 'assets/service_icons/headscale.svg',
  'zerotier': 'assets/service_icons/zerotier.svg',
  'samba': 'assets/service_icons/samba-server.svg',
  'minecraft': 'assets/service_icons/minecraft.svg',
  'minecraft-bedrock': 'assets/service_icons/minecraft.svg',
  'jellyseerr': 'assets/service_icons/jellyseerr.svg',
  'sonarr': 'assets/service_icons/sonarr.svg',
  'radarr': 'assets/service_icons/radarr.svg',
  'lidarr': 'assets/service_icons/lidarr.svg',
  'prowlarr': 'assets/service_icons/prowlarr.svg',
  'navidrome': 'assets/service_icons/navidrome.svg',
  'calibre-web': 'assets/service_icons/calibre-web.svg',
  'paperless-ngx': 'assets/service_icons/paperless-ngx.svg',
  'actual-budget': 'assets/service_icons/actual-budget.svg',
  'forgejo': 'assets/service_icons/forgejo.svg',
  'gitlab': 'assets/service_icons/gitlab.svg',
  'jenkins': 'assets/service_icons/jenkins.svg',
  'miniflux': 'assets/service_icons/miniflux.svg',
  'searxng': 'assets/service_icons/searxng.svg',
  'openproject': 'assets/service_icons/openproject.svg',
  'kanboard': 'assets/service_icons/kanboard.svg',
  'outline': 'assets/service_icons/outline.svg',
  'steamcmd': 'assets/service_icons/steam.svg',
  'nanokvm-usb-gateway': 'assets/service_icons/sipeed.svg',
  'drone': 'assets/service_icons/drone.svg',
  'terraria': 'assets/service_icons/terraria.png',
  'ariang': 'assets/service_icons/ariang-icon.png',
  'palworld': 'assets/service_icons/palworld.png',
  'factorio': 'assets/service_icons/factorio-logo.png',
  'memos': 'assets/service_icons/memos-logo.png',
  'valheim': 'assets/service_icons/valheim-logo.png',
};
