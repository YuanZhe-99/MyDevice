# lib/features/network/models/network.dart

Model source for [Networks](../../../../features/networks.md). Defines `NetworkType`/`AddressMode`
(the two serialization enums), `Network` (a LAN/VPN overlay definition), `NetworkDevice` (a
device's membership/assignment in a network), and the top-level `NetworkData` container persisted
by [`../services/network_storage.md`](../services/network_storage.md). Every model here follows the
app's standard shape — a plain/const constructor, `toJson`/`fromJson`, and a
`mergeUnknownFieldsFrom` built on the generic
[`../../../../shared/utils/json_preservation.md`](../../../shared/utils/json_preservation.md)
helpers — with one deliberate exception: `NetworkDevice` has **no `id` and no `modifiedAt`** at all.
See [Networks](../../../../features/networks.md#composite-key-identity--and-why) for why (the
`(networkId, deviceId)` pair is already a unique key, and the missing timestamp is what forces
`mergeAssignments` in `sync_merge.dart` to do
[content-comparison merge](../../../../algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)
instead of the timestamp-based `mergeRecords<T>` every other model uses. See
[Data Formats](../../../../data-formats.md#network--networkdevice-libfeaturesnetworkmodelsnetworkdart)
for the exhaustive persisted-field reference.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `jsonValue` | getter (`NetworkType`) | B | Return the serialized enum name. |
| [`NetworkType.fromJson`](#networktype-fromjson) | static method | A | Parse a `NetworkType`, defaulting to `other` on no match. |
| [`jsonValue`](#jsonvalue) | getter (`AddressMode`) | A | Return the serialized address-mode string (`"dhcp"`/`"static"`). |
| [`AddressMode.fromJson`](#addressmode-fromjson) | static method | A | Parse an `AddressMode`, defaulting to `dhcp`. |
| [`Network`](#network-new) | constructor | A | Create a `Network` instance (fresh `id`/`modifiedAt` by default). |
| [`copyWith`](#network-copywith) | method (`Network`) | A | Create a copy with selected fields replaced or cleared. |
| [`toJson`](#network-tojson) | method (`Network`) | A | Serialize this value into a JSON-compatible map. |
| [`Network.fromJson`](#network-fromjson) | factory constructor | A | Parse a `Network` from JSON. |
| [`mergeUnknownFieldsFrom`](#network-mergeunknownfieldsfrom) | method (`Network`) | A | Three-way merge unknown JSON fields from another `Network`. |
| [`NetworkDevice`](#networkdevice-new) | constructor | A | Create a `NetworkDevice` instance (no `id`/`modifiedAt`). |
| [`copyWith`](#networkdevice-copywith) | method (`NetworkDevice`) | A | Create a copy with selected fields replaced or cleared. |
| [`toJson`](#networkdevice-tojson) | method (`NetworkDevice`) | A | Serialize this value into a JSON-compatible map. |
| [`NetworkDevice.fromJson`](#networkdevice-fromjson) | factory constructor | A | Parse a `NetworkDevice` from JSON. |
| [`mergeUnknownFieldsFrom`](#networkdevice-mergeunknownfieldsfrom) | method (`NetworkDevice`) | A | Three-way merge unknown JSON fields from another `NetworkDevice`. |
| [`NetworkData`](#networkdata-new) | constructor | A | Create a `NetworkData` instance. |
| [`toJson`](#networkdata-tojson) | method (`NetworkData`) | A | Serialize this value into a JSON-compatible map. |
| [`NetworkData.fromJson`](#networkdata-fromjson) | factory constructor | A | Parse a `NetworkData` from JSON. |

Row count (17) matches `grep -c 'Purpose:' network.dart` (17) exactly.

## Documentation

### `static NetworkType fromJson(String value)` <a id="networktype-fromjson"></a>
- **Kind:** static method of enum `NetworkType`.
- **Source:** `lib/features/network/models/network.dart` (line 48).
- **Purpose:** Parse a `NetworkType` from its serialized name, defaulting to `other` for any
  unrecognized value.
- **Inputs:** `value`.
- **Returns:** `NetworkType` — never `null`.
- **Side effects:** None.
- **Algorithm:** `NetworkType.values.firstWhere((e) => e.name == value, orElse: () =>
  NetworkType.other)`.
- **Usage:**
  ```dart
  type: NetworkType.fromJson(json['type'] as String),
  ```
  (from [`Network.fromJson`](#network-fromjson))
- **Notes:** An unrecognized or future `type` string degrades to `other` rather than throwing,
  so a network created by a newer app version with a type this build doesn't know about still
  round-trips without crashing.

### `String get jsonValue` (AddressMode) <a id="jsonvalue"></a>
- **Kind:** getter of enum `AddressMode`.
- **Source:** `lib/features/network/models/network.dart` (line 64).
- **Purpose:** Return the serialized string for this address mode — `"dhcp"` or `"static"`.
- **Inputs:** None.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** `switch (this) { AddressMode.dhcp => 'dhcp', AddressMode.static_ => 'static' }`.
- **Usage:**
  ```dart
  'addressMode': addressMode.jsonValue,
  ```
  (from [`NetworkDevice.toJson`](#networkdevice-tojson))
- **Notes:** Unlike `NetworkType.jsonValue` (which is a plain `=> name`), this getter cannot use
  `name` directly — the enum value is spelled `static_` (trailing underscore, to dodge the `static`
  keyword) but the persisted JSON string must be the keyword-free `"static"`. See
  [Networks](../../../../features/networks.md) for the same quirk described from the data-format
  side.

### `static AddressMode fromJson(String value)` <a id="addressmode-fromjson"></a>
- **Kind:** static method of enum `AddressMode`.
- **Source:** `lib/features/network/models/network.dart` (line 74).
- **Purpose:** Parse an `AddressMode` from its serialized string, defaulting to `dhcp` for any
  value other than exactly `"static"`.
- **Inputs:** `value`.
- **Returns:** `AddressMode` — never `null`.
- **Side effects:** None.
- **Algorithm:** `switch (value) { 'static' => AddressMode.static_, _ => AddressMode.dhcp }`.
- **Usage:**
  ```dart
  addressMode: AddressMode.fromJson(json['addressMode'] as String? ?? 'dhcp'),
  ```
  (from [`NetworkDevice.fromJson`](#networkdevice-fromjson))
- **Notes:** `dhcp` is the fallback for both "absent" and "unrecognized" — matching the
  constructor's own default (`this.addressMode = AddressMode.dhcp`).

### `Network({String? id, required this.name, required this.type, this.subnet, this.gateway, this.dnsServers = const [], this.notes, DateTime? modifiedAt, this.extraJson = const {}})` <a id="network-new"></a>
- **Kind:** constructor of `Network`.
- **Source:** `lib/features/network/models/network.dart` (line 97).
- **Purpose:** Create a network record, generating a fresh UUID `id` and UTC `modifiedAt` when
  neither is supplied.
- **Inputs:** `name`, `type` required; `subnet`/`gateway`/`notes` optional; `dnsServers` defaults to
  `[]`; `id`/`modifiedAt` auto-generated when omitted.
- **Returns:** A new `Network`.
- **Side effects:** None (beyond `Uuid().v4()`/`DateTime.now()` — no I/O).
- **Algorithm:** `id = id ?? const Uuid().v4()`, `modifiedAt = modifiedAt ?? DateTime.now().toUtc()`
  in the initializer list; remaining fields plain-assigned.
- **Usage:**
  ```dart
  final network = Network(
    id: widget.network?.id,
    name: _nameCtrl.text.trim(),
    type: _type,
    subnet: _nonEmpty(_subnetCtrl.text),
    gateway: _nonEmpty(_gatewayCtrl.text),
    dnsServers: dnsServers,
    notes: _nonEmpty(_notesCtrl.text),
    extraJson: widget.network?.extraJson ?? const {},
  );
  ```
  (from [`network_edit_page.md`](../views/network_edit_page.md)'s save handler; passing
  `widget.network?.id` preserves the same `id` across an edit rather than minting a new one)
- **Notes:** `modifiedAt` always refreshes to "now" unless explicitly overridden — this is the
  timestamp `mergeRecords<Network>` uses to detect which side changed during sync (see
  [Three-Way Merge](../../../../algorithms/three-way-merge.md)). This is the ordinary,
  timestamp-based merge path — unlike `NetworkDevice` below, `Network` has a real `id`/`modifiedAt`
  pair.

### `Network copyWith({String? name, NetworkType? type, String? subnet, String? gateway, List<String>? dnsServers, String? notes, DateTime? modifiedAt, bool clearSubnet = false, bool clearGateway = false, bool clearNotes = false})` <a id="network-copywith"></a>
- **Kind:** method of `Network`.
- **Source:** `lib/features/network/models/network.dart` (line 115).
- **Purpose:** Create a copy of this network with selected fields replaced, and optionally clear
  `subnet`/`gateway`/`notes` back to `null` explicitly.
- **Inputs:** Any field to override; `clearSubnet`/`clearGateway`/`clearNotes` — explicit-clear
  flags, since passing `null` for a field is indistinguishable from "don't change it" otherwise.
- **Returns:** A new `Network` — `id` is always preserved from `this`; `modifiedAt` defaults to
  "now" if not explicitly passed.
- **Side effects:** None.
- **Algorithm:** For each nullable field, `clearX ? null : (x ?? this.x)` — the clear flag takes
  priority over both the new value and the existing value.
- **Usage:** Not called anywhere in the current codebase (`network_edit_page.dart` constructs a
  fresh `Network(...)` directly instead — see [`Network`](#network-new) above); provided for parity
  with the app's other models and available for future callers.
- **Notes:** `extraJson` is always carried over unchanged from `this` — `copyWith` cannot alter or
  clear unknown fields; only [`mergeUnknownFieldsFrom`](#network-mergeunknownfieldsfrom) does that.

### `Map<String, dynamic> toJson()` <a id="network-tojson"></a>
- **Kind:** method of `Network`.
- **Source:** `lib/features/network/models/network.dart` (line 145).
- **Purpose:** Serialize this network into the JSON persisted inside `network_data.json`'s
  `networks` array.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` — `extraJson` spread first, then `id`/`name`/`type` always,
  `subnet`/`gateway`/`notes`/`dnsServers` only when set/non-empty, `modifiedAt` as ISO-8601.
- **Side effects:** None.
- **Algorithm:** `{...extraJson, if (field-present) 'field': field, ...}` for each optional field.
- **Usage:** Called by [`NetworkData.toJson`](#networkdata-tojson) for each entry of `networks`, and
  by [`mergeUnknownFieldsFrom`](#network-mergeunknownfieldsfrom).
- **Notes:** Spreading `extraJson` before the known fields means a known field always wins if an
  unrecognized key happens to collide with a known key name.

### `factory Network.fromJson(Map<String, dynamic> json)` <a id="network-fromjson"></a>
- **Kind:** factory constructor of `Network`.
- **Source:** `lib/features/network/models/network.dart` (line 162).
- **Purpose:** Parse a `Network` from JSON.
- **Inputs:** `json`.
- **Returns:** A new `Network`; `extraJson` holds every key not in `_networkJsonKeys`.
- **Side effects:** None.
- **Algorithm:** Direct field extraction for each known key; `type` via
  [`NetworkType.fromJson`](#networktype-fromjson); `dnsServers` maps a `List<dynamic>` to
  `List<String>` or defaults to `[]` if absent; `modifiedAt` via `DateTime.parse`.
- **Usage:** Called by [`NetworkData.fromJson`](#networkdata-fromjson) for each entry of
  `json['networks']`.
- **Notes:** None.

### `Network mergeUnknownFieldsFrom(Network other, {Network? base})` <a id="network-mergeunknownfieldsfrom"></a>
- **Kind:** method of `Network`.
- **Source:** `lib/features/network/models/network.dart` (line 181).
- **Purpose:** Three-way merge this `Network`'s unknown JSON fields with another's, so unrecognized
  keys survive a sync merge the same way known fields do.
- **Inputs:** `other` — the other side (typically remote when `this` is local); optional `base` —
  the last-synced snapshot.
- **Returns:** A new `Network` — same known fields as `this`, `extraJson` replaced by the merged
  result.
- **Side effects:** None.
- **Algorithm:** Re-parse `{...toJson(), ...mergeUnknownJsonFields(primary: extraJson, secondary:
  other.extraJson, base: base?.extraJson)}` through `Network.fromJson` — see
  [`mergeUnknownJsonFields`](../../../shared/utils/json_preservation.md) for the underlying
  per-key three-way merge rule.
- **Usage:** Called by `mergeRecords<Network>` in `sync_merge.dart` alongside the known-field merge
  (see [Three-Way Merge](../../../../algorithms/three-way-merge.md)).
- **Notes:** Only `extraJson` is merged here — the known fields (`name`, `type`, etc.) always come
  from `this` (the primary side).

### `const NetworkDevice({required this.networkId, required this.deviceId, this.addressMode = AddressMode.dhcp, this.ipAddress, this.hostname, this.isExitNode = false, this.extraJson = const {}})` <a id="networkdevice-new"></a>
- **Kind:** constructor of `NetworkDevice`.
- **Source:** `lib/features/network/models/network.dart` (line 208).
- **Purpose:** Create a device's membership/assignment record for a network — which device, its
  address mode, optional static IP/hostname, and whether it acts as the network's exit node.
- **Inputs:** `networkId`, `deviceId` required; `addressMode` defaults to `dhcp`; `ipAddress`/
  `hostname` optional; `isExitNode` defaults to `false`.
- **Returns:** A new `NetworkDevice`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment with defaults — notably **no `id` and no `modifiedAt`**
  field exist on this class at all.
- **Usage:**
  ```dart
  NetworkDevice(networkId: widget.networkId, deviceId: device.id),
  ```
  (from [`network_detail_page.md`](../views/network_detail_page.md)'s `_addDevice`, as the seed
  passed to the assignment-configuration dialog)
- **Notes:** The `(networkId, deviceId)` pair is the record's natural unique key — see
  [Networks](../../../../features/networks.md#composite-key-identity--and-why) for why a
  synthetic `id` would be redundant here, and why the missing `modifiedAt` forces sync to use
  content comparison
  ([`mergeAssignments`](../../../../algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge))
  instead of timestamp comparison for this one model.

### `NetworkDevice copyWith({AddressMode? addressMode, String? ipAddress, String? hostname, bool? isExitNode, bool clearIpAddress = false, bool clearHostname = false})` <a id="networkdevice-copywith"></a>
- **Kind:** method of `NetworkDevice`.
- **Source:** `lib/features/network/models/network.dart` (line 223).
- **Purpose:** Create a copy of this assignment with selected fields replaced, and optionally clear
  `ipAddress`/`hostname` back to `null` explicitly.
- **Inputs:** Any field to override; `clearIpAddress`/`clearHostname` — explicit-clear flags.
  `networkId`/`deviceId` cannot be changed (there is no parameter for them — they always come from
  `this`, since changing either would change the record's identity).
- **Returns:** A new `NetworkDevice`.
- **Side effects:** None.
- **Algorithm:** Same `clearX ? null : (x ?? this.x)` shape as [`Network.copyWith`](#network-copywith).
- **Usage:** Not called anywhere in the current codebase (`network_detail_page.dart` constructs a
  fresh `NetworkDevice(...)` directly in `_showAssignmentDialog` instead); provided for parity with
  the app's other models.
- **Notes:** Because `networkId`/`deviceId` aren't parameters here, `copyWith` can never accidentally
  re-key a `NetworkDevice` to a different network/device pair.

### `Map<String, dynamic> toJson()` <a id="networkdevice-tojson"></a>
- **Kind:** method of `NetworkDevice`.
- **Source:** `lib/features/network/models/network.dart` (line 247).
- **Purpose:** Serialize this assignment into the JSON persisted inside `network_data.json`'s
  `assignments` array.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` — `extraJson` spread first, then `networkId`/`deviceId`/
  `addressMode` always, `ipAddress`/`hostname` only when set, `isExitNode` only when `true`
  (omitted entirely when `false`).
- **Side effects:** None.
- **Algorithm:** Same spread-then-known-fields shape as [`Network.toJson`](#network-tojson);
  `addressMode` serialized via [`jsonValue`](#jsonvalue).
- **Usage:** Called by [`NetworkData.toJson`](#networkdata-tojson) for each entry of `assignments`,
  and by [`mergeUnknownFieldsFrom`](#networkdevice-mergeunknownfieldsfrom).
- **Notes:** `isExitNode` being omitted (rather than written as `false`) when unset keeps the
  persisted JSON compact; [`fromJson`](#networkdevice-fromjson) treats an absent key the same as
  `false`.

### `factory NetworkDevice.fromJson(Map<String, dynamic> json)` <a id="networkdevice-fromjson"></a>
- **Kind:** factory constructor of `NetworkDevice`.
- **Source:** `lib/features/network/models/network.dart` (line 262).
- **Purpose:** Parse a `NetworkDevice` from JSON.
- **Inputs:** `json`.
- **Returns:** A new `NetworkDevice`; `extraJson` holds every key not in `_networkDeviceJsonKeys`.
- **Side effects:** None.
- **Algorithm:** Direct field extraction; `addressMode` via
  [`AddressMode.fromJson`](#addressmode-fromjson) with a `'dhcp'` default when the key is absent;
  `isExitNode` defaults to `false` when absent.
- **Usage:** Called by [`NetworkData.fromJson`](#networkdata-fromjson) for each entry of
  `json['assignments']`.
- **Notes:** None.

### `NetworkDevice mergeUnknownFieldsFrom(NetworkDevice other, {NetworkDevice? base})` <a id="networkdevice-mergeunknownfieldsfrom"></a>
- **Kind:** method of `NetworkDevice`.
- **Source:** `lib/features/network/models/network.dart` (line 277).
- **Purpose:** Three-way merge this `NetworkDevice`'s unknown JSON fields with another's.
- **Inputs:** `other`; optional `base`.
- **Returns:** A new `NetworkDevice` with merged `extraJson`.
- **Side effects:** None.
- **Algorithm:** Identical shape to [`Network.mergeUnknownFieldsFrom`](#network-mergeunknownfieldsfrom).
- **Usage:** Called by `mergeAssignments` in `sync_merge.dart` alongside its composite-key
  content-comparison merge (see
  [Three-Way Merge](../../../../algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)).
- **Notes:** Only `extraJson` is merged; the known fields still come from `this`. This is the
  *unknown-field* merge only — the decision of *which side's `NetworkDevice` wins at all* (since
  there's no `modifiedAt` to compare) happens one level up, in `mergeAssignments` itself, not in
  this method.

### `const NetworkData({this.networks = const [], this.assignments = const [], this.extraJson = const {}})` <a id="networkdata-new"></a>
- **Kind:** constructor of `NetworkData`.
- **Source:** `lib/features/network/models/network.dart` (line 303).
- **Purpose:** Hold the full persisted network dataset: every `Network` plus every `NetworkDevice`
  assignment.
- **Inputs:** `networks`, `assignments` both default to `[]`.
- **Returns:** A new `NetworkData`.
- **Side effects:** None.
- **Algorithm:** Trivial field assignment with defaults.
- **Usage:**
  ```dart
  await save(NetworkData(networks: networks, assignments: data.assignments));
  ```
  (from [`network_storage.md`](../services/network_storage.md)'s `addOrUpdateNetwork`)
- **Notes:** None.

### `Map<String, dynamic> toJson()` <a id="networkdata-tojson"></a>
- **Kind:** method of `NetworkData`.
- **Source:** `lib/features/network/models/network.dart` (line 314).
- **Purpose:** Serialize the full network dataset into the JSON written to `network_data.json`.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` with `networks` and `assignments` arrays.
- **Side effects:** None.
- **Algorithm:** `{...extraJson, 'networks': networks.map(toJson), 'assignments':
  assignments.map(toJson)}`.
- **Usage:** Called by [`network_storage.md`](../services/network_storage.md)'s `save`.
- **Notes:** None.

### `factory NetworkData.fromJson(Map<String, dynamic> json)` <a id="networkdata-fromjson"></a>
- **Kind:** factory constructor of `NetworkData`.
- **Source:** `lib/features/network/models/network.dart` (line 325).
- **Purpose:** Parse a `NetworkData` from the JSON stored in `network_data.json`.
- **Inputs:** `json`.
- **Returns:** A new `NetworkData`; both lists default to `[]` if their key is absent.
- **Side effects:** None.
- **Algorithm:** Maps `json['networks']`/`json['assignments']` through
  [`Network.fromJson`](#network-fromjson)/[`NetworkDevice.fromJson`](#networkdevice-fromjson)
  respectively.
- **Usage:** Called by [`network_storage.md`](../services/network_storage.md)'s `load`.
- **Notes:** None.
