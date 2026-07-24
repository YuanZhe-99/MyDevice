# lib/shared/utils/json_preservation.dart

The generic unknown-JSON-field preservation engine referenced throughout
[../../../data-formats.md](../../../data-formats.md) and [../../../algorithms/three-way-merge.md](../../../algorithms/three-way-merge.md).
Unlike MyDay's `json_preservation.dart` (which also bakes in per-model field schemas), MyDevice's
version is purely generic — schema-free, model-agnostic — at only 2.6KB.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`unknownJsonFields`](#unknownjsonfields) | top-level function | A | Extract JSON keys not in a known-keys set. |
| [`mergeUnknownJsonFields`](#mergeunknownjsonfields) | top-level function | A | Three-way merge of unknown-field maps. |
| [`jsonValueEquals`](#jsonvalueequals) | top-level function | A | Deep-equality check for arbitrary JSON values. |
| [`_canonicalJson`](#canonicaljson) | top-level function | A | Recursively sort map keys for canonical comparison. |

## Documentation

### `Map<String, dynamic> unknownJsonFields(Map<String, dynamic> json, Set<String> knownKeys)` <a id="unknownjsonfields"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/json_preservation.dart` (line 8).
- **Purpose:** Extract every key in `json` that is not in `knownKeys`, for storage as a model's
  `extraJson` field.
- **Inputs:** `json` — a decoded JSON object; `knownKeys` — the set of field names the calling
  model already parses explicitly.
- **Returns:** `Map<String, dynamic>` containing only the unrecognized entries.
- **Side effects:** None.
- **Algorithm:** A map-comprehension filter: include `entry.key: entry.value` only when
  `!knownKeys.contains(entry.key)`.
- **Usage:** Called from every model's `fromJson` (e.g. `Device.fromJson`, `Network.fromJson`,
  `ServiceNode.fromJson`) to populate its `extraJson` field so forward-compatible unknown fields
  survive a parse→edit→write round trip.
- **Notes:** This is the generic half of the app's "no app-specific knowledge belongs in shared
  code" convention — the caller supplies `knownKeys`, this function has no notion of any model's
  schema.

### `Map<String, dynamic> mergeUnknownJsonFields({required Map<String, dynamic> primary, required Map<String, dynamic> secondary, Map<String, dynamic>? base})` <a id="mergeunknownjsonfields"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/json_preservation.dart` (line 21).
- **Purpose:** Three-way merge of two records' unknown-field maps so unknown fields survive sync
  merges the same way known fields do.
- **Inputs:** `primary` — the side that wins ties (typically local); `secondary` — the other side
  (typically remote); `base` — the last-synced snapshot, optional.
- **Returns:** `Map<String, dynamic>` — the merged unknown-field map.
- **Side effects:** None.
- **Algorithm:** For the union of keys across `primary`/`secondary`/`base`: if both sides have the
  key and there is a `base` value, keep `secondary`'s value only when `primary` is unchanged from
  base *and* `secondary` has changed from base (i.e. only-remote-changed auto-resolves to remote);
  in every other both-present case, `primary` wins. If only one side has the key, use that side's
  value. If neither side has the key (it existed in `base` but was removed from both), it is
  dropped from the result via `result.remove(key)`.
- **Usage:** Called by the generic merge engine in `sync_merge.dart` (see
  [../services/sync_merge.md](../services/sync_merge.md)) alongside each model's known-field merge,
  so a record's `extraJson` participates in the same three-way conflict logic as its modeled
  fields.
- **Notes:** This mirrors the per-record three-way merge semantics documented in
  [../../../sync.md](../../../sync.md) (auto-resolve when only one side changed), applied at the
  granularity of individual unknown JSON keys rather than whole records.

### `bool jsonValueEquals(Object? a, Object? b)` <a id="jsonvalueequals"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/json_preservation.dart` (line 64).
- **Purpose:** Deep-compare two arbitrary JSON-decoded values (maps/lists/primitives) for logical
  equality, independent of map key insertion order.
- **Inputs:** `a`, `b` — any JSON-decodable value.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Canonicalize both values via `_canonicalJson` (which sorts map keys
  recursively), then compare their `jsonEncode` string output for exact equality.
- **Usage:** Called by `mergeUnknownJsonFields` to detect whether `primary`/`secondary` changed
  relative to `base`, and is reusable anywhere a value-equality (not reference-equality) check on
  decoded JSON is needed.
- **Notes:** Comparing via re-serialized canonical JSON is a simple way to get deep, order-
  independent equality without hand-writing a recursive comparator for every value shape.

### `Object? _canonicalJson(Object? value)` <a id="canonicaljson"></a>
- **Kind:** top-level function.
- **Source:** `lib/shared/utils/json_preservation.dart` (line 72).
- **Purpose:** Recursively rewrite a decoded JSON value into a canonical form (map keys sorted)
  so two structurally-equal-but-differently-ordered maps serialize identically.
- **Inputs:** `value` — any JSON-decodable value.
- **Returns:** `Object?` — the same structure with every nested `Map`'s keys sorted
  lexicographically; `List`s are mapped recursively; other values pass through unchanged.
- **Side effects:** None.
- **Algorithm:** If `value` is a `Map`, sort its keys and rebuild the map recursively canonicalizing
  each value; if a `List`, map `_canonicalJson` over its elements; otherwise return `value` as-is.
- **Usage:** Called only by `jsonValueEquals`.
- **Notes:** Internal helper — not intended to be called directly elsewhere.
