import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../models/device.dart';
import '../widgets/device_category_icon.dart';
import 'device_edit_page.dart';

class DeviceDetailPage extends StatelessWidget {
  final Device device;
  final VoidCallback? onDeviceChanged;

  const DeviceDetailPage({
    super.key,
    required this.device,
    this.onDeviceChanged,
  });

  static const _brandLogoMap = {
    'apple': 'assets/logos/apple.svg',
    'samsung': 'assets/logos/samsung.svg',
    'google': 'assets/logos/google.svg',
    'microsoft': 'assets/logos/microsoft.svg',
    'sony': 'assets/logos/sony.svg',
    'lg': 'assets/logos/lg.svg',
    'huawei': 'assets/logos/huawei.svg',
    'xiaomi': 'assets/logos/xiaomi.svg',
    'lenovo': 'assets/logos/lenovo.svg',
    'dell': 'assets/logos/dell.svg',
    'hp': 'assets/logos/hp.svg',
    'asus': 'assets/logos/asus.svg',
    'acer': 'assets/logos/acer.svg',
    'nvidia': 'assets/logos/nvidia.svg',
    'amd': 'assets/logos/amd.svg',
    'intel': 'assets/logos/intel.svg',
    'qualcomm': 'assets/logos/qualcomm.svg',
    'mediatek': 'assets/logos/mediatek.svg',
    'broadcom': 'assets/logos/broadcom.svg',
    'arm': 'assets/logos/arm.svg',
    'nintendo': 'assets/logos/nintendo.svg',
    'razer': 'assets/logos/razer.svg',
    'oneplus': 'assets/logos/oneplus.svg',
    'raspberry': 'assets/logos/raspberrypi.svg',
    'valve': 'assets/logos/valve.svg',
    'linksys': 'assets/logos/linksys.svg',
    'tp-link': 'assets/logos/tplink.svg',
    'netgear': 'assets/logos/netgear.svg',
    'ubiquiti': 'assets/logos/ubiquiti.svg',
    'gl.inet': 'assets/logos/glinet.svg',
    'oracle': 'assets/logos/oracle.svg',
    'google cloud': 'assets/logos/googlecloud.svg',
    'aws': 'assets/logos/amazonaws.svg',
    'amazon': 'assets/logos/amazonaws.svg',
    'digitalocean': 'assets/logos/digitalocean.svg',
    'vultr': 'assets/logos/vultr.svg',
    'cloudflare': 'assets/logos/cloudflare.svg',
    'hetzner': 'assets/logos/hetzner.svg',
    'akamai': 'assets/logos/akamai.svg',
    'ovh': 'assets/logos/ovh.svg',
  };

  static const _storageBrandLogoMap = {
    'samsung': 'assets/logos/samsung.svg',
    'western digital': 'assets/logos/westerndigital.svg',
    'wd': 'assets/logos/westerndigital.svg',
    'seagate': 'assets/logos/seagate.svg',
    'kingston': 'assets/logos/kingston.svg',
    'crucial': 'assets/logos/micron.svg',
    'micron': 'assets/logos/micron.svg',
    'sandisk': 'assets/logos/sandisk.svg',
    'sk hynix': 'assets/logos/skhynix.svg',
    'skhynix': 'assets/logos/skhynix.svg',
    'hynix': 'assets/logos/skhynix.svg',
    'toshiba': 'assets/logos/toshiba.svg',
    'kioxia': 'assets/logos/kioxia.svg',
    'intel': 'assets/logos/intel.svg',
    'apple': 'assets/logos/apple.svg',
  };

  static const _osLogoMap = {
    'windows': 'assets/logos/windows.svg',
    'android': 'assets/logos/android.svg',
    'ios': 'assets/logos/ios.svg',
    'ipados': 'assets/logos/ios.svg',
    'macos': 'assets/logos/macos.svg',
    'mac os': 'assets/logos/macos.svg',
    'linux': 'assets/logos/linux.svg',
    'ubuntu': 'assets/logos/ubuntu.svg',
    'debian': 'assets/logos/debian.svg',
    'fedora': 'assets/logos/fedora.svg',
    'arch': 'assets/logos/archlinux.svg',
    'chromeos': 'assets/logos/chromeos.svg',
    'chrome os': 'assets/logos/chromeos.svg',
    'harmonyos': 'assets/logos/harmonyos.svg',
    'harmony': 'assets/logos/harmonyos.svg',
    'openwrt': 'assets/logos/openwrt.svg',
    'freebsd': 'assets/logos/freebsd.svg',
  };

  String? _detectBrandLogo() {
    if (device.brand == null) return null;
    final lower = device.brand!.toLowerCase();
    for (final entry in _brandLogoMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static String? _detectModelLogo(String? model) {
    if (model == null) return null;
    final lower = model.toLowerCase();
    for (final entry in _brandLogoMap.entries) {
      if (lower.startsWith(entry.key)) return entry.value;
    }
    // ARM Mali GPUs
    if (lower.startsWith('mali')) return _brandLogoMap['arm'];
    if (lower.startsWith('immortalis')) return _brandLogoMap['arm'];
    return null;
  }

  /// Detect storage brand logo.
  static String? _detectStorageBrandLogo(String? brand) {
    if (brand == null) return null;
    final lower = brand.toLowerCase();
    for (final entry in _storageBrandLogoMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Detect OS logo with flexible matching.
  /// "Windows 11 LTSC" → windows, "Ubuntu Server" → ubuntu, etc.
  static String? _detectOsLogo(String? os) {
    if (os == null) return null;
    final lower = os.toLowerCase();
    for (final entry in _osLogoMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deviceDetail),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => DeviceEditPage(device: device),
                ),
              );
              onDeviceChanged?.call();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Hero header ──
          _buildHeader(theme, cs, l10n),
          const SizedBox(height: 24),

          // ── CPU ──
          if (device.cpu.model != null) ...[
            _sectionTitle(theme, cs, l10n.cpuInfo, Icons.memory,
                logoPath: _detectModelLogo(device.cpu.model)),
            _specCard(theme, [
              _specRow(l10n.cpuModel, device.cpu.model),
              _specRow(l10n.cpuArchitecture, device.cpu.architecture),
              _specRow(l10n.cpuFrequency, device.cpu.frequency),
              _specRow(l10n.cpuPCores, device.cpu.performanceCores?.toString()),
              _specRow(l10n.cpuECores, device.cpu.efficiencyCores?.toString()),
              _specRow(l10n.cpuThreads, device.cpu.threads?.toString()),
              _specRow(l10n.cpuCache, device.cpu.cache),
            ]),
            const SizedBox(height: 16),
          ],

          // ── GPU ──
          if (device.gpu.model != null) ...[
            _sectionTitle(theme, cs, l10n.gpuInfo, Icons.graphic_eq,
                logoPath: _detectModelLogo(device.gpu.model)),
            _specCard(theme, [
              _specRow(l10n.gpuModel, device.gpu.model),
              _specRow(l10n.gpuArchitecture, device.gpu.architecture),
            ]),
            const SizedBox(height: 16),
          ],

          // ── Memory & Storage ──
          if (device.ram != null || device.storage.isNotEmpty) ...[
            _sectionTitle(theme, cs, l10n.ram, Icons.sd_storage),
            _specCard(theme, [
              _specRow(l10n.ram, device.ram != null
                  ? device.ramType != null
                      ? '${device.ram} ${device.ramType!.displayName}'
                      : device.ram
                  : null),
              for (int i = 0; i < device.storage.length; i++) ...[
                _specRow('${l10n.storage} ${i + 1}', device.storage[i].displayString),
                if (device.storage[i].brand != null)
                  _specRowWithLogo(l10n.storageBrand, device.storage[i].brand!, _detectStorageBrandLogo(device.storage[i].brand), cs),
                if (device.storage[i].serialNumber != null)
                  _specRow(l10n.storageSerialNumber, device.storage[i].serialNumber),
              ],
            ]),
            const SizedBox(height: 16),
          ],

          // ── Display ──
          if (device.screenSize != null ||
              device.screenResolutionW != null) ...[
            _sectionTitle(theme, cs, l10n.screenSize, Icons.monitor),
            _specCard(theme, [
              _specRow(l10n.screenSize, device.screenSize),
              if (device.screenResolutionW != null &&
                  device.screenResolutionH != null)
                _specRow(
                  l10n.screenResolution,
                  '${device.screenResolutionW} × ${device.screenResolutionH}',
                ),
              if (device.ppi != null)
                _specRow(l10n.ppi, device.ppi!.toStringAsFixed(0)),
            ]),
            const SizedBox(height: 16),
          ],

          // ── Other ──
          if (device.battery != null || device.os != null || device.locationName != null || device.serialNumber != null) ...[
            _sectionTitle(theme, cs, l10n.os, Icons.info_outline,
                logoPath: _detectOsLogo(device.os)),
            _specCard(theme, [
              _specRow(l10n.deviceSerialNumber, device.serialNumber),
              _specRow(l10n.battery, device.battery),
              _specRow(l10n.os, device.os),
              _specRow(l10n.deviceLocation, device.locationName),
            ]),
            const SizedBox(height: 16),
          ],

          // ── Map ──
          if (device.latitude != null && device.longitude != null) ...[
            _sectionTitle(theme, cs, l10n.deviceLocation, Icons.map),
            SizedBox(
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(device.latitude!, device.longitude!),
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.mydevice',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(device.latitude!, device.longitude!),
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.location_pin,
                            size: 40,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Notes ──
          if (device.notes != null) ...[
            _sectionTitle(theme, cs, l10n.deviceNotes, Icons.notes),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(device.notes!,
                    style: theme.textTheme.bodyMedium),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme cs, AppLocalizations l10n) {
    final logoPath = _detectBrandLogo();
    final purchaseStr = device.purchaseDate != null
        ? '${device.purchaseDate!.year}-'
            '${device.purchaseDate!.month.toString().padLeft(2, '0')}-'
            '${device.purchaseDate!.day.toString().padLeft(2, '0')}'
        : null;
    final releaseStr = device.releaseDate != null
        ? '${device.releaseDate!.year}-'
            '${device.releaseDate!.month.toString().padLeft(2, '0')}-'
            '${device.releaseDate!.day.toString().padLeft(2, '0')}'
        : null;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                _buildHeaderAvatar(cs),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      if (device.brand != null || device.model != null)
                        Text(
                          [device.brand, device.model]
                              .where((s) => s != null)
                              .join(' '),
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                if (logoPath != null)
                  SvgPicture.asset(
                    logoPath,
                    width: 36,
                    height: 36,
                    colorFilter: ColorFilter.mode(
                      cs.onSurface,
                      BlendMode.srcIn,
                    ),
                  ),
              ],
            ),
            if (purchaseStr != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    '${l10n.devicePurchaseDate}: $purchaseStr',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
            if (releaseStr != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.new_releases_outlined,
                      size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    '${l10n.deviceReleaseDate}: $releaseStr',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAvatar(ColorScheme cs) {
    if (device.emoji != null) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: cs.primaryContainer,
        child: Text(device.emoji!, style: const TextStyle(fontSize: 28)),
      );
    }
    if (device.imagePath != null) {
      return FutureBuilder<File>(
        future: ImageService.resolve(device.imagePath!),
        builder: (context, snap) {
          if (snap.hasData && snap.data!.existsSync()) {
            return CircleAvatar(
              radius: 28,
              backgroundColor: cs.primaryContainer,
              child: ClipOval(
                child: Image.file(
                  snap.data!,
                  fit: BoxFit.contain,
                  width: 56,
                  height: 56,
                ),
              ),
            );
          }
          return CircleAvatar(
            radius: 28,
            backgroundColor: cs.primaryContainer,
            child: Icon(deviceCategoryIcon(device.category), size: 28, color: cs.onPrimaryContainer),
          );
        },
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: cs.primaryContainer,
      child: Icon(deviceCategoryIcon(device.category), size: 28, color: cs.onPrimaryContainer),
    );
  }

  Widget _sectionTitle(
      ThemeData theme, ColorScheme cs, String title, IconData icon,
      {String? logoPath}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
          if (logoPath != null) ...[
            const Spacer(),
            SvgPicture.asset(
              logoPath,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(cs.onSurface, BlendMode.srcIn),
            ),
          ],
        ],
      ),
    );
  }

  Widget _specCard(ThemeData theme, List<Widget?> rows) {
    final validRows = rows.whereType<Widget>().toList();
    if (validRows.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(children: validRows),
      ),
    );
  }

  Widget? _specRow(String label, String? value) {
    if (value == null || value.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _specRowWithLogo(String label, String value, String? logoPath, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          if (logoPath != null) ...[
            SvgPicture.asset(
              logoPath,
              height: 16,
              colorFilter: ColorFilter.mode(
                cs.onSurface,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
