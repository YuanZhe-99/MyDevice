import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../features/devices/models/device.dart';
import '../../features/devices/widgets/device_category_icon.dart';
import '../../l10n/app_localizations.dart';

/// A map view showing device locations as markers.
class DeviceMapPage extends StatelessWidget {
  final String title;
  final List<Device> devices;

  const DeviceMapPage({super.key, required this.title, required this.devices});

  List<Device> get _locatedDevices =>
      devices.where((d) => d.latitude != null && d.longitude != null).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final located = _locatedDevices;

    // Compute center and bounds
    LatLng center = const LatLng(35.6762, 139.6503); // default Tokyo
    double zoom = 3;
    if (located.length == 1) {
      center = LatLng(located.first.latitude!, located.first.longitude!);
      zoom = 13;
    } else if (located.length > 1) {
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
      for (final d in located) {
        if (d.latitude! < minLat) minLat = d.latitude!;
        if (d.latitude! > maxLat) maxLat = d.latitude!;
        if (d.longitude! < minLng) minLng = d.longitude!;
        if (d.longitude! > maxLng) maxLng = d.longitude!;
      }
      center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      // Rough zoom based on extent
      final latSpan = maxLat - minLat;
      final lngSpan = maxLng - minLng;
      final span = latSpan > lngSpan ? latSpan : lngSpan;
      if (span < 0.01) {
        zoom = 15;
      } else if (span < 0.1) {
        zoom = 12;
      } else if (span < 1) {
        zoom = 9;
      } else if (span < 10) {
        zoom = 6;
      } else if (span < 50) {
        zoom = 4;
      } else {
        zoom = 2;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: located.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.mapNoLocations,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            )
          : FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: zoom),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mydevice',
                ),
                MarkerLayer(
                  markers: located.map((d) {
                    return Marker(
                      point: LatLng(d.latitude!, d.longitude!),
                      width: 120,
                      height: 48,
                      child: _DeviceMarker(device: d, colorScheme: cs),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}

class _DeviceMarker extends StatelessWidget {
  final Device device;
  final ColorScheme colorScheme;

  const _DeviceMarker({required this.device, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                deviceCategoryIcon(device.category),
                size: 14,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  device.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.location_pin, size: 20, color: colorScheme.primary),
      ],
    );
  }
}
