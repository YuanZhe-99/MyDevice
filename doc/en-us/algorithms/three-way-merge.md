# Three-Way Merge

Source: `lib/shared/services/sync_merge.dart` (~22 KB). This is the generic merge engine
behind [WebDAV Sync](../sync.md); see that page for how it plugs into the full 9-step
sync flow, and [Data Formats](../data-formats.md) for the models being merged.

There are two merge algorithms in this file: the generic ID/timestamp-based
`mergeRecords<T>` used by every model that has an `id` and a `modifiedAt`, and the
composite-key/content-comparison `mergeAssignments` used specifically for
`NetworkDevice`, which has neither.

## `mergeRecords<T>` — generic ID + timestamp merge

Confirmed signature:

```dart
RecordMergeResult<T> mergeRecords<T>({
  required List<T> local,
  required List<T> remote,
  required List<T>? base,
  required String Function(T) getId,
  required DateTime Function(T) getModifiedAt,
  required String Function(T) getDisplayName,
  T Function(T primary, T secondary, T? base)? mergeUnknownFields,
  bool autoResolve = false,
  String Function(T)? serialize,
})
```

It's used for `Device`, `Network`, `DataSet`, `ServiceNode`, and `ServiceRoute` — every
model with an `id` and a `modifiedAt` (see `mergeDeviceData`, `mergeNetworkData`,
`mergeDataSetData`, `mergeServiceData` in the same file, each of which decodes JSON,
calls `mergeRecords<T>` with the model's own `id`/`modifiedAt`/display-name accessors,
and reassembles a typed `*MergeResult`).

### Algorithm

Build three ID-keyed maps (`localMap`, `remoteMap`, `baseMap`) and iterate the union of
all IDs seen anywhere:

1. **Both sides have the record, and a base exists (true three-way case):**
   - Determine `localChanged` / `remoteChanged` by comparing each side's `modifiedAt`
     to the base's `modifiedAt` (`isAfter`).
   - **Both changed:**
     - If `serialize` is provided and `serialize(local) == serialize(remote)` —
       identical content on both sides — merge without a conflict (this is what lets a
       record survive a stale base from an earlier failed upload without falsely
       flagging a conflict; see [WebDAV Sync](../sync.md#the-9-step-flow) step 4).
     - Else if `autoResolve` is true, pick whichever side has the later `modifiedAt` as
       primary (last-writer-wins), the other as secondary for unknown-field merge.
     - Else, emit a `RecordConflict<T>` with both sides for the caller to resolve (used
       by manual sync and auto-sync alike, since both use `autoResolve: false` — see
       [WebDAV Sync](../sync.md#manual-vs-auto-sync)).
   - **Only local changed:** keep local (merging remote's unknown fields in via
     `preserveUnknown`).
   - **Only remote changed:** keep remote.
   - **Neither changed:** keep local (arbitrary — both are equivalent from the base).
2. **Both sides have the record, no base (first sync, or both sides independently
   created the same ID):** primary = whichever side has the later `modifiedAt`;
   secondary = the other.
3. **Only local has the record:**
   - With a base: if local changed since base, it survived a remote deletion — keep it
     (a delete-vs-modify conflict resolves in favor of the modification). If local
     didn't change, it was deleted remotely and untouched locally — drop it.
   - Without a base: it's new locally — include it.
4. **Only remote has the record:** symmetric to case 3.
5. **Neither side has it (both null), but it was in the base:** deleted on both sides —
   excluded from the result.

`preserveUnknown(primary, secondary, base)` calls the caller-supplied
`mergeUnknownFields` callback (typically the model's own `mergeUnknownFieldsFrom`, see
[Data Formats](../data-formats.md#extrajson-unknown-field-preservation)) or just returns
`primary` unchanged if no callback was given.

### Result shape

```dart
class RecordConflict<T> {
  final String id;
  final T localRecord;
  final T remoteRecord;
  final String displayName;
}

class RecordMergeResult<T> {
  final List<T> merged;
  final List<RecordConflict<T>> conflicts;
}
```

Each per-model wrapper (`DeviceMergeResult`, `NetworkMergeResult`, `DataSetMergeResult`,
`ServiceMergeResult`) exposes `hasConflicts` and a `buildResolved(resolutions)` method
that takes the caller's per-conflict-ID resolution choices and produces the final typed
data container (`DeviceData`, `NetworkData`, etc.) ready to upload.

## `mergeAssignments` — composite-key content-comparison merge

`NetworkDevice` has no `id` and no `modifiedAt` (see
[Networks](../features/networks.md#composite-key-identity--and-why)), so it needs a
different algorithm. Confirmed signature:

```dart
List<NetworkDevice> mergeAssignments(
  List<NetworkDevice> local,
  List<NetworkDevice> remote,
  List<NetworkDevice>? base,
)
```

The key function is `'${networkId}:${deviceId}'`; the change-detection function is
`jsonEncode(assignment.toJson())` — i.e. **content equality against the base**, not a
timestamp comparison.

### Algorithm

For each composite key across local/remote/base:

1. **Both sides have it, with a base:** compare each side's serialized content to the
   base's serialized content for that key.
   - Remote changed and local didn't → take remote (merging in local's unknown fields).
   - Otherwise (local changed, or both changed, or neither changed) → **take local**.
     Note this is a deliberate simplification versus `mergeRecords<T>`: with no
     timestamp to pick a winner when *both* sides changed, this function always
     prefers local rather than surfacing a conflict to the user. `mergeUnknownFieldsFrom`
     is still called both ways so unknown fields from both sides are preserved
     regardless of which side's known fields win.
2. **Both sides have it, no base:** both new — merge unknown fields, keep local's known
   fields as primary.
3. **Only local has it:**
   - With a base: if local's content changed vs. base, remote deleted it but local
     modified it — keep local. If local's content matches base, remote deleted it and
     local didn't touch it — drop it.
   - Without a base: new locally — keep it.
4. **Only remote has it:** symmetric to case 3.

Unlike `mergeRecords<T>`, `mergeAssignments` **never produces a `RecordConflict`** —
every case resolves deterministically (with a local-wins bias when both sides changed
the same assignment). This is why the conflict dialog has nothing to show for
`NetworkDevice` and instead falls back to the record's composite-key ID when it *does*
need to display one (e.g. inside a `Network` conflict that also touches assignments) —
see [WebDAV Sync](../sync.md#networkdevice-composite-key-merge).

`mergeNetworkData()` runs `mergeRecords<Network>` for the `Network` list (with real
`RecordConflict<Network>` support) and `mergeAssignments()` for the assignment list
separately, then combines them into one `NetworkMergeResult`.

## Related

- [WebDAV Sync](../sync.md) — the full 9-step flow this merge engine plugs into.
- [Sync Walkthrough](../examples/sync-walkthrough.md) — worked examples of both merge
  paths, including a `NetworkDevice` assignment scenario.
- [Data Formats](../data-formats.md#extrajson-unknown-field-preservation) — the
  `mergeUnknownJsonFields`/`jsonValueEquals` helpers used by both algorithms above.
