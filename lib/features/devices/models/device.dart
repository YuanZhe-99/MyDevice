import 'dart:math' show sqrt;

import 'package:uuid/uuid.dart';

/// Category of the device.
enum DeviceCategory {
  desktop,
  laptop,
  phone,
  tablet,
  headphone,
  watch,
  router,
  gameConsole,
  vps,
  devBoard,
  other;

  String get jsonValue => name;

  static DeviceCategory fromJson(String value) =>
      DeviceCategory.values.firstWhere(
        (e) => e.name == value,
        orElse: () => DeviceCategory.other,
      );
}

/// CPU information for a device.
class CpuInfo {
  final String? model;
  final String? architecture;
  final String? frequency;
  final int? performanceCores;
  final int? efficiencyCores;
  final int? threads;
  final String? cache;

  const CpuInfo({
    this.model,
    this.architecture,
    this.frequency,
    this.performanceCores,
    this.efficiencyCores,
    this.threads,
    this.cache,
  });

  bool get isEmpty =>
      model == null &&
      architecture == null &&
      frequency == null &&
      performanceCores == null &&
      efficiencyCores == null &&
      threads == null &&
      cache == null;

  Map<String, dynamic> toJson() => {
        if (model != null) 'model': model,
        if (architecture != null) 'architecture': architecture,
        if (frequency != null) 'frequency': frequency,
        if (performanceCores != null) 'performanceCores': performanceCores,
        if (efficiencyCores != null) 'efficiencyCores': efficiencyCores,
        if (threads != null) 'threads': threads,
        if (cache != null) 'cache': cache,
      };

  factory CpuInfo.fromJson(Map<String, dynamic> json) => CpuInfo(
        model: json['model'] as String?,
        architecture: json['architecture'] as String?,
        frequency: json['frequency'] as String?,
        performanceCores: json['performanceCores'] as int? ?? json['cores'] as int?,
        efficiencyCores: json['efficiencyCores'] as int?,
        threads: json['threads'] as int?,
        cache: json['cache'] as String?,
      );
}

/// GPU information for a device.
class GpuInfo {
  final String? model;
  final String? architecture;

  const GpuInfo({this.model, this.architecture});

  bool get isEmpty => model == null && architecture == null;

  Map<String, dynamic> toJson() => {
        if (model != null) 'model': model,
        if (architecture != null) 'architecture': architecture,
      };

  factory GpuInfo.fromJson(Map<String, dynamic> json) => GpuInfo(
        model: json['model'] as String?,
        architecture: json['architecture'] as String?,
      );
}

/// Type of storage media.
enum StorageType {
  ssd,
  sdCard,
  hdd;

  String get jsonValue => name;

  static StorageType? fromJson(String? value) {
    if (value == null) return null;
    return StorageType.values
        .where((e) => e.name == value)
        .firstOrNull;
  }
}

/// RAM type / standard.
enum RamType {
  ddr3,
  lpddr3,
  ddr4,
  lpddr4,
  lpddr4x,
  ddr5,
  lpddr5,
  lpddr5x,
  lpddr6;

  String get jsonValue => name;

  String get displayName => switch (this) {
        RamType.ddr3 => 'DDR3',
        RamType.lpddr3 => 'LPDDR3',
        RamType.ddr4 => 'DDR4',
        RamType.lpddr4 => 'LPDDR4',
        RamType.lpddr4x => 'LPDDR4X',
        RamType.ddr5 => 'DDR5',
        RamType.lpddr5 => 'LPDDR5',
        RamType.lpddr5x => 'LPDDR5X',
        RamType.lpddr6 => 'LPDDR6',
      };

  static RamType? fromJson(String? value) {
    if (value == null) return null;
    return RamType.values
        .where((e) => e.name == value)
        .firstOrNull;
  }
}

/// Physical interface of the storage device.
enum StorageInterface {
  m2Nvme,
  sata25,
  m2Sata,
  usb;

  String get jsonValue => name;

  static StorageInterface? fromJson(String? value) {
    if (value == null) return null;
    return StorageInterface.values
        .where((e) => e.name == value)
        .firstOrNull;
  }
}

/// Storage device information.
class StorageInfo {
  final String? capacity; // e.g. "512 GB"
  final StorageType? type;
  final StorageInterface? interface_;
  final String? serialNumber;
  final String? brand;

  const StorageInfo({this.capacity, this.type, this.interface_, this.serialNumber, this.brand});

  bool get isEmpty => capacity == null && type == null && interface_ == null && serialNumber == null && brand == null;

  /// Human-readable summary, e.g. "512 GB SSD (M.2 NVMe)".
  String get displayString {
    final parts = <String>[];
    if (capacity != null) parts.add(capacity!);
    if (type != null) {
      parts.add(switch (type!) {
        StorageType.ssd => 'SSD',
        StorageType.sdCard => 'SD Card',
        StorageType.hdd => 'HDD',
      });
    }
    if (interface_ != null) {
      parts.add('(${switch (interface_!) {
        StorageInterface.m2Nvme => 'M.2 NVMe',
        StorageInterface.sata25 => '2.5" SATA',
        StorageInterface.m2Sata => 'M.2 SATA',
        StorageInterface.usb => 'USB',
      }})');
    }
    return parts.join(' ');
  }

  Map<String, dynamic> toJson() => {
        if (capacity != null) 'capacity': capacity,
        if (type != null) 'type': type!.jsonValue,
        if (interface_ != null) 'interface': interface_!.jsonValue,
        if (serialNumber != null) 'serialNumber': serialNumber,
        if (brand != null) 'brand': brand,
      };

  factory StorageInfo.fromJson(dynamic json) {
    if (json is String) {
      // Legacy format: plain string like "512 GB"
      return StorageInfo(capacity: json);
    }
    final map = json as Map<String, dynamic>;
    return StorageInfo(
      capacity: map['capacity'] as String?,
      type: StorageType.fromJson(map['type'] as String?),
      interface_: StorageInterface.fromJson(map['interface'] as String?),
      serialNumber: map['serialNumber'] as String?,
      brand: map['brand'] as String?,
    );
  }
}

/// A device record.
class Device {
  final String id;
  final String name;
  final DeviceCategory category;
  final String? emoji;
  final String? imagePath;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final CpuInfo cpu;
  final GpuInfo gpu;
  final String? ram;
  final RamType? ramType;
  final List<StorageInfo> storage;
  final String? screenSize;
  final int? screenResolutionW;
  final int? screenResolutionH;
  final String? battery;
  final String? os;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final DateTime? purchaseDate;
  final DateTime? releaseDate;
  final String? notes;
  final DateTime modifiedAt;

  Device({
    String? id,
    required this.name,
    required this.category,
    this.emoji,
    this.imagePath,
    this.brand,
    this.model,
    this.serialNumber,
    this.cpu = const CpuInfo(),
    this.gpu = const GpuInfo(),
    this.ram,
    this.ramType,
    this.storage = const [],
    this.screenSize,
    this.screenResolutionW,
    this.screenResolutionH,
    this.battery,
    this.os,
    this.locationName,
    this.latitude,
    this.longitude,
    this.purchaseDate,
    this.releaseDate,
    this.notes,
    DateTime? modifiedAt,
  })  : id = id ?? const Uuid().v4(),
        modifiedAt = modifiedAt ?? DateTime.now();

  /// Compute PPI from resolution and screen diagonal (inches).
  double? get ppi {
    if (screenResolutionW == null || screenResolutionH == null) return null;
    final diagonal = _parseScreenDiagonal(screenSize);
    if (diagonal == null || diagonal <= 0) return null;
    final w = screenResolutionW!.toDouble();
    final h = screenResolutionH!.toDouble();
    return sqrt(w * w + h * h) / diagonal;
  }

  static double? _parseScreenDiagonal(String? s) {
    if (s == null || s.isEmpty) return null;
    // Remove common suffixes like " or inch / 寸 etc.
    final cleaned = s.replaceAll(RegExp(r'''["\x27''寸inchs]+$''', caseSensitive: false), '').trim();
    return double.tryParse(cleaned);
  }

  Device copyWith({
    String? name,
    DeviceCategory? category,
    String? emoji,
    String? imagePath,
    String? brand,
    String? model,
    String? serialNumber,
    CpuInfo? cpu,
    GpuInfo? gpu,
    String? ram,
    RamType? ramType,
    List<StorageInfo>? storage,
    String? screenSize,
    int? screenResolutionW,
    int? screenResolutionH,
    String? battery,
    String? os,
    String? locationName,
    double? latitude,
    double? longitude,
    DateTime? purchaseDate,
    DateTime? releaseDate,
    String? notes,
    DateTime? modifiedAt,
    bool clearEmoji = false,
    bool clearImagePath = false,
    bool clearBrand = false,
    bool clearModel = false,
    bool clearSerialNumber = false,
    bool clearRam = false,
    bool clearRamType = false,
    bool clearScreenSize = false,
    bool clearScreenResolutionW = false,
    bool clearScreenResolutionH = false,
    bool clearBattery = false,
    bool clearOs = false,
    bool clearLocationName = false,
    bool clearLatitude = false,
    bool clearLongitude = false,
    bool clearPurchaseDate = false,
    bool clearReleaseDate = false,
    bool clearNotes = false,
  }) {
    return Device(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      emoji: clearEmoji ? null : (emoji ?? this.emoji),
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      brand: clearBrand ? null : (brand ?? this.brand),
      model: clearModel ? null : (model ?? this.model),
      serialNumber: clearSerialNumber ? null : (serialNumber ?? this.serialNumber),
      cpu: cpu ?? this.cpu,
      gpu: gpu ?? this.gpu,
      ram: clearRam ? null : (ram ?? this.ram),
      ramType: clearRamType ? null : (ramType ?? this.ramType),
      storage: storage ?? this.storage,
      screenSize: clearScreenSize ? null : (screenSize ?? this.screenSize),
      screenResolutionW: clearScreenResolutionW ? null : (screenResolutionW ?? this.screenResolutionW),
      screenResolutionH: clearScreenResolutionH ? null : (screenResolutionH ?? this.screenResolutionH),
      battery: clearBattery ? null : (battery ?? this.battery),
      os: clearOs ? null : (os ?? this.os),
      locationName: clearLocationName ? null : (locationName ?? this.locationName),
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      purchaseDate:
          clearPurchaseDate ? null : (purchaseDate ?? this.purchaseDate),
      releaseDate:
          clearReleaseDate ? null : (releaseDate ?? this.releaseDate),
      notes: clearNotes ? null : (notes ?? this.notes),
      modifiedAt: modifiedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.jsonValue,
        if (emoji != null) 'emoji': emoji,
        if (imagePath != null) 'imagePath': imagePath,
        if (brand != null) 'brand': brand,
        if (model != null) 'model': model,
        if (serialNumber != null) 'serialNumber': serialNumber,
        if (!cpu.isEmpty) 'cpu': cpu.toJson(),
        if (!gpu.isEmpty) 'gpu': gpu.toJson(),
        if (ram != null) 'ram': ram,
        if (ramType != null) 'ramType': ramType!.jsonValue,
        if (storage.isNotEmpty)
          'storage': storage.map((s) => s.toJson()).toList(),
        if (screenSize != null) 'screenSize': screenSize,
        if (screenResolutionW != null) 'screenResolutionW': screenResolutionW,
        if (screenResolutionH != null) 'screenResolutionH': screenResolutionH,
        if (battery != null) 'battery': battery,
        if (os != null) 'os': os,
        if (locationName != null) 'locationName': locationName,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (purchaseDate != null)
          'purchaseDate': purchaseDate!.toIso8601String(),
        if (releaseDate != null)
          'releaseDate': releaseDate!.toIso8601String(),
        if (notes != null) 'notes': notes,
        'modifiedAt': modifiedAt.toIso8601String(),
      };

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        name: json['name'] as String,
        category: DeviceCategory.fromJson(json['category'] as String),
        emoji: json['emoji'] as String?,
        imagePath: json['imagePath'] as String?,
        brand: json['brand'] as String?,
        model: json['model'] as String?,
        serialNumber: json['serialNumber'] as String?,
        cpu: json['cpu'] != null
            ? CpuInfo.fromJson(json['cpu'] as Map<String, dynamic>)
            : const CpuInfo(),
        gpu: json['gpu'] != null
            ? GpuInfo.fromJson(json['gpu'] as Map<String, dynamic>)
            : const GpuInfo(),
        ram: json['ram'] as String?,
        ramType: RamType.fromJson(json['ramType'] as String?),
        storage: json['storage'] != null
            ? (json['storage'] is String
                ? [StorageInfo.fromJson(json['storage'])]
                : (json['storage'] as List<dynamic>)
                    .map((e) => StorageInfo.fromJson(e))
                    .toList())
            : const [],
        screenSize: json['screenSize'] as String?,
        screenResolutionW: json['screenResolutionW'] as int?,
        screenResolutionH: json['screenResolutionH'] as int?,
        battery: json['battery'] as String?,
        os: json['os'] as String?,
        locationName: json['locationName'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        purchaseDate: json['purchaseDate'] != null
            ? DateTime.parse(json['purchaseDate'] as String)
            : null,
        releaseDate: json['releaseDate'] != null
            ? DateTime.parse(json['releaseDate'] as String)
            : null,
        notes: json['notes'] as String?,
        modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      );
}

/// Top-level data container persisted to disk.
class DeviceData {
  final List<Device> devices;

  const DeviceData({this.devices = const []});

  Map<String, dynamic> toJson() => {
        'devices': devices.map((d) => d.toJson()).toList(),
      };

  factory DeviceData.fromJson(Map<String, dynamic> json) => DeviceData(
        devices: (json['devices'] as List<dynamic>?)
                ?.map((e) => Device.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
