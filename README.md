# MyDevice!!!!! — Your Personal Device Inventory

A clean, privacy-first app for tracking all your devices with detailed hardware specs, network management, and data organization.

## Features

- **Device Inventory** — Track all your devices by category (Desktop, Laptop, Phone, Tablet, Headphone, Watch, Router, Game Console, VPS, Dev Board). Add emoji icons or device photos as avatars.
- **CPU & GPU Chip Search** — Fetch specs from TechPowerUp, AMD, and Intel in one search. 130+ built-in CPU/GPU templates (Intel, AMD, Apple, Qualcomm, MediaTek, and more) for instant auto-fill.
- **Network Management** — Manage LAN, Tailscale, ZeroTier, EasyTier, WireGuard, and custom networks. Configure subnet, gateway, DNS, and per-device IPs.
- **Data Sets** — Organize storage drives into named data sets with per-device breakdown display.
- **Map View** — Pin device locations on an interactive map for devices and network nodes.
- **WebDAV Cloud Sync** — Sync data to your own cloud (e.g. Nextcloud) via WebDAV, with auto or manual sync.
- **Backup & Restore** — One-tap full backup (data + images). Optional auto-backup with retention policies.
- **ZIP Export / Import** — Export all data as a `.zip` archive for easy migration.
- **Multi-Language** — English, Japanese, Simplified Chinese, Traditional Chinese.

## Platforms

| Platform | Artifact |
|----------|----------|
| Windows  | Inno Setup installer (`MyDevice_x.x.x_Setup.exe`) |
| Android  | APK (`app-release.apk`) |

## Build

```bash
# Android APK (icons are dynamically stored, need --no-tree-shake-icons)
flutter build apk --release --no-tree-shake-icons

# Windows installer (requires Inno Setup 6)
flutter build windows --release
& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" installer.iss
# Output: build\installer\MyDevice_<version>_Setup.exe
```

## Privacy Policy

MyDevice!!!!! does not collect, upload, or share any personal information. See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for the full policy.

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
