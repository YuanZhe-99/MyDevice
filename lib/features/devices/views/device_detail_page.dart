import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/detail_layout.dart';
import '../models/device.dart';
import '../services/exchange_rate_service.dart';
import '../widgets/device_avatar.dart';
import 'device_edit_page.dart';

class DeviceDetailPage extends StatelessWidget {
  final Device device;
  final VoidCallback? onDeviceChanged;

  /// Purpose: Create a device detail page instance.
  /// Inputs: None.
  /// Returns: A new `DeviceDetailPage` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
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

  /// Purpose: Provide the internal detect brand logo helper for this file.
  /// Inputs: None.
  /// Returns: `String?`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String? _detectBrandLogo() {
    if (device.brand == null) return null;
    final lower = device.brand!.toLowerCase();
    for (final entry in _brandLogoMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Purpose: Provide the internal detect model logo helper for this file.
  /// Inputs: `model`.
  /// Returns: `String?`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal detect storage brand logo helper for this file.
  /// Inputs: `brand`.
  /// Returns: `String?`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  /// Detect storage brand logo.
  static String? _detectStorageBrandLogo(String? brand) {
    if (brand == null) return null;
    final lower = brand.toLowerCase();
    for (final entry in _storageBrandLogoMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Purpose: Provide the internal detect os logo helper for this file.
  /// Inputs: `os`.
  /// Returns: `String?`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Return the display label for status label.
  /// Inputs: `l10n`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _statusLabel(AppLocalizations l10n) =>
      switch (device.lifecycleStatus) {
        DeviceLifecycleStatus.inService => l10n.statusInService,
        DeviceLifecycleStatus.retired => l10n.statusRetired,
        DeviceLifecycleStatus.sold => l10n.statusSold,
      };

  /// Purpose: Return the display label for acquisition type label.
  /// Inputs: `l10n`, `type`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _acquisitionTypeLabel(
    AppLocalizations l10n,
    DeviceAcquisitionType type,
  ) {
    return switch (type) {
      DeviceAcquisitionType.purchased => l10n.acquisitionPurchased,
      DeviceAcquisitionType.leased => l10n.acquisitionLeased,
      DeviceAcquisitionType.purchasedWithSubscription =>
        l10n.acquisitionPurchasedWithSubscription,
      DeviceAcquisitionType.other => l10n.acquisitionOther,
    };
  }

  /// Purpose: Return the display label for recurring cost kind label.
  /// Inputs: `l10n`, `kind`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _recurringCostKindLabel(
    AppLocalizations l10n,
    RecurringCostKind kind,
  ) {
    return switch (kind) {
      RecurringCostKind.lease => l10n.recurringCostLease,
      RecurringCostKind.insurance => l10n.recurringCostInsurance,
      RecurringCostKind.subscription => l10n.recurringCostSubscription,
      RecurringCostKind.other => l10n.recurringCostOther,
    };
  }

  /// Purpose: Return the display label for billing cycle label.
  /// Inputs: `l10n`, `cycle`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _billingCycleLabel(AppLocalizations l10n, BillingCycle cycle) {
    return switch (cycle) {
      BillingCycle.monthly => l10n.billingMonthly,
      BillingCycle.yearly => l10n.billingYearly,
    };
  }

  /// Purpose: Provide the internal money text helper for this file.
  /// Inputs: `money`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _moneyText(MoneyValue money) {
    final symbol = DeviceExchangeRateService.currencySymbol(money.currency);
    final baseSymbol = DeviceExchangeRateService.currencySymbol(
      money.defaultCurrency,
    );
    final original = '$symbol${money.amount.toStringAsFixed(2)}';
    if (money.currency == money.defaultCurrency) return original;
    return '$original ($baseSymbol${money.convertedAmount.toStringAsFixed(2)} ${money.defaultCurrency})';
  }

  /// Purpose: Provide the internal default money text helper for this file.
  /// Inputs: `amount`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _defaultMoneyText(double amount) {
    final currency =
        device.purchasePrice?.defaultCurrency ??
        device.soldPrice?.defaultCurrency ??
        device.recurringCosts.firstOrNull?.price.defaultCurrency ??
        '';
    return '${DeviceExchangeRateService.currencySymbol(currency)}${amount.toStringAsFixed(2)}';
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state. Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Keep this method cheap because Flutter may call it often.
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
      body: _buildBody(context, theme, cs, l10n),
    );
  }

  /// Purpose: Build the page body in whichever layout the window calls for.
  /// Inputs: `context`, `theme`, `cs`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None beyond building widgets.
  /// Notes: Internal helper used within this file only. The gate reads the
  /// whole screen through `useDetailTwoPane`; the pane width reads the body's
  /// own constraints, which are the raw window because this page is pushed
  /// above the shell. A device with no spec section at all keeps the single
  /// column even on a wide window — the right pane would otherwise be blank.
  /// The single-column order (header, specs, map, notes) is unchanged; the
  /// two-pane layout keeps the header, map and notes on the left and scrolls
  /// the spec cards on the right.
  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    final screen = MediaQuery.sizeOf(context);
    final header = _buildHeader(theme, cs, l10n);
    final specs = _buildSpecSections(theme, cs, l10n);
    final trailing = _buildTrailingSections(theme, cs, l10n);

    if (!useDetailTwoPane(screen.width, screen.height) || specs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [header, const SizedBox(height: 24), ...specs, ...trailing],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final paneWidth = detailLeftPaneWidth(constraints.maxWidth);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: paneWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, const SizedBox(height: 24), ...trailing],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: specs,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Purpose: Build the conditional spec sections (finance, CPU, GPU, memory,
  /// display, other), each a title and a card followed by a 16 dp gap.
  /// Inputs: `theme`, `cs`, `l10n`.
  /// Returns: `List<Widget>` — empty when the device carries no spec at all.
  /// Side effects: None beyond building widgets.
  /// Notes: Internal helper used within this file only. Extracted from
  /// `build` unchanged so the same sections can be the middle of the single
  /// column or the whole right pane, rather than being written twice.
  List<Widget> _buildSpecSections(
    ThemeData theme,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    return [
      if (device.hasFinancialData ||
          device.acquisitionType != null ||
          device.lifecycleStatus != DeviceLifecycleStatus.inService) ...[
        _sectionTitle(
          theme,
          cs,
          l10n.lifecycleAndFinance,
          Icons.payments_outlined,
        ),
        _specCard(theme, [
          _specRow(l10n.deviceStatus, _statusLabel(l10n)),
          if (device.acquisitionType != null)
            _specRow(
              l10n.acquisitionType,
              _acquisitionTypeLabel(l10n, device.acquisitionType!),
            ),
          _specRow(
            l10n.deviceRetiredDate,
            device.retiredDate != null
                ? DateFormat.yMd(l10n.localeName).format(device.retiredDate!)
                : null,
          ),
          _specRow(
            l10n.purchasePrice,
            device.purchasePrice != null
                ? _moneyText(device.purchasePrice!)
                : null,
          ),
          _specRow(
            l10n.soldPrice,
            device.soldPrice != null ? _moneyText(device.soldPrice!) : null,
          ),
          for (final cost in device.recurringCosts)
            _specRow(
              cost.name ?? _recurringCostKindLabel(l10n, cost.kind),
              '${_moneyText(cost.price)} / ${_billingCycleLabel(l10n, cost.billingCycle)}',
            ),
          if (device.hasFinancialData)
            _specRow(
              l10n.financialTotalCost,
              _defaultMoneyText(device.totalCost()),
            ),
          if (device.averageDailyCost() != null)
            _specRow(
              l10n.financialDailyCost,
              _defaultMoneyText(device.averageDailyCost()!),
            ),
        ]),
        const SizedBox(height: 16),
      ],

      // ── CPU ──
      if (device.cpu.model != null) ...[
        _sectionTitle(
          theme,
          cs,
          l10n.cpuInfo,
          Icons.memory,
          logoPath: _detectModelLogo(device.cpu.model),
        ),
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
        _sectionTitle(
          theme,
          cs,
          l10n.gpuInfo,
          Icons.graphic_eq,
          logoPath: _detectModelLogo(device.gpu.model),
        ),
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
          _specRow(
            l10n.ram,
            device.ram != null
                ? device.ramType != null
                      ? '${device.ram} ${device.ramType!.displayName}'
                      : device.ram
                : null,
          ),
          for (int i = 0; i < device.storage.length; i++) ...[
            _specRow(
              '${l10n.storage} ${i + 1}',
              device.storage[i].displayString,
            ),
            if (device.storage[i].brand != null)
              _specRowWithLogo(
                l10n.storageBrand,
                device.storage[i].brand!,
                _detectStorageBrandLogo(device.storage[i].brand),
                cs,
              ),
            if (device.storage[i].serialNumber != null)
              _specRow(
                l10n.storageSerialNumber,
                device.storage[i].serialNumber,
              ),
          ],
        ]),
        const SizedBox(height: 16),
      ],

      // ── Display ──
      if (device.screenSize != null || device.screenResolutionW != null) ...[
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
      if (device.battery != null ||
          device.os != null ||
          device.locationName != null ||
          device.serialNumber != null) ...[
        _sectionTitle(
          theme,
          cs,
          l10n.os,
          Icons.info_outline,
          logoPath: _detectOsLogo(device.os),
        ),
        _specCard(theme, [
          _specRow(l10n.deviceSerialNumber, device.serialNumber),
          _specRow(l10n.battery, device.battery),
          _specRow(l10n.os, device.os),
          _specRow(l10n.deviceLocation, device.locationName),
        ]),
        const SizedBox(height: 16),
      ],
    ];
  }

  /// Purpose: Build the sections that follow the specs: the location map and
  /// the notes card, each conditional.
  /// Inputs: `theme`, `cs`, `l10n`.
  /// Returns: `List<Widget>`, possibly empty.
  /// Side effects: None beyond building widgets.
  /// Notes: Internal helper used within this file only. These sit at the end
  /// of the single column and under the header in the two-pane left pane.
  List<Widget> _buildTrailingSections(
    ThemeData theme,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    return [
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
            child: Text(device.notes!, style: theme.textTheme.bodyMedium),
          ),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  /// Purpose: Build and return header for the current context.
  /// Inputs: `theme`, `cs`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildHeader(ThemeData theme, ColorScheme cs, AppLocalizations l10n) {
    final logoPath = _detectBrandLogo();
    final dateFmt = DateFormat.yMd(l10n.localeName);
    final purchaseStr = device.purchaseDate != null
        ? dateFmt.format(device.purchaseDate!)
        : null;
    final releaseStr = device.releaseDate != null
        ? dateFmt.format(device.releaseDate!)
        : null;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                DeviceAvatar.fromDevice(device, size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (device.brand != null || device.model != null)
                        Text(
                          [
                            device.brand,
                            device.model,
                          ].where((s) => s != null).join(' '),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
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
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${l10n.devicePurchaseDate}: $purchaseStr',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (releaseStr != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.new_releases_outlined,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${l10n.deviceReleaseDate}: $releaseStr',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Purpose: Provide the internal section title helper for this file.
  /// Inputs: `theme`, `cs`, `title`, `icon`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _sectionTitle(
    ThemeData theme,
    ColorScheme cs,
    String title,
    IconData icon, {
    String? logoPath,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
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

  /// Purpose: Provide the internal spec card helper for this file.
  /// Inputs: `theme`, `rows`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal spec row helper for this file.
  /// Inputs: `label`, `value`.
  /// Returns: `Widget?`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget? _specRow(String label, String? value) {
    if (value == null || value.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Purpose: Provide the internal spec row with logo helper for this file.
  /// Inputs: `label`, `value`, `logoPath`, `cs`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _specRowWithLogo(
    String label,
    String value,
    String? logoPath,
    ColorScheme cs,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          if (logoPath != null) ...[
            SvgPicture.asset(
              logoPath,
              height: 16,
              colorFilter: ColorFilter.mode(cs.onSurface, BlendMode.srcIn),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
