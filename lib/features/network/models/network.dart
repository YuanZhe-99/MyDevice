import 'package:uuid/uuid.dart';

import '../../../shared/utils/json_preservation.dart';

const _networkJsonKeys = {
  'id',
  'name',
  'type',
  'subnet',
  'gateway',
  'dnsServers',
  'notes',
  'modifiedAt',
};

const _networkDeviceJsonKeys = {
  'networkId',
  'deviceId',
  'addressMode',
  'ipAddress',
  'hostname',
  'isExitNode',
};

const _networkDataJsonKeys = {'networks', 'assignments'};

/// Type of network.
enum NetworkType {
  lan,
  tailscale,
  zerotier,
  easytier,
  wireguard,
  other;

  /// Purpose: Return the serialized enum value used in JSON data.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  String get jsonValue => name;

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: None.
  /// Returns: The parsed model instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  static NetworkType fromJson(String value) => NetworkType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => NetworkType.other,
  );
}

/// How a device obtains its IP address on a network.
enum AddressMode {
  dhcp,
  static_;

  /// Purpose: Return the serialized enum value used in JSON data.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  String get jsonValue => switch (this) {
    AddressMode.dhcp => 'dhcp',
    AddressMode.static_ => 'static',
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: None.
  /// Returns: The parsed model instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  static AddressMode fromJson(String value) => switch (value) {
    'static' => AddressMode.static_,
    _ => AddressMode.dhcp,
  };
}

/// A network (LAN, VPN overlay, etc.).
class Network {
  final String id;
  final String name;
  final NetworkType type;
  final String? subnet;
  final String? gateway;
  final List<String> dnsServers;
  final String? notes;
  final DateTime modifiedAt;
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a network instance.
  /// Inputs: `dnsServers`.
  /// Returns: A new `Network` instance.
  /// Side effects: None.
  /// Notes: None.
  Network({
    String? id,
    required this.name,
    required this.type,
    this.subnet,
    this.gateway,
    this.dnsServers = const [],
    this.notes,
    DateTime? modifiedAt,
    this.extraJson = const {},
  }) : id = id ?? const Uuid().v4(),
       modifiedAt = modifiedAt ?? DateTime.now();

  /// Purpose: Create a copy with selected fields replaced.
  /// Inputs: `clearSubnet`.
  /// Returns: `Network`.
  /// Side effects: None.
  /// Notes: None.
  Network copyWith({
    String? name,
    NetworkType? type,
    String? subnet,
    String? gateway,
    List<String>? dnsServers,
    String? notes,
    DateTime? modifiedAt,
    bool clearSubnet = false,
    bool clearGateway = false,
    bool clearNotes = false,
  }) {
    return Network(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      subnet: clearSubnet ? null : (subnet ?? this.subnet),
      gateway: clearGateway ? null : (gateway ?? this.gateway),
      dnsServers: dnsServers ?? this.dnsServers,
      notes: clearNotes ? null : (notes ?? this.notes),
      modifiedAt: modifiedAt ?? DateTime.now(),
      extraJson: extraJson,
    );
  }

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'id': id,
    'name': name,
    'type': type.jsonValue,
    if (subnet != null) 'subnet': subnet,
    if (gateway != null) 'gateway': gateway,
    if (dnsServers.isNotEmpty) 'dnsServers': dnsServers,
    if (notes != null) 'notes': notes,
    'modifiedAt': modifiedAt.toIso8601String(),
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A new `Network.fromJson` instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  factory Network.fromJson(Map<String, dynamic> json) => Network(
    id: json['id'] as String,
    name: json['name'] as String,
    type: NetworkType.fromJson(json['type'] as String),
    subnet: json['subnet'] as String?,
    gateway: json['gateway'] as String?,
    dnsServers: json['dnsServers'] != null
        ? (json['dnsServers'] as List<dynamic>).map((e) => e as String).toList()
        : const [],
    notes: json['notes'] as String?,
    modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    extraJson: unknownJsonFields(json, _networkJsonKeys),
  );

  /// Purpose: Merge preserved unknown JSON fields from another instance.
  /// Inputs: `other`.
  /// Returns: `Network`.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  Network mergeUnknownFieldsFrom(Network other, {Network? base}) {
    return Network.fromJson({
      ...toJson(),
      ...mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    });
  }
}

/// A device's membership in a network.
class NetworkDevice {
  final String networkId;
  final String deviceId;
  final AddressMode addressMode;
  final String? ipAddress;
  final String? hostname;
  final bool isExitNode;
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a network device instance.
  /// Inputs: `addressMode`.
  /// Returns: A new `NetworkDevice` instance.
  /// Side effects: None.
  /// Notes: None.
  const NetworkDevice({
    required this.networkId,
    required this.deviceId,
    this.addressMode = AddressMode.dhcp,
    this.ipAddress,
    this.hostname,
    this.isExitNode = false,
    this.extraJson = const {},
  });

  /// Purpose: Create a copy with selected fields replaced.
  /// Inputs: `clearIpAddress`.
  /// Returns: `NetworkDevice`.
  /// Side effects: None.
  /// Notes: None.
  NetworkDevice copyWith({
    AddressMode? addressMode,
    String? ipAddress,
    String? hostname,
    bool? isExitNode,
    bool clearIpAddress = false,
    bool clearHostname = false,
  }) {
    return NetworkDevice(
      networkId: networkId,
      deviceId: deviceId,
      addressMode: addressMode ?? this.addressMode,
      ipAddress: clearIpAddress ? null : (ipAddress ?? this.ipAddress),
      hostname: clearHostname ? null : (hostname ?? this.hostname),
      isExitNode: isExitNode ?? this.isExitNode,
      extraJson: extraJson,
    );
  }

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'networkId': networkId,
    'deviceId': deviceId,
    'addressMode': addressMode.jsonValue,
    if (ipAddress != null) 'ipAddress': ipAddress,
    if (hostname != null) 'hostname': hostname,
    if (isExitNode) 'isExitNode': true,
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A new `NetworkDevice.fromJson` instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  factory NetworkDevice.fromJson(Map<String, dynamic> json) => NetworkDevice(
    networkId: json['networkId'] as String,
    deviceId: json['deviceId'] as String,
    addressMode: AddressMode.fromJson(json['addressMode'] as String? ?? 'dhcp'),
    ipAddress: json['ipAddress'] as String?,
    hostname: json['hostname'] as String?,
    isExitNode: json['isExitNode'] as bool? ?? false,
    extraJson: unknownJsonFields(json, _networkDeviceJsonKeys),
  );

  /// Purpose: Merge preserved unknown JSON fields from another instance.
  /// Inputs: `other`.
  /// Returns: `NetworkDevice`.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  NetworkDevice mergeUnknownFieldsFrom(
    NetworkDevice other, {
    NetworkDevice? base,
  }) {
    return NetworkDevice.fromJson({
      ...toJson(),
      ...mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    });
  }
}

/// Top-level data container for network persistence.
class NetworkData {
  final List<Network> networks;
  final List<NetworkDevice> assignments;
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a network data instance.
  /// Inputs: `networks`.
  /// Returns: A new `NetworkData` instance.
  /// Side effects: None.
  /// Notes: None.
  const NetworkData({
    this.networks = const [],
    this.assignments = const [],
    this.extraJson = const {},
  });

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'networks': networks.map((n) => n.toJson()).toList(),
    'assignments': assignments.map((a) => a.toJson()).toList(),
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A new `NetworkData.fromJson` instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  factory NetworkData.fromJson(Map<String, dynamic> json) => NetworkData(
    networks: (json['networks'] as List<dynamic>? ?? [])
        .map((e) => Network.fromJson(e as Map<String, dynamic>))
        .toList(),
    assignments: (json['assignments'] as List<dynamic>? ?? [])
        .map((e) => NetworkDevice.fromJson(e as Map<String, dynamic>))
        .toList(),
    extraJson: unknownJsonFields(json, _networkDataJsonKeys),
  );
}
