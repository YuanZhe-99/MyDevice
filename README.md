# MyDevice!!!!! — Your Personal Device Inventory

A clean, privacy-first app for tracking all your devices with detailed hardware specs, network management, and data organization.

## Features

- **Device Inventory** — Track all your devices by category (Desktop, Laptop, Phone, Tablet, Headphone, Watch, Router, Game Console, VPS, Dev Board). Add emoji icons or device photos as avatars.
- **CPU & GPU Chip Search** *(full flavor only)* — Fetch specs from TechPowerUp, AMD, and Intel in one search. 130+ built-in CPU/GPU templates (Intel, AMD, Apple, Qualcomm, MediaTek, and more) for instant auto-fill.
- **Network Management** — Manage LAN, Tailscale, ZeroTier, EasyTier, WireGuard, and custom networks. Configure subnet, gateway, DNS, and per-device IPs.
- **Data Sets** — Organize storage drives into named data sets with per-device breakdown display.
- **Map View** — Pin device locations on an interactive map for devices and network nodes.
- **WebDAV Cloud Sync** — Sync data to your own cloud (e.g. Nextcloud) via WebDAV, with auto or manual sync.
- **Backup & Restore** — One-tap full backup (data + images). Optional auto-backup with retention policies.
- **ZIP Export / Import** — Export all data as a `.zip` archive for easy migration.
- **Multi-Language** — English, Japanese, Simplified Chinese, Traditional Chinese.

## Build Flavors

| Flavor | Description | Online Search |
|--------|-------------|---------------|
| `full` | All features enabled — for direct distribution (GitHub Releases, desktop installer) | Yes |
| `store` | App Store / Google Play compliant — online search removed at compile time | No |

The flavor is controlled via `--dart-define=FLAVOR=store|full` (default: `full`).

## Platforms

| Platform | Artifact | Flavor |
|----------|----------|--------|
| Windows (x64)  | Inno Setup installer (`MyDevice_x.x.x_Setup.exe`) | full |
| Windows (ARM64) | Inno Setup installer (`MyDevice_x.x.x_arm64_Setup.exe`) | full |
| Android  | APK (`app-release.apk`) | full |
| Android  | AAB (`app-release.aab`) | store |
| iOS      | Sideload IPA | full |
| iOS      | App Store IPA | store |
| macOS    | DMG | full |

## Build

```bash
# ── Full flavor (direct distribution) ──

# Windows x64 installer (requires Inno Setup 6)
flutter build windows --release --dart-define=FLAVOR=full
iscc installer.iss

# Windows ARM64 installer (requires Flutter master for ARM64 engine)
flutter build windows --release --dart-define=FLAVOR=full
iscc /DARM64 installer.iss

# Android APK (icons are dynamically stored, need --no-tree-shake-icons)
flutter build apk --release --no-tree-shake-icons --dart-define=FLAVOR=full

# iOS Sideload (.app archive → install via AltStore / Sideloadly / etc.)
flutter build ios --release --no-codesign --dart-define=FLAVOR=full
# The .app is at build/ios/iphoneos/Runner.app
# To create an IPA:
mkdir -p build/ios/ipa/Payload
cp -r build/ios/iphoneos/Runner.app build/ios/ipa/Payload/
cd build/ios/ipa && zip -r MyDevice_sideload.ipa Payload && cd -

# macOS DMG
flutter build macos --release --dart-define=FLAVOR=full
# Create a DMG (requires create-dmg):
create-dmg \
  --volname "MyDevice!!!!!" \
  --app-drop-link 400 150 \
  "build/macos/MyDevice.dmg" \
  "build/macos/Build/Products/Release/MyDevice!!!!!.app"

# ── Store flavor (App Store / Google Play) ──

# Android AAB
flutter build appbundle --release --no-tree-shake-icons --dart-define=FLAVOR=store

# iOS App Store (requires signing & provisioning profile)
flutter build ipa --release --dart-define=FLAVOR=store
# Upload build/ios/ipa/*.ipa via Transporter or `xcrun altool`

# Windows (for testing only)
flutter build windows --release --dart-define=FLAVOR=store
```


## Privacy Policy

MyDevice!!!!! does not collect, upload, or share any personal information. See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for the full policy.

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
