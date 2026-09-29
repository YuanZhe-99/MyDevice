# Service icon sources

Most service SVGs below come from the pinned Dashboard Icons revision
[`homarr-labs/dashboard-icons@ab52e3bfaa737cba86793c76ccfcb312f8841278`](https://github.com/homarr-labs/dashboard-icons/tree/ab52e3bfaa737cba86793c76ccfcb312f8841278).
Its full Apache-2.0 license is included as `LICENSE-Dashboard-Icons.txt`. Its README
states that product names and marks belong to their owners and are used for identification
without implying endorsement; Apache-2.0 does not grant ownership of third-party marks or
override brand guidelines.

Assets from other sources and local modifications are recorded below. For Flutter compatibility,
SVG CSS classes are inlined, unsupported animation/editor metadata is removed, and Steam's
symbol/use wrapper is expanded with a corrected viewBox. Background plates are removed from
Plex, Outline, Actual Budget, OpenProject, Open WebUI, Termix, Portainer, Sipeed and ZeroTier.
Their foreground paths remain complete. OpenCode's clip geometry is preserved; selected neutral
foregrounds use currentColor, and monochrome marks follow the app theme. Portainer uses the
upstream portainer-alt.svg variant with its blue backing circle removed.

AriaNg, Palworld and Memos raster backgrounds are removed by a border-connected colour flood,
leaving enclosed details and foreground pixels intact. The cutouts are centered on transparent
square canvases. Memos is stored losslessly as PNG after editing its upstream WebP. Terraria's
near-transparent background alpha (1-2/255) is normalized to zero. CloudCone and the Factorio
wordmark retain their original transparency. The shared renderer adds circular-safe spacing.

**Trademarks and licensing.** Every icon here is the mark of the service or product it names,
a trademark of its owner, used only to identify that service; its use implies no affiliation with
or endorsement by the owner, and an icon will be removed if its owner asks. A copyright license
(Apache-2.0, MIT and so on, listed per file) is separate from trademark rights. These files are not
part of MyDevice's GPL-3.0 source.

## SVG files and direct source URLs

| File | Fixed source URL |
|---|---|
| `actual-budget.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/actual-budget.svg) |
| `adguard-home.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/adguard-home.svg) |
| `caddy.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/caddy.svg) |
| `calibre-web.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/calibre-web.svg) |
| `cloudflared.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/cloudflared.svg) |
| `coder.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/coder.svg) |
| `filebrowser.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/filebrowser.svg) |
| `forgejo.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/forgejo.svg) |
| `frp.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/frp.svg) |
| `gitea.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/gitea.svg) |
| `gitlab.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/gitlab.svg) |
| `grafana.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/grafana.svg) |
| `headscale.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/headscale.svg) |
| `home-assistant.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/home-assistant.svg) |
| `immich.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/immich.svg) |
| `jellyfin.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/jellyfin.svg) |
| `jellyseerr.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/jellyseerr.svg) |
| `jenkins.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/jenkins.svg) |
| `jupyter.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/jupyter.svg) |
| `kanboard.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/kanboard.svg) |
| `lidarr.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/lidarr.svg) |
| `mariadb.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/mariadb.svg) |
| `minecraft.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/minecraft.svg) |
| `miniflux.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/miniflux.svg) |
| `minio.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/minio.svg) |
| `navidrome.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/navidrome.svg) |
| `nextcloud.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/nextcloud.svg) |
| `nginx.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/nginx.svg) |
| `ollama.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/ollama.svg) |
| `opencode.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/opencode.svg) |
| `openproject.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/openproject.svg) |
| `open-webui.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/open-webui.svg) |
| `openwrt.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/openwrt.svg) |
| `outline.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/outline.svg) |
| `overleaf.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/overleaf.svg) |
| `pangolin.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/pangolin.svg) |
| `paperless-ngx.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/paperless-ngx.svg) |
| `plex.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/plex.svg) |
| `portainer.svg` (transparent alternate) | [upstream `portainer-alt.svg`](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/portainer-alt.svg) |
| `postgresql.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/postgresql.svg) |
| `prometheus.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/prometheus.svg) |
| `prowlarr.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/prowlarr.svg) |
| `qbittorrent.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/qbittorrent.svg) |
| `radarr.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/radarr.svg) |
| `redis.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/redis.svg) |
| `samba-server.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/samba-server.svg) |
| `searxng.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/searxng.svg) |
| `sonarr.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/sonarr.svg) |
| `steam.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/steam.svg) |
| `sunshine.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/sunshine.svg) |
| `syncthing.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/syncthing.svg) |
| `tailscale.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/tailscale.svg) |
| `termix.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/termix.svg) |
| `traefik.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/traefik.svg) |
| `uptime-kuma.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/uptime-kuma.svg) |
| `vaultwarden.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/vaultwarden.svg) |
| `wireguard.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/wireguard.svg) |
| `wordpress.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/wordpress.svg) |
| `zerotier.svg` | [upstream](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/zerotier.svg) |

## Additional assets and licensing

| File | Fixed source URL | License / trademark note |
|---|---|---|
| `astrbot.svg` | [AstrBot `dashboard/public/favicon.svg` at `e99432c`](https://github.com/AstrBotDevs/AstrBot/blob/e99432c8766e23b6090b38b0064d843271513855/dashboard/public/favicon.svg) | Official repository asset; source repository AGPL-3.0 text is included as `LICENSE-AstrBot.txt`. AstrBot marks remain owned by their owner. Plain SVG: no `foreignObject`, `<style>`, animation, or embedded image. |
| `drone.svg` | [Drone brand `drone-logo-vector-dark.svg` at `5087d8d`](https://github.com/drone/brand/blob/5087d8deb7924bddeb502551e00f1f9f6468e0ae/logos/vector/drone-logo-vector-dark.svg) | Official Drone brand repository; its full CC BY-NC-ND 4.0 license is included as `LICENSE-Drone-Brand.txt`. Preserve the original asset and follow the license and Drone brand rules. |
| `ariang-icon.png` | [AriaNg `src/touchicon.png` at `d3ccb51`](https://github.com/mayswind/AriaNg/blob/d3ccb51527d56d8b77a5928f0e1421d02ecbc1a1/src/touchicon.png) | Official project touch icon; its gray rounded-square background was removed locally. Full MIT license included as `LICENSE-AriaNg.txt`; project mark remains its owner's trademark. |
| `sipeed.svg` | [Dashboard Icons `sipeed.svg` at pinned revision](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/svg/sipeed.svg) | Apache-2.0 text is included as `LICENSE-Dashboard-Icons.txt`; Sipeed remains a third-party mark. Dashboard Icons lists NanoKVM as an alias for this Sipeed asset. |
| `cloudcone-logo.png` | [CloudCone official brand logo](https://cloudcone.com/wp-content/uploads/2019/02/cloudcone_logo_main.png), linked from [CloudCone brand resources](https://cloudcone.com/logos/) | Official 979 x 338 PNG with native transparency, unmodified. Follow CloudCone's linked brand rules; the logo is a CloudCone mark. |
| `factorio-logo.png` | [Factorio Wiki image](https://wiki.factorio.com/images/Factorio-logo.png) | Original transparent wordmark PNG; the wiki identifies it as coming from Factorio game files. Copyright belongs to Wube Software; use as a brand identifier. The official [press-kit page](https://www.factorio.com/support/press-kit) was checked, but no direct logo file was verified there. |
| `palworld.png` | [Dashboard Icons `palworld.png` at pinned revision](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/png/palworld.png) | Apache-2.0 collection license is included as `LICENSE-Dashboard-Icons.txt`. Its purple circular background was removed locally; Palworld marks remain Pocketpair's trademarks. |
| `terraria.png` | [Dashboard Icons `terraria.png` at pinned revision](https://github.com/homarr-labs/dashboard-icons/blob/ab52e3bfaa737cba86793c76ccfcb312f8841278/png/terraria.png) | Apache-2.0 collection license is included as `LICENSE-Dashboard-Icons.txt`. The tree artwork has transparent background; near-transparent background alpha was normalized. Terraria marks remain Re-Logic's property. |
| `memos-logo.png` | [Memos `web/public/logo.webp` at `cb42e32`](https://github.com/usememos/memos/blob/cb42e326ba9cc266a6a9570c53e0fe04c62793f4/web/public/logo.webp) | Official current Memos parrot mark converted to PNG and locally background-cleaned. Full MIT license included as `LICENSE-Memos.txt`; Memos marks remain their owners' property. The upstream WEBP is a source reference, not the shipped output. |
| `valheim-logo.png` | [Official Valheim press kit](https://a.storyblok.com/f/157036/x/c6d35a5963/valheim_presskit.zip), `Valheim/Logos/logo_valheim.png` | Official transparent wordmark. Iron Gate trademark; transparent outer margins trimmed without cropping the artwork. |

The official [aria2 source tree](https://github.com/aria2/aria2/tree/9e7273583f83e881e3ec067b523ba88724088d2f)
contains no identifiable logo asset. Its [project website favicon](https://github.com/aria2/aria2.github.io/blob/b5c98b96d27dd3ecfa6b2e0a05b499ad8ac8cbd5/favicon.png)
is an official 16 x 16 opaque gray tile with a glyph resembling a zero, not a sufficiently
identifiable brand logo; it was excluded. Keep `aria2` on its generic category icon.

BandwagonHost and Cudy router templates retain category icons because no verified official
background-free logo was found. CloudCone uses its official transparent wordmark.

Valheim uses `Valheim/Logos/logo_valheim.png` from the [official press kit](https://a.storyblok.com/f/157036/x/c6d35a5963/valheim_presskit.zip), linked by the [official press page](https://valheim.com/press/).
It is saved as `valheim-logo.png` with transparent outer margins trimmed; its complete lettering
and original alpha are preserved. Valheim remains an Iron Gate trademark. The discarded
Dashboard icon's textured stone backing is not shipped.

## Service template ID mapping

| Template ID | File |
|---|---|
| `code-server` | `coder.svg` |
| `opencode` | `opencode.svg` |
| `moonlight` | `sunshine.svg` (Sunshine mark, per service configuration correction; ID retained) |
| `termix` | `termix.svg` |
| `sharelatex` | `overleaf.svg` |
| `gitea`, `gitea-large-repo` | `gitea.svg` |
| `file-browser`, `filebrowser-https` | `filebrowser.svg` |
| `nanokvm-usb-gateway` | `sipeed.svg` |
| `nextcloud` | `nextcloud.svg` |
| `vaultwarden`, `vaultwarden-admin` | `vaultwarden.svg` |
| `astrbot` | `astrbot.svg` |
| `jellyfin` | `jellyfin.svg` |
| `wordpress` | `wordpress.svg` |
| `pangolin` | `pangolin.svg` |
| `ariang` | `ariang-icon.png` (PNG; gray background removed) |
| `luci` | `openwrt.svg` |
| `adguard-home` | `adguard-home.svg` |
| `caddy` | `caddy.svg` |
| `frp` | `frp.svg` |
| `cloudflare-tunnel`, `cloudflare-tunnel-compose` | `cloudflared.svg` |
| `nginx` | `nginx.svg` |
| `traefik` | `traefik.svg` |
| `portainer` | `portainer.svg` |
| `home-assistant` | `home-assistant.svg` |
| `immich` | `immich.svg` |
| `plex` | `plex.svg` |
| `qbittorrent` | `qbittorrent.svg` |
| `syncthing` | `syncthing.svg` |
| `minio` | `minio.svg` |
| `postgresql` | `postgresql.svg` |
| `mysql` | `mariadb.svg` (template label is MySQL/MariaDB) |
| `redis` | `redis.svg` |
| `grafana` | `grafana.svg` |
| `prometheus` | `prometheus.svg` |
| `uptime-kuma` | `uptime-kuma.svg` |
| `open-webui` | `open-webui.svg` |
| `ollama` | `ollama.svg` |
| `jupyterlab` | `jupyter.svg` |
| `ssh`, `rdp`, `vnc` | Material protocol/category icon |
| `wireguard` | `wireguard.svg` |
| `tailscale` | `tailscale.svg` |
| `headscale` | `headscale.svg` |
| `zerotier` | `zerotier.svg` |
| `samba` | `samba-server.svg` |
| `nfs`, `webdav` | Material protocol/category icon |
| `minecraft`, `minecraft-bedrock` | `minecraft.svg` |
| `palworld` | `palworld.png` (background removed; see source note) |
| `factorio` | `factorio-logo.png` |
| `valheim` | `valheim-logo.png` |
| `terraria` | `terraria.png` |
| `aria2` | Material category icon (official favicon is not a recognizable brand logo) |
| `jellyseerr` | `jellyseerr.svg` |
| `sonarr` | `sonarr.svg` |
| `radarr` | `radarr.svg` |
| `lidarr` | `lidarr.svg` |
| `prowlarr` | `prowlarr.svg` |
| `navidrome` | `navidrome.svg` |
| `calibre-web` | `calibre-web.svg` |
| `paperless-ngx` | `paperless-ngx.svg` |
| `actual-budget` | `actual-budget.svg` |
| `memos` | `memos-logo.png` (official parrot mark; background removed) |
| `forgejo` | `forgejo.svg` |
| `gitlab` | `gitlab.svg` |
| `drone` | `drone.svg` |
| `jenkins` | `jenkins.svg` |
| `miniflux` | `miniflux.svg` |
| `searxng` | `searxng.svg` |
| `openproject` | `openproject.svg` |
| `kanboard` | `kanboard.svg` |
| `outline` | `outline.svg` |
| `steamcmd` | `steam.svg` |

`aria2` retains its generic download icon because no verified usable brand mark was found. `code-server` uses the Coder product mark because the project is maintained under
the Coder brand. `mysql` reuses MariaDB's mark to cover the template's combined MySQL/MariaDB
label.

Template IDs correspond to `lib/features/services/services/service_template_service.dart`.
Generic protocols and aria2 keep their existing Material icons.
