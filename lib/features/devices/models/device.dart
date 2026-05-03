import 'dart:math' show max, sqrt;

import 'package:uuid/uuid.dart';

import '../../../shared/utils/json_preservation.dart';

const _cpuInfoJsonKeys = {
  'model',
  'architecture',
  'frequency',
  'performanceCores',
  'efficiencyCores',
  'threads',
  'cache',
  'cores',
};

const _gpuInfoJsonKeys = {'model', 'architecture'};

const _storageInfoJsonKeys = {
  'capacity',
  'type',
  'interface',
  'serialNumber',
  'brand',
};

const _moneyValueJsonKeys = {
  'amount',
  'currency',
  'defaultCurrency',
  'convertedAmount',
  'exchangeRate',
  'autoRate',
  'rateUpdatedAt',
};

const _recurringCostJsonKeys = {'id', 'kind', 'name', 'price', 'billingCycle'};

const _deviceJsonKeys = {
  'id',
  'name',
  'category',
  'emoji',
  'imagePath',
  'brand',
  'model',
  'serialNumber',
  'cpu',
  'gpu',
  'ram',
  'ramType',
  'storage',
  'screenSize',
  'screenResolutionW',
  'screenResolutionH',
  'battery',
  'os',
  'locationName',
  'latitude',
  'longitude',
  'purchaseDate',
  'releaseDate',
  'acquisitionType',
  'isRetired',
  'retiredDate',
  'purchasePrice',
  'isSold',
  'soldPrice',
  'recurringCosts',
  'notes',
  'modifiedAt',
};

const _deviceDataJsonKeys = {'devices'};

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

  static DeviceCategory fromJson(String value) => DeviceCategory.values
      .firstWhere((e) => e.name == value, orElse: () => DeviceCategory.other);
}

/// How a device is financially acquired or paid for.
enum DeviceAcquisitionType {
  purchased,
  leased,
  purchasedWithSubscription,
  other;

  String get jsonValue => name;

  static DeviceAcquisitionType? fromJson(String? value) {
    if (value == null) return null;
    return DeviceAcquisitionType.values
        .where((e) => e.name == value)
        .firstOrNull;
  }
}

/// Lifecycle bucket used by the home filter and financial summary.
enum DeviceLifecycleStatus { inService, retired, sold }

/// Type of recurring device cost.
enum RecurringCostKind {
  lease,
  insurance,
  subscription,
  other;

  String get jsonValue => name;

  static RecurringCostKind fromJson(String? value) =>
      RecurringCostKind.values.where((e) => e.name == value).firstOrNull ??
      RecurringCostKind.other;
}

/// Billing cadence for recurring device costs.
enum BillingCycle {
  monthly,
  yearly;

  String get jsonValue => name;

  static BillingCycle fromJson(String? value) =>
      BillingCycle.values.where((e) => e.name == value).firstOrNull ??
      BillingCycle.monthly;
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
  final Map<String, dynamic> extraJson;

  const CpuInfo({
    this.model,
    this.architecture,
    this.frequency,
    this.performanceCores,
    this.efficiencyCores,
    this.threads,
    this.cache,
    this.extraJson = const {},
  });

  bool get isEmpty =>
      model == null &&
      architecture == null &&
      frequency == null &&
      performanceCores == null &&
      efficiencyCores == null &&
      threads == null &&
      cache == null &&
      extraJson.isEmpty;

  Map<String, dynamic> toJson() => {
    ...extraJson,
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
    extraJson: unknownJsonFields(json, _cpuInfoJsonKeys),
  );

  CpuInfo mergeUnknownFieldsFrom(CpuInfo other, {CpuInfo? base}) {
    return CpuInfo.fromJson({
      ...toJson(),
      ...mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    });
  }
}

/// GPU information for a device.
class GpuInfo {
  final String? model;
  final String? architecture;
  final Map<String, dynamic> extraJson;

  const GpuInfo({this.model, this.architecture, this.extraJson = const {}});

  bool get isEmpty =>
      model == null && architecture == null && extraJson.isEmpty;

  Map<String, dynamic> toJson() => {
    ...extraJson,
    if (model != null) 'model': model,
    if (architecture != null) 'architecture': architecture,
  };

  factory GpuInfo.fromJson(Map<String, dynamic> json) => GpuInfo(
    model: json['model'] as String?,
    architecture: json['architecture'] as String?,
    extraJson: unknownJsonFields(json, _gpuInfoJsonKeys),
  );

  GpuInfo mergeUnknownFieldsFrom(GpuInfo other, {GpuInfo? base}) {
    return GpuInfo.fromJson({
      ...toJson(),
      ...mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    });
  }
}

/// Type of storage media.
enum StorageType {
  ssd,
  sdCard,
  hdd;

  String get jsonValue => name;

  static StorageType? fromJson(String? value) {
    if (value == null) return null;
    return StorageType.values.where((e) => e.name == value).firstOrNull;
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
    return RamType.values.where((e) => e.name == value).firstOrNull;
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
    return StorageInterface.values.where((e) => e.name == value).firstOrNull;
  }
}

/// Storage device information.
class StorageInfo {
  final String? capacity; // e.g. "512 GB"
  final StorageType? type;
  final StorageInterface? interface_;
  final String? serialNumber;
  final String? brand;
  final Map<String, dynamic> extraJson;

  const StorageInfo({
    this.capacity,
    this.type,
    this.interface_,
    this.serialNumber,
    this.brand,
    this.extraJson = const {},
  });

  bool get isEmpty =>
      capacity == null &&
      type == null &&
      interface_ == null &&
      serialNumber == null &&
      brand == null &&
      extraJson.isEmpty;

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
      parts.add(
        '(${switch (interface_!) {
          StorageInterface.m2Nvme => 'M.2 NVMe',
          StorageInterface.sata25 => '2.5" SATA',
          StorageInterface.m2Sata => 'M.2 SATA',
          StorageInterface.usb => 'USB',
        }})',
      );
    }
    return parts.join(' ');
  }

  Map<String, dynamic> toJson() => {
    ...extraJson,
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
      extraJson: unknownJsonFields(map, _storageInfoJsonKeys),
    );
  }

  StorageInfo mergeUnknownFieldsFrom(StorageInfo other, {StorageInfo? base}) {
    return StorageInfo.fromJson({
      ...toJson(),
      ...mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    });
  }
}

/// A price entered in any currency and converted to the app default currency.
class MoneyValue {
  final double amount;
  final String currency;
  final String defaultCurrency;
  final double convertedAmount;
  final double exchangeRate;
  final bool autoRate;
  final DateTime? rateUpdatedAt;
  final Map<String, dynamic> extraJson;

  const MoneyValue({
    required this.amount,
    required this.currency,
    required this.defaultCurrency,
    required this.convertedAmount,
    required this.exchangeRate,
    required this.autoRate,
    this.rateUpdatedAt,
    this.extraJson = const {},
  });

  Map<String, dynamic> toJson() => {
    ...extraJson,
    'amount': amount,
    'currency': currency,
    'defaultCurrency': defaultCurrency,
    'convertedAmount': convertedAmount,
    'exchangeRate': exchangeRate,
    'autoRate': autoRate,
    if (rateUpdatedAt != null)
      'rateUpdatedAt': rateUpdatedAt!.toIso8601String(),
  };

  factory MoneyValue.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] as num).toDouble();
    final currency = json['currency'] as String;
    final defaultCurrency =
        json['defaultCurrency'] as String? ?? json['baseCurrency'] as String?;
    final exchangeRate = (json['exchangeRate'] as num?)?.toDouble() ?? 1.0;
    return MoneyValue(
      amount: amount,
      currency: currency,
      defaultCurrency: defaultCurrency ?? currency,
      convertedAmount:
          (json['convertedAmount'] as num?)?.toDouble() ??
          (amount * exchangeRate),
      exchangeRate: exchangeRate,
      autoRate: json['autoRate'] as bool? ?? true,
      rateUpdatedAt: json['rateUpdatedAt'] != null
          ? DateTime.parse(json['rateUpdatedAt'] as String)
          : null,
      extraJson: unknownJsonFields(json, _moneyValueJsonKeys),
    );
  }

  MoneyValue mergeUnknownFieldsFrom(MoneyValue other, {MoneyValue? base}) {
    return MoneyValue.fromJson({
      ...toJson(),
      ...mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    });
  }
}

/// A recurring lease, insurance, subscription, or other device cost.
class DeviceRecurringCost {
  final String id;
  final RecurringCostKind kind;
  final String? name;
  final MoneyValue price;
  final BillingCycle billingCycle;
  final Map<String, dynamic> extraJson;

  DeviceRecurringCost({
    String? id,
    required this.kind,
    this.name,
    required this.price,
    this.billingCycle = BillingCycle.monthly,
    this.extraJson = const {},
  }) : id = id ?? const Uuid().v4();

  double get annualConvertedAmount => switch (billingCycle) {
    BillingCycle.monthly => price.convertedAmount * 12,
    BillingCycle.yearly => price.convertedAmount,
  };

  double get dailyConvertedAmount => annualConvertedAmount / 365;

  Map<String, dynamic> toJson() => {
    ...extraJson,
    'id': id,
    'kind': kind.jsonValue,
    if (name != null) 'name': name,
    'price': price.toJson(),
    'billingCycle': billingCycle.jsonValue,
  };

  factory DeviceRecurringCost.fromJson(Map<String, dynamic> json) =>
      DeviceRecurringCost(
        id: json['id'] as String?,
        kind: RecurringCostKind.fromJson(json['kind'] as String?),
        name: json['name'] as String?,
        price: MoneyValue.fromJson(json['price'] as Map<String, dynamic>),
        billingCycle: BillingCycle.fromJson(json['billingCycle'] as String?),
        extraJson: unknownJsonFields(json, _recurringCostJsonKeys),
      );

  DeviceRecurringCost mergeUnknownFieldsFrom(
    DeviceRecurringCost other, {
    DeviceRecurringCost? base,
  }) {
    final json = toJson();
    json.addAll(
      mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    );
    json['price'] = price
        .mergeUnknownFieldsFrom(other.price, base: base?.price)
        .toJson();
    return DeviceRecurringCost.fromJson(json);
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
  final DeviceAcquisitionType? acquisitionType;
  final bool isRetired;
  final DateTime? retiredDate;
  final MoneyValue? purchasePrice;
  final bool isSold;
  final MoneyValue? soldPrice;
  final List<DeviceRecurringCost> recurringCosts;
  final String? notes;
  final DateTime modifiedAt;
  final Map<String, dynamic> extraJson;

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
    this.acquisitionType,
    this.isRetired = false,
    this.retiredDate,
    this.purchasePrice,
    this.isSold = false,
    this.soldPrice,
    this.recurringCosts = const [],
    this.notes,
    DateTime? modifiedAt,
    this.extraJson = const {},
  }) : id = id ?? const Uuid().v4(),
       modifiedAt = modifiedAt ?? DateTime.now();

  DeviceLifecycleStatus get lifecycleStatus {
    if (isSold) return DeviceLifecycleStatus.sold;
    if (isRetired) return DeviceLifecycleStatus.retired;
    return DeviceLifecycleStatus.inService;
  }

  bool get isInService => lifecycleStatus == DeviceLifecycleStatus.inService;

  bool get hasFinancialData =>
      purchasePrice != null || soldPrice != null || recurringCosts.isNotEmpty;

  int? serviceDays({DateTime? asOf}) {
    if (purchaseDate == null) return null;
    final now = asOf ?? DateTime.now();
    final end = isInService ? now : (retiredDate ?? now);
    return max(1, end.difference(purchaseDate!).inDays + 1);
  }

  double recurringCostThrough({DateTime? asOf}) {
    final days = serviceDays(asOf: asOf);
    if (days == null) return 0;
    return recurringCosts.fold<double>(
      0,
      (sum, cost) => sum + cost.dailyConvertedAmount * days,
    );
  }

  double totalCost({DateTime? asOf}) {
    return (purchasePrice?.convertedAmount ?? 0) +
        recurringCostThrough(asOf: asOf) -
        (soldPrice?.convertedAmount ?? 0);
  }

  double? averageDailyCost({DateTime? asOf}) {
    final days = serviceDays(asOf: asOf);
    if (days == null || !hasFinancialData) return null;
    return totalCost(asOf: asOf) / days;
  }

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
    final cleaned = s
        .replaceAll(RegExp(r'''["\x27''寸inchs]+$''', caseSensitive: false), '')
        .trim();
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
    DeviceAcquisitionType? acquisitionType,
    bool? isRetired,
    DateTime? retiredDate,
    MoneyValue? purchasePrice,
    bool? isSold,
    MoneyValue? soldPrice,
    List<DeviceRecurringCost>? recurringCosts,
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
    bool clearAcquisitionType = false,
    bool clearRetiredDate = false,
    bool clearPurchasePrice = false,
    bool clearSoldPrice = false,
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
      serialNumber: clearSerialNumber
          ? null
          : (serialNumber ?? this.serialNumber),
      cpu: cpu ?? this.cpu,
      gpu: gpu ?? this.gpu,
      ram: clearRam ? null : (ram ?? this.ram),
      ramType: clearRamType ? null : (ramType ?? this.ramType),
      storage: storage ?? this.storage,
      screenSize: clearScreenSize ? null : (screenSize ?? this.screenSize),
      screenResolutionW: clearScreenResolutionW
          ? null
          : (screenResolutionW ?? this.screenResolutionW),
      screenResolutionH: clearScreenResolutionH
          ? null
          : (screenResolutionH ?? this.screenResolutionH),
      battery: clearBattery ? null : (battery ?? this.battery),
      os: clearOs ? null : (os ?? this.os),
      locationName: clearLocationName
          ? null
          : (locationName ?? this.locationName),
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      purchaseDate: clearPurchaseDate
          ? null
          : (purchaseDate ?? this.purchaseDate),
      releaseDate: clearReleaseDate ? null : (releaseDate ?? this.releaseDate),
      acquisitionType: clearAcquisitionType
          ? null
          : (acquisitionType ?? this.acquisitionType),
      isRetired: isRetired ?? this.isRetired,
      retiredDate: clearRetiredDate ? null : (retiredDate ?? this.retiredDate),
      purchasePrice: clearPurchasePrice
          ? null
          : (purchasePrice ?? this.purchasePrice),
      isSold: isSold ?? this.isSold,
      soldPrice: clearSoldPrice ? null : (soldPrice ?? this.soldPrice),
      recurringCosts: recurringCosts ?? this.recurringCosts,
      notes: clearNotes ? null : (notes ?? this.notes),
      modifiedAt: modifiedAt ?? DateTime.now(),
      extraJson: extraJson,
    );
  }

  Map<String, dynamic> toJson() => {
    ...extraJson,
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
    if (storage.isNotEmpty) 'storage': storage.map((s) => s.toJson()).toList(),
    if (screenSize != null) 'screenSize': screenSize,
    if (screenResolutionW != null) 'screenResolutionW': screenResolutionW,
    if (screenResolutionH != null) 'screenResolutionH': screenResolutionH,
    if (battery != null) 'battery': battery,
    if (os != null) 'os': os,
    if (locationName != null) 'locationName': locationName,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (purchaseDate != null) 'purchaseDate': purchaseDate!.toIso8601String(),
    if (releaseDate != null) 'releaseDate': releaseDate!.toIso8601String(),
    if (acquisitionType != null) 'acquisitionType': acquisitionType!.jsonValue,
    if (isRetired) 'isRetired': isRetired,
    if (retiredDate != null) 'retiredDate': retiredDate!.toIso8601String(),
    if (purchasePrice != null) 'purchasePrice': purchasePrice!.toJson(),
    if (isSold) 'isSold': isSold,
    if (soldPrice != null) 'soldPrice': soldPrice!.toJson(),
    if (recurringCosts.isNotEmpty)
      'recurringCosts': recurringCosts.map((c) => c.toJson()).toList(),
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
    acquisitionType: DeviceAcquisitionType.fromJson(
      json['acquisitionType'] as String?,
    ),
    isRetired: json['isRetired'] as bool? ?? false,
    retiredDate: json['retiredDate'] != null
        ? DateTime.parse(json['retiredDate'] as String)
        : null,
    purchasePrice: json['purchasePrice'] != null
        ? MoneyValue.fromJson(json['purchasePrice'] as Map<String, dynamic>)
        : null,
    isSold: json['isSold'] as bool? ?? false,
    soldPrice: json['soldPrice'] != null
        ? MoneyValue.fromJson(json['soldPrice'] as Map<String, dynamic>)
        : null,
    recurringCosts: json['recurringCosts'] != null
        ? (json['recurringCosts'] as List<dynamic>)
              .map(
                (e) => DeviceRecurringCost.fromJson(e as Map<String, dynamic>),
              )
              .toList()
        : const [],
    notes: json['notes'] as String?,
    modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    extraJson: unknownJsonFields(json, _deviceJsonKeys),
  );

  Device mergeUnknownFieldsFrom(Device other, {Device? base}) {
    final json = toJson();
    json.addAll(
      mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    );

    final mergedCpu = cpu.mergeUnknownFieldsFrom(other.cpu, base: base?.cpu);
    if (mergedCpu.isEmpty) {
      json.remove('cpu');
    } else {
      json['cpu'] = mergedCpu.toJson();
    }

    final mergedGpu = gpu.mergeUnknownFieldsFrom(other.gpu, base: base?.gpu);
    if (mergedGpu.isEmpty) {
      json.remove('gpu');
    } else {
      json['gpu'] = mergedGpu.toJson();
    }

    if (storage.isNotEmpty) {
      json['storage'] = [
        for (var i = 0; i < storage.length; i++)
          storage[i]
              .mergeUnknownFieldsFrom(
                i < other.storage.length
                    ? other.storage[i]
                    : const StorageInfo(),
                base: base != null && i < base.storage.length
                    ? base.storage[i]
                    : null,
              )
              .toJson(),
      ];
    }

    if (purchasePrice != null && other.purchasePrice != null) {
      json['purchasePrice'] = purchasePrice!
          .mergeUnknownFieldsFrom(
            other.purchasePrice!,
            base: base?.purchasePrice,
          )
          .toJson();
    }
    if (soldPrice != null && other.soldPrice != null) {
      json['soldPrice'] = soldPrice!
          .mergeUnknownFieldsFrom(other.soldPrice!, base: base?.soldPrice)
          .toJson();
    }
    if (recurringCosts.isNotEmpty) {
      json['recurringCosts'] = [
        for (var i = 0; i < recurringCosts.length; i++)
          recurringCosts[i]
              .mergeUnknownFieldsFrom(
                i < other.recurringCosts.length
                    ? other.recurringCosts[i]
                    : recurringCosts[i],
                base: base != null && i < base.recurringCosts.length
                    ? base.recurringCosts[i]
                    : null,
              )
              .toJson(),
      ];
    }

    return Device.fromJson(json);
  }
}

/// Top-level data container persisted to disk.
class DeviceData {
  final List<Device> devices;
  final Map<String, dynamic> extraJson;

  const DeviceData({this.devices = const [], this.extraJson = const {}});

  Map<String, dynamic> toJson() => {
    ...extraJson,
    'devices': devices.map((d) => d.toJson()).toList(),
  };

  factory DeviceData.fromJson(Map<String, dynamic> json) => DeviceData(
    devices:
        (json['devices'] as List<dynamic>?)
            ?.map((e) => Device.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    extraJson: unknownJsonFields(json, _deviceDataJsonKeys),
  );
}
