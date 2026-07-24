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
