# Networks

Model source: `lib/features/network/models/network.dart`. See
[Data Formats](../data-formats.md#network--networkdevice-libfeaturesnetworkmodelsnetworkdart)
for the exact field list.

## Network

`Network` represents a LAN, VPN overlay, or similar: `id`, `name`, `type`, `subnet`,
`gateway`, `dnsServers` (`List<String>`), `notes`, `modifiedAt`, `extraJson`.

`NetworkType` values (confirmed enum): `lan`, `tailscale`, `zerotier`, `easytier`,
`wireguard`, `other`.

## NetworkDevice

### Configuration and CSV import (1.9.0)

Automatic matching uses node ID, exact case-insensitive names, then names ignoring
spaces/hyphens/underscores/dots. Preview shows reasons and ambiguous candidates.
Every target can be corrected; new devices have editable name/category/OS. Per-column
old/new values and checkboxes retain unchecked values. Moving a known node shows a
warning and preserves its old inventory device. Concurrent membership changes reject save.

EasyTier menus open a raw TOML/YAML editor with file read, copy, export and save.
Each membership has independent text; changing the label never converts or executes it.
Tailscale CSV import previews existing/new/skip choices, matching node IDs first and
suggesting only unambiguous exact names. Every original column and address survives.
Details open from the membership menu. Missing nodes are not removed and inventory
specs are not overwritten. Retired/sold devices cannot be selected. Multiple rows
cannot target one device. Devices save before one queued network batch; failures
keep the preview and generated IDs for retry. This is not a cross-file transaction:
new inventory records may remain if the network batch fails. Identical imports skip
the network write.

`NetworkDevice` is a device's membership/assignment in a network: `networkId`,
`deviceId`, `addressMode` (`AddressMode`: `dhcp` or `static_`, serialized as `"dhcp"` /
`"static"`), `ipAddress`, `hostname`, `isExitNode`, `extraJson`.

## Composite-key identity — and why

Confirmed directly in the `NetworkDevice` class body: its constructor has **no `id`
parameter and no `modifiedAt` field at all** — only `networkId`, `deviceId`,
`addressMode`, `ipAddress`, `hostname`, `isExitNode`, `extraJson`. This is intentional:

- A `NetworkDevice` is inherently a *relationship* between one `Network` and one
  `Device` — the pair `(networkId, deviceId)` is already a natural unique key, so a
  separate synthetic `id` would just be redundant bookkeeping for a many-to-many join
  row.
- Without a `modifiedAt`, three-way sync merge cannot use "who changed more recently"
  to detect which side changed. Instead, `mergeAssignments()` in
  `lib/shared/services/sync_merge.dart` compares the **serialized JSON content** of each
  side against the last-synced base snapshot for that same composite key. See
  [Three-Way Merge](../algorithms/three-way-merge.md#mergeassignments-composite-key-content-comparison-merge)
  for the exact algorithm and
  [Sync Walkthrough](../examples/sync-walkthrough.md#networkdevice-assignment-example)
  for a worked example.
- Because there's no timestamp, the sync conflict dialog falls back to showing the
  record's composite-key ID instead of a `modifiedAt` for `NetworkDevice` assignments
  specifically (every other record type shows real timestamps). See
  [WebDAV Sync](../sync.md#networkdevice-composite-key-merge).

## Related

- [WebDAV Sync](../sync.md) for how `Network` and `NetworkDevice` sync differently.
- [Data Formats](../data-formats.md) for the full persisted-data inventory.
- Retired/sold devices are removed from network assignments and pickers — see
  [Devices](devices.md#cascade-rules-on-retiresell-delete).
