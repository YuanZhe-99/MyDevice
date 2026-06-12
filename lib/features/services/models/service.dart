import 'package:uuid/uuid.dart';

import '../../../shared/utils/json_preservation.dart';

const _serviceEndpointJsonKeys = {
  'id',
  'label',
  'protocol',
  'transport',
  'bindAddress',
  'port',
  'portEnd',
  'path',
  'networkId',
  'scope',
  'isPrimary',
  'notes',
};

const _serviceNodeJsonKeys = {
  'id',
  'deviceId',
  'name',
  'templateId',
  'icon',
  'kind',
  'runtime',
  'state',
  'endpoints',
  'tags',
  'notes',
  'dockerCompose',
  'modifiedAt',
};

const _serviceRouteHopJsonKeys = {
  'id',
  'type',
  'serviceId',
  'endpointId',
  'deviceId',
  'label',
  'scheme',
  'host',
  'port',
  'path',
  'method',
  'notes',
};

const _serviceRouteJsonKeys = {
  'id',
  'name',
  'sourceServiceId',
  'sourceEndpointId',
  'hops',
  'finalUrl',
  'accessLevel',
  'notes',
  'modifiedAt',
};

const _serviceDataJsonKeys = {'services', 'routes'};

enum ServiceKind {
  web,
  reverseProxy,
  tunnel,
  media,
  storage,
  git,
  dev,
  game,
  network,
  database,
  monitoring,
  ai,
  custom;

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
  static ServiceKind fromJson(String? value) =>
      ServiceKind.values.where((e) => e.name == value).firstOrNull ??
      ServiceKind.custom;
}

enum ServiceRuntime {
  docker,
  compose,
  native,
  systemd,
  launchd,
  routerApp,
  container,
  custom;

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
  static ServiceRuntime? fromJson(String? value) {
    if (value == null) return null;
    return ServiceRuntime.values.where((e) => e.name == value).firstOrNull;
  }
}

enum ServiceState {
  active,
  paused,
  deprecated,
  unknown;

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
  static ServiceState fromJson(String? value) =>
      ServiceState.values.where((e) => e.name == value).firstOrNull ??
      ServiceState.active;
}

enum ServiceProtocol {
  http,
  https,
  tcp,
  udp,
  ssh,
  minecraft,
  rtsp,
  vnc,
  custom;

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
  static ServiceProtocol fromJson(String? value) =>
      ServiceProtocol.values.where((e) => e.name == value).firstOrNull ??
      ServiceProtocol.custom;
}

enum ServiceTransport {
  tcp,
  udp,
  tcpUdp;

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
  static ServiceTransport fromJson(String? value) =>
      ServiceTransport.values.where((e) => e.name == value).firstOrNull ??
      ServiceTransport.tcp;
}

enum ServiceScope {
  localhost,
  lan,
  vpn,
  public,
  custom;

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
  static ServiceScope fromJson(String? value) =>
      ServiceScope.values.where((e) => e.name == value).firstOrNull ??
      ServiceScope.lan;
}

enum ServiceRouteHopType {
  origin,
  reverseProxy,
  tunnel,
  portForward,
  publicEndpoint,
  internalEndpoint,
  dns,
  manual;

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
  static ServiceRouteHopType fromJson(String? value) =>
      ServiceRouteHopType.values.where((e) => e.name == value).firstOrNull ??
      ServiceRouteHopType.manual;
}

enum ServiceRouteMethod {
  caddy,
  nginx,
  traefik,
  frp,
  cloudflareTunnel,
  pangolin,
  tailscaleFunnel,
  routerPortForward,
  direct,
  custom;

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
  static ServiceRouteMethod? fromJson(String? value) {
    if (value == null) return null;
    return ServiceRouteMethod.values.where((e) => e.name == value).firstOrNull;
  }
}

enum ServiceAccessLevel {
  lan,
  vpn,
  authenticated,
  public,
  custom;

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
  static ServiceAccessLevel fromJson(String? value) =>
      ServiceAccessLevel.values.where((e) => e.name == value).firstOrNull ??
      ServiceAccessLevel.lan;
}

class ServiceEndpoint {
  final String id;
  final String? label;
  final ServiceProtocol protocol;
  final ServiceTransport transport;
  final String? bindAddress;
  final int? port;
  final int? portEnd;
  final String? path;
  final String? networkId;
  final ServiceScope scope;
  final bool isPrimary;
  final String? notes;
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a service endpoint instance.
  /// Inputs: `protocol`.
  /// Returns: A new `ServiceEndpoint` instance.
  /// Side effects: None.
  /// Notes: None.
  ServiceEndpoint({
    String? id,
    this.label,
    this.protocol = ServiceProtocol.http,
    this.transport = ServiceTransport.tcp,
    this.bindAddress,
    this.port,
    this.portEnd,
    this.path,
    this.networkId,
    this.scope = ServiceScope.lan,
    this.isPrimary = false,
    this.notes,
    this.extraJson = const {},
  }) : id = id ?? const Uuid().v4();

  ServiceEndpoint copyWith({
    String? label,
    ServiceProtocol? protocol,
    ServiceTransport? transport,
    String? bindAddress,
    int? port,
    int? portEnd,
    String? path,
    String? networkId,
    ServiceScope? scope,
    bool? isPrimary,
    String? notes,
    bool clearLabel = false,
    bool clearBindAddress = false,
    bool clearPort = false,
    bool clearPortEnd = false,
    bool clearPath = false,
    bool clearNetworkId = false,
    bool clearNotes = false,
  }) {
    return ServiceEndpoint(
      id: id,
      label: clearLabel ? null : (label ?? this.label),
      protocol: protocol ?? this.protocol,
      transport: transport ?? this.transport,
      bindAddress: clearBindAddress ? null : (bindAddress ?? this.bindAddress),
      port: clearPort ? null : (port ?? this.port),
      portEnd: clearPortEnd ? null : (portEnd ?? this.portEnd),
      path: clearPath ? null : (path ?? this.path),
      networkId: clearNetworkId ? null : (networkId ?? this.networkId),
      scope: scope ?? this.scope,
      isPrimary: isPrimary ?? this.isPrimary,
      notes: clearNotes ? null : (notes ?? this.notes),
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
    if (label != null && label!.isNotEmpty) 'label': label,
    'protocol': protocol.jsonValue,
    'transport': transport.jsonValue,
    if (bindAddress != null && bindAddress!.isNotEmpty)
      'bindAddress': bindAddress,
    if (port != null) 'port': port,
    if (portEnd != null) 'portEnd': portEnd,
    if (path != null && path!.isNotEmpty) 'path': path,
    if (networkId != null) 'networkId': networkId,
    'scope': scope.jsonValue,
    if (isPrimary) 'isPrimary': true,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `ServiceEndpoint.fromJson` instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  factory ServiceEndpoint.fromJson(Map<String, dynamic> json) =>
      ServiceEndpoint(
        id: json['id'] as String?,
        label: json['label'] as String?,
        protocol: ServiceProtocol.fromJson(json['protocol'] as String?),
        transport: ServiceTransport.fromJson(json['transport'] as String?),
        bindAddress: json['bindAddress'] as String?,
        port: json['port'] as int?,
        portEnd: json['portEnd'] as int?,
        path: json['path'] as String?,
        networkId: json['networkId'] as String?,
        scope: ServiceScope.fromJson(json['scope'] as String?),
        isPrimary: json['isPrimary'] as bool? ?? false,
        notes: json['notes'] as String?,
        extraJson: unknownJsonFields(json, _serviceEndpointJsonKeys),
      );

  /// Purpose: Merge preserved unknown JSON fields from another instance.
  /// Inputs: `other`.
  /// Returns: `ServiceEndpoint`.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  ServiceEndpoint mergeUnknownFieldsFrom(
    ServiceEndpoint other, {
    ServiceEndpoint? base,
  }) {
    return ServiceEndpoint.fromJson({
      ...toJson(),
      ...mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    });
  }

  /// Purpose: Return the current port text value.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  String get portText {
    if (port == null) return '-';
    if (portEnd != null && portEnd != port) return '$port-$portEnd';
    return '$port';
  }
}

class ServiceNode {
  final String id;
  final String deviceId;
  final String name;
  final String? templateId;
  final String? icon;
  final ServiceKind kind;
  final ServiceRuntime? runtime;
  final ServiceState state;
  final List<ServiceEndpoint> endpoints;
  final List<String> tags;
  final String? notes;
  final String? dockerCompose;
  final DateTime modifiedAt;
  final Map<String, dynamic> extraJson;

  ServiceNode({
    String? id,
    required this.deviceId,
    required this.name,
    this.templateId,
    this.icon,
    this.kind = ServiceKind.custom,
    this.runtime,
    this.state = ServiceState.active,
    this.endpoints = const [],
    this.tags = const [],
    this.notes,
    this.dockerCompose,
    DateTime? modifiedAt,
    this.extraJson = const {},
  }) : id = id ?? const Uuid().v4(),
       modifiedAt = modifiedAt ?? DateTime.now().toUtc();

  ServiceNode copyWith({
    String? deviceId,
    String? name,
    String? templateId,
    String? icon,
    ServiceKind? kind,
    ServiceRuntime? runtime,
    ServiceState? state,
    List<ServiceEndpoint>? endpoints,
    List<String>? tags,
    String? notes,
    String? dockerCompose,
    DateTime? modifiedAt,
    bool clearTemplateId = false,
    bool clearIcon = false,
    bool clearRuntime = false,
    bool clearNotes = false,
    bool clearDockerCompose = false,
  }) {
    return ServiceNode(
      id: id,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      templateId: clearTemplateId ? null : (templateId ?? this.templateId),
      icon: clearIcon ? null : (icon ?? this.icon),
      kind: kind ?? this.kind,
      runtime: clearRuntime ? null : (runtime ?? this.runtime),
      state: state ?? this.state,
      endpoints: endpoints ?? this.endpoints,
      tags: tags ?? this.tags,
      notes: clearNotes ? null : (notes ?? this.notes),
      dockerCompose: clearDockerCompose
          ? null
          : (dockerCompose ?? this.dockerCompose),
      modifiedAt: modifiedAt ?? DateTime.now().toUtc(),
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
    'deviceId': deviceId,
    'name': name,
    if (templateId != null) 'templateId': templateId,
    if (icon != null && icon!.isNotEmpty) 'icon': icon,
    'kind': kind.jsonValue,
    if (runtime != null) 'runtime': runtime!.jsonValue,
    'state': state.jsonValue,
    if (endpoints.isNotEmpty)
      'endpoints': endpoints.map((e) => e.toJson()).toList(),
    if (tags.isNotEmpty) 'tags': tags,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    if (dockerCompose != null && dockerCompose!.isNotEmpty)
      'dockerCompose': dockerCompose,
    'modifiedAt': modifiedAt.toIso8601String(),
  };

  factory ServiceNode.fromJson(Map<String, dynamic> json) => ServiceNode(
    id: json['id'] as String?,
    deviceId: json['deviceId'] as String,
    name: json['name'] as String,
    templateId: json['templateId'] as String?,
    icon: json['icon'] as String?,
    kind: ServiceKind.fromJson(json['kind'] as String?),
    runtime: ServiceRuntime.fromJson(json['runtime'] as String?),
    state: ServiceState.fromJson(json['state'] as String?),
    endpoints:
        (json['endpoints'] as List<dynamic>?)
            ?.map((e) => ServiceEndpoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    tags:
        (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        const [],
    notes: json['notes'] as String?,
    dockerCompose: json['dockerCompose'] as String?,
    modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    extraJson: unknownJsonFields(json, _serviceNodeJsonKeys),
  );

  /// Purpose: Merge preserved unknown JSON fields from another instance.
  /// Inputs: `other`.
  /// Returns: `ServiceNode`.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  ServiceNode mergeUnknownFieldsFrom(ServiceNode other, {ServiceNode? base}) {
    final json = toJson();
    json.addAll(
      mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    );

    if (endpoints.isNotEmpty) {
      json['endpoints'] = [
        for (final endpoint in endpoints)
          endpoint
              .mergeUnknownFieldsFrom(
                other.endpoints.where((e) => e.id == endpoint.id).firstOrNull ??
                    ServiceEndpoint(id: endpoint.id),
                base: base?.endpoints
                    .where((e) => e.id == endpoint.id)
                    .firstOrNull,
              )
              .toJson(),
      ];
    }

    return ServiceNode.fromJson(json);
  }
}

class ServiceRouteHop {
  final String id;
  final ServiceRouteHopType type;
  final String? serviceId;
  final String? endpointId;
  final String? deviceId;
  final String? label;
  final String? scheme;
  final String? host;
  final int? port;
  final String? path;
  final ServiceRouteMethod? method;
  final String? notes;
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a service route hop instance.
  /// Inputs: `type`.
  /// Returns: A new `ServiceRouteHop` instance.
  /// Side effects: None.
  /// Notes: None.
  ServiceRouteHop({
    String? id,
    this.type = ServiceRouteHopType.manual,
    this.serviceId,
    this.endpointId,
    this.deviceId,
    this.label,
    this.scheme,
    this.host,
    this.port,
    this.path,
    this.method,
    this.notes,
    this.extraJson = const {},
  }) : id = id ?? const Uuid().v4();

  ServiceRouteHop copyWith({
    ServiceRouteHopType? type,
    String? serviceId,
    String? endpointId,
    String? deviceId,
    String? label,
    String? scheme,
    String? host,
    int? port,
    String? path,
    ServiceRouteMethod? method,
    String? notes,
    bool clearServiceId = false,
    bool clearEndpointId = false,
    bool clearDeviceId = false,
    bool clearLabel = false,
    bool clearScheme = false,
    bool clearHost = false,
    bool clearPort = false,
    bool clearPath = false,
    bool clearMethod = false,
    bool clearNotes = false,
  }) {
    return ServiceRouteHop(
      id: id,
      type: type ?? this.type,
      serviceId: clearServiceId ? null : (serviceId ?? this.serviceId),
      endpointId: clearEndpointId ? null : (endpointId ?? this.endpointId),
      deviceId: clearDeviceId ? null : (deviceId ?? this.deviceId),
      label: clearLabel ? null : (label ?? this.label),
      scheme: clearScheme ? null : (scheme ?? this.scheme),
      host: clearHost ? null : (host ?? this.host),
      port: clearPort ? null : (port ?? this.port),
      path: clearPath ? null : (path ?? this.path),
      method: clearMethod ? null : (method ?? this.method),
      notes: clearNotes ? null : (notes ?? this.notes),
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
    'type': type.jsonValue,
    if (serviceId != null) 'serviceId': serviceId,
    if (endpointId != null) 'endpointId': endpointId,
    if (deviceId != null) 'deviceId': deviceId,
    if (label != null && label!.isNotEmpty) 'label': label,
    if (scheme != null && scheme!.isNotEmpty) 'scheme': scheme,
    if (host != null && host!.isNotEmpty) 'host': host,
    if (port != null) 'port': port,
    if (path != null && path!.isNotEmpty) 'path': path,
    if (method != null) 'method': method!.jsonValue,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: `json`.
  /// Returns: A new `ServiceRouteHop.fromJson` instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  factory ServiceRouteHop.fromJson(Map<String, dynamic> json) =>
      ServiceRouteHop(
        id: json['id'] as String?,
        type: ServiceRouteHopType.fromJson(json['type'] as String?),
        serviceId: json['serviceId'] as String?,
        endpointId: json['endpointId'] as String?,
        deviceId: json['deviceId'] as String?,
        label: json['label'] as String?,
        scheme: json['scheme'] as String?,
        host: json['host'] as String?,
        port: json['port'] as int?,
        path: json['path'] as String?,
        method: ServiceRouteMethod.fromJson(json['method'] as String?),
        notes: json['notes'] as String?,
        extraJson: unknownJsonFields(json, _serviceRouteHopJsonKeys),
      );

  /// Purpose: Merge preserved unknown JSON fields from another instance.
  /// Inputs: `other`.
  /// Returns: `ServiceRouteHop`.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  ServiceRouteHop mergeUnknownFieldsFrom(
    ServiceRouteHop other, {
    ServiceRouteHop? base,
  }) {
    return ServiceRouteHop.fromJson({
      ...toJson(),
      ...mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    });
  }
}

class ServiceRoute {
  final String id;
  final String name;
  final String sourceServiceId;
  final String? sourceEndpointId;
  final List<ServiceRouteHop> hops;
  final String? finalUrl;
  final ServiceAccessLevel accessLevel;
  final String? notes;
  final DateTime modifiedAt;
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a service route instance.
  /// Inputs: `hops`.
  /// Returns: A new `ServiceRoute` instance.
  /// Side effects: None.
  /// Notes: None.
  ServiceRoute({
    String? id,
    required this.name,
    required this.sourceServiceId,
    this.sourceEndpointId,
    this.hops = const [],
    this.finalUrl,
    this.accessLevel = ServiceAccessLevel.lan,
    this.notes,
    DateTime? modifiedAt,
    this.extraJson = const {},
  }) : id = id ?? const Uuid().v4(),
       modifiedAt = modifiedAt ?? DateTime.now().toUtc();

  /// Purpose: Create a copy with selected fields replaced.
  /// Inputs: `clearSourceEndpointId`.
  /// Returns: `ServiceRoute`.
  /// Side effects: None.
  /// Notes: None.
  ServiceRoute copyWith({
    String? name,
    String? sourceServiceId,
    String? sourceEndpointId,
    List<ServiceRouteHop>? hops,
    String? finalUrl,
    ServiceAccessLevel? accessLevel,
    String? notes,
    DateTime? modifiedAt,
    bool clearSourceEndpointId = false,
    bool clearFinalUrl = false,
    bool clearNotes = false,
  }) {
    return ServiceRoute(
      id: id,
      name: name ?? this.name,
      sourceServiceId: sourceServiceId ?? this.sourceServiceId,
      sourceEndpointId: clearSourceEndpointId
          ? null
          : (sourceEndpointId ?? this.sourceEndpointId),
      hops: hops ?? this.hops,
      finalUrl: clearFinalUrl ? null : (finalUrl ?? this.finalUrl),
      accessLevel: accessLevel ?? this.accessLevel,
      notes: clearNotes ? null : (notes ?? this.notes),
      modifiedAt: modifiedAt ?? DateTime.now().toUtc(),
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
    'sourceServiceId': sourceServiceId,
    if (sourceEndpointId != null) 'sourceEndpointId': sourceEndpointId,
    if (hops.isNotEmpty) 'hops': hops.map((h) => h.toJson()).toList(),
    if (finalUrl != null && finalUrl!.isNotEmpty) 'finalUrl': finalUrl,
    'accessLevel': accessLevel.jsonValue,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    'modifiedAt': modifiedAt.toIso8601String(),
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A new `ServiceRoute.fromJson` instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  factory ServiceRoute.fromJson(Map<String, dynamic> json) => ServiceRoute(
    id: json['id'] as String?,
    name: json['name'] as String,
    sourceServiceId: json['sourceServiceId'] as String,
    sourceEndpointId: json['sourceEndpointId'] as String?,
    hops:
        (json['hops'] as List<dynamic>?)
            ?.map((e) => ServiceRouteHop.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    finalUrl: json['finalUrl'] as String?,
    accessLevel: ServiceAccessLevel.fromJson(json['accessLevel'] as String?),
    notes: json['notes'] as String?,
    modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    extraJson: unknownJsonFields(json, _serviceRouteJsonKeys),
  );

  /// Purpose: Merge preserved unknown JSON fields from another instance.
  /// Inputs: `other`.
  /// Returns: `ServiceRoute`.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  ServiceRoute mergeUnknownFieldsFrom(
    ServiceRoute other, {
    ServiceRoute? base,
  }) {
    final json = toJson();
    json.addAll(
      mergeUnknownJsonFields(
        primary: extraJson,
        secondary: other.extraJson,
        base: base?.extraJson,
      ),
    );

    if (hops.isNotEmpty) {
      json['hops'] = [
        for (final hop in hops)
          hop
              .mergeUnknownFieldsFrom(
                other.hops.where((h) => h.id == hop.id).firstOrNull ??
                    ServiceRouteHop(id: hop.id),
                base: base?.hops.where((h) => h.id == hop.id).firstOrNull,
              )
              .toJson(),
      ];
    }

    return ServiceRoute.fromJson(json);
  }
}

class ServiceData {
  final List<ServiceNode> services;
  final List<ServiceRoute> routes;
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a service data instance.
  /// Inputs: `services`.
  /// Returns: A new `ServiceData` instance.
  /// Side effects: None.
  /// Notes: None.
  const ServiceData({
    this.services = const [],
    this.routes = const [],
    this.extraJson = const {},
  });

  /// Purpose: Serialize this value into a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keep the output aligned with the persisted file and sync format.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'services': services.map((s) => s.toJson()).toList(),
    'routes': routes.map((r) => r.toJson()).toList(),
  };

  /// Purpose: Create an instance from a JSON-compatible map.
  /// Inputs: None.
  /// Returns: A new `ServiceData.fromJson` instance.
  /// Side effects: None.
  /// Notes: Use this path when preserving forward-compatible persisted fields matters.
  factory ServiceData.fromJson(Map<String, dynamic> json) => ServiceData(
    services:
        (json['services'] as List<dynamic>?)
            ?.map((e) => ServiceNode.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    routes:
        (json['routes'] as List<dynamic>?)
            ?.map((e) => ServiceRoute.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    extraJson: unknownJsonFields(json, _serviceDataJsonKeys),
  );
}
