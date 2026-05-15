import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/device.dart';

class PresetService {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `PresetService._` instance.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  PresetService._();

  static List<CpuInfo>? _cpus;
  static List<GpuInfo>? _gpus;
  static List<BrandEntry>? _brands;
  static List<DeviceTemplate>? _templates;

  /// Purpose: Load cpus into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<List<CpuInfo>>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<List<CpuInfo>> loadCpus() async {
    if (_cpus != null) return _cpus!;
    final raw = await rootBundle.loadString('assets/presets/cpus.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['cpus'] as List<dynamic>)
        .map((e) => CpuInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    _cpus = list;
    return list;
  }

  /// Purpose: Load gpus into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<List<GpuInfo>>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<List<GpuInfo>> loadGpus() async {
    if (_gpus != null) return _gpus!;
    final raw = await rootBundle.loadString('assets/presets/gpus.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['gpus'] as List<dynamic>)
        .map((e) => GpuInfo.fromJson(e as Map<String, dynamic>))
        .toList();
    _gpus = list;
    return list;
  }

  /// Purpose: Load brands into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<List<BrandEntry>>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<List<BrandEntry>> loadBrands() async {
    if (_brands != null) return _brands!;
    final raw = await rootBundle.loadString('assets/presets/brands.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['brands'] as List<dynamic>)
        .map((e) => BrandEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    _brands = list;
    return list;
  }

  /// Purpose: Load templates into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<List<DeviceTemplate>>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  static Future<List<DeviceTemplate>> loadTemplates() async {
    if (_templates != null) return _templates!;
    final raw = await rootBundle.loadString(
      'assets/presets/device_templates.json',
    );
    final json = jsonDecode(raw) as List<dynamic>;
    final list = json
        .map((e) => DeviceTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
    _templates = list;
    return list;
  }
}

class BrandEntry {
  final String name;
  final String? logo;

  /// Purpose: Create a brand entry instance.
  /// Inputs: None.
  /// Returns: A new `BrandEntry` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const BrandEntry({required this.name, this.logo});

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `BrandEntry.fromJson` instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  factory BrandEntry.fromJson(Map<String, dynamic> json) =>
      BrandEntry(name: json['name'] as String, logo: json['logo'] as String?);
}

class DeviceTemplate {
  final String name;
  final DeviceCategory category;
  final String? brand;
  final String? model;
  final String? cpu;
  final String? gpu;
  final String? ram;
  final List<StorageInfo> storage;
  final String? screenSize;
  final int? screenResolutionW;
  final int? screenResolutionH;
  final String? battery;
  final String? os;
  final DateTime? releaseDate;

  /// Purpose: Create a device template instance.
  /// Inputs: `storage`.
  /// Returns: A new `DeviceTemplate` instance.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  const DeviceTemplate({
    required this.name,
    required this.category,
    this.brand,
    this.model,
    this.cpu,
    this.gpu,
    this.ram,
    this.storage = const [],
    this.screenSize,
    this.screenResolutionW,
    this.screenResolutionH,
    this.battery,
    this.os,
    this.releaseDate,
  });

  /// Purpose: Provide the internal as string helper for this file.
  /// Inputs: `value`.
  /// Returns: `String?`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  static String? _asString(dynamic value) {
    if (value is String) return value;
    if (value is Map<String, dynamic>) return value['model'] as String?;
    return null;
  }

  factory DeviceTemplate.fromJson(Map<String, dynamic> json) => DeviceTemplate(
    name: json['name'] as String,
    category: DeviceCategory.fromJson(json['category'] as String),
    brand: json['brand'] as String?,
    model: json['model'] as String?,
    cpu: _asString(json['cpu']),
    gpu: _asString(json['gpu']),
    ram: json['ram'] as String?,
    storage:
        (json['storage'] as List<dynamic>?)
            ?.map((e) => StorageInfo.fromJson(e))
            .toList() ??
        const [],
    screenSize: json['screenSize'] as String?,
    screenResolutionW: json['screenResolutionW'] as int?,
    screenResolutionH: json['screenResolutionH'] as int?,
    battery: json['battery'] as String?,
    os: json['os'] as String?,
    releaseDate: json['releaseDate'] != null
        ? DateTime.parse(json['releaseDate'] as String)
        : null,
  );

  /// Purpose: Implement the to device behavior for this file.
  /// Inputs: None.
  /// Returns: `Device`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: None.
  /// Convert to a new Device, pre-filling all template fields.
  /// If [cpuPresets] / [gpuPresets] are provided, matching entries
  /// will be used to fill in full CPU/GPU details automatically.
  Device toDevice({List<CpuInfo>? cpuPresets, List<GpuInfo>? gpuPresets}) {
    CpuInfo cpuInfo = CpuInfo(model: cpu);
    if (cpu != null && cpuPresets != null) {
      final match = cpuPresets
          .where((c) => c.model != null && c.model == cpu)
          .firstOrNull;
      if (match != null) cpuInfo = match;
    }

    GpuInfo gpuInfo = GpuInfo(model: gpu);
    if (gpu != null && gpuPresets != null) {
      // Try exact match first, then prefix match (GPU presets may have
      // core-count suffixes like "(10-core)").
      var match = gpuPresets
          .where((g) => g.model != null && g.model == gpu)
          .firstOrNull;
      match ??= gpuPresets
          .where((g) => g.model != null && g.model!.startsWith(gpu!))
          .firstOrNull;
      if (match != null) gpuInfo = match;
    }

    return Device(
      name: name,
      category: category,
      brand: brand,
      model: model,
      cpu: cpuInfo,
      gpu: gpuInfo,
      ram: ram,
      storage: storage.isNotEmpty ? [storage.first] : [],
      screenSize: screenSize,
      screenResolutionW: screenResolutionW,
      screenResolutionH: screenResolutionH,
      battery: battery,
      os: os,
      releaseDate: releaseDate,
    );
  }
}
