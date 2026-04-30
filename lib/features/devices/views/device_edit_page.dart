import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../l10n/app_localizations.dart';
import '../../../app/flavor.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/widgets/map_picker_page.dart';
import '../models/device.dart';
import '../services/device_storage.dart';
import '../services/preset_service.dart';
import '../widgets/device_category_icon.dart';
import 'chip_search_dialog.dart';
import 'device_search_dialog.dart';

class DeviceEditPage extends StatefulWidget {
  final Device? device;
  final Map<String, dynamic>? searchResult;

  const DeviceEditPage({super.key, this.device, this.searchResult});

  @override
  State<DeviceEditPage> createState() => _DeviceEditPageState();
}

class _DeviceEditPageState extends State<DeviceEditPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _serialNumberCtrl;
  late final TextEditingController _ramCtrl;
  late final TextEditingController _screenSizeCtrl;
  late final TextEditingController _batteryCtrl;
  late final TextEditingController _osCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _notesCtrl;

  // CPU
  late final TextEditingController _cpuModelCtrl;
  late final TextEditingController _cpuArchCtrl;
  late final TextEditingController _cpuFreqCtrl;
  late final TextEditingController _cpuPCoresCtrl;
  late final TextEditingController _cpuECoresCtrl;
  late final TextEditingController _cpuThreadsCtrl;
  late final TextEditingController _cpuCacheCtrl;

  // GPU
  late final TextEditingController _gpuModelCtrl;
  late final TextEditingController _gpuArchCtrl;

  // Screen resolution
  late final TextEditingController _screenResWCtrl;
  late final TextEditingController _screenResHCtrl;

  String? _emoji;
  String? _imagePath;

  late DeviceCategory _category;
  DateTime? _purchaseDate;
  DateTime? _releaseDate;
  late List<String> _storageEntries;
  late List<String> _storageUnits;
  late List<StorageType?> _storageTypes;
  late List<StorageInterface?> _storageInterfaces;
  late List<TextEditingController> _storageBrandCtrls;
  late List<TextEditingController> _storageSerialCtrls;
  late String _ramUnit;
  RamType? _ramType;
  double? _latitude;
  double? _longitude;

  List<CpuInfo> _cpuPresets = [];
  List<GpuInfo> _gpuPresets = [];
  List<BrandEntry> _brandPresets = [];

  // Keys to force Autocomplete rebuild when presets are applied
  int _cpuAutoKey = 0;
  int _gpuAutoKey = 0;

  bool get _isEditing => widget.device != null;

  @override
  void initState() {
    super.initState();
    final d = widget.device;
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _brandCtrl = TextEditingController(text: d?.brand ?? '');
    _modelCtrl = TextEditingController(text: d?.model ?? '');
    _serialNumberCtrl = TextEditingController(text: d?.serialNumber ?? '');
    _emoji = d?.emoji;
    _imagePath = d?.imagePath;
    final ramParsed = _parseValueUnit(d?.ram);
    _ramCtrl = TextEditingController(text: ramParsed.$1);
    _ramUnit = ramParsed.$2;
    _ramType = d?.ramType;
    _screenSizeCtrl = TextEditingController(text: d?.screenSize ?? '');
    _batteryCtrl = TextEditingController(text: d?.battery ?? '');
    _osCtrl = TextEditingController(text: d?.os ?? '');
    _locationCtrl = TextEditingController(text: d?.locationName ?? '');
    _latitude = d?.latitude;
    _longitude = d?.longitude;
    _notesCtrl = TextEditingController(text: d?.notes ?? '');

    _cpuModelCtrl = TextEditingController(text: d?.cpu.model ?? '');
    _cpuArchCtrl = TextEditingController(text: d?.cpu.architecture ?? '');
    _cpuFreqCtrl = TextEditingController(text: d?.cpu.frequency ?? '');
    _cpuPCoresCtrl = TextEditingController(
      text: d?.cpu.performanceCores?.toString() ?? '',
    );
    _cpuECoresCtrl = TextEditingController(
      text: d?.cpu.efficiencyCores?.toString() ?? '',
    );
    _cpuThreadsCtrl = TextEditingController(
      text: d?.cpu.threads?.toString() ?? '',
    );
    _cpuCacheCtrl = TextEditingController(text: d?.cpu.cache ?? '');

    _gpuModelCtrl = TextEditingController(text: d?.gpu.model ?? '');
    _gpuArchCtrl = TextEditingController(text: d?.gpu.architecture ?? '');

    _screenResWCtrl = TextEditingController(
      text: d?.screenResolutionW?.toString() ?? '',
    );
    _screenResHCtrl = TextEditingController(
      text: d?.screenResolutionH?.toString() ?? '',
    );

    _category = d?.category ?? DeviceCategory.phone;
    _purchaseDate = d?.purchaseDate;
    _releaseDate = d?.releaseDate;
    if (d != null && d.storage.isNotEmpty) {
      _storageEntries = <String>[];
      _storageUnits = <String>[];
      _storageTypes = <StorageType?>[];
      _storageInterfaces = <StorageInterface?>[];
      _storageBrandCtrls = <TextEditingController>[];
      _storageSerialCtrls = <TextEditingController>[];
      for (final s in d.storage) {
        final parsed = _parseValueUnit(s.capacity);
        _storageEntries.add(parsed.$1);
        _storageUnits.add(parsed.$2);
        _storageTypes.add(s.type);
        _storageInterfaces.add(s.interface_);
        _storageBrandCtrls.add(TextEditingController(text: s.brand ?? ''));
        _storageSerialCtrls.add(
          TextEditingController(text: s.serialNumber ?? ''),
        );
      }
    } else {
      _storageEntries = [''];
      _storageUnits = ['GB'];
      _storageTypes = [null];
      _storageInterfaces = [null];
      _storageBrandCtrls = [TextEditingController()];
      _storageSerialCtrls = [TextEditingController()];
    }

    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final cpus = await PresetService.loadCpus();
    final gpus = await PresetService.loadGpus();
    final brands = await PresetService.loadBrands();
    if (mounted) {
      setState(() {
        _cpuPresets = cpus;
        _gpuPresets = gpus;
        _brandPresets = brands;
      });
      if (widget.searchResult != null) {
        _applySearchResult(widget.searchResult!);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _serialNumberCtrl.dispose();
    _ramCtrl.dispose();
    for (final c in _storageBrandCtrls) {
      c.dispose();
    }
    for (final c in _storageSerialCtrls) {
      c.dispose();
    }
    _screenSizeCtrl.dispose();
    _batteryCtrl.dispose();
    _osCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _cpuModelCtrl.dispose();
    _cpuArchCtrl.dispose();
    _cpuFreqCtrl.dispose();
    _cpuPCoresCtrl.dispose();
    _cpuECoresCtrl.dispose();
    _cpuThreadsCtrl.dispose();
    _cpuCacheCtrl.dispose();
    _gpuModelCtrl.dispose();
    _gpuArchCtrl.dispose();
    _screenResWCtrl.dispose();
    _screenResHCtrl.dispose();
    super.dispose();
  }

  static const _memoryUnits = ['MB', 'GB', 'TB'];

  /// Parse "16 GB" or "512 GB NVMe SSD" into ("16", "GB") or ("512", "GB").
  /// Falls back to (original, "GB") when no known unit is found.
  static (String, String) _parseValueUnit(String? value) {
    if (value == null || value.trim().isEmpty) return ('', 'GB');
    final trimmed = value.trim();
    final match = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(MB|GB|TB)\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (match != null) {
      return (match.group(1)!, match.group(2)!.toUpperCase());
    }
    return (trimmed, 'GB');
  }

  String? _combineValueUnit(String value, String unit) {
    final v = value.trim();
    if (v.isEmpty) return null;
    return '$v $unit';
  }

  String? _nonEmpty(String value) => value.trim().isEmpty ? null : value.trim();

  int? _parseInt(String value) => int.tryParse(value.trim());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final storageList = <StorageInfo>[];
    for (int i = 0; i < _storageEntries.length; i++) {
      final v = _storageEntries[i].trim();
      final brand = _nonEmpty(_storageBrandCtrls[i].text);
      final serial = _nonEmpty(_storageSerialCtrls[i].text);
      if (v.isNotEmpty ||
          _storageTypes[i] != null ||
          _storageInterfaces[i] != null ||
          brand != null ||
          serial != null) {
        storageList.add(
          StorageInfo(
            capacity: v.isNotEmpty ? '$v ${_storageUnits[i]}' : null,
            type: _storageTypes[i],
            interface_: _storageInterfaces[i],
            brand: brand,
            serialNumber: serial,
            extraJson:
                widget.device != null && i < widget.device!.storage.length
                ? widget.device!.storage[i].extraJson
                : const {},
          ),
        );
      }
    }

    final device = Device(
      id: widget.device?.id,
      name: _nameCtrl.text.trim(),
      category: _category,
      emoji: _emoji,
      imagePath: _imagePath,
      brand: _nonEmpty(_brandCtrl.text),
      model: _nonEmpty(_modelCtrl.text),
      serialNumber: _nonEmpty(_serialNumberCtrl.text),
      cpu: CpuInfo(
        model: _nonEmpty(_cpuModelCtrl.text),
        architecture: _nonEmpty(_cpuArchCtrl.text),
        frequency: _nonEmpty(_cpuFreqCtrl.text),
        performanceCores: _parseInt(_cpuPCoresCtrl.text),
        efficiencyCores: _parseInt(_cpuECoresCtrl.text),
        threads: _parseInt(_cpuThreadsCtrl.text),
        cache: _nonEmpty(_cpuCacheCtrl.text),
        extraJson: widget.device?.cpu.extraJson ?? const {},
      ),
      gpu: GpuInfo(
        model: _nonEmpty(_gpuModelCtrl.text),
        architecture: _nonEmpty(_gpuArchCtrl.text),
        extraJson: widget.device?.gpu.extraJson ?? const {},
      ),
      ram: _combineValueUnit(_ramCtrl.text, _ramUnit),
      ramType: _ramType,
      storage: storageList,
      screenSize: _nonEmpty(_screenSizeCtrl.text),
      screenResolutionW: _parseInt(_screenResWCtrl.text),
      screenResolutionH: _parseInt(_screenResHCtrl.text),
      battery: _nonEmpty(_batteryCtrl.text),
      os: _nonEmpty(_osCtrl.text),
      locationName: _nonEmpty(_locationCtrl.text),
      latitude: _latitude,
      longitude: _longitude,
      purchaseDate: _purchaseDate,
      releaseDate: _releaseDate,
      notes: _nonEmpty(_notesCtrl.text),
      extraJson: widget.device?.extraJson ?? const {},
    );

    await DeviceStorage.addOrUpdate(device);
    AutoSyncService.instance.notifySaved();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _pickReleaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _releaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _releaseDate = picked);
    }
  }

  String _storageTypeLabel(AppLocalizations l10n, StorageType t) {
    return switch (t) {
      StorageType.ssd => l10n.storageTypeSsd,
      StorageType.sdCard => l10n.storageTypeSdCard,
      StorageType.hdd => l10n.storageTypeHdd,
    };
  }

  String _storageInterfaceLabel(AppLocalizations l10n, StorageInterface t) {
    return switch (t) {
      StorageInterface.m2Nvme => l10n.storageInterfaceM2Nvme,
      StorageInterface.sata25 => l10n.storageInterfaceSata25,
      StorageInterface.m2Sata => l10n.storageInterfaceM2Sata,
      StorageInterface.usb => l10n.storageInterfaceUsb,
    };
  }

  String _categoryLabel(AppLocalizations l10n, DeviceCategory cat) {
    return switch (cat) {
      DeviceCategory.desktop => l10n.deviceCategoryDesktop,
      DeviceCategory.laptop => l10n.deviceCategoryLaptop,
      DeviceCategory.phone => l10n.deviceCategoryPhone,
      DeviceCategory.tablet => l10n.deviceCategoryTablet,
      DeviceCategory.headphone => l10n.deviceCategoryHeadphone,
      DeviceCategory.watch => l10n.deviceCategoryWatch,
      DeviceCategory.router => l10n.deviceCategoryRouter,
      DeviceCategory.gameConsole => l10n.deviceCategoryGameConsole,
      DeviceCategory.vps => l10n.deviceCategoryVps,
      DeviceCategory.devBoard => l10n.deviceCategoryDevBoard,
      DeviceCategory.other => l10n.deviceCategoryOther,
    };
  }

  void _applyCpuPreset(CpuInfo cpu) {
    setState(() {
      _cpuModelCtrl.text = cpu.model ?? '';
      _cpuArchCtrl.text = cpu.architecture ?? '';
      _cpuFreqCtrl.text = cpu.frequency ?? '';
      _cpuPCoresCtrl.text = cpu.performanceCores?.toString() ?? '';
      _cpuECoresCtrl.text = cpu.efficiencyCores?.toString() ?? '';
      _cpuThreadsCtrl.text = cpu.threads?.toString() ?? '';
      _cpuCacheCtrl.text = cpu.cache ?? '';
      _cpuAutoKey++;
    });
  }

  void _applyGpuPreset(GpuInfo gpu) {
    setState(() {
      _gpuModelCtrl.text = gpu.model ?? '';
      _gpuArchCtrl.text = gpu.architecture ?? '';
      _gpuAutoKey++;
    });
  }

  Future<void> _searchCpuOnline() async {
    final cpu = await showCpuSearchDialog(
      context,
      initialQuery: _cpuModelCtrl.text,
      presets: _cpuPresets,
    );
    if (cpu != null) _applyCpuPreset(cpu);
  }

  Future<void> _searchGpuOnline() async {
    final gpu = await showGpuSearchDialog(
      context,
      initialQuery: _gpuModelCtrl.text,
      presets: _gpuPresets,
    );
    if (gpu != null) _applyGpuPreset(gpu);
  }

  Future<void> _pickCpuPreset() async {
    final cpu = await showModalBottomSheet<CpuInfo>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CpuPresetPicker(presets: _cpuPresets),
    );
    if (cpu != null) _applyCpuPreset(cpu);
  }

  Future<void> _pickGpuPreset() async {
    final gpu = await showModalBottomSheet<GpuInfo>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _GpuPresetPicker(presets: _gpuPresets),
    );
    if (gpu != null) _applyGpuPreset(gpu);
  }

  Future<void> _showSearchDialog() async {
    // Build initial query from existing name/model
    final query = _modelCtrl.text.trim().isNotEmpty
        ? '${_brandCtrl.text.trim()} ${_modelCtrl.text.trim()}'.trim()
        : _nameCtrl.text.trim();

    final result = await showDeviceSearchDialog(
      context,
      initialQuery: query,
      currentBrand: _nonEmpty(_brandCtrl.text),
      currentModel: _nonEmpty(_modelCtrl.text),
      currentChipset: _nonEmpty(_cpuModelCtrl.text),
      currentGpu: _nonEmpty(_gpuModelCtrl.text),
      currentRam: _combineValueUnit(_ramCtrl.text, _ramUnit),
      currentStorage:
          _storageEntries.isNotEmpty && _storageEntries.first.trim().isNotEmpty
          ? '${_storageEntries.first.trim()} ${_storageUnits.first}'
          : null,
      currentScreenSize: _nonEmpty(_screenSizeCtrl.text),
      currentScreenResW: _parseInt(_screenResWCtrl.text),
      currentScreenResH: _parseInt(_screenResHCtrl.text),
      currentBattery: _nonEmpty(_batteryCtrl.text),
      currentOs: _nonEmpty(_osCtrl.text),
      currentReleaseDate: _releaseDate,
      currentImagePath: _imagePath,
    );
    if (result == null || !mounted) return;
    _applySearchResult(result);
  }

  void _applySearchResult(Map<String, dynamic> result) {
    setState(() {
      if (result['brand'] is String) _brandCtrl.text = result['brand'];
      if (result['model'] is String) _modelCtrl.text = result['model'];

      // CPU: try matching against presets
      if (result['chipset'] is String) {
        final chipset = result['chipset'] as String;
        final chipsetLower = chipset.toLowerCase();
        final cpuMatch = _cpuPresets.where((c) {
          if (c.model == null) return false;
          final presetLower = c.model!.toLowerCase();
          return chipsetLower.contains(presetLower) ||
              presetLower.contains(chipsetLower);
        }).firstOrNull;
        if (cpuMatch != null) {
          _applyCpuPreset(cpuMatch);
        } else {
          _cpuModelCtrl.text = chipset;
          _cpuAutoKey++;
        }
      }

      // GPU: try matching against presets
      if (result['gpuName'] is String) {
        final gpuName = result['gpuName'] as String;
        final gpuLower = gpuName.toLowerCase();
        final gpuMatch = _gpuPresets.where((g) {
          if (g.model == null) return false;
          final presetLower = g.model!.toLowerCase();
          return gpuLower.contains(presetLower) ||
              presetLower.contains(gpuLower);
        }).firstOrNull;
        if (gpuMatch != null) {
          _applyGpuPreset(gpuMatch);
        } else {
          _gpuModelCtrl.text = gpuName;
          _gpuAutoKey++;
        }
      }

      // RAM: parse value and unit
      if (result['ram'] is String) {
        final parsed = _parseValueUnit(result['ram'] as String);
        _ramCtrl.text = parsed.$1;
        _ramUnit = parsed.$2;
      }

      // Storage: set first entry
      if (result['storage'] is String) {
        final parsed = _parseValueUnit(result['storage'] as String);
        if (_storageEntries.isNotEmpty) {
          _storageEntries[0] = parsed.$1;
          _storageUnits[0] = parsed.$2;
        }
      }

      if (result['screenSize'] is String) {
        _screenSizeCtrl.text = result['screenSize'];
      }
      if (result['screenResolutionW'] is int) {
        _screenResWCtrl.text = result['screenResolutionW'].toString();
      }
      if (result['screenResolutionH'] is int) {
        _screenResHCtrl.text = result['screenResolutionH'].toString();
      }
      if (result['battery'] is String) {
        _batteryCtrl.text = result['battery'];
      }
      if (result['os'] is String) {
        _osCtrl.text = result['os'];
      }
      if (result['releaseDate'] is DateTime) {
        _releaseDate = result['releaseDate'];
      }
      if (result['image'] is String) {
        _imagePath = result['image'];
        _emoji = null;
      }
    });
  }

  /// Detect brand logo from a model name (e.g. "NVIDIA GeForce RTX 4090" → nvidia.svg)
  static const _brandLogoMap = {
    'nvidia': 'assets/logos/nvidia.svg',
    'amd': 'assets/logos/amd.svg',
    'intel': 'assets/logos/intel.svg',
    'apple': 'assets/logos/apple.svg',
    'qualcomm': 'assets/logos/qualcomm.svg',
    'mediatek': 'assets/logos/mediatek.svg',
    'samsung': 'assets/logos/samsung.svg',
    'broadcom': 'assets/logos/broadcom.svg',
    'mali': 'assets/logos/arm.svg',
    'google': 'assets/logos/google.svg',
    'razer': 'assets/logos/razer.svg',
  };

  String? _detectLogoForModel(String model) {
    final lower = model.toLowerCase();
    for (final entry in _brandLogoMap.entries) {
      if (lower.startsWith(entry.key)) return entry.value;
    }
    return null;
  }

  Widget _brandLogoWidget(String? logoPath) {
    if (logoPath == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SvgPicture.asset(
        logoPath,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(
          Theme.of(context).colorScheme.onSurface,
          BlendMode.srcIn,
        ),
      ),
    );
  }

  static const _commonEmojis = [
    '💻',
    '📱',
    '🖥️',
    '🎮',
    '🎧',
    '⌚',
    '📡',
    '🖨️',
    '🔌',
    '💾',
    '📷',
    '🔧',
    '🛠️',
    '🏠',
    '🏢',
    '🌐',
    '☁️',
    '🔒',
    '🎯',
    '⚡',
    '🚀',
    '🌟',
    '💡',
    '🔬',
    '📊',
    '🎵',
    '🎬',
    '📺',
    '🕹️',
    '🤖',
    '📟',
    '🧮',
  ];

  void _showEmojiPicker(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.deviceEmoji,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: _commonEmojis.length,
                itemBuilder: (context, index) {
                  final emoji = _commonEmojis[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _emoji = emoji;
                        _imagePath = null;
                      });
                      Navigator.pop(context);
                    },
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final path = await ImageService.pickAndSaveImage();
    if (path != null) {
      setState(() {
        _imagePath = path;
        _emoji = null;
      });
    }
  }

  void _removeIcon() {
    setState(() {
      _emoji = null;
      _imagePath = null;
    });
  }

  Widget _buildIconSection(AppLocalizations l10n, ThemeData theme) {
    Widget preview;
    if (_emoji != null) {
      preview = Text(_emoji!, style: const TextStyle(fontSize: 32));
    } else if (_imagePath != null) {
      preview = FutureBuilder<File>(
        future: ImageService.resolve(_imagePath!),
        builder: (context, snap) {
          if (snap.hasData && snap.data!.existsSync()) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                snap.data!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            );
          }
          return const Icon(Icons.image, size: 32);
        },
      );
    } else {
      preview = Icon(
        deviceCategoryIcon(_category),
        size: 32,
        color: theme.colorScheme.onSurfaceVariant,
      );
    }

    return Row(
      children: [
        preview,
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.emoji_emotions, size: 18),
                label: Text(l10n.deviceEmoji),
                onPressed: () => _showEmojiPicker(l10n),
              ),
              ActionChip(
                avatar: const Icon(Icons.image, size: 18),
                label: Text(
                  _imagePath != null
                      ? l10n.deviceChangeImage
                      : l10n.devicePickImage,
                ),
                onPressed: _pickImage,
              ),
              if (_emoji != null || _imagePath != null)
                ActionChip(
                  avatar: const Icon(Icons.clear, size: 18),
                  label: Text(l10n.deviceRemoveIcon),
                  onPressed: _removeIcon,
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editDevice : l10n.addDevice),
        actions: [
          if (AppFlavor.isFull)
            IconButton(
              icon: const Icon(Icons.travel_explore),
              tooltip: l10n.fetchFromInternet,
              onPressed: _showSearchDialog,
            ),
          TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Basic info ──
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l10n.deviceName),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.deviceName : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DeviceCategory>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l10n.deviceCategory),
              items: DeviceCategory.values
                  .map(
                    (cat) => DropdownMenuItem(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(deviceCategoryIcon(cat), size: 20),
                          const SizedBox(width: 8),
                          Text(_categoryLabel(l10n, cat)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 12),
            Autocomplete<BrandEntry>(
              initialValue: _brandCtrl.value,
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return _brandPresets;
                final query = textEditingValue.text.toLowerCase();
                return _brandPresets.where(
                  (b) => b.name.toLowerCase().contains(query),
                );
              },
              displayStringForOption: (b) => b.name,
              fieldViewBuilder: (context, ctrl, focusNode, onSubmit) {
                _brandCtrl.text = ctrl.text;
                ctrl.addListener(() => _brandCtrl.text = ctrl.text);
                return TextFormField(
                  controller: ctrl,
                  focusNode: focusNode,
                  decoration: InputDecoration(labelText: l10n.deviceBrand),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 240,
                        maxWidth: 360,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final brand = options.elementAt(index);
                          return ListTile(
                            leading: brand.logo != null
                                ? SvgPicture.asset(
                                    brand.logo!,
                                    width: 24,
                                    height: 24,
                                    colorFilter: ColorFilter.mode(
                                      Theme.of(context).colorScheme.onSurface,
                                      BlendMode.srcIn,
                                    ),
                                  )
                                : const Icon(Icons.business, size: 24),
                            title: Text(brand.name),
                            dense: true,
                            onTap: () => onSelected(brand),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modelCtrl,
              decoration: InputDecoration(labelText: l10n.deviceModel),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _serialNumberCtrl,
              decoration: InputDecoration(labelText: l10n.deviceSerialNumber),
            ),
            const SizedBox(height: 12),

            // ── Emoji / Image icon ──
            _buildIconSection(l10n, theme),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.devicePurchaseDate),
              subtitle: Text(
                _purchaseDate != null
                    ? DateFormat.yMd(l10n.localeName).format(_purchaseDate!)
                    : '—',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickDate,
                  ),
                  if (_purchaseDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _purchaseDate = null),
                    ),
                ],
              ),
            ),

            // ── Release date ──
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.deviceReleaseDate),
              subtitle: Text(
                _releaseDate != null
                    ? DateFormat.yMd(l10n.localeName).format(_releaseDate!)
                    : '—',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickReleaseDate,
                  ),
                  if (_releaseDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _releaseDate = null),
                    ),
                ],
              ),
            ),

            const Divider(height: 32),

            // ── CPU section ──
            Row(
              children: [
                _brandLogoWidget(_detectLogoForModel(_cpuModelCtrl.text)),
                Expanded(
                  child: Text(
                    l10n.cpuInfo,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (AppFlavor.isFull)
                  IconButton(
                    icon: const Icon(Icons.travel_explore, size: 20),
                    tooltip: l10n.fetchFromInternet,
                    onPressed: _searchCpuOnline,
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.list, size: 18),
                  label: Text(l10n.cpuInfo),
                  onPressed: _cpuPresets.isNotEmpty ? _pickCpuPreset : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Autocomplete<CpuInfo>(
              key: ValueKey('cpu_auto_$_cpuAutoKey'),
              initialValue: _cpuModelCtrl.value,
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return const [];
                final query = textEditingValue.text.toLowerCase();
                return _cpuPresets.where(
                  (c) => (c.model ?? '').toLowerCase().contains(query),
                );
              },
              displayStringForOption: (c) => c.model ?? '',
              fieldViewBuilder: (context, ctrl, focusNode, onSubmit) {
                ctrl.addListener(() => _cpuModelCtrl.text = ctrl.text);
                return TextFormField(
                  controller: ctrl,
                  focusNode: focusNode,
                  decoration: InputDecoration(labelText: l10n.cpuModel),
                );
              },
              onSelected: (cpu) => _applyCpuPreset(cpu),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cpuArchCtrl,
              decoration: InputDecoration(
                labelText: l10n.cpuArchitecture,
                hintText: l10n.cpuArchHint,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cpuFreqCtrl,
              decoration: InputDecoration(
                labelText: l10n.cpuFrequency,
                hintText: l10n.cpuFreqHint,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cpuPCoresCtrl,
                    decoration: InputDecoration(labelText: l10n.cpuPCores),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cpuECoresCtrl,
                    decoration: InputDecoration(labelText: l10n.cpuECores),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cpuThreadsCtrl,
                    decoration: InputDecoration(labelText: l10n.cpuThreads),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cpuCacheCtrl,
              decoration: InputDecoration(
                labelText: l10n.cpuCache,
                hintText: l10n.cpuCacheHint,
              ),
            ),

            const Divider(height: 32),

            // ── GPU section ──
            Row(
              children: [
                _brandLogoWidget(_detectLogoForModel(_gpuModelCtrl.text)),
                Expanded(
                  child: Text(
                    l10n.gpuInfo,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                if (AppFlavor.isFull)
                  IconButton(
                    icon: const Icon(Icons.travel_explore, size: 20),
                    tooltip: l10n.fetchFromInternet,
                    onPressed: _searchGpuOnline,
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.list, size: 18),
                  label: Text(l10n.gpuInfo),
                  onPressed: _gpuPresets.isNotEmpty ? _pickGpuPreset : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Autocomplete<GpuInfo>(
              key: ValueKey('gpu_auto_$_gpuAutoKey'),
              initialValue: _gpuModelCtrl.value,
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return const [];
                final query = textEditingValue.text.toLowerCase();
                return _gpuPresets.where(
                  (g) => (g.model ?? '').toLowerCase().contains(query),
                );
              },
              displayStringForOption: (g) => g.model ?? '',
              fieldViewBuilder: (context, ctrl, focusNode, onSubmit) {
                ctrl.addListener(() => _gpuModelCtrl.text = ctrl.text);
                return TextFormField(
                  controller: ctrl,
                  focusNode: focusNode,
                  decoration: InputDecoration(labelText: l10n.gpuModel),
                );
              },
              onSelected: (gpu) => _applyGpuPreset(gpu),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _gpuArchCtrl,
              decoration: InputDecoration(
                labelText: l10n.gpuArchitecture,
                hintText: l10n.gpuArchHint,
              ),
            ),

            const Divider(height: 32),

            // ── Other specs ──
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ramCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.ram,
                      hintText: l10n.ramHint,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _ramUnit,
                  underline: const SizedBox.shrink(),
                  items: _memoryUnits
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _ramUnit = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<RamType>(
              initialValue: _ramType,
              decoration: InputDecoration(
                labelText: l10n.ramType,
                isDense: true,
              ),
              items: [
                DropdownMenuItem<RamType>(value: null, child: Text('-')),
                ...RamType.values.map(
                  (t) => DropdownMenuItem(value: t, child: Text(t.displayName)),
                ),
              ],
              onChanged: (v) => setState(() => _ramType = v),
            ),
            const SizedBox(height: 12),

            // ── Storage (multiple entries) ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.storage,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => setState(() {
                    _storageEntries.add('');
                    _storageUnits.add('GB');
                    _storageTypes.add(null);
                    _storageInterfaces.add(null);
                    _storageBrandCtrls.add(TextEditingController());
                    _storageSerialCtrls.add(TextEditingController());
                  }),
                ),
              ],
            ),
            for (int i = 0; i < _storageEntries.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _storageEntries[i],
                            decoration: InputDecoration(
                              labelText: '${l10n.storage} ${i + 1}',
                              hintText: l10n.storageCapacityHint,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => _storageEntries[i] = v,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _storageUnits[i],
                          underline: const SizedBox.shrink(),
                          items: _memoryUnits
                              .map(
                                (u) =>
                                    DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _storageUnits[i] = v);
                          },
                        ),
                        if (_storageEntries.length > 1)
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 20,
                            ),
                            onPressed: () => setState(() {
                              _storageBrandCtrls[i].dispose();
                              _storageSerialCtrls[i].dispose();
                              _storageEntries.removeAt(i);
                              _storageUnits.removeAt(i);
                              _storageTypes.removeAt(i);
                              _storageInterfaces.removeAt(i);
                              _storageBrandCtrls.removeAt(i);
                              _storageSerialCtrls.removeAt(i);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<StorageType?>(
                            initialValue: _storageTypes[i],
                            decoration: InputDecoration(
                              labelText: l10n.storageType,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              DropdownMenuItem<StorageType?>(
                                value: null,
                                child: Text('-'),
                              ),
                              ...StorageType.values.map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(_storageTypeLabel(l10n, t)),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _storageTypes[i] = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<StorageInterface?>(
                            initialValue: _storageInterfaces[i],
                            decoration: InputDecoration(
                              labelText: l10n.storageInterface,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              DropdownMenuItem<StorageInterface?>(
                                value: null,
                                child: Text('-'),
                              ),
                              ...StorageInterface.values.map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(_storageInterfaceLabel(l10n, t)),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _storageInterfaces[i] = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _storageBrandCtrls[i],
                            decoration: InputDecoration(
                              labelText: l10n.storageBrand,
                              isDense: true,
                              hintText: l10n.storageBrandHint,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _storageSerialCtrls[i],
                            decoration: InputDecoration(
                              labelText: l10n.storageSerialNumber,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),
            TextFormField(
              controller: _screenSizeCtrl,
              decoration: InputDecoration(
                labelText: l10n.screenSize,
                hintText: l10n.screenSizeHint,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _screenResWCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.screenResolution,
                      hintText: 'W',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('×'),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _screenResHCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.screenResolution,
                      hintText: 'H',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            Builder(
              builder: (context) {
                final w = int.tryParse(_screenResWCtrl.text.trim());
                final h = int.tryParse(_screenResHCtrl.text.trim());
                if (w == null || h == null) return const SizedBox.shrink();
                final tempDevice = Device(
                  name: '',
                  category: _category,
                  screenSize: _nonEmpty(_screenSizeCtrl.text),
                  screenResolutionW: w,
                  screenResolutionH: h,
                );
                final ppi = tempDevice.ppi;
                if (ppi == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${l10n.ppi}: ${ppi.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _batteryCtrl,
              decoration: InputDecoration(
                labelText: l10n.battery,
                hintText: l10n.batteryHint,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _osCtrl,
              decoration: InputDecoration(
                labelText: l10n.os,
                hintText: l10n.osHint,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration: InputDecoration(
                labelText: l10n.deviceLocation,
                hintText: l10n.locationHint,
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map_outlined),
                  tooltip: l10n.mapPickLocation,
                  onPressed: () async {
                    final initial = (_latitude != null && _longitude != null)
                        ? LatLng(_latitude!, _longitude!)
                        : null;
                    final result =
                        await Navigator.of(
                          context,
                          rootNavigator: true,
                        ).push<LatLng>(
                          MaterialPageRoute(
                            builder: (_) =>
                                MapPickerPage(initialPosition: initial),
                          ),
                        );
                    if (result != null && mounted) {
                      setState(() {
                        _latitude = result.latitude;
                        _longitude = result.longitude;
                      });
                    }
                  },
                ),
              ),
            ),
            if (_latitude != null && _longitude != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Text(
                  '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            const Divider(height: 32),

            // ── Notes ──
            TextFormField(
              controller: _notesCtrl,
              decoration: InputDecoration(labelText: l10n.deviceNotes),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet to browse and search CPU presets.
class _CpuPresetPicker extends StatefulWidget {
  final List<CpuInfo> presets;

  const _CpuPresetPicker({required this.presets});

  @override
  State<_CpuPresetPicker> createState() => _CpuPresetPickerState();
}

class _CpuPresetPickerState extends State<_CpuPresetPicker> {
  String _query = '';

  List<CpuInfo> get _filtered {
    if (_query.isEmpty) return widget.presets;
    final q = _query.toLowerCase();
    return widget.presets.where((c) {
      final model = (c.model ?? '').toLowerCase();
      final arch = (c.architecture ?? '').toLowerCase();
      return model.contains(q) || arch.contains(q);
    }).toList();
  }

  String _coresLabel(CpuInfo cpu) {
    final parts = <String>[];
    if (cpu.performanceCores != null) parts.add('${cpu.performanceCores}P');
    if (cpu.efficiencyCores != null) parts.add('${cpu.efficiencyCores}E');
    if (cpu.threads != null) parts.add('${cpu.threads}T');
    return parts.join('+');
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        final l10n = AppLocalizations.of(context)!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.cpuPresetSearch,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final cpu = items[index];
                  return ListTile(
                    title: Text(cpu.model ?? ''),
                    subtitle: Text(
                      [
                        if (cpu.architecture != null) cpu.architecture!,
                        if (cpu.frequency != null) cpu.frequency!,
                        _coresLabel(cpu),
                      ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                    dense: true,
                    onTap: () => Navigator.pop(context, cpu),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bottom sheet to browse and search GPU presets.
class _GpuPresetPicker extends StatefulWidget {
  final List<GpuInfo> presets;

  const _GpuPresetPicker({required this.presets});

  @override
  State<_GpuPresetPicker> createState() => _GpuPresetPickerState();
}

class _GpuPresetPickerState extends State<_GpuPresetPicker> {
  String _query = '';

  List<GpuInfo> get _filtered {
    if (_query.isEmpty) return widget.presets;
    final q = _query.toLowerCase();
    return widget.presets.where((g) {
      final model = (g.model ?? '').toLowerCase();
      final arch = (g.architecture ?? '').toLowerCase();
      return model.contains(q) || arch.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        final l10n = AppLocalizations.of(context)!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.gpuPresetSearch,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final gpu = items[index];
                  return ListTile(
                    title: Text(gpu.model ?? ''),
                    subtitle: gpu.architecture != null
                        ? Text(gpu.architecture!)
                        : null,
                    dense: true,
                    onTap: () => Navigator.pop(context, gpu),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
