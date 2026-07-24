# Sync Walkthrough

A worked example of the [WebDAV Sync](../sync.md) flow, covering an auto-resolve case, a
true conflict case, and a `NetworkDevice` composite-key merge. This walks through the
concepts in [Three-Way Merge](../algorithms/three-way-merge.md) with concrete data.

Setup: two devices, "Laptop A" and "Desktop B", both configured to sync the same WebDAV
folder. Both have already synced once, so each has a local `.sync_base/device_data.json`
matching what was last uploaded.

## Case 1: auto-resolve (only one side changed)

1. On Laptop A, the user edits a `Device` record (id `dev-1`, name "ThinkPad X1") to
   add a `purchasePrice`. This bumps `dev-1.modifiedAt` to `2026-07-23T10:00:00Z`
   (UTC — see [Data Formats](../data-formats.md#utc-modifiedat)).
2. Desktop B never touched `dev-1` since the last sync — its local `modifiedAt` for
   `dev-1` still equals the base snapshot's `modifiedAt`.
3. Laptop A opens WebDAV settings and syncs (or auto-sync's 30-second-after-save timer
   fires):
   - **Step 1** ([9-step flow](../sync.md#the-9-step-flow)): acquires `.lock` with a
     60-second TTL.
   - **Step 2:** downloads `device_data.json` from remote — succeeds (HTTP 200).
   - **Step 3:** loads local `device_data.json` and `.sync_base/device_data.json`.
   - **Step 4:** `mergeRecords<Device>` compares `dev-1`'s local `modifiedAt` against
     the base — local changed, remote did not.
   - **Step 5:** auto-resolves to local's version of `dev-1` (no conflict, since only
     one side changed — see [Three-Way Merge](../algorithms/three-way-merge.md#mergerecordst--generic-id--timestamp-merge)
     case "only local changed").
   - **Step 7:** no conflicts at all in this merge → force-uploads the complete merged
     `device_data.json` under the still-valid `.lock`.
   - **Step 9:** saves the new base snapshot, clears the upload lock.
4. When Desktop B next syncs, it downloads the updated `device_data.json`, merges
   (its own `dev-1` didn't change, remote did → takes remote's version), and its
   `.sync_base` catches up. No user interaction was needed on either device.

## Case 2: true conflict (both sides changed the same record)

1. Starting from the same base, the user edits `dev-1`'s `notes` field on **Laptop A**
   at `10:00:00Z`.
2. Before Laptop A syncs, the user also edits `dev-1`'s `screenSize` field on
   **Desktop B** at `10:05:00Z` — a genuinely different change, not the same edit made
   twice.
3. Desktop B syncs first: uploads successfully (auto-resolve applies the same way as
   Case 1, since from Desktop B's point of view only *it* changed `dev-1` relative to
   its own base at sync time).
4. Laptop A syncs next:
   - **Step 4:** `mergeRecords<Device>` compares both sides against the base — both
     `localChanged` and `remoteChanged` are true for `dev-1`.
   - The identical-content check (`serialize(local) == serialize(remote)`) fails —
     `notes` and `screenSize` genuinely differ.
   - Both **manual sync and auto-sync use `autoResolve: false`** (see
     [WebDAV Sync](../sync.md#manual-vs-auto-sync)), so this is not resolved via
     last-writer-wins. A `RecordConflict<Device>` is emitted with `localRecord`
     (Laptop A's version, `notes` edited) and `remoteRecord` (Desktop B's version,
     `screenSize` edited).
   - **Step 8:** the conflict is returned to the user instead of uploading. The
     conflict dialog shows both sides' `modifiedAt` (`10:00:00Z` vs. `10:05:00Z` — a
     real `Device` has a timestamp, unlike `NetworkDevice`; see Case 3 below).
5. The user picks a resolution (or merges manually outside the app and re-enters it).
   Say they keep Desktop B's version. The app calls `finalizePendingSync`:
   - Reacquires `.lock`.
   - Force-uploads the complete resolved JSON (with `dev-1` = Desktop B's version, but
     `extraJson` unknown fields still merged from both sides per
     [Data Formats](../data-formats.md#extrajson-unknown-field-preservation)).
   - On success, saves the new base snapshot for `device_data.json`.
6. If the user instead dismisses the conflict dialog (e.g. system back gesture), per
   [WebDAV Sync](../sync.md#manual-vs-auto-sync) the whole resolution aborts: nothing
   uploads, the conflict stays visible as pending status in Settings/WebDAV, and neither
   side is silently chosen.

## NetworkDevice assignment example

`NetworkDevice` has no `id` and no `modifiedAt` — its identity is the composite key
`(networkId, deviceId)` and merge compares serialized content, not timestamps (see
[Networks](../features/networks.md#composite-key-identity--and-why) and
[Three-Way Merge](../algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)).

1. Base state: `dev-1` is assigned to network `net-home` with
   `NetworkDevice(networkId: 'net-home', deviceId: 'dev-1', addressMode: dhcp,
   ipAddress: null)`. Both devices last synced this exact assignment.
2. On **Laptop A**, the user sets a static IP for `dev-1` on `net-home`:
   `addressMode: static_, ipAddress: '192.168.1.50'`.
3. **Desktop B** never touched this assignment.
4. Laptop A syncs first (uploads successfully — remote now has the static-IP version).
5. Desktop B syncs:
   - `mergeAssignments()` computes `key = 'net-home:dev-1'`.
   - Compares `content(local)` (still DHCP, matches base) against `baseContent[key]` —
     unchanged.
   - Compares `content(remote)` (static IP) against `baseContent[key]` — changed.
   - Per the algorithm ("remote changed and local didn't → take remote"), Desktop B's
     merge takes the remote (static-IP) version. No conflict is ever raised for
     `NetworkDevice` — the algorithm always resolves deterministically (with a
     local-wins bias only in the case where *both* sides changed the same assignment;
     see [Three-Way Merge](../algorithms/three-way-merge.md#algorithm-1)).
6. If a `Network` (not assignment) conflict happened to arise in the same sync and the
   conflict dialog needed to reference this assignment, it would show the composite-key
   ID `net-home:dev-1` rather than a `modifiedAt` on each side, since none exists — see
   [WebDAV Sync](../sync.md#networkdevice-composite-key-merge).

## Related

- [WebDAV Sync](../sync.md) — the full 9-step flow.
- [Three-Way Merge](../algorithms/three-way-merge.md) — the underlying algorithms.
- [Data Formats](../data-formats.md) — the `Device`/`NetworkDevice` field shapes used
  above.
