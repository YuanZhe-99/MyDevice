# MyDevice!!!!! Documentation

**MyDevice!!!!!** (five exclamation marks in every user-facing app name, installer
metadata, macOS bundle name, and window title) is a privacy-first personal device
inventory app. It tracks detailed hardware specs, service/port/route notes, network
management, dataset organization, map locations, WebDAV sync, local backup, ZIP/Markdown
export, desktop tray behavior, local API access, and device lifecycle/finance tracking.

- **License:** GPL-3.0
- **Platforms:** Windows, Android, iOS, macOS (Linux/web project files exist but are not
  primary release targets)
- **Framework:** Flutter (Dart SDK `^3.11.3`)

This tree is the English "concept" documentation — architecture, data formats, and
feature-level explanations of how the app works. It complements the per-function
reference pages under [`functions/`](functions/) (a separate, exhaustive per-source-file
index) and the [translation guide](translation-guide.md).

The authoritative, actively maintained source of truth for the whole project is the
repository's own `AGENTS.md`. Everything in this tree is derived from it and from the
current Dart source; if something here ever looks stale, `AGENTS.md` and the source win.

## Contents

### Core concepts

- [Architecture](architecture.md) — app shell, routing, state management, theming,
  localization, repository layout.
- [Data Formats](data-formats.md) — every persisted model's fields, the `extraJson`
  unknown-field preservation pattern, and the full persisted-data inventory.
- [WebDAV Sync](sync.md) — the 9-step per-record three-way sync flow, retry/heartbeat
  policy, image sync, and known limitations.
- [Backup and Restore](backup-restore.md) — backup format v2, blob dedup/GC, restore
  safety rules, ZIP export/import, Markdown export.
- [Platform Notes](platform-notes.md) — Windows/macOS/iOS/Android caveats, the desktop
  local API server, system tray, launch-at-startup.

### Feature areas

- [Devices](features/devices.md) — device model, lifecycle/finance tracking, financial
  overview charts, avatar rendering, cascade-delete rules.
- [Networks](features/networks.md) — `Network` / `NetworkDevice`, network types,
  composite-key assignment identity.
- [Datasets](features/datasets.md) — `DataSet` / `DataSetStorageLink`, storage-slot-index
  linking and remapping.
- [Services and Topology](features/services-topology.md) — manual service inventory,
  routes/hops, the topology graph views, FRP-style modeling, templates.
- [Online Search and Presets](features/online-search-and-presets.md) — device/chip online
  search, store-flavor gating, bundled presets.
- [Map](features/map.md) — the read-only device map and the full-screen location picker.

### Algorithms

- [Three-Way Merge](algorithms/three-way-merge.md) — the generic `mergeRecords<T>` engine
  and the composite-key `mergeAssignments` variant for `NetworkDevice`.
- [Service Topology Layout](algorithms/service-topology-layout.md) — the semantic layered
  layout and orthogonal edge-routing algorithm behind the topology graph.

### Worked examples

- [Sync Walkthrough](examples/sync-walkthrough.md) — a two-device sync scenario covering
  auto-resolve, a true conflict, and a `NetworkDevice` composite-key merge.
- [Service Topology Walkthrough](examples/service-topology-walkthrough.md) — modeling a
  service behind a reverse proxy behind an FRP tunnel to a public domain.

### Other

- [Translation Guide](translation-guide.md) — process notes for the (future)
  `doc/zh-cn/` translation pass. Not part of this English pass.
- [Function Index](functions/) — per-source-file declaration reference (separate,
  exhaustive layer; not duplicated here).
