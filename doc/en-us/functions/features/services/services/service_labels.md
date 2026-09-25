# lib/features/services/services/service_labels.dart

UI-only label helpers for the services module. Each takes `AppLocalizations` and turns a model
enum into the string the current language shows: route hop types, route methods, access levels
and reachability, topology lanes and node roles, and the guided flow's access patterns (see
[service_access_patterns.md](service_access_patterns.md)).

The persisted side stays English on purpose: route names (`serviceRouteGeneratedName`), the
Markdown export and the local API keep using the unlocalized `serviceRouteMethodLabel` from
[service_analysis.md](service_analysis.md), so a route's stored name never changes with the
language of whichever device saved it. Product names — Caddy, Nginx, Traefik, FRP, Cloudflare
Tunnel, Pangolin, Tailscale Funnel — are never translated; only the generic Direct, Custom and
Router port forward are.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`serviceWarningLabel`](#servicewarninglabel) | top-level function | A | Localized text of a reference warning (moved from the services overview). |
| `serviceAccessDraftWarningLabel` | top-level function | B | Localized text of a guided-draft warning. |
| [`serviceHopFallbackLabel`](#servicehopfallbacklabel) | top-level function | A | Name a hop without a service or label: its method, else its type. |
| `serviceHopTypeLabel` | top-level function | B | Localized label for a `ServiceRouteHopType`. |
| [`serviceRouteMethodUiLabel`](#serviceroutemethoduilabel) | top-level function | A | UI label for a route method: product names as-is, generic methods localized. |
| [`serviceAccessLevelLabel`](#serviceaccesslevellabel) | top-level function | A | Localized label for a `ServiceAccessLevel`. |
| `serviceReachabilityLabel` | top-level function | B | Localized label for a `ServiceReachability`, through its access level. |
| `serviceAccessLaneLabel` | top-level function | B | Localized label for a `ServiceAccessLane` (LAN / WiFi, VPN / Tailscale, Public / VPS). |
| `serviceTopologyRoleLabel` | top-level function | B | Localized label for a `ServiceTopologyNodeRole`. |
| [`serviceAccessPatternLabel`](#serviceaccesspatternlabel) | top-level function | A | Display name of an access pattern. |
| `serviceAccessPatternDescription` | top-level function | B | One-line description shown under a pattern's name. |

## Documentation

### `String serviceWarningLabel(AppLocalizations l10n, ServiceWarning warning)` <a id="servicewarninglabel"></a>
- **Kind:** top-level function. **Source:** line 17.
- **Purpose:** Return the localized text of a reference warning.
- **Inputs:** `l10n`, `warning`. **Returns:** `String`. **Side effects:** None.
- **Algorithm:** One ARB message per `ServiceWarningKind`, each taking the warning's name.
- **Usage:** The services overview's warning card and the guided access-path page's preview.
- **Notes:** Moved from the overview's private `_warningText` in 1.5.6, so both places use the
  same words.

### `String serviceHopFallbackLabel(AppLocalizations l10n, ServiceRouteHop hop)` <a id="servicehopfallbacklabel"></a>
- **Kind:** top-level function. **Source:** line 69.
- **Purpose:** Name a hop that has neither a service nor a label of its own.
- **Inputs:** `l10n`, `hop`. **Returns:** `String`. **Side effects:** None.
- **Algorithm:** The localized method (`serviceRouteMethodUiLabel`) when the hop has one, else
  the localized hop type.
- **Usage:** The `hopFallback` both route editors pass to `serviceRouteChainPreview`.
- **Notes:** Prefers the method so a direct hop previews as "Direct" rather than as its "Manual"
  hop type.

### `String serviceRouteMethodUiLabel(AppLocalizations l10n, ServiceRouteMethod method)` <a id="serviceroutemethoduilabel"></a>
- **Kind:** top-level function. **Source:** line 103.
- **Purpose:** Return the label a route method shows in the UI.
- **Inputs:** `l10n`, `method`. **Returns:** `String`. **Side effects:** None.
- **Algorithm:** `direct`, `custom` and `routerPortForward` map to their ARB keys; every other
  method returns `serviceRouteMethodLabel(method)` unchanged.
- **Usage:** The advanced route editor's method dropdown and hop rows; the topology's relay
  subtitles.
- **Notes:** Never used for anything persisted.

### `String serviceAccessLevelLabel(AppLocalizations l10n, ServiceAccessLevel level)` <a id="serviceaccesslevellabel"></a>
- **Kind:** top-level function. **Source:** line 119.
- **Purpose:** Return the localized label for a route access level.
- **Inputs:** `l10n`, `level`. **Returns:** `String`. **Side effects:** None.
- **Algorithm:** One ARB key per level (`serviceAccessLevelLan`, `…Vpn`, `…Authenticated`,
  `…Public`, `…Custom`).
- **Usage:** The advanced editor's access-level dropdown, the route summaries on the list page
  and in the topology node details.
- **Notes:** `serviceReachabilityLabel` reuses these keys, so the guided page's reachability
  chips read exactly like the advanced editor's access levels.

### `String serviceAccessPatternLabel(AppLocalizations l10n, ServiceAccessPattern pattern)` <a id="serviceaccesspatternlabel"></a>
- **Kind:** top-level function. **Source:** line 182.
- **Purpose:** Return the display name of an access pattern.
- **Inputs:** `l10n`, `pattern`. **Returns:** `String`. **Side effects:** None.
- **Algorithm:** `direct` ⇒ `servicePatternDirect` ("Direct (LAN / VPN)"); `reverseProxy` ⇒ the
  reverse-proxy hop-type label; `routerPortForward` ⇒ the router port forward method label; the
  product patterns ⇒ `serviceRouteMethodLabel` of their fixed method.
- **Usage:** The guided page's pattern cards.
- **Notes:** None.
