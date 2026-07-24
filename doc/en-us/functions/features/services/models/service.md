# lib/features/services/models/service.dart

The service-inventory model family: `ServiceNode` (a service instance on a device),
`ServiceEndpoint` (one manually recorded listening endpoint), `ServiceRoute` and
`ServiceRouteHop` (a manually recorded access path and its hops), the top-level
`ServiceData` container persisted by
[`../services/service_storage.md`](../services/service_storage.md), and every supporting
enum (`ServiceKind`, `ServiceRuntime`, `ServiceState`, `ServiceProtocol`,
`ServiceTransport`, `ServiceScope`, `ServiceRouteHopType`, `ServiceRouteMethod`,
`ServiceAccessLevel`). Every model here follows the app's standard shape: a constructor
with a fresh auto-generated `id` (and, for `ServiceNode`/`ServiceRoute`, a fresh UTC
`modifiedAt`), `toJson`/`fromJson`, and a `mergeUnknownFieldsFrom` that participates in
the three-way sync merge (see [Three-Way Merge](../../../../algorithms/three-way-merge.md)
and
[`../../../../shared/utils/json_preservation.md`](../../../shared/utils/json_preservation.md)
for the generic `unknownJsonFields`/`mergeUnknownJsonFields` helpers every `fromJson`/
`mergeUnknownFieldsFrom` here calls). See
[Services and Topology](../../../../features/services-topology.md) for the
manual-inventory-only constraint and view-level behavior these models support, and
[Data Formats](../../../../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)
for the exhaustive persisted-field reference. `lib/features/services/services/service_analysis.dart`
(see [`../services/service_analysis.md`](../services/service_analysis.md)) is the main
consumer of these types beyond simple storage — it builds the topology graph, port
conflict list, and reference-warning list from them.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `jsonValue` | getter (`ServiceKind`) | B | Return the serialized enum name. |
| [`ServiceKind.fromJson`](#servicekind-fromjson) | static method | A | Parse a `ServiceKind`, defaulting to `custom`. |
| `jsonValue` | getter (`ServiceRuntime`) | B | Return the serialized enum name. |
| [`ServiceRuntime.fromJson`](#serviceruntime-fromjson) | static method | A | Parse a `ServiceRuntime`, or `null`. |
| `jsonValue` | getter (`ServiceState`) | B | Return the serialized enum name. |
| [`ServiceState.fromJson`](#servicestate-fromjson) | static method | A | Parse a `ServiceState`, defaulting to `active`. |
| `jsonValue` | getter (`ServiceProtocol`) | B | Return the serialized enum name. |
| [`ServiceProtocol.fromJson`](#serviceprotocol-fromjson) | static method | A | Parse a `ServiceProtocol`, defaulting to `custom`. |
| `jsonValue` | getter (`ServiceTransport`) | B | Return the serialized enum name. |
| [`ServiceTransport.fromJson`](#servicetransport-fromjson) | static method | A | Parse a `ServiceTransport`, defaulting to `tcp`. |
| `jsonValue` | getter (`ServiceScope`) | B | Return the serialized enum name. |
| [`ServiceScope.fromJson`](#servicescope-fromjson) | static method | A | Parse a `ServiceScope`, defaulting to `lan`. |
| `jsonValue` | getter (`ServiceRouteHopType`) | B | Return the serialized enum name. |
| [`ServiceRouteHopType.fromJson`](#serviceroutehoptype-fromjson) | static method | A | Parse a `ServiceRouteHopType`, defaulting to `manual`. |
| `jsonValue` | getter (`ServiceRouteMethod`) | B | Return the serialized enum name. |
| [`ServiceRouteMethod.fromJson`](#serviceroutemethod-fromjson) | static method | A | Parse a `ServiceRouteMethod`, or `null`. |
| `jsonValue` | getter (`ServiceAccessLevel`) | B | Return the serialized enum name. |
| [`ServiceAccessLevel.fromJson`](#serviceaccesslevel-fromjson) | static method | A | Parse a `ServiceAccessLevel`, defaulting to `lan`. |
| [`ServiceEndpoint`](#serviceendpoint-new) | constructor | A | Create a `ServiceEndpoint` instance (fresh `id` by default). |
| [`copyWith`](#serviceendpoint-copywith) | method (`ServiceEndpoint`) | A | Create a copy with any subset of fields replaced or cleared. |
| [`toJson`](#serviceendpoint-tojson) | method (`ServiceEndpoint`) | A | Serialize this value into a JSON-compatible map. |
| [`ServiceEndpoint.fromJson`](#serviceendpoint-fromjson) | factory constructor | A | Parse a `ServiceEndpoint` from JSON. |
| [`mergeUnknownFieldsFrom`](#serviceendpoint-mergeunknownfieldsfrom) | method (`ServiceEndpoint`) | A | Three-way merge unknown JSON fields from another `ServiceEndpoint`. |
| [`portText`](#serviceendpoint-porttext) | getter (`ServiceEndpoint`) | A | Render `port`/`portEnd` as a display string (`"8080"`, `"8080-8090"`, or `"-"`). |
| [`ServiceNode`](#servicenode-new) | constructor | A | Create a `ServiceNode` instance (fresh `id`/`modifiedAt` by default). |
| [`copyWith`](#servicenode-copywith) | method (`ServiceNode`) | A | Create a copy with any subset of fields replaced or cleared. |
| [`toJson`](#servicenode-tojson) | method (`ServiceNode`) | A | Serialize this value into a JSON-compatible map. |
| [`ServiceNode.fromJson`](#servicenode-fromjson) | factory constructor | A | Parse a `ServiceNode` from JSON. |
| [`mergeUnknownFieldsFrom`](#servicenode-mergeunknownfieldsfrom) | method (`ServiceNode`) | A | Merge unknown fields plus each endpoint's own unknown fields. |
| [`ServiceRouteHop`](#serviceroutehop-new) | constructor | A | Create a `ServiceRouteHop` instance (fresh `id` by default). |
| [`copyWith`](#serviceroutehop-copywith) | method (`ServiceRouteHop`) | A | Create a copy with any subset of fields replaced or cleared. |
| [`toJson`](#serviceroutehop-tojson) | method (`ServiceRouteHop`) | A | Serialize this value into a JSON-compatible map. |
| [`ServiceRouteHop.fromJson`](#serviceroutehop-fromjson) | factory constructor | A | Parse a `ServiceRouteHop` from JSON. |
| [`mergeUnknownFieldsFrom`](#serviceroutehop-mergeunknownfieldsfrom) | method (`ServiceRouteHop`) | A | Three-way merge unknown JSON fields from another `ServiceRouteHop`. |
| [`ServiceRoute`](#serviceroute-new) | constructor | A | Create a `ServiceRoute` instance (fresh `id`/`modifiedAt` by default). |
| [`copyWith`](#serviceroute-copywith) | method (`ServiceRoute`) | A | Create a copy with any subset of fields replaced or cleared. |
| [`toJson`](#serviceroute-tojson) | method (`ServiceRoute`) | A | Serialize this value into a JSON-compatible map. |
| [`ServiceRoute.fromJson`](#serviceroute-fromjson) | factory constructor | A | Parse a `ServiceRoute` from JSON. |
| [`mergeUnknownFieldsFrom`](#serviceroute-mergeunknownfieldsfrom) | method (`ServiceRoute`) | A | Merge unknown fields plus each hop's own unknown fields. |
| [`ServiceData`](#servicedata-new) | constructor | A | Create a `ServiceData` instance. |
| [`toJson`](#servicedata-tojson) | method (`ServiceData`) | A | Serialize this value into a JSON-compatible map. |
| [`ServiceData.fromJson`](#servicedata-fromjson) | factory constructor | A | Parse a `ServiceData` from JSON. |

Row count (42) does not match `grep -c 'Purpose:' service.dart` (37). Confirmed by reading
the file directly: five declarations carry no `/// Purpose:` doc comment at all —
[`ServiceEndpoint.copyWith`](#serviceendpoint-copywith),
[`ServiceNode`](#servicenode-new)'s constructor, [`ServiceNode.copyWith`](#servicenode-copywith),
[`ServiceNode.fromJson`](#servicenode-fromjson), and
[`ServiceRouteHop.copyWith`](#serviceroutehop-copywith). Every other declaration in the
file (all 9 enums' `jsonValue`/`fromJson` pairs, the rest of `ServiceEndpoint`, the rest
of `ServiceNode`, the rest of `ServiceRouteHop`, all of `ServiceRoute` including its own
`copyWith`, and all of `ServiceData`) carries one — 37 declarations documented, 5 not,
42 total. `ServiceAccessLane`/`ServiceTopologyNode*`-style bare enums with no
getters/methods of their own would be skipped per this doc set's convention of indexing
only executable declarations, but every enum in this file has at least a `jsonValue`
getter and a `fromJson` parser, so all nine appear.

## Documentation

### `static ServiceKind fromJson(String? value)` <a id="servicekind-fromjson"></a>
- **Kind:** static method of enum `ServiceKind`.
- **Source:** `lib/features/services/models/service.dart` (line 92).
- **Purpose:** Parse a `ServiceKind` from its serialized name, defaulting to `custom` for
  any unrecognized or missing value.
- **Inputs:** `value` — nullable.
- **Returns:** `ServiceKind` — never `null`.
- **Side effects:** None.
- **Algorithm:** `ServiceKind.values.where((e) => e.name == value).firstOrNull ??
  ServiceKind.custom`.
- **Usage:**
  ```dart
  kind: ServiceKind.fromJson(json['kind'] as String?),
  ```
  (from [`ServiceNode.fromJson`](#servicenode-fromjson))
- **Notes:** `custom` is both the "unrecognized" and "absent" fallback, and also
  `ServiceNode`'s own constructor default for `kind` — a service record can never end up
  with a null/invalid kind.

### `static ServiceRuntime? fromJson(String? value)` <a id="serviceruntime-fromjson"></a>
- **Kind:** static method of enum `ServiceRuntime`.
- **Source:** `lib/features/services/models/service.dart` (line 119).
- **Purpose:** Parse a `ServiceRuntime` from its serialized name.
- **Inputs:** `value` — nullable.
- **Returns:** `ServiceRuntime?` — `null` if `value` is `null` or unrecognized.
- **Side effects:** None.
- **Algorithm:** Null-check, then `ServiceRuntime.values.where((e) => e.name ==
  value).firstOrNull`.
- **Usage:** Called by [`ServiceNode.fromJson`](#servicenode-fromjson) for `runtime`, and
  directly by `_ServiceTemplatePicker`/`service_edit_page.dart` when reading a template's
  `runtime`.
- **Notes:** Unlike `ServiceKind.fromJson`, an unrecognized runtime yields `null` (no
  runtime recorded) rather than a fallback value — matching the field's own optionality
  (`ServiceNode.runtime` is `ServiceRuntime?`).

### `static ServiceState fromJson(String? value)` <a id="servicestate-fromjson"></a>
- **Kind:** static method of enum `ServiceState`.
- **Source:** `lib/features/services/models/service.dart` (line 143).
- **Purpose:** Parse a `ServiceState`, defaulting to `active` when unrecognized or
  absent.
- **Inputs:** `value` — nullable.
- **Returns:** `ServiceState` — never `null`.
- **Side effects:** None.
- **Algorithm:** `.where(...).firstOrNull ?? ServiceState.active`.
- **Usage:** Called by [`ServiceNode.fromJson`](#servicenode-fromjson) for `state`.
- **Notes:** `active` is also `ServiceNode`'s own constructor default, so a newly created
  service and a service parsed from data missing the `state` key behave identically.

### `static ServiceProtocol fromJson(String? value)` <a id="serviceprotocol-fromjson"></a>
- **Kind:** static method of enum `ServiceProtocol`.
- **Source:** `lib/features/services/models/service.dart` (line 171).
- **Purpose:** Parse a `ServiceProtocol`, defaulting to `custom`.
- **Inputs:** `value` — nullable.
- **Returns:** `ServiceProtocol` — never `null`.
- **Side effects:** None.
- **Algorithm:** `.where(...).firstOrNull ?? ServiceProtocol.custom`.
- **Usage:** Called by [`ServiceEndpoint.fromJson`](#serviceendpoint-fromjson) for
  `protocol`.
- **Notes:** None.

### `static ServiceTransport fromJson(String? value)` <a id="servicetransport-fromjson"></a>
- **Kind:** static method of enum `ServiceTransport`.
- **Source:** `lib/features/services/models/service.dart` (line 193).
- **Purpose:** Parse a `ServiceTransport`, defaulting to `tcp`.
- **Inputs:** `value` — nullable.
- **Returns:** `ServiceTransport` — never `null`.
- **Side effects:** None.
- **Algorithm:** `.where(...).firstOrNull ?? ServiceTransport.tcp`.
- **Usage:** Called by [`ServiceEndpoint.fromJson`](#serviceendpoint-fromjson) for
  `transport`.
- **Notes:** `tcpUdp` (meaning "both") is a real value of this enum, not a special case
  of this parser — [`listServicePortUses`](../services/service_analysis.md#listserviceportuses)
  is what expands a `tcpUdp` endpoint into separate TCP and UDP port uses.

### `static ServiceScope fromJson(String? value)` <a id="servicescope-fromjson"></a>
- **Kind:** static method of enum `ServiceScope`.
- **Source:** `lib/features/services/models/service.dart` (line 217).
- **Purpose:** Parse a `ServiceScope`, defaulting to `lan`.
- **Inputs:** `value` — nullable.
- **Returns:** `ServiceScope` — never `null`.
- **Side effects:** None.
- **Algorithm:** `.where(...).firstOrNull ?? ServiceScope.lan`.
- **Usage:** Called by [`ServiceEndpoint.fromJson`](#serviceendpoint-fromjson) for
  `scope`.
- **Notes:** None.

### `static ServiceRouteHopType fromJson(String? value)` <a id="serviceroutehoptype-fromjson"></a>
- **Kind:** static method of enum `ServiceRouteHopType`.
- **Source:** `lib/features/services/models/service.dart` (line 244).
- **Purpose:** Parse a `ServiceRouteHopType`, defaulting to `manual`.
- **Inputs:** `value` — nullable.
- **Returns:** `ServiceRouteHopType` — never `null`.
- **Side effects:** None.
- **Algorithm:** `.where(...).firstOrNull ?? ServiceRouteHopType.manual`.
- **Usage:** Called by [`ServiceRouteHop.fromJson`](#serviceroutehop-fromjson) for
  `type`.
- **Notes:** `manual` is both the parse fallback and `ServiceRouteHop`'s own constructor
  default.

### `static ServiceRouteMethod? fromJson(String? value)` <a id="serviceroutemethod-fromjson"></a>
- **Kind:** static method of enum `ServiceRouteMethod`.
- **Source:** `lib/features/services/models/service.dart` (line 273).
- **Purpose:** Parse a `ServiceRouteMethod` from its serialized name.
- **Inputs:** `value` — nullable.
- **Returns:** `ServiceRouteMethod?` — `null` if `value` is `null` or unrecognized.
- **Side effects:** None.
- **Algorithm:** Null-check, then `.where(...).firstOrNull`.
- **Usage:** Called by [`ServiceRouteHop.fromJson`](#serviceroutehop-fromjson) for
  `method`; also read throughout
  [`../services/service_analysis.md`](../services/service_analysis.md) (e.g.
  `serviceAccessLaneForRoute`, `_isPortMappingHop`) to decide FRP/reverse-proxy/tunnel
  behavior.
- **Notes:** A `null` method (no method recorded on a hop) is meaningfully different from
  `ServiceRouteMethod.custom` — several `service_analysis.dart` functions branch on
  `hop.method == null` specifically (e.g. falling back to `hop.type` for a label).

### `static ServiceAccessLevel fromJson(String? value)` <a id="serviceaccesslevel-fromjson"></a>
- **Kind:** static method of enum `ServiceAccessLevel`.
- **Source:** `lib/features/services/models/service.dart` (line 298).
- **Purpose:** Parse a `ServiceAccessLevel`, defaulting to `lan`.
- **Inputs:** `value` — nullable.
- **Returns:** `ServiceAccessLevel` — never `null`.
- **Side effects:** None.
- **Algorithm:** `.where(...).firstOrNull ?? ServiceAccessLevel.lan`.
- **Usage:** Called by [`ServiceRoute.fromJson`](#serviceroute-fromjson) for
  `accessLevel`.
- **Notes:** `lan` is both the parse fallback and `ServiceRoute`'s own constructor
  default, matching the pattern used by every other enum parser in this file except
  `ServiceRuntime.fromJson`/`ServiceRouteMethod.fromJson` (whose fields are nullable with
  no default at all).

### `ServiceEndpoint({String? id, this.label, this.protocol = ServiceProtocol.http, this.transport = ServiceTransport.tcp, this.bindAddress, this.port, this.portEnd, this.path, this.networkId, this.scope = ServiceScope.lan, this.isPrimary = false, this.notes, this.extraJson = const {}})` <a id="serviceendpoint-new"></a>
- **Kind:** constructor of `ServiceEndpoint`.
- **Source:** `lib/features/services/models/service.dart` (line 323).
- **Purpose:** Create a manually recorded local/listening endpoint, generating a fresh
  UUID `id` when none is supplied.
- **Inputs:** All fields optional; `protocol` defaults to `http`, `transport` to `tcp`,
  `scope` to `lan`, `isPrimary` to `false`, `extraJson` to `{}`.
- **Returns:** A new `ServiceEndpoint`.
- **Side effects:** None (beyond `Uuid().v4()` when `id` is null — no I/O).
- **Algorithm:** `id = id ?? const Uuid().v4()` in the initializer list; every other field
  plain-assigned with its declared default.
- **Usage:**
  ```dart
  Navigator.pop(
    ctx,
    ServiceEndpoint(
      id: initial?.id,
      label: _emptyToNull(labelCtrl.text),
      protocol: protocol,
      transport: transport,
      bindAddress: _emptyToNull(bindCtrl.text),
      port: int.tryParse(portCtrl.text.trim()),
      portEnd: int.tryParse(portEndCtrl.text.trim()),
      path: _emptyToNull(pathCtrl.text),
      scope: scope,
      isPrimary: primary,
      extraJson: initial?.extraJson ?? const {},
    ),
  );
  ```
  (from `service_edit_page.dart`'s endpoint add/edit dialog; also constructed by
  `_applyTemplate` when copying a
  [`ServiceTemplate`](../services/service_template_service.md#servicetemplate-new)'s
  endpoints)
- **Notes:** Passing `id: initial?.id` (the existing endpoint's id, or `null` for a new
  one) is what lets editing an endpoint update it in place rather than appearing as a
  delete-plus-add to anything matching endpoints by id.

### `ServiceEndpoint copyWith({...})` <a id="serviceendpoint-copywith"></a>
- **Kind:** method of `ServiceEndpoint`.
- **Source:** `lib/features/services/models/service.dart` (line 339).
- **Purpose:** Create a copy of this endpoint with any subset of fields replaced, or
  explicitly cleared via a `clearXxx` flag (`clearLabel`, `clearBindAddress`,
  `clearPort`, `clearPortEnd`, `clearPath`, `clearNetworkId`, `clearNotes`).
- **Inputs:** One optional parameter per mutable field, plus one `bool clearXxx = false`
  per nullable field.
- **Returns:** A new `ServiceEndpoint` — same `id` and `extraJson` as `this`.
- **Side effects:** None.
- **Algorithm:** For each nullable field, `clearXxx ? null : (xxx ?? this.xxx)` — the
  clear flag takes priority over a replacement value if a caller somehow passed both.
  Non-nullable fields (`protocol`, `transport`, `scope`, `isPrimary`) use plain `??`.
- **Usage:** No call site exists anywhere in `lib/` for `ServiceEndpoint.copyWith`
  specifically — grepping the repo for `endpoint.copyWith`/`.copyWith(` on a
  `ServiceEndpoint`-typed receiver finds none.
- **Notes:** This declaration has no `/// Purpose:` doc comment in source. Like
  [`ServiceTemplate.toService`](../services/service_template_service.md#servicetemplate-toservice),
  this method is currently unused — every place that changes an endpoint constructs a
  brand-new `ServiceEndpoint` directly (see the constructor's own Usage example above)
  rather than copying an existing one.

### `Map<String, dynamic> toJson()` (`ServiceEndpoint`) <a id="serviceendpoint-tojson"></a>
- **Kind:** method of `ServiceEndpoint`.
- **Source:** `lib/features/services/models/service.dart` (line 381).
- **Purpose:** Serialize this endpoint into the JSON persisted inside a service's
  `endpoints` list.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` — `extraJson` spread first, then `id` and
  `protocol`/`transport`/`scope` unconditionally (via `.jsonValue`), every other field
  only `if` non-null/non-empty, and `isPrimary` only `if (isPrimary)` (a `false` value is
  omitted entirely rather than written out).
- **Side effects:** None.
- **Algorithm:** `{...extraJson, 'id': id, if (label...) ..., 'protocol':
  protocol.jsonValue, 'transport': transport.jsonValue, ..., 'scope': scope.jsonValue, if
  (isPrimary) 'isPrimary': true, if (notes...) ...}`.
- **Usage:** Called by [`ServiceNode.toJson`](#servicenode-tojson) for each entry of
  `endpoints`, and by [`mergeUnknownFieldsFrom`](#serviceendpoint-mergeunknownfieldsfrom).
- **Notes:** Omitting `isPrimary` entirely when `false` (rather than writing
  `"isPrimary": false`) keeps the common case — most endpoints on a multi-endpoint
  service are not primary — out of the persisted JSON.

### `factory ServiceEndpoint.fromJson(Map<String, dynamic> json)` <a id="serviceendpoint-fromjson"></a>
- **Kind:** factory constructor of `ServiceEndpoint`.
- **Source:** `lib/features/services/models/service.dart` (line 403).
- **Purpose:** Parse a `ServiceEndpoint` from JSON.
- **Inputs:** `json`.
- **Returns:** A new `ServiceEndpoint`; `extraJson` holds every key not in
  `_serviceEndpointJsonKeys`.
- **Side effects:** None.
- **Algorithm:** Direct field extraction for each known key, parsing `protocol`/
  `transport`/`scope` via their respective enum `fromJson` parsers; `isPrimary` defaults
  to `false` if absent.
- **Usage:** Called by [`ServiceNode.fromJson`](#servicenode-fromjson) for each entry of
  `json['endpoints']`.
- **Notes:** None.

### `ServiceEndpoint mergeUnknownFieldsFrom(ServiceEndpoint other, {ServiceEndpoint? base})` <a id="serviceendpoint-mergeunknownfieldsfrom"></a>
- **Kind:** method of `ServiceEndpoint`.
- **Source:** `lib/features/services/models/service.dart` (line 425).
- **Purpose:** Three-way merge this endpoint's unknown JSON fields with another's, so
  unrecognized keys survive a sync merge the same way known fields do.
- **Inputs:** `other` — typically the remote side when `this` is local; optional `base`
  — the last-synced snapshot.
- **Returns:** A new `ServiceEndpoint` — same known fields as `this`, `extraJson`
  replaced by the merged result.
- **Side effects:** None.
- **Algorithm:** Re-parse `{...toJson(), ...mergeUnknownJsonFields(primary: extraJson,
  secondary: other.extraJson, base: base?.extraJson)}` through
  `ServiceEndpoint.fromJson` — see
  [`mergeUnknownJsonFields`](../../../shared/utils/json_preservation.md) for the
  underlying per-key three-way merge rule.
- **Usage:** Called by [`ServiceNode.mergeUnknownFieldsFrom`](#servicenode-mergeunknownfieldsfrom)
  once per index-aligned pair of `endpoints` entries (matched by `id`, falling back to a
  fresh empty `ServiceEndpoint(id: endpoint.id)` when the other side has no matching
  endpoint).
- **Notes:** Only `extraJson` is merged here — the known endpoint fields (`protocol`,
  `port`, etc.) always come from `this` (the primary side), matching how every other
  model's `mergeUnknownFieldsFrom` in this file treats its own known fields.

### `String get portText` <a id="serviceendpoint-porttext"></a>
- **Kind:** getter of `ServiceEndpoint`.
- **Source:** `lib/features/services/models/service.dart` (line 444).
- **Purpose:** Render this endpoint's port (and, if different, port range end) as a
  compact display string.
- **Inputs:** None.
- **Returns:** `String` — `'-'` if `port` is `null`; `'$port-$portEnd'` if `portEnd` is
  set and differs from `port`; otherwise `'$port'`.
- **Side effects:** None.
- **Algorithm:** 1. `port == null` → `'-'`. 2. `portEnd != null && portEnd != port` →
  `'$port-$portEnd'`. 3. Otherwise `'$port'`.
- **Usage:**
  ```dart
  detail: [
    if (endpoint.bindAddress?.trim().isNotEmpty == true) endpoint.bindAddress!.trim(),
    endpoint.portText,
    if (endpoint.path?.trim().isNotEmpty == true) endpoint.path!.trim(),
  ].where((part) => part.isNotEmpty && part != '-').join(':'),
  ```
  (from
  [`buildServiceTopology`'s `addEndpointNode`](../services/service_analysis.md#buildservicetopology)
  when labeling an endpoint node; also read directly by `service_list_page.dart`'s and
  `service_edit_page.dart`'s endpoint list tiles)
- **Notes:** A `'-'` result is filtered back out by most callers (like the topology
  labeler above, via `part != '-'`) rather than displayed literally — this getter's `'-'`
  sentinel exists so callers have a single non-null `String` to test against, not so it
  gets shown to the user.

### `ServiceNode({String? id, required this.deviceId, required this.name, this.templateId, this.icon, this.kind = ServiceKind.custom, this.runtime, this.state = ServiceState.active, this.endpoints = const [], this.tags = const [], this.notes, this.dockerCompose, DateTime? modifiedAt, this.extraJson = const {}})` <a id="servicenode-new"></a>
- **Kind:** constructor of `ServiceNode`.
- **Source:** `lib/features/services/models/service.dart` (line 467).
- **Purpose:** Create a service instance record, generating a fresh UUID `id` and UTC
  `modifiedAt` timestamp when neither is supplied.
- **Inputs:** `deviceId`, `name` required; every other field optional (`kind` defaults to
  `custom`, `state` to `active`, `endpoints`/`tags` to `[]`).
- **Returns:** A new `ServiceNode`.
- **Side effects:** None (beyond `Uuid().v4()`/`DateTime.now()` calls — no I/O).
- **Algorithm:** `id = id ?? const Uuid().v4()`, `modifiedAt = modifiedAt ??
  DateTime.now().toUtc()` in the initializer list; every other field plain-assigned.
- **Usage:**
  ```dart
  final service = ServiceNode(
    id: existing?.id,
    deviceId: _deviceId!,
    name: _nameCtrl.text.trim(),
    templateId: _templateId,
    icon: _icon,
    kind: _kind,
    runtime: _runtime,
    state: _state,
    endpoints: _endpoints,
    tags: existing?.tags ?? const [],
    notes: _emptyToNull(_notesCtrl.text),
    dockerCompose: _emptyToNull(_composeCtrl.text),
    extraJson: existing?.extraJson ?? const {},
  );
  await ServiceStorage.addOrUpdateService(service);
  ```
  (from `service_edit_page.dart`'s save handler — passing `existing?.id` preserves the
  same `id` across an edit rather than minting a new one, exactly as
  [`Device`](../../devices/models/device.md#device-new)'s constructor does)
- **Notes:** This declaration has no `/// Purpose:` doc comment in source (see the
  row-count note above the Declarations table). `modifiedAt` is always refreshed to "now"
  unless explicitly overridden, which is what
  [`mergeRecords<ServiceNode>`](../../../../algorithms/three-way-merge.md) (called from
  `lib/shared/services/sync_merge.dart`) uses to detect which side changed.

### `ServiceNode copyWith({...})` <a id="servicenode-copywith"></a>
- **Kind:** method of `ServiceNode`.
- **Source:** `lib/features/services/models/service.dart` (line 485).
- **Purpose:** Create a copy of this service with any subset of fields replaced, or
  explicitly cleared via a `clearXxx` flag (`clearTemplateId`, `clearIcon`,
  `clearRuntime`, `clearNotes`, `clearDockerCompose`).
- **Inputs:** One optional parameter per mutable field, plus five `clearXxx` flags.
- **Returns:** A new `ServiceNode` — same `id` and `extraJson` as `this`;
  `modifiedAt` defaults to `DateTime.now().toUtc()` if not explicitly passed (unlike most
  fields, which default to `this`'s current value).
- **Side effects:** None.
- **Algorithm:** Same clear-flag-priority shape as
  [`ServiceEndpoint.copyWith`](#serviceendpoint-copywith), with `modifiedAt: modifiedAt ??
  DateTime.now().toUtc()` instead of falling back to `this.modifiedAt` — so calling
  `copyWith()` with zero arguments still bumps the timestamp.
- **Usage:** No call site exists anywhere in `lib/` — `service_edit_page.dart`'s save
  handler constructs a brand-new `ServiceNode` directly (see the constructor's own Usage
  example) rather than calling `copyWith` on `existing`.
- **Notes:** This declaration has no `/// Purpose:` doc comment in source, and — like
  [`ServiceEndpoint.copyWith`](#serviceendpoint-copywith) — is currently unused. Its
  always-refreshing `modifiedAt` default means that if something did start calling it, an
  all-default `copyWith()` call would still register as a sync-relevant change, unlike a
  typical no-op copy.

### `Map<String, dynamic> toJson()` (`ServiceNode`) <a id="servicenode-tojson"></a>
- **Kind:** method of `ServiceNode`.
- **Source:** `lib/features/services/models/service.dart` (line 529).
- **Purpose:** Serialize this service into the JSON persisted inside `ServiceData.services`.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` — `extraJson` spread first, `id`/`deviceId`/`name`/
  `kind`/`state`/`modifiedAt` unconditional, every other field only `if` present/non-empty.
- **Side effects:** None.
- **Algorithm:** Spread-then-known-fields shape identical to
  [`ServiceEndpoint.toJson`](#serviceendpoint-tojson); `endpoints` serialized via
  `endpoints.map((e) => e.toJson()).toList()` only `if (endpoints.isNotEmpty)`.
- **Usage:** Called by [`ServiceData.toJson`](#servicedata-tojson) for each entry of
  `services`, and by [`mergeUnknownFieldsFrom`](#servicenode-mergeunknownfieldsfrom).
- **Notes:** None.

### `factory ServiceNode.fromJson(Map<String, dynamic> json)` <a id="servicenode-fromjson"></a>
- **Kind:** factory constructor of `ServiceNode`.
- **Source:** `lib/features/services/models/service.dart` (line 548).
- **Purpose:** Parse a `ServiceNode` from JSON.
- **Inputs:** `json`.
- **Returns:** A new `ServiceNode`; `extraJson` holds every key not in
  `_serviceNodeJsonKeys`.
- **Side effects:** None.
- **Algorithm:** Direct field extraction for each known key; `kind`/`runtime`/`state` via
  their enum `fromJson` parsers; `endpoints` mapped through
  [`ServiceEndpoint.fromJson`](#serviceendpoint-fromjson) (defaulting to `[]` if the key
  is absent); `modifiedAt` via `DateTime.parse` (required, throws if missing/malformed).
- **Usage:** Called by [`ServiceData.fromJson`](#servicedata-fromjson) for each entry of
  `json['services']`.
- **Notes:** This declaration has no `/// Purpose:` doc comment in source. Unlike
  [`Device.fromJson`](../../devices/models/device.md#device-fromjson), there is no legacy
  string-shape tolerance here — `ServiceNode` has no equivalent of `Device.storage`'s
  plain-string backward-compatibility path.

### `ServiceNode mergeUnknownFieldsFrom(ServiceNode other, {ServiceNode? base})` <a id="servicenode-mergeunknownfieldsfrom"></a>
- **Kind:** method of `ServiceNode`.
- **Source:** `lib/features/services/models/service.dart` (line 576).
- **Purpose:** Three-way merge this service's unknown JSON fields with another's,
  including merging each endpoint's own unknown fields by matching endpoint `id`.
- **Inputs:** `other`; optional `base`.
- **Returns:** A new `ServiceNode` with merged top-level `extraJson` and, if `endpoints`
  is non-empty, a merged `endpoints` list.
- **Side effects:** None.
- **Algorithm:** 1. Start from `toJson()`, merge in top-level `extraJson` via
  `mergeUnknownJsonFields` same as every other model here. 2. If `endpoints.isNotEmpty`,
  overwrite `json['endpoints']` with, for each of `this`'s endpoints, that endpoint's own
  [`mergeUnknownFieldsFrom`](#serviceendpoint-mergeunknownfieldsfrom) against the
  matching endpoint in `other.endpoints` (matched by `id`, or a fresh empty
  `ServiceEndpoint(id: endpoint.id)` if `other` has no matching endpoint), passing the
  matching entry from `base?.endpoints` too. 3. Re-parse via `ServiceNode.fromJson`.
- **Usage:**
  ```dart
  mergeUnknownFields: (primary, secondary, base) =>
      primary.mergeUnknownFieldsFrom(secondary, base: base),
  ```
  (from `lib/shared/services/sync_merge.dart`'s `mergeRecords<ServiceNode>` call, which
  supplies this as the per-record unknown-field merge callback — see
  [Three-Way Merge](../../../../algorithms/three-way-merge.md))
- **Notes:** Endpoints are matched by `id` for this recursive merge only — the *known*
  fields of each endpoint (protocol, port, etc.) still come entirely from `this`'s side;
  only the nested `extraJson` per endpoint is reconciled three-way, the same restriction
  documented on [`DeviceRecurringCost.mergeUnknownFieldsFrom`](../../devices/models/device.md#devicerecurringcost-mergeunknownfieldsfrom).

### `ServiceRouteHop({String? id, this.type = ServiceRouteHopType.manual, this.serviceId, this.endpointId, this.deviceId, this.label, this.scheme, this.host, this.port, this.path, this.method, this.notes, this.extraJson = const {}})` <a id="serviceroutehop-new"></a>
- **Kind:** constructor of `ServiceRouteHop`.
- **Source:** `lib/features/services/models/service.dart` (line 625).
- **Purpose:** Create one hop of a service route, generating a fresh UUID `id` when none
  is supplied.
- **Inputs:** All fields optional; `type` defaults to `manual`.
- **Returns:** A new `ServiceRouteHop`.
- **Side effects:** None (beyond `Uuid().v4()` when `id` is null).
- **Algorithm:** `id = id ?? const Uuid().v4()`; every other field plain-assigned.
- **Usage:**
  ```dart
  return ServiceRouteHop(
    type: ServiceRouteHopType.portForward,
    method: method,
    serviceId: _relayServiceId,
    deviceId: _remoteDeviceId,
    label: _relayServiceId == null ? serviceRouteMethodLabel(method) : null,
    host: _emptyToNull(_remoteHostCtrl.text),
    port: int.tryParse(_remotePortCtrl.text.trim()),
  );
  ```
  (from `service_list_page.dart`'s `_buildHop`, the quick access-route creation flow's
  single-hop builder — see
  [Services and Topology](../../../../features/services-topology.md#quick-access-route-creation-vs-the-advanced-editor);
  also constructed directly by `service_route_edit_page.dart`'s advanced multi-hop editor
  dialog)
- **Notes:** None.

### `ServiceRouteHop copyWith({...})` <a id="serviceroutehop-copywith"></a>
- **Kind:** method of `ServiceRouteHop`.
- **Source:** `lib/features/services/models/service.dart` (line 641).
- **Purpose:** Create a copy of this hop with any subset of fields replaced, or
  explicitly cleared via a `clearXxx` flag (one per nullable field: `serviceId`,
  `endpointId`, `deviceId`, `label`, `scheme`, `host`, `port`, `path`, `method`, `notes`).
- **Inputs:** One optional parameter per mutable field, plus ten `clearXxx` flags.
- **Returns:** A new `ServiceRouteHop` — same `id` and `extraJson` as `this`.
- **Side effects:** None.
- **Algorithm:** Same clear-flag-priority shape as
  [`ServiceEndpoint.copyWith`](#serviceendpoint-copywith).
- **Usage:** No call site exists anywhere in `lib/` — hops are always replaced wholesale
  (a route's `hops` list is rebuilt or a fresh `ServiceRouteHop` constructed, per the
  constructor's own Usage example) rather than copied field-by-field.
- **Notes:** This declaration has no `/// Purpose:` doc comment in source. This is the
  third of three `copyWith` methods in this file with no current call site (alongside
  [`ServiceEndpoint.copyWith`](#serviceendpoint-copywith) and
  [`ServiceNode.copyWith`](#servicenode-copywith)) — only
  [`ServiceRoute.copyWith`](#serviceroute-copywith) is actually called anywhere in this
  codebase.

### `Map<String, dynamic> toJson()` (`ServiceRouteHop`) <a id="serviceroutehop-tojson"></a>
- **Kind:** method of `ServiceRouteHop`.
- **Source:** `lib/features/services/models/service.dart` (line 686).
- **Purpose:** Serialize this hop into the JSON persisted inside a route's `hops` list.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` — `extraJson` spread first, `id`/`type`
  unconditional, every other field only `if` present/non-empty.
- **Side effects:** None.
- **Algorithm:** Same spread-then-known-fields shape as the other `toJson` methods in
  this file; `type`/`method` serialized via `.jsonValue`.
- **Usage:** Called by [`ServiceRoute.toJson`](#serviceroute-tojson) for each entry of
  `hops`, and by
  [`mergeUnknownFieldsFrom`](#serviceroutehop-mergeunknownfieldsfrom).
- **Notes:** None.

### `factory ServiceRouteHop.fromJson(Map<String, dynamic> json)` <a id="serviceroutehop-fromjson"></a>
- **Kind:** factory constructor of `ServiceRouteHop`.
- **Source:** `lib/features/services/models/service.dart` (line 707).
- **Purpose:** Parse a `ServiceRouteHop` from JSON.
- **Inputs:** `json`.
- **Returns:** A new `ServiceRouteHop`; `extraJson` holds every key not in
  `_serviceRouteHopJsonKeys`.
- **Side effects:** None.
- **Algorithm:** Direct field extraction; `type` via
  [`ServiceRouteHopType.fromJson`](#serviceroutehoptype-fromjson) (defaulting to
  `manual`); `method` via
  [`ServiceRouteMethod.fromJson`](#serviceroutemethod-fromjson) (nullable, no fallback).
- **Usage:** Called by [`ServiceRoute.fromJson`](#serviceroute-fromjson) for each entry
  of `json['hops']`.
- **Notes:** None.

### `ServiceRouteHop mergeUnknownFieldsFrom(ServiceRouteHop other, {ServiceRouteHop? base})` <a id="serviceroutehop-mergeunknownfieldsfrom"></a>
- **Kind:** method of `ServiceRouteHop`.
- **Source:** `lib/features/services/models/service.dart` (line 729).
- **Purpose:** Three-way merge this hop's unknown JSON fields with another's.
- **Inputs:** `other`; optional `base`.
- **Returns:** A new `ServiceRouteHop` with merged `extraJson`.
- **Side effects:** None.
- **Algorithm:** Identical shape to
  [`ServiceEndpoint.mergeUnknownFieldsFrom`](#serviceendpoint-mergeunknownfieldsfrom).
- **Usage:** Called by [`ServiceRoute.mergeUnknownFieldsFrom`](#serviceroute-mergeunknownfieldsfrom)
  once per index-aligned pair of `hops` entries (matched by `id`).
- **Notes:** None.

### `ServiceRoute({String? id, required this.name, required this.sourceServiceId, this.sourceEndpointId, this.hops = const [], this.finalUrl, this.accessLevel = ServiceAccessLevel.lan, this.notes, DateTime? modifiedAt, this.extraJson = const {}})` <a id="serviceroute-new"></a>
- **Kind:** constructor of `ServiceRoute`.
- **Source:** `lib/features/services/models/service.dart` (line 761).
- **Purpose:** Create a manually recorded access path, generating a fresh UUID `id` and
  UTC `modifiedAt` timestamp when neither is supplied.
- **Inputs:** `name`, `sourceServiceId` required; every other field optional (`hops`
  defaults to `[]`, `accessLevel` to `lan`).
- **Returns:** A new `ServiceRoute`.
- **Side effects:** None (beyond `Uuid().v4()`/`DateTime.now()` calls).
- **Algorithm:** `id = id ?? const Uuid().v4()`, `modifiedAt = modifiedAt ??
  DateTime.now().toUtc()`; every other field plain-assigned.
- **Usage:**
  ```dart
  final route = ServiceRoute(
    id: existing?.id,
    name: serviceRouteGeneratedName(
      sourceName: source?.name ?? existing?.name ?? '',
      hops: _hops,
      targets: targets,
    ),
    sourceServiceId: _sourceServiceId!,
    sourceEndpointId: _sourceEndpointId,
    hops: _hops,
    finalUrl: targets.firstOrNull,
    accessLevel: _accessLevel,
    notes: _emptyToNull(_notesCtrl.text),
    extraJson: serviceRouteExtraJsonWithTargets(existing?.extraJson ?? const {}, targets),
  );
  ```
  (from `service_route_edit_page.dart`'s save handler; the route `name` is always
  machine-generated via
  [`serviceRouteGeneratedName`](../services/service_analysis.md#serviceroutegeneratedname)
  rather than user-typed — see
  [Services and Topology](../../../../features/services-topology.md#quick-access-route-creation-vs-the-advanced-editor))
- **Notes:** `finalUrl` stores only the first/primary target for backward compatibility;
  additional grouped URLs sharing the same access path live in
  `extraJson['publicTargets']`, written by
  [`serviceRouteExtraJsonWithTargets`](../services/service_analysis.md#serviceRouteExtraJsonWithTargets)
  rather than by this constructor directly.

### `ServiceRoute copyWith({...})` <a id="serviceroute-copywith"></a>
- **Kind:** method of `ServiceRoute`.
- **Source:** `lib/features/services/models/service.dart` (line 780).
- **Purpose:** Create a copy of this route with any subset of fields replaced, or
  explicitly cleared via `clearSourceEndpointId`/`clearFinalUrl`/`clearNotes`.
- **Inputs:** One optional parameter per mutable field, plus three `clearXxx` flags.
- **Returns:** A new `ServiceRoute` — same `id`/`extraJson` as `this`; `modifiedAt`
  defaults to `DateTime.now().toUtc()` if not explicitly passed, same as
  [`ServiceNode.copyWith`](#servicenode-copywith).
- **Side effects:** None.
- **Algorithm:** Same clear-flag-priority shape as the other `copyWith` methods in this
  file.
- **Usage:**
  ```dart
  final routes = data.routes
      .where((route) => route.sourceServiceId != id)
      .map(
        (route) => route.copyWith(
          hops: route.hops.where((hop) => hop.serviceId != id).toList(),
        ),
      )
      .toList();
  ```
  (from
  [`ServiceStorage.deleteService`](../services/service_storage.md#deleteservice) and
  [`ServiceStorage.removeDeviceReferences`](../services/service_storage.md#removedevicereferences),
  both rebuilding a route's `hops` list while leaving every other field untouched)
- **Notes:** This is the only `copyWith` in this file with a real call site — unlike
  [`ServiceEndpoint.copyWith`](#serviceendpoint-copywith),
  [`ServiceNode.copyWith`](#servicenode-copywith), and
  [`ServiceRouteHop.copyWith`](#serviceroutehop-copywith), which are all currently
  unused. Both call sites pass only `hops:`, relying on every other field defaulting to
  `this`'s current value — but note that still bumps `modifiedAt` to "now" (see
  Algorithm), so a hop-cleanup pass always marks the route as sync-changed even if no hop
  actually needed to be removed for a given route.

### `Map<String, dynamic> toJson()` (`ServiceRoute`) <a id="serviceroute-tojson"></a>
- **Kind:** method of `ServiceRoute`.
- **Source:** `lib/features/services/models/service.dart` (line 814).
- **Purpose:** Serialize this route into the JSON persisted inside `ServiceData.routes`.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` — `extraJson` spread first, `id`/`name`/
  `sourceServiceId`/`accessLevel`/`modifiedAt` unconditional, everything else only `if`
  present/non-empty.
- **Side effects:** None.
- **Algorithm:** Same spread-then-known-fields shape as the other `toJson` methods;
  `hops` serialized via `hops.map((h) => h.toJson()).toList()` only `if
  (hops.isNotEmpty)`.
- **Usage:** Called by [`ServiceData.toJson`](#servicedata-tojson) for each entry of
  `routes`, and by
  [`mergeUnknownFieldsFrom`](#serviceroute-mergeunknownfieldsfrom).
- **Notes:** None.

### `factory ServiceRoute.fromJson(Map<String, dynamic> json)` <a id="serviceroute-fromjson"></a>
- **Kind:** factory constructor of `ServiceRoute`.
- **Source:** `lib/features/services/models/service.dart` (line 832).
- **Purpose:** Parse a `ServiceRoute` from JSON.
- **Inputs:** `json`.
- **Returns:** A new `ServiceRoute`; `extraJson` holds every key not in
  `_serviceRouteJsonKeys` (including `publicTargets`, which is not a known top-level key
  and therefore round-trips through `extraJson` like any other unrecognized field).
- **Side effects:** None.
- **Algorithm:** Direct field extraction; `hops` mapped through
  [`ServiceRouteHop.fromJson`](#serviceroutehop-fromjson) (defaulting to `[]`);
  `accessLevel` via [`ServiceAccessLevel.fromJson`](#serviceaccesslevel-fromjson);
  `modifiedAt` via `DateTime.parse` (required).
- **Usage:** Called by [`ServiceData.fromJson`](#servicedata-fromjson) for each entry of
  `json['routes']`.
- **Notes:** None.

### `ServiceRoute mergeUnknownFieldsFrom(ServiceRoute other, {ServiceRoute? base})` <a id="serviceroute-mergeunknownfieldsfrom"></a>
- **Kind:** method of `ServiceRoute`.
- **Source:** `lib/features/services/models/service.dart` (line 854).
- **Purpose:** Three-way merge this route's unknown JSON fields with another's,
  including merging each hop's own unknown fields by matching hop `id`.
- **Inputs:** `other`; optional `base`.
- **Returns:** A new `ServiceRoute` with merged top-level `extraJson` and, if `hops` is
  non-empty, a merged `hops` list.
- **Side effects:** None.
- **Algorithm:** Same shape as
  [`ServiceNode.mergeUnknownFieldsFrom`](#servicenode-mergeunknownfieldsfrom): re-parse
  `toJson()` merged with the top-level `mergeUnknownJsonFields` result, then (if
  `hops.isNotEmpty`) overwrite `json['hops']` with each hop's own
  [`mergeUnknownFieldsFrom`](#serviceroutehop-mergeunknownfieldsfrom) against the
  matching hop in `other.hops` (by `id`, falling back to a fresh
  `ServiceRouteHop(id: hop.id)`), then re-parse via `ServiceRoute.fromJson`.
- **Usage:**
  ```dart
  mergeUnknownFields: (primary, secondary, base) =>
      primary.mergeUnknownFieldsFrom(secondary, base: base),
  ```
  (from `lib/shared/services/sync_merge.dart`'s `mergeRecords<ServiceRoute>` call, the
  routes-side counterpart to
  [`ServiceNode.mergeUnknownFieldsFrom`](#servicenode-mergeunknownfieldsfrom)'s usage)
- **Notes:** Because `publicTargets` lives inside `extraJson` (not a declared field),
  this method's generic `extraJson` three-way merge is also what reconciles a route's
  grouped public targets across a sync, not a dedicated field-level merge rule.

### `const ServiceData({this.services = const [], this.routes = const [], this.extraJson = const {}})` <a id="servicedata-new"></a>
- **Kind:** constructor of `ServiceData`.
- **Source:** `lib/features/services/models/service.dart` (line 894).
- **Purpose:** Hold the complete service inventory: every `ServiceNode` and every
  `ServiceRoute`, plus any unrecognized top-level JSON fields.
- **Inputs:** All fields optional, defaulting to empty.
- **Returns:** A new `ServiceData`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment (this is the only `const` constructor among
  the file's non-enum types with a fresh-id/timestamp pattern — `ServiceData` itself has
  no `id`/`modifiedAt`, being a singleton top-level container rather than a per-record
  model).
- **Usage:**
  ```dart
  await save(
    ServiceData(services: services, routes: data.routes, extraJson: data.extraJson),
  );
  ```
  (from [`ServiceStorage.addOrUpdateService`](../services/service_storage.md#addorupdateservice)
  and every other `ServiceStorage` mutator, each reconstructing a full `ServiceData` to
  pass to [`ServiceStorage.save`](../services/service_storage.md#save); `const
  ServiceData()` on its own is `ServiceStorage.load()`'s empty-file fallback)
- **Notes:** Unlike `Device`/`ServiceNode`/`ServiceRoute`, `ServiceData` has no
  `mergeUnknownFieldsFrom` of its own — its two lists (`services`/`routes`) are merged
  independently as top-level `mergeRecords<T>` collections in
  `lib/shared/services/sync_merge.dart`, not merged as a whole document the way a nested
  value object (like `CpuInfo` inside `Device`) would be.

### `Map<String, dynamic> toJson()` (`ServiceData`) <a id="servicedata-tojson"></a>
- **Kind:** method of `ServiceData`.
- **Source:** `lib/features/services/models/service.dart` (line 905).
- **Purpose:** Serialize the full service inventory into the JSON persisted as
  `service_data.json`.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` with `services`/`routes` always present (even if
  empty, unlike every nested model's `toJson`, which omits empty list fields).
- **Side effects:** None.
- **Algorithm:** `{...extraJson, 'services': services.map((s) =>
  s.toJson()).toList(), 'routes': routes.map((r) => r.toJson()).toList()}`.
- **Usage:** Called by
  [`ServiceStorage.save`](../services/service_storage.md#save) via `data.toJson()`.
- **Notes:** `services`/`routes` are written unconditionally (no `if (...isNotEmpty)`
  guard), unlike the list fields on `ServiceNode`/`ServiceRoute` — an empty inventory
  still serializes as `{"services": [], "routes": []}` rather than `{}`.

### `factory ServiceData.fromJson(Map<String, dynamic> json)` <a id="servicedata-fromjson"></a>
- **Kind:** factory constructor of `ServiceData`.
- **Source:** `lib/features/services/models/service.dart` (line 916).
- **Purpose:** Parse a `ServiceData` from JSON.
- **Inputs:** `json`.
- **Returns:** A new `ServiceData`; `extraJson` holds every key not in
  `_serviceDataJsonKeys` (`{'services', 'routes'}`).
- **Side effects:** None.
- **Algorithm:** Map `json['services']` through
  [`ServiceNode.fromJson`](#servicenode-fromjson) and `json['routes']` through
  [`ServiceRoute.fromJson`](#serviceroute-fromjson), each defaulting to `[]` if the key
  is absent.
- **Usage:**
  ```dart
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return ServiceData.fromJson(json);
  ```
  (from [`ServiceStorage.load`](../services/service_storage.md#load))
- **Notes:** None.
