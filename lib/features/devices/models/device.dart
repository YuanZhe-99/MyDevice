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
  'status',
  'statusNote',
};

const _storageArrayJsonKeys = {'id', 'name', 'level', 'memberIndices'};

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
  'templateImage',
  'brand',
  'model',
  'serialNumber',
  'cpu',
  'gpu',
  'ram',
  'ramType',
  'storage',
  'storageArrays',
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

  /// Purpose: Return the serialized enum value used in JSON data.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  String get jsonValue => name;

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `value`.
  /// Returns: The parsed model instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  static DeviceCategory fromJson(String value) => DeviceCategory.values
      .firstWhere((e) => e.name == value, orElse: () => DeviceCategory.other);
}

/// How a device is financially acquired or paid for.
enum DeviceAcquisitionType {
  purchased,
  leased,
  purchasedWithSubscription,
  other;

  /// Purpose: Return the serialized enum value used in JSON data.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  String get jsonValue => name;

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `value`.
  /// Returns: The parsed model instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
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

  /// Purpose: Return the serialized enum value used in JSON data.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  String get jsonValue => name;

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `value`.
  /// Returns: The parsed model instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  static RecurringCostKind fromJson(String? value) =>
      RecurringCostKind.values.where((e) => e.name == value).firstOrNull ??
      RecurringCostKind.other;
}

/// Billing cadence for recurring device costs.
enum BillingCycle {
  monthly,
  yearly;

  /// Purpose: Return the serialized enum value used in JSON data.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  String get jsonValue => name;

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `value`.
  /// Returns: The parsed model instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
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

  /// Purpose: Create a cpu info instance.
  /// Inputs: `extraJson`.
  /// Returns: A new `CpuInfo` instance.
  /// Side effects: None.
  /// Notes: None.
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

  /// Purpose: Return whether empty is true.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isEmpty =>
      model == null &&
      architecture == null &&
      frequency == null &&
      performanceCores == null &&
      efficiencyCores == null &&
      threads == null &&
      cache == null &&
      extraJson.isEmpty;

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
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

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A new `CpuInfo.fromJson` instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
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

  /// Purpose: Merge preserved unknown JSON fields from another instance.
  /// Inputs: `other`.
  /// Returns: `CpuInfo`.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
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

  /// Purpose: Create a gpu info instance.
  /// Inputs: `extraJson`.
  /// Returns: A new `GpuInfo` instance.
  /// Side effects: None.
  /// Notes: None.
  const GpuInfo({this.model, this.architecture, this.extraJson = const {}});

  /// Purpose: Return whether empty is true.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isEmpty =>
      model == null && architecture == null && extraJson.isEmpty;

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    if (model != null) 'model': model,
    if (architecture != null) 'architecture': architecture,
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A new `GpuInfo.fromJson` instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  factory GpuInfo.fromJson(Map<String, dynamic> json) => GpuInfo(
    model: json['model'] as String?,
    architecture: json['architecture'] as String?,
    extraJson: unknownJsonFields(json, _gpuInfoJsonKeys),
  );

  /// Purpose: Merge preserved unknown JSON fields from another instance.
  /// Inputs: `other`.
  /// Returns: `GpuInfo`.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
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

  /// Purpose: Return the serialized enum value used in JSON data.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  String get jsonValue => name;

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `value`.
  /// Returns: The parsed model instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
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

  /// Purpose: Return the serialized enum value used in JSON data.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  String get jsonValue => name;

  /// Purpose: Return the current display name value.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
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

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `value`.
  /// Returns: The parsed model instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
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

  /// Purpose: Return the serialized enum value used in JSON data.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  String get jsonValue => name;

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `value`.
  /// Returns: The parsed model instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  static StorageInterface? fromJson(String? value) {
    if (value == null) return null;
    return StorageInterface.values.where((e) => e.name == value).firstOrNull;
  }
}

/// Whether a storage device is working. A failed or offline drive is kept
/// in the inventory but holds no usable data.
enum StorageHealth {
  ok,
  failed,
  offline;

  /// Purpose: Return the serialized enum value used in JSON data.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: `ok` is never written; an absent `status` means `ok`.
  String get jsonValue => name;

  /// Purpose: Parse a stored health value.
  /// Inputs: `value`.
  /// Returns: The health; `ok` for null or an unknown value.
  /// Side effects: None.
  /// Notes: `StorageInfo.fromJson` keeps an unknown value from a newer build
  /// in `extraJson`, so it survives a save.
  static StorageHealth fromJson(String? value) =>
      StorageHealth.values.where((e) => e.name == value).firstOrNull ?? ok;
}

/// RAID level (or pooling scheme) of a storage array.
enum RaidLevel {
  raid0,
  raid1,
  raid5,
  raid6,
  raid10,
  raidz1,
  raidz2,
  raidz3,
  jbod,
  other;

  /// Purpose: Return the serialized enum value used in JSON data.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  String get jsonValue => name;

  /// Purpose: Return the level as it is usually written.
  /// Inputs: None.
  /// Returns: E.g. `RAID 5`, `RAID-Z2`, `JBOD`; `RAID` for `other`.
  /// Side effects: None.
  /// Notes: Not localized; these are technical names.
  String get displayName => switch (this) {
    RaidLevel.raid0 => 'RAID 0',
    RaidLevel.raid1 => 'RAID 1',
    RaidLevel.raid5 => 'RAID 5',
    RaidLevel.raid6 => 'RAID 6',
    RaidLevel.raid10 => 'RAID 10',
    RaidLevel.raidz1 => 'RAID-Z1',
    RaidLevel.raidz2 => 'RAID-Z2',
    RaidLevel.raidz3 => 'RAID-Z3',
    RaidLevel.jbod => 'JBOD',
    RaidLevel.other => 'RAID',
  };

  /// Purpose: Return how many member drives may fail without losing data.
  /// Inputs: `members` — the array's member count.
  /// Returns: The tolerance, or null when the level does not define one
  /// (`other`).
  /// Side effects: None.
  /// Notes: RAID 10 is counted conservatively as tolerating one failure —
  /// two in the same mirror pair lose data.
  int? faultTolerance(int members) => switch (this) {
    RaidLevel.raid0 || RaidLevel.jbod => 0,
    RaidLevel.raid1 => members - 1,
    RaidLevel.raid5 || RaidLevel.raidz1 || RaidLevel.raid10 => 1,
    RaidLevel.raid6 || RaidLevel.raidz2 => 2,
    RaidLevel.raidz3 => 3,
    RaidLevel.other => null,
  };

  /// Purpose: Parse a stored level.
  /// Inputs: `value`.
  /// Returns: The level; `other` for null or an unknown value.
  /// Side effects: None.
  /// Notes: None.
  static RaidLevel fromJson(String? value) =>
      RaidLevel.values.where((e) => e.name == value).firstOrNull ?? other;
}

/// Storage device information.
class StorageInfo {
  final String? capacity; // e.g. "512 GB"
  final StorageType? type;
  final StorageInterface? interface_;
  final String? serialNumber;
  final String? brand;

  /// Whether the drive works; failed and offline drives stay listed.
  final StorageHealth status;

  /// Free text about a failure, e.g. when it went offline.
  final String? statusNote;
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a storage info instance.
  /// Inputs: `status` — defaults to `ok`; `statusNote`; `extraJson`.
  /// Returns: A new `StorageInfo` instance.
  /// Side effects: None.
  /// Notes: None.
  const StorageInfo({
    this.capacity,
    this.type,
    this.interface_,
    this.serialNumber,
    this.brand,
    this.status = StorageHealth.ok,
    this.statusNote,
    this.extraJson = const {},
  });

  /// Purpose: Tell whether the drive is working.
  /// Inputs: None.
  /// Returns: True when `status` is `ok`.
  /// Side effects: None.
  /// Notes: None.
  bool get isHealthy => status == StorageHealth.ok;

  /// Purpose: Return whether empty is true.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isEmpty =>
      capacity == null &&
      type == null &&
      interface_ == null &&
      serialNumber == null &&
      brand == null &&
      status == StorageHealth.ok &&
      statusNote == null &&
      extraJson.isEmpty;

  /// Purpose: Return the current display string value.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
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

  /// Purpose: Serialize this storage entry into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map; unset fields are omitted.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    if (capacity != null) 'capacity': capacity,
    if (type != null) 'type': type!.jsonValue,
    if (interface_ != null) 'interface': interface_!.jsonValue,
    if (serialNumber != null) 'serialNumber': serialNumber,
    if (brand != null) 'brand': brand,
    if (status != StorageHealth.ok) 'status': status.jsonValue,
    if (statusNote != null) 'statusNote': statusNote,
  };

  /// Purpose: Create an instance from a JSON value, including the legacy string
  /// shape.
  /// Inputs: `json` — a map, or a plain capacity string such as "512 GB".
  /// Returns: A new `StorageInfo`.
  /// Side effects: None.
  /// Notes: A legacy string becomes `StorageInfo(capacity: json)`; unknown map
  /// keys go to `extraJson`. A missing `status` means `ok`.
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
      status: StorageHealth.fromJson(map['status'] as String?),
      statusNote: map['statusNote'] as String?,
      extraJson: {
        ...unknownJsonFields(map, _storageInfoJsonKeys),
        // A status this build does not know reads as ok but is written back.
        if (map['status'] is String &&
            !StorageHealth.values.any((e) => e.name == map['status']))
          'status': map['status'],
      },
    );
  }

  /// Purpose: Merge preserved unknown JSON fields from another instance.
  /// Inputs: `other`; optional `base` for the three-way merge.
  /// Returns: `StorageInfo`.
  /// Side effects: None.
  /// Notes: Known fields always come from `this`; only `extraJson` is merged.
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

/// A RAID array (or pool) built from some of a device's storage slots. Data
/// on it is one copy, however many drives it spans.
class StorageArray {
  final String id;
  final String name;
  final RaidLevel level;

  /// Indices into the device's `storage` list.
  final List<int> memberIndices;
  final Map<String, dynamic> extraJson;

  /// Purpose: Create an array.
  /// Inputs: `id` — generated when absent; `name` — may be empty; `level`;
  /// `memberIndices`; `extraJson`.
  /// Returns: A new `StorageArray`.
  /// Side effects: None.
  /// Notes: Data sets reference arrays by `id`, so it must stay stable.
  StorageArray({
    String? id,
    this.name = '',
    this.level = RaidLevel.other,
    this.memberIndices = const [],
    this.extraJson = const {},
  }) : id = id ?? const Uuid().v4();

  /// Purpose: Name the array for display.
  /// Inputs: None.
  /// Returns: `<level> · <name>`, or just the level when unnamed.
  /// Side effects: None.
  /// Notes: None.
  String get displayString =>
      name.isEmpty ? level.displayName : '${level.displayName} · $name';

  /// Purpose: Serialize this array into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'id': id,
    if (name.isNotEmpty) 'name': name,
    'level': level.jsonValue,
    'memberIndices': memberIndices,
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `StorageArray`.
  /// Side effects: None.
  /// Notes: Unknown keys go to `extraJson`.
  factory StorageArray.fromJson(Map<String, dynamic> json) => StorageArray(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    level: RaidLevel.fromJson(json['level'] as String?),
    memberIndices:
        (json['memberIndices'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        const [],
    extraJson: unknownJsonFields(json, _storageArrayJsonKeys),
  );

  /// Purpose: Merge preserved unknown JSON fields from another instance.
  /// Inputs: `other`; optional `base` for the three-way merge.
  /// Returns: `StorageArray`.
  /// Side effects: None.
  /// Notes: Known fields always come from `this`.
  StorageArray mergeUnknownFieldsFrom(
    StorageArray other, {
    StorageArray? base,
  }) {
    return StorageArray.fromJson({
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

  /// Purpose: Create a money value instance.
  /// Inputs: The entered `amount` and `currency`, the app `defaultCurrency`,
  /// `convertedAmount`, `exchangeRate`, `autoRate`, optional `rateUpdatedAt`.
  /// Returns: A new `MoneyValue` instance.
  /// Side effects: None.
  /// Notes: None.
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

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
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

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `MoneyValue`.
  /// Side effects: None.
  /// Notes: Accepts the legacy `baseCurrency` key; a missing `convertedAmount`
  /// is derived from `amount * exchangeRate`, and `autoRate` defaults to true.
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

  /// Purpose: Merge preserved unknown JSON fields from another instance.
  /// Inputs: `other`; optional `base` for the three-way merge.
  /// Returns: `MoneyValue`.
  /// Side effects: None.
  /// Notes: Known fields always come from `this`; only `extraJson` is merged.
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

  /// Purpose: Create a recurring cost instance.
  /// Inputs: `kind`, `price` required; optional `id`, `name`, `billingCycle`
  /// (monthly by default).
  /// Returns: A new `DeviceRecurringCost` instance.
  /// Side effects: None.
  /// Notes: A fresh UUID `id` is generated when none is supplied.
  DeviceRecurringCost({
    String? id,
    required this.kind,
    this.name,
    required this.price,
    this.billingCycle = BillingCycle.monthly,
    this.extraJson = const {},
  }) : id = id ?? const Uuid().v4();

  /// Purpose: Project this cost to a yearly amount in the default currency.
  /// Inputs: None.
  /// Returns: The converted price times 12 for monthly, or as is for yearly.
  /// Side effects: None.
  /// Notes: None.
  double get annualConvertedAmount => switch (billingCycle) {
    BillingCycle.monthly => price.convertedAmount * 12,
    BillingCycle.yearly => price.convertedAmount,
  };

  /// Purpose: Spread the yearly converted amount over one day.
  /// Inputs: None.
  /// Returns: `annualConvertedAmount / 365`.
  /// Side effects: None.
  /// Notes: None.
  double get dailyConvertedAmount => annualConvertedAmount / 365;

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'id': id,
    'kind': kind.jsonValue,
    if (name != null) 'name': name,
    'price': price.toJson(),
    'billingCycle': billingCycle.jsonValue,
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `DeviceRecurringCost`.
  /// Side effects: None.
  /// Notes: Unknown keys go to `extraJson`.
  factory DeviceRecurringCost.fromJson(Map<String, dynamic> json) =>
      DeviceRecurringCost(
        id: json['id'] as String?,
        kind: RecurringCostKind.fromJson(json['kind'] as String?),
        name: json['name'] as String?,
        price: MoneyValue.fromJson(json['price'] as Map<String, dynamic>),
        billingCycle: BillingCycle.fromJson(json['billingCycle'] as String?),
        extraJson: unknownJsonFields(json, _recurringCostJsonKeys),
      );

  /// Purpose: Merge preserved unknown JSON fields, including the nested
  /// `price`.
  /// Inputs: `other`; optional `base` for the three-way merge.
  /// Returns: `DeviceRecurringCost`.
  /// Side effects: None.
  /// Notes: Known fields always come from `this`.
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

  /// Bundled thumbnail the user chose by hand (an asset path as
  /// `DeviceTemplate.image` stores it). Wins over automatic matching.
  final String? templateImage;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final CpuInfo cpu;
  final GpuInfo gpu;
  final String? ram;
  final RamType? ramType;
  final List<StorageInfo> storage;

  /// RAID arrays built from slots of `storage`.
  final List<StorageArray> storageArrays;
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

  /// Purpose: Create a device instance.
  /// Inputs: `name`, `category` required; every other field optional.
  /// Returns: A new `Device` instance.
  /// Side effects: None.
  /// Notes: A fresh UUID `id` and UTC `modifiedAt` are generated when not
  /// supplied, so every save through this constructor bumps the sync timestamp.
  Device({
    String? id,
    required this.name,
    required this.category,
    this.emoji,
    this.imagePath,
    this.templateImage,
    this.brand,
    this.model,
    this.serialNumber,
    this.cpu = const CpuInfo(),
    this.gpu = const GpuInfo(),
    this.ram,
    this.ramType,
    this.storage = const [],
    this.storageArrays = const [],
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
       modifiedAt = modifiedAt ?? DateTime.now().toUtc();

  /// Purpose: Derive the lifecycle bucket from the sold/retired flags.
  /// Inputs: None.
  /// Returns: `sold`, `retired` or `inService`.
  /// Side effects: None.
  /// Notes: Sold wins when both flags are set; the model does not make them
  /// exclusive.
  DeviceLifecycleStatus get lifecycleStatus {
    if (isSold) return DeviceLifecycleStatus.sold;
    if (isRetired) return DeviceLifecycleStatus.retired;
    return DeviceLifecycleStatus.inService;
  }

  /// Purpose: Tell whether the device is still in service.
  /// Inputs: None.
  /// Returns: True when `lifecycleStatus` is `inService`.
  /// Side effects: None.
  /// Notes: None.
  bool get isInService => lifecycleStatus == DeviceLifecycleStatus.inService;

  /// Purpose: Tell whether any financial data is recorded.
  /// Inputs: None.
  /// Returns: True when a purchase price, sold price or recurring cost exists.
  /// Side effects: None.
  /// Notes: Guards `averageDailyCost` so a device without data reports null,
  /// not 0.
  bool get hasFinancialData =>
      purchasePrice != null || soldPrice != null || recurringCosts.isNotEmpty;

  /// Purpose: Count the days the device has been, or was, in service.
  /// Inputs: `asOf` — replaces "now"; defaults to the current time.
  /// Returns: Days from `purchaseDate` to now or `retiredDate` (at least 1), or
  /// null without a purchase date.
  /// Side effects: None.
  /// Notes: A retired device without a `retiredDate` counts up to now.
  int? serviceDays({DateTime? asOf}) {
    if (purchaseDate == null) return null;
    final now = asOf ?? DateTime.now();
    final end = isInService ? now : (retiredDate ?? now);
    return max(1, end.difference(purchaseDate!).inDays + 1);
  }

  /// Purpose: Total the recurring costs across the service days.
  /// Inputs: `asOf`, forwarded to `serviceDays`.
  /// Returns: The accumulated converted amount, or 0 without a purchase date.
  /// Side effects: None.
  /// Notes: Every cost is charged for the whole service span; costs have no
  /// start date of their own.
  double recurringCostThrough({DateTime? asOf}) {
    final days = serviceDays(asOf: asOf);
    if (days == null) return 0;
    return recurringCosts.fold<double>(
      0,
      (sum, cost) => sum + cost.dailyConvertedAmount * days,
    );
  }

  /// Purpose: Compute the total cost of ownership.
  /// Inputs: `asOf`, forwarded to `recurringCostThrough`.
  /// Returns: Purchase price plus recurring costs minus sold price.
  /// Side effects: None.
  /// Notes: Not clamped; may be negative.
  double totalCost({DateTime? asOf}) {
    return (purchasePrice?.convertedAmount ?? 0) +
        recurringCostThrough(asOf: asOf) -
        (soldPrice?.convertedAmount ?? 0);
  }

  /// Purpose: Compute the average daily cost of ownership.
  /// Inputs: `asOf`, forwarded to `serviceDays` and `totalCost`.
  /// Returns: `totalCost / serviceDays`, or null without a purchase date or
  /// financial data.
  /// Side effects: None.
  /// Notes: None.
  double? averageDailyCost({DateTime? asOf}) {
    final days = serviceDays(asOf: asOf);
    if (days == null || !hasFinancialData) return null;
    return totalCost(asOf: asOf) / days;
  }

  /// Purpose: Compute pixels per inch from resolution and screen size.
  /// Inputs: None.
  /// Returns: The PPI, or null when resolution or a parseable diagonal is
  /// missing.
  /// Side effects: None.
  /// Notes: None.
  /// Compute PPI from resolution and screen diagonal (inches).
  double? get ppi {
    if (screenResolutionW == null || screenResolutionH == null) return null;
    final diagonal = _parseScreenDiagonal(screenSize);
    if (diagonal == null || diagonal <= 0) return null;
    final w = screenResolutionW!.toDouble();
    final h = screenResolutionH!.toDouble();
    return sqrt(w * w + h * h) / diagonal;
  }

  /// Purpose: Parse a free-text screen size into inches.
  /// Inputs: `s`, e.g. `6.7"`, `15.6 inch`, `13寸`.
  /// Returns: The number of inches, or null when it does not parse.
  /// Side effects: None.
  /// Notes: Only a trailing unit suffix is stripped. Internal helper used
  /// within this file only.
  static double? _parseScreenDiagonal(String? s) {
    if (s == null || s.isEmpty) return null;
    // Remove common suffixes like " or inch / 寸 etc.
    final cleaned = s
        .replaceAll(RegExp(r'''["\x27''寸inchs]+$''', caseSensitive: false), '')
        .trim();
    return double.tryParse(cleaned);
  }

  /// Purpose: Create a copy with any subset of fields replaced or cleared.
  /// Inputs: One optional value per field, plus a `clearXxx` flag per nullable
  /// field (e.g. `clearImagePath`, `clearTemplateImage`).
  /// Returns: A new `Device` with the same `id`.
  /// Side effects: None.
  /// Notes: `extraJson` is copied unchanged; `modifiedAt` defaults to now in
  /// UTC.
  Device copyWith({
    String? name,
    DeviceCategory? category,
    String? emoji,
    String? imagePath,
    String? templateImage,
    String? brand,
    String? model,
    String? serialNumber,
    CpuInfo? cpu,
    GpuInfo? gpu,
    String? ram,
    RamType? ramType,
    List<StorageInfo>? storage,
    List<StorageArray>? storageArrays,
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
    bool clearTemplateImage = false,
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
      templateImage: clearTemplateImage
          ? null
          : (templateImage ?? this.templateImage),
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
      storageArrays: storageArrays ?? this.storageArrays,
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
      modifiedAt: modifiedAt ?? DateTime.now().toUtc(),
      extraJson: extraJson,
    );
  }

  /// Purpose: Serialize this device into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map; unset and default-false fields are
  /// omitted.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'id': id,
    'name': name,
    'category': category.jsonValue,
    if (emoji != null) 'emoji': emoji,
    if (imagePath != null) 'imagePath': imagePath,
    if (templateImage != null) 'templateImage': templateImage,
    if (brand != null) 'brand': brand,
    if (model != null) 'model': model,
    if (serialNumber != null) 'serialNumber': serialNumber,
    if (!cpu.isEmpty) 'cpu': cpu.toJson(),
    if (!gpu.isEmpty) 'gpu': gpu.toJson(),
    if (ram != null) 'ram': ram,
    if (ramType != null) 'ramType': ramType!.jsonValue,
    if (storage.isNotEmpty) 'storage': storage.map((s) => s.toJson()).toList(),
    if (storageArrays.isNotEmpty)
      'storageArrays': storageArrays.map((a) => a.toJson()).toList(),
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

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `Device`.
  /// Side effects: None.
  /// Notes: Accepts the legacy single-string `storage` shape; unknown keys go
  /// to `extraJson`.
  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: json['id'] as String,
    name: json['name'] as String,
    category: DeviceCategory.fromJson(json['category'] as String),
    emoji: json['emoji'] as String?,
    imagePath: json['imagePath'] as String?,
    templateImage: json['templateImage'] as String?,
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
    storageArrays:
        (json['storageArrays'] as List<dynamic>?)
            ?.map((e) => StorageArray.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
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

  /// Purpose: Merge preserved unknown JSON fields, including nested structures.
  /// Inputs: `other`; optional `base` for the three-way merge.
  /// Returns: `Device`.
  /// Side effects: None.
  /// Notes: Recurses into `cpu`, `gpu`, `storage`, `storageArrays` (by id),
  /// both prices and `recurringCosts` so no nested unknown field is lost.
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

    if (storageArrays.isNotEmpty) {
      final otherById = {for (final a in other.storageArrays) a.id: a};
      final baseById = {for (final a in base?.storageArrays ?? []) a.id: a};
      json['storageArrays'] = [
        for (final a in storageArrays)
          (otherById[a.id] == null
                  ? a
                  : a.mergeUnknownFieldsFrom(
                      otherById[a.id]!,
                      base: baseById[a.id],
                    ))
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

  /// Purpose: Create a device data instance.
  /// Inputs: `devices`.
  /// Returns: A new `DeviceData` instance.
  /// Side effects: None.
  /// Notes: None.
  const DeviceData({this.devices = const [], this.extraJson = const {}});

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'devices': devices.map((d) => d.toJson()).toList(),
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A new `DeviceData.fromJson` instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  factory DeviceData.fromJson(Map<String, dynamic> json) => DeviceData(
    devices:
        (json['devices'] as List<dynamic>?)
            ?.map((e) => Device.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    extraJson: unknownJsonFields(json, _deviceDataJsonKeys),
  );
}
