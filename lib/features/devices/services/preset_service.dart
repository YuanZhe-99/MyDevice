import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

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

  /// Purpose: Expose the template catalog if it has already been loaded.
  /// Inputs: None.
  /// Returns: The cached templates, or null before the first [loadTemplates].
  /// Side effects: None.
  /// Notes: Lets widgets resolve a thumbnail synchronously on rebuild instead
  /// of flashing their fallback while a future completes.
  static List<DeviceTemplate>? get cachedTemplates => _templates;

  /// Purpose: Find the bundled thumbnail of the template a device matches.
  /// Inputs: The device's `brand`, `model` and `name`.
  /// Returns: The template's `image` asset path, or null when none matches.
  /// Side effects: Loads and caches the template catalog on first use.
  /// Notes: Display-only. The path is never written into the device, so a
  /// device created before thumbnails existed picks one up too. See
  /// [matchTemplateImage] for the matching rules.
  static Future<String?> findTemplateImage({
    String? brand,
    String? model,
    String? name,
  }) async {
    final templates = await loadTemplates();
    return matchTemplateImage(
      templates,
      brand: brand,
      model: model,
      name: name,
    );
  }

  /// Purpose: Match a device to a template thumbnail by normalized identity.
  /// Inputs: `templates` to search; the device's `brand`, `model` and `name`.
  /// Returns: The first matching template's `image`, or null.
  /// Side effects: None.
  /// Notes: Keys are lowercased with every non-alphanumeric removed, then
  /// compared for equality only, in this order: brand+model against the
  /// template's brand+model; name against the template's name; brand+model
  /// against the template's name. Only templates that carry an image take
  /// part. Equality rather than containment keeps "iPhone 15" from claiming
  /// an "iPhone 15 Pro" photo.
  static String? matchTemplateImage(
    List<DeviceTemplate> templates, {
    String? brand,
    String? model,
    String? name,
  }) {
    final withImage = templates.where((t) => t.image != null).toList();
    if (withImage.isEmpty) return null;
    final brandModel = _identityKey('${brand ?? ''}${model ?? ''}');
    final nameKey = _identityKey(name ?? '');
    final hasModel = _identityKey(model ?? '').isNotEmpty;

    if (hasModel) {
      for (final t in withImage) {
        if (_identityKey('${t.brand ?? ''}${t.model ?? ''}') == brandModel) {
          return t.image;
        }
      }
    }
    if (nameKey.isNotEmpty) {
      for (final t in withImage) {
        if (_identityKey(t.name) == nameKey) return t.image;
      }
    }
    if (hasModel) {
      for (final t in withImage) {
        if (_identityKey(t.name) == brandModel) return t.image;
      }
    }
    return null;
  }

  /// Purpose: Tell whether an asset path is one of the bundled thumbnails.
  /// Inputs: `templates` — the catalog; `asset` — a stored `templateImage`.
  /// Returns: True when some template carries exactly that `image`.
  /// Side effects: None.
  /// Notes: A thumbnail chosen by hand may be renamed or dropped by a later
  /// release; the avatar then falls back to automatic matching instead of
  /// showing a broken image.
  static bool isTemplateImage(List<DeviceTemplate> templates, String asset) =>
      templates.any((t) => t.image == asset);

  /// Purpose: Order every bundled thumbnail by how well it fits a device.
  /// Inputs: `templates` to rank; the device's `brand`, `model` and `name`.
  /// Returns: One template per distinct `image`, best candidates first.
  /// Side effects: None.
  /// Notes: Feeds the hand-picked thumbnail chooser, so the list is always
  /// complete: an exact [matchTemplateImage]-style identity hit comes first,
  /// then templates sharing the most words (lowercase letter/digit runs) with
  /// the device (the brand counts as one of them), ties and the rest in
  /// catalog order. Several templates often share one file (sibling
  /// models); the first in catalog order stands for it. Unlike automatic
  /// matching this is deliberately fuzzy, because the user makes the final
  /// choice.
  static List<DeviceTemplate> rankTemplateImageCandidates(
    List<DeviceTemplate> templates, {
    String? brand,
    String? model,
    String? name,
  }) {
    final exact = matchTemplateImage(
      templates,
      brand: brand,
      model: model,
      name: name,
    );
    final wanted = {..._tokens(brand), ..._tokens(model), ..._tokens(name)};
    final seen = <String>{};
    final scored = <(DeviceTemplate, int, int)>[];
    var order = 0;
    for (final t in templates) {
      final image = t.image;
      if (image == null || !seen.add(image)) continue;
      var score = 0;
      if (wanted.isNotEmpty) {
        final have = {
          ..._tokens(t.brand),
          ..._tokens(t.model),
          ..._tokens(t.name),
        };
        score = have.intersection(wanted).length;
      }
      if (image == exact) score = 1 << 20;
      scored.add((t, score, order++));
    }
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      return byScore != 0 ? byScore : a.$3.compareTo(b.$3);
    });
    return [for (final s in scored) s.$1];
  }

  /// Purpose: Split an identity string into lowercase word tokens.
  /// Inputs: `value`, which may be null.
  /// Returns: The set of letter/digit runs, e.g. `{ipad, pro, 13, m4}`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Set<String> _tokens(String? value) => {
    for (final m in RegExp(
      r'[a-z0-9]+',
    ).allMatches((value ?? '').toLowerCase()))
      m.group(0)!,
  };

  /// Purpose: Reduce a device identity string to its comparison key.
  /// Inputs: `value`.
  /// Returns: `value` lowercased with every non-alphanumeric removed.
  /// Side effects: None.
  /// Notes: Makes `iPad Pro 13" (M4)` equal `ipad pro 13 m4`. Internal helper
  /// used within this file only.
  static String _identityKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
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

  /// Full CPU detail when the template authored `cpu` as an object rather than
  /// a bare model string. Null for the plain-string form.
  final CpuInfo? cpuDetail;
  final String? gpu;
  final List<GpuInfo>? gpus;
  final List<DisplayInfo>? displays;
  final String? ram;

  /// Every capacity the template lists, in authored order. A template may
  /// legitimately offer several (a MacBook Pro lists 512 GB through 4 TB);
  /// picking one is the caller's job, not this class's.
  final List<StorageInfo> storage;
  final String? screenSize;
  final int? screenResolutionW;
  final int? screenResolutionH;
  final String? battery;
  final String? os;
  final DateTime? releaseDate;

  /// Bundled thumbnail of the device itself (`assets/device_images/*.png`):
  /// transparent background, all content inside the avatar circle. Null when
  /// no freely licensed photo exists; the UI then falls back to the brand
  /// logo or category icon.
  final String? image;

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
    this.cpuDetail,
    this.gpu,
    this.gpus,
    this.displays,
    this.ram,
    this.storage = const [],
    this.screenSize,
    this.screenResolutionW,
    this.screenResolutionH,
    this.battery,
    this.os,
    this.releaseDate,
    this.image,
  });

  /// Purpose: Provide the internal as string helper for this file.
  /// Inputs: `value`.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: Templates author `cpu`/`gpu` either as a plain model string or as
  /// an object. This reduces both to the model name; the object form's extra
  /// fields are preserved separately by [DeviceTemplate._asCpuInfo].
  /// Internal helper used within this file only.
  static String? _asString(dynamic value) {
    if (value is String) return value;
    if (value is Map<String, dynamic>) return value['model'] as String?;
    return null;
  }

  /// Purpose: Keep the detail an object-form `cpu` carries beyond its model.
  /// Inputs: `value` — the raw `cpu` JSON value.
  /// Returns: A `CpuInfo` when the template authored an object, else null.
  /// Side effects: None.
  /// Notes: The 14 VPS templates author `architecture` and `performanceCores`
  /// inside `cpu`. Reducing that to the model string alone discarded them at
  /// parse time, and `toDevice`'s exact-match preset lookup could not recover
  /// them either, because names like `Intel Xeon` and `Ampere Altra` are not
  /// in `cpus.json`. The authored data never reached the UI.
  /// Internal helper used within this file only.
  static CpuInfo? _asCpuInfo(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    return CpuInfo.fromJson(value);
  }

  /// Purpose: Create a template from one `device_templates.json` entry.
  /// Inputs: `json`.
  /// Returns: A new `DeviceTemplate`.
  /// Side effects: None.
  /// Notes: CPU/GPU accept string or object forms; ordered gpus/displays override
  /// legacy values when supplied. Image is optional.
  factory DeviceTemplate.fromJson(Map<String, dynamic> json) => DeviceTemplate(
    name: json['name'] as String,
    category: DeviceCategory.fromJson(json['category'] as String),
    brand: json['brand'] as String?,
    model: json['model'] as String?,
    cpu: _asString(json['cpu']),
    cpuDetail: _asCpuInfo(json['cpu']),
    gpu: _asString(json['gpu']),
    gpus: (json['gpus'] as List<dynamic>?)
        ?.map(
          (e) => e is String
              ? GpuInfo(model: e)
              : GpuInfo.fromJson(e as Map<String, dynamic>),
        )
        .toList(),
    displays: (json['displays'] as List<dynamic>?)
        ?.map((e) => DisplayInfo.fromJson(e as Map<String, dynamic>))
        .toList(),
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
    image: json['image'] as String?,
  );

  /// Purpose: Convert this template into a new `Device`.
  /// Inputs: `cpuPresets` / `gpuPresets` to fill in full chip detail, and
  /// `storageIndex` to choose among the capacities this template offers.
  /// Returns: `Device`.
  /// Side effects: None.
  /// Notes: CPU detail resolves in priority order — the template's own
  /// object-form `cpuDetail` first, then an exact match in `cpuPresets`, then
  /// the bare model string. The template's own detail wins because a VPS
  /// template authors `architecture` and core counts for chips that are
  /// deliberately absent from `cpus.json`.
  ///
  /// `storageIndex` is clamped into range, so an out-of-date caller cannot
  /// throw. It exists because a template may list several capacities and
  /// silently taking the first made every multi-capacity template
  /// (a MacBook Pro offering 512 GB through 4 TB) collapse to its smallest.
  ///
  /// The template's thumbnail is carried as `templateImage`, so the device
  /// keeps it after the user renames it.
  Device toDevice({
    List<CpuInfo>? cpuPresets,
    List<GpuInfo>? gpuPresets,
    int storageIndex = 0,
  }) {
    CpuInfo cpuInfo = CpuInfo(model: cpu);
    if (cpu != null && cpuPresets != null) {
      final match = cpuPresets
          .where((c) => c.model != null && c.model == cpu)
          .firstOrNull;
      if (match != null) cpuInfo = match;
    }
    if (cpuDetail != null && !cpuDetail!.isEmpty) cpuInfo = cpuDetail!;

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
      gpus: gpus
          ?.map(
            (g) => GpuInfo.fromJson({
              ...?gpuPresets
                  ?.where((p) => p.model == g.model)
                  .firstOrNull
                  ?.toJson(),
              ...g.toJson(),
              'id': const Uuid().v4(),
            }),
          )
          .toList(),
      displays: displays
          ?.map(
            (d) =>
                DisplayInfo.fromJson({...d.toJson(), 'id': const Uuid().v4()}),
          )
          .toList(),
      ram: ram,
      storage: storage.isEmpty
          ? []
          : [storage[storageIndex.clamp(0, storage.length - 1)]],
      screenSize: screenSize,
      screenResolutionW: screenResolutionW,
      screenResolutionH: screenResolutionH,
      battery: battery,
      os: os,
      releaseDate: releaseDate,
      templateImage: image,
    );
  }
}
