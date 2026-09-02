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

**These docs are the authoritative description of the code.** The repository's `AGENTS.md`
is deliberately limited to instructions for agents — workflow, authoring rules, the
behavior contract, and the release process — and points here for everything else. When
code changes, these pages are updated first; when docs and code disagree, verify against
the code and then fix the page.

The shared WebDAV sync, backup, and ZIP engines are not in this repository. They live in
the `myapps_data` package embedded at `packages/myapps_data`, documented at
`packages/myapps_data/doc/en-us/`.

## Contents

### Core concepts

- [Architecture](architecture.md) — app shell, routing, state management, theming,
  localization, repository layout.
- [Adaptive Layout](adaptive-layout.md) — when a layout may split on a foldable, tablet or
  desktop window, where navigation lives, how many columns fit, and why the rule is an aspect
  test rather than a width breakpoint.
- [Data Formats](data-formats.md) — every persisted model's fields, the `extraJson`
  unknown-field preservation pattern, and the full persisted-data inventory.
- [WebDAV Sync](sync.md) — the 9-step per-record three-way sync flow, retry/heartbeat
  policy, image sync, and known limitations.
- [Backup and Restore](backup-restore.md) — backup format v2, blob dedup/GC, restore
  safety rules, ZIP export/import, Markdown export.
- [Platform Notes](platform-notes.md) — Windows/macOS/iOS/Android caveats, the desktop
  local API server, system tray, launch-at-startup.
- [CI/CD](ci-cd.md) — CI jobs and workflow caveats, the build/verify command set, and
  fresh-clone (submodule) steps.
- [Version History](version-history.md) — release-by-release summary. Worth checking
  before changing a behavior that looks odd; several entries record deliberate safety
  fixes.

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
