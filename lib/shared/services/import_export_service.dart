/// Purpose: MyDevice's ZIP and Markdown export/import API. The ZIP half is now
/// a facade over the shared `ZipTransfer` engine; the Markdown export is
/// domain-specific and stays here (PLAN.md M14 non-goal).
/// Inputs: Destination directories and ZIP file paths from the settings pages.
/// Returns: Written file paths, or import success flags.
/// Side effects: Reads and writes the app data directory.
/// Notes: PLAN.md P3.3.3. `exportZip`/`importZip` keep their names, signatures,
/// and archive naming (`mydevice_export_<stamp>.zip`) (I7).
library;

import 'dart:io';

import 'package:intl/intl.dart';
import 'package:myapps_data/myapps_data.dart' as shared;
import 'package:path/path.dart' as p;

import '../../app/data_modules.dart';
import '../../features/datasets/models/dataset.dart';
import '../../features/datasets/services/dataset_storage.dart';
import '../../features/devices/models/device.dart';
import '../../features/devices/services/device_storage.dart';
import '../../features/devices/services/exchange_rate_service.dart';
import '../../features/network/models/network.dart';
import '../../features/network/services/network_storage.dart';
import '../../features/services/models/service.dart';
import '../../features/services/services/service_analysis.dart';
import '../../features/services/services/service_storage.dart';

class ImportExportService {
  /// Shared ZIP engine configured to match MyDevice's existing leniency.
  ///
  /// Unknown entries are skipped rather than rejected so an archive from a
  /// newer build still imports, and payloads are written as raw bytes without
  /// UTF-8 or model validation — exactly what this service did before.
  /// Path traversal is the one thing that is not configurable: the engine
  /// always refuses such an archive outright.
  static final shared.ZipTransfer _zip = shared.ZipTransfer(
    storage: const DeviceStorageAdapter(),
    modules: deviceModuleRegistry,
    archiveNamePrefix: deviceArchiveNamePrefix,
    rejectUnknownEntries: false,
    strictUtf8: false,
    validateBeforeWrite: false,
    atomicWrites: false,
  );

  /// Purpose: Export zip to an external representation.
  /// Inputs: `destDir`.
  /// Returns: `Future<String?>` — the exported file path, or null on failure.
  /// Side effects: Writes `mydevice_export_<yyyyMMdd_HHmmss>.zip` in `destDir`.
  /// Notes: Bundles the registry's data files in registry order plus flat
  /// `images/<name>` entries. Config, `.sync_base/`, and `backups/` are never
  /// included.
  static Future<String?> exportZip(String destDir) => _zip.exportZip(destDir);

  /// Purpose: Import data from a previously exported ZIP file.
  /// Inputs: `filePath`.
  /// Returns: `Future<bool>` — true on success.
  /// Side effects: Overwrites allowlisted data files and images.
  /// Notes: Only allowlisted entries (the registry's data files and flat files
  /// under `images/`) are extracted, and every entry must resolve inside the
  /// app dir. An archive containing a traversal entry is now rejected outright
  /// (returns false, writes nothing) rather than having the bad entry skipped —
  /// see PLAN.md's accepted-unification list.
  static Future<bool> importZip(String filePath) => _zip.importZip(filePath);

  /// Purpose: Export markdown to an external representation.
  /// Inputs: `destDir`.
  /// Returns: `Future<String?>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  /// Export all data as a Markdown file for LLM personalization.
  /// Returns the exported file path, or null on failure.
  static Future<String?> exportMarkdown(String destDir) async {
    try {
      final deviceData = await DeviceStorage.load();
      final networkData = await NetworkStorage.load();
      final datasetData = await DataSetStorage.load();
      final serviceData = await ServiceStorage.load();

      final markdown = buildMarkdown(
        deviceData: deviceData,
        networkData: networkData,
        datasetData: datasetData,
        serviceData: serviceData,
      );

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final outFile = File(p.join(destDir, 'mydevice_export_$stamp.md'));
      await outFile.writeAsString(markdown);
      return outFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Build and return markdown for the current context.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static String buildMarkdown({
    required DeviceData deviceData,
    required NetworkData networkData,
    required DataSetData datasetData,
    required ServiceData serviceData,
    DateTime? exportedAt,
  }) {
    final devices = List<Device>.from(deviceData.devices)
      ..sort((a, b) {
        if (a.purchaseDate == null && b.purchaseDate == null) {
          return a.name.compareTo(b.name);
        }
        if (a.purchaseDate == null) return 1;
        if (b.purchaseDate == null) return -1;
        return a.purchaseDate!.compareTo(b.purchaseDate!);
      });

    final deviceMap = {for (final d in deviceData.devices) d.id: d};
    final networkMap = {for (final n in networkData.networks) n.id: n};
    final serviceMap = {for (final s in serviceData.services) s.id: s};
    final services = List<ServiceNode>.from(serviceData.services)
      ..sort((a, b) {
        final aDevice = deviceMap[a.deviceId]?.name ?? a.deviceId;
        final bDevice = deviceMap[b.deviceId]?.name ?? b.deviceId;
        final deviceCmp = aDevice.toLowerCase().compareTo(
          bDevice.toLowerCase(),
        );
        if (deviceCmp != 0) return deviceCmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final routes = List<ServiceRoute>.from(serviceData.routes)
      ..sort((a, b) {
        final aSource =
            serviceMap[a.sourceServiceId]?.name ?? a.sourceServiceId;
        final bSource =
            serviceMap[b.sourceServiceId]?.name ?? b.sourceServiceId;
        final sourceCmp = aSource.toLowerCase().compareTo(
          bSource.toLowerCase(),
        );
        if (sourceCmp != 0) return sourceCmp;
        return serviceRouteDisplayTarget(
          a,
        ).toLowerCase().compareTo(serviceRouteDisplayTarget(b).toLowerCase());
      });

    final buf = StringBuffer();
    buf.writeln('# MyDevice!!!!! — Device Inventory');
    buf.writeln();
    buf.writeln(
      'Exported: ${DateFormat('yyyy-MM-dd HH:mm').format(exportedAt ?? DateTime.now())}',
    );
    buf.writeln(
      'Total: ${devices.length} devices, ${networkData.networks.length} networks, ${datasetData.datasets.length} datasets, ${services.length} services, ${routes.length} service routes',
    );
    buf.writeln();
    buf.writeln('---');

    // ── Devices ──
    if (devices.isNotEmpty) {
      buf.writeln();
      buf.writeln('# Devices');

      for (final d in devices) {
        buf.writeln();
        final title = d.emoji != null ? '${d.emoji} ${d.name}' : d.name;
        buf.writeln('## $title');
        buf.writeln();

        buf.writeln('- **Category:** ${_categoryLabel(d.category)}');
        if (d.brand != null) buf.writeln('- **Brand:** ${d.brand}');
        if (d.model != null) buf.writeln('- **Model:** ${d.model}');
        if (d.serialNumber != null) {
          buf.writeln('- **Serial Number:** ${d.serialNumber}');
        }

        // CPU
        if (!d.cpu.isEmpty) {
          final parts = <String>[];
          if (d.cpu.model != null) parts.add(d.cpu.model!);
          if (d.cpu.architecture != null) parts.add(d.cpu.architecture!);
          if (d.cpu.frequency != null) parts.add(d.cpu.frequency!);
          final cores = <String>[];
          if (d.cpu.performanceCores != null) {
            cores.add('${d.cpu.performanceCores}P');
          }
          if (d.cpu.efficiencyCores != null) {
            cores.add('${d.cpu.efficiencyCores}E');
          }
          if (cores.isNotEmpty) parts.add('${cores.join('+')} cores');
          if (d.cpu.threads != null) parts.add('${d.cpu.threads}T');
          if (d.cpu.cache != null) parts.add(d.cpu.cache!);
          buf.writeln('- **CPU:** ${parts.join(', ')}');
        }

        // GPU
        if (!d.gpu.isEmpty) {
          final parts = <String>[];
          if (d.gpu.model != null) parts.add(d.gpu.model!);
          if (d.gpu.architecture != null) {
            parts.add('(${d.gpu.architecture})');
          }
          buf.writeln('- **GPU:** ${parts.join(' ')}');
        }

        // RAM
        if (d.ram != null) {
          final ramStr = d.ramType != null
              ? '${d.ram} GB ${d.ramType!.displayName}'
              : '${d.ram} GB';
          buf.writeln('- **RAM:** $ramStr');
        }

        // Storage
        for (final s in d.storage) {
          if (!s.isEmpty) buf.writeln('- **Storage:** ${s.displayString}');
        }

        // Screen
        if (d.screenSize != null || d.screenResolutionW != null) {
          final parts = <String>[];
          if (d.screenSize != null) parts.add(d.screenSize!);
          if (d.screenResolutionW != null && d.screenResolutionH != null) {
            parts.add('${d.screenResolutionW}×${d.screenResolutionH}');
            if (d.ppi != null) parts.add('${d.ppi!.round()} PPI');
          }
          buf.writeln('- **Screen:** ${parts.join(', ')}');
        }

        if (d.battery != null) buf.writeln('- **Battery:** ${d.battery}');
        if (d.os != null) buf.writeln('- **OS:** ${d.os}');
        if (d.locationName != null) {
          buf.writeln('- **Location:** ${d.locationName}');
        }
        if (d.purchaseDate != null) {
          buf.writeln(
            '- **Purchase Date:** ${DateFormat('yyyy-MM-dd').format(d.purchaseDate!)}',
          );
        }
        if (d.releaseDate != null) {
          buf.writeln(
            '- **Release Date:** ${DateFormat('yyyy-MM-dd').format(d.releaseDate!)}',
          );
        }
        if (d.lifecycleStatus != DeviceLifecycleStatus.inService) {
          buf.writeln('- **Status:** ${_statusLabel(d.lifecycleStatus)}');
        }
        if (d.retiredDate != null) {
          buf.writeln(
            '- **Retirement Date:** ${DateFormat('yyyy-MM-dd').format(d.retiredDate!)}',
          );
        }
        if (d.acquisitionType != null) {
          buf.writeln(
            '- **Acquisition:** ${_acquisitionTypeLabel(d.acquisitionType!)}',
          );
        }
        if (d.purchasePrice != null) {
          buf.writeln('- **Purchase Price:** ${_moneyText(d.purchasePrice!)}');
        }
        if (d.soldPrice != null) {
          buf.writeln('- **Sold Price:** ${_moneyText(d.soldPrice!)}');
        }
        for (final cost in d.recurringCosts) {
          buf.writeln(
            '- **Recurring ${_recurringCostKindLabel(cost.kind)}:** ${_moneyText(cost.price)} / ${_billingCycleLabel(cost.billingCycle)}${cost.name != null ? ' (${cost.name})' : ''}',
          );
        }
        if (d.notes != null && d.notes!.isNotEmpty) {
          buf.writeln('- **Notes:** ${d.notes}');
        }
      }
    }

    // ── Networks ──
    if (networkData.networks.isNotEmpty) {
      buf.writeln();
      buf.writeln('---');
      buf.writeln();
      buf.writeln('# Networks');

      for (final n in networkData.networks) {
        buf.writeln();
        buf.writeln('## ${n.name}');
        buf.writeln();

        buf.writeln('- **Type:** ${_networkTypeLabel(n.type)}');
        if (n.subnet != null) buf.writeln('- **Subnet:** ${n.subnet}');
        if (n.gateway != null) buf.writeln('- **Gateway:** ${n.gateway}');
        if (n.dnsServers.isNotEmpty) {
          buf.writeln('- **DNS:** ${n.dnsServers.join(', ')}');
        }
        if (n.notes != null && n.notes!.isNotEmpty) {
          buf.writeln('- **Notes:** ${n.notes}');
        }

        // Devices in this network
        final assignments = networkData.assignments
            .where((a) => a.networkId == n.id)
            .toList();
        if (assignments.isNotEmpty) {
          buf.writeln();
          buf.writeln('**Devices:**');
          buf.writeln();
          for (final a in assignments) {
            final device = deviceMap[a.deviceId];
            final name = device?.name ?? a.deviceId;
            final parts = <String>[];
            if (a.ipAddress != null) parts.add(a.ipAddress!);
            if (a.hostname != null) parts.add(a.hostname!);
            parts.add(a.addressMode == AddressMode.static_ ? 'Static' : 'DHCP');
            if (a.isExitNode) parts.add('Exit Node');
            buf.writeln('- $name — ${parts.join(', ')}');
          }
        }
      }
    }

    // ── Datasets ──
    if (datasetData.datasets.isNotEmpty) {
      buf.writeln();
      buf.writeln('---');
      buf.writeln();
      buf.writeln('# Data Sets');

      for (final ds in datasetData.datasets) {
        buf.writeln();
        buf.writeln('## ${ds.emoji} ${ds.name}');

        if (ds.storageLinks.isNotEmpty) {
          buf.writeln();
          buf.writeln('**Linked Storages:**');
          buf.writeln();
          for (final link in ds.storageLinks) {
            final device = deviceMap[link.deviceId];
            final dName = device?.name ?? link.deviceId;
            if (device != null && link.storageIndices.isNotEmpty) {
              final slots = link.storageIndices
                  .where((i) => i < device.storage.length)
                  .map((i) => device.storage[i].displayString)
                  .where((s) => s.isNotEmpty)
                  .toList();
              if (slots.isNotEmpty) {
                buf.writeln('- $dName: ${slots.join(', ')}');
              } else {
                buf.writeln('- $dName');
              }
            } else {
              buf.writeln('- $dName');
            }
          }
        }
      }
    }

    // ── Services ──
    if (services.isNotEmpty) {
      buf.writeln();
      buf.writeln('---');
      buf.writeln();
      buf.writeln('# Services');

      for (final service in services) {
        final device = deviceMap[service.deviceId];
        buf.writeln();
        buf.writeln('## ${service.name}');
        buf.writeln();

        buf.writeln('- **Device:** ${device?.name ?? service.deviceId}');
        buf.writeln('- **Kind:** ${service.kind.name}');
        buf.writeln('- **State:** ${service.state.name}');
        if (service.runtime != null) {
          buf.writeln('- **Runtime:** ${service.runtime!.name}');
        }
        if (service.tags.isNotEmpty) {
          buf.writeln('- **Tags:** ${service.tags.join(', ')}');
        }
        if (service.notes != null && service.notes!.trim().isNotEmpty) {
          buf.writeln('- **Notes:** ${service.notes}');
        }
        if (service.endpoints.isNotEmpty) {
          buf.writeln();
          buf.writeln('**Endpoints:**');
          buf.writeln();
          for (final endpoint in service.endpoints) {
            buf.writeln('- ${_serviceEndpointText(endpoint, networkMap)}');
          }
        }
        if (service.dockerCompose != null &&
            service.dockerCompose!.trim().isNotEmpty) {
          buf.writeln();
          buf.writeln('**Docker Compose:**');
          buf.writeln();
          buf.writeln('```yaml');
          buf.writeln(service.dockerCompose!.trimRight());
          buf.writeln('```');
        }
      }
    }

    // ── Service Routes ──
    if (routes.isNotEmpty) {
      buf.writeln();
      buf.writeln('---');
      buf.writeln();
      buf.writeln('# Service Routes');

      for (final route in routes) {
        final source = serviceMap[route.sourceServiceId];
        final sourceEndpoint = source == null
            ? null
            : _serviceEndpointById(source, route.sourceEndpointId);
        final targets = serviceRouteAccessTargets(route);
        buf.writeln();
        buf.writeln('## ${serviceRouteDisplayTarget(route)}');
        buf.writeln();

        buf.writeln('- **Source:** ${source?.name ?? route.sourceServiceId}');
        if (sourceEndpoint != null) {
          buf.writeln(
            '- **Source Endpoint:** ${_serviceEndpointText(sourceEndpoint, networkMap)}',
          );
        }
        buf.writeln('- **Access Level:** ${route.accessLevel.name}');
        if (targets.isNotEmpty) {
          buf.writeln(
            '- **Targets:** ${targets.map(compactAccessTargetLabel).join(', ')}',
          );
        }
        if (route.notes != null && route.notes!.trim().isNotEmpty) {
          buf.writeln('- **Notes:** ${route.notes}');
        }
        if (route.hops.isNotEmpty) {
          buf.writeln();
          buf.writeln('**Hops:**');
          buf.writeln();
          for (final hop in route.hops) {
            buf.writeln(
              '- ${_serviceRouteHopText(hop, serviceMap, deviceMap, networkMap)}',
            );
          }
        }
      }
    }

    return buf.toString();
  }

  /// Purpose: Return the display label for category label.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static String _categoryLabel(DeviceCategory c) => switch (c) {
    DeviceCategory.desktop => 'Desktop',
    DeviceCategory.laptop => 'Laptop',
    DeviceCategory.phone => 'Phone',
    DeviceCategory.tablet => 'Tablet',
    DeviceCategory.headphone => 'Headphone',
    DeviceCategory.watch => 'Watch',
    DeviceCategory.router => 'Router',
    DeviceCategory.gameConsole => 'Game Console',
    DeviceCategory.vps => 'VPS',
    DeviceCategory.devBoard => 'Dev Board',
    DeviceCategory.other => 'Other',
  };

  /// Purpose: Return the display label for status label.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static String _statusLabel(DeviceLifecycleStatus status) => switch (status) {
    DeviceLifecycleStatus.inService => 'In Service',
    DeviceLifecycleStatus.retired => 'Retired',
    DeviceLifecycleStatus.sold => 'Sold',
  };

  /// Purpose: Return the display label for acquisition type label.
  /// Inputs: `type`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static String _acquisitionTypeLabel(DeviceAcquisitionType type) =>
      switch (type) {
        DeviceAcquisitionType.purchased => 'One-time Purchase',
        DeviceAcquisitionType.leased => 'Lease',
        DeviceAcquisitionType.purchasedWithSubscription =>
          'Purchase + Subscription',
        DeviceAcquisitionType.other => 'Other',
      };

  /// Purpose: Return the display label for recurring cost kind label.
  /// Inputs: `kind`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static String _recurringCostKindLabel(RecurringCostKind kind) =>
      switch (kind) {
        RecurringCostKind.lease => 'Lease',
        RecurringCostKind.insurance => 'Insurance',
        RecurringCostKind.subscription => 'Subscription',
        RecurringCostKind.other => 'Other',
      };

  /// Purpose: Return the display label for billing cycle label.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static String _billingCycleLabel(BillingCycle cycle) => switch (cycle) {
    BillingCycle.monthly => 'month',
    BillingCycle.yearly => 'year',
  };

  /// Purpose: Provide the internal money text helper for this file.
  /// Inputs: `money`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static String _moneyText(MoneyValue money) {
    final symbol = DeviceExchangeRateService.currencySymbol(money.currency);
    final baseSymbol = DeviceExchangeRateService.currencySymbol(
      money.defaultCurrency,
    );
    final original = '$symbol${money.amount.toStringAsFixed(2)}';
    if (money.currency == money.defaultCurrency) return original;
    return '$original ($baseSymbol${money.convertedAmount.toStringAsFixed(2)} ${money.defaultCurrency})';
  }

  /// Purpose: Return the display label for network type label.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static String _networkTypeLabel(NetworkType t) => switch (t) {
    NetworkType.lan => 'LAN',
    NetworkType.tailscale => 'Tailscale',
    NetworkType.zerotier => 'ZeroTier',
    NetworkType.easytier => 'EasyTier',
    NetworkType.wireguard => 'WireGuard',
    NetworkType.other => 'Other',
  };

  /// Purpose: Provide the internal service endpoint text helper for this file.
  /// Inputs: `endpoint`, `networkMap`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static String _serviceEndpointText(
    ServiceEndpoint endpoint,
    Map<String, Network> networkMap,
  ) {
    final parts = <String>[
      if (endpoint.label != null && endpoint.label!.trim().isNotEmpty)
        endpoint.label!.trim(),
      '${endpoint.protocol.name}/${endpoint.transport.name}',
      if (endpoint.port != null) endpoint.portText,
      if (endpoint.bindAddress != null &&
          endpoint.bindAddress!.trim().isNotEmpty)
        'bind ${endpoint.bindAddress!.trim()}',
      if (endpoint.path != null && endpoint.path!.trim().isNotEmpty)
        endpoint.path!.trim(),
      endpoint.scope.name,
      if (endpoint.networkId != null)
        'network ${networkMap[endpoint.networkId]?.name ?? endpoint.networkId}',
      if (endpoint.isPrimary) 'primary',
      if (endpoint.notes != null && endpoint.notes!.trim().isNotEmpty)
        endpoint.notes!.trim(),
    ];
    return parts.join(', ');
  }

  /// Purpose: Look up service endpoint by id from the current in-memory state.
  /// Inputs: `service`, `endpointId`.
  /// Returns: `ServiceEndpoint?`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static ServiceEndpoint? _serviceEndpointById(
    ServiceNode service,
    String? endpointId,
  ) {
    if (endpointId == null) return null;
    return service.endpoints
        .where((endpoint) => endpoint.id == endpointId)
        .firstOrNull;
  }

  /// Purpose: Provide the internal service route hop text helper for this file.
  /// Inputs: `hop`, `serviceMap`, `deviceMap`, `networkMap`.
  /// Returns: `String`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static String _serviceRouteHopText(
    ServiceRouteHop hop,
    Map<String, ServiceNode> serviceMap,
    Map<String, Device> deviceMap,
    Map<String, Network> networkMap,
  ) {
    final service = hop.serviceId == null ? null : serviceMap[hop.serviceId];
    final endpoint = service == null
        ? null
        : _serviceEndpointById(service, hop.endpointId);
    final device = hop.deviceId == null ? null : deviceMap[hop.deviceId];
    final hostParts = <String>[
      if (hop.scheme != null && hop.scheme!.trim().isNotEmpty)
        '${hop.scheme!.trim()}://',
      if (hop.host != null && hop.host!.trim().isNotEmpty) hop.host!.trim(),
      if (hop.port != null) ':${hop.port}',
      if (hop.path != null && hop.path!.trim().isNotEmpty) hop.path!.trim(),
    ];
    final parts = <String>[
      hop.method == null ? hop.type.name : serviceRouteMethodLabel(hop.method!),
      if (hop.label != null && hop.label!.trim().isNotEmpty) hop.label!.trim(),
      if (service != null) 'service ${service.name}',
      if (endpoint != null)
        'endpoint ${_serviceEndpointText(endpoint, networkMap)}',
      if (device != null) 'device ${device.name}',
      if (hostParts.isNotEmpty) hostParts.join(),
      if (hop.notes != null && hop.notes!.trim().isNotEmpty) hop.notes!.trim(),
    ];
    return parts.join(', ');
  }
}
