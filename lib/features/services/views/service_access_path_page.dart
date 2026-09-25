import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/utils/detail_layout.dart';
import '../../devices/models/device.dart';
import '../../devices/services/device_storage.dart';
import '../../devices/widgets/device_category_icon.dart';
import '../../network/models/network.dart';
import '../../network/services/network_storage.dart';
import '../models/service.dart';
import '../services/service_access_patterns.dart';
import '../services/service_analysis.dart';
import '../services/service_labels.dart';
import '../services/service_storage.dart';
import '../services/service_template_service.dart';
import 'service_edit_page.dart';
import 'service_endpoint_dialog.dart';
import 'service_route_edit_page.dart';
import 'service_topology_widgets.dart';

/// The guided "Add access path" page: one scrolling form over a
/// [ServiceAccessDraft] that saves exactly one `ServiceRoute`.
///
/// Pushed on the root navigator like the other edit pages; pops `true` when a
/// route was saved or deleted, and nothing when the user backs out.
class ServiceAccessPathPage extends StatefulWidget {
  /// The draft a new access path starts from, e.g. with its source prefilled.
  final ServiceAccessDraft? draft;

  /// The saved route to edit; the page reads it with
  /// `ServiceAccessDraft.fromRoute` once the services have loaded.
  final ServiceRoute? route;

  /// Purpose: Create the guided access-path page.
  /// Inputs: `draft` — the starting draft of a new path; `route` — a saved
  /// route to edit instead.
  /// Returns: A new `ServiceAccessPathPage`.
  /// Side effects: None.
  /// Notes: When `route` is set the page is in edit mode (title, delete
  /// action). A route the guided form cannot represent hands over to the
  /// advanced editor as soon as the page has loaded.
  const ServiceAccessPathPage({super.key, this.draft, this.route});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `_ServiceAccessPathPageState`.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<ServiceAccessPathPage> createState() => _ServiceAccessPathPageState();
}

class _ServiceAccessPathPageState extends State<ServiceAccessPathPage> {
  late final TextEditingController _targetsCtrl;
  late final TextEditingController _publicHostCtrl;
  late final TextEditingController _publicPortCtrl;
  late final TextEditingController _notesCtrl;
  List<ServiceNode> _services = const [];
  List<ServiceRoute> _routes = const [];
  List<Device> _devices = const [];
  List<Network> _networks = const [];
  List<NetworkDevice> _assignments = const [];
  ServiceAccessDraft _draft = const ServiceAccessDraft();
  bool _loading = true;
  bool _reachabilityTouched = false;
  bool _showIssues = false;
  bool _saving = false;

  /// The direct-access suggestion the page filled into the targets field
  /// itself, so leaving the direct pattern can take it back out untouched.
  String? _autoTarget;

  /// Purpose: Report whether the page edits a saved route.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  bool get _editing => widget.route != null;

  /// Purpose: Create the text controllers and start loading the inventory.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Kicks off `_load`, which reads storage.
  /// Notes: The draft is resolved in `_load`, because reading a saved route
  /// back needs the services.
  @override
  void initState() {
    super.initState();
    _targetsCtrl = TextEditingController();
    _publicHostCtrl = TextEditingController();
    _publicPortCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _load(initial: true);
  }

  /// Purpose: Release the text controllers.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes controllers.
  /// Notes: None.
  @override
  void dispose() {
    _targetsCtrl.dispose();
    _publicHostCtrl.dispose();
    _publicPortCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Purpose: Load services, routes, devices and network assignments, and on
  /// the first load resolve the starting draft.
  /// Inputs: `initial` — true only for the load from `initState`.
  /// Returns: `Future<void>`.
  /// Side effects: Reads storage; updates state; may hand a route the form
  /// cannot represent over to the advanced editor; a new path whose draft
  /// names a source gets the direct-access suggestion, one that names an FRP
  /// relay the public-host suggestion, and one started from a device with a
  /// single service gets that service as its source.
  /// Notes: Later loads (after inline creation) keep the user's draft and
  /// only refresh the inventory it points into.
  Future<void> _load({bool initial = false}) async {
    final serviceData = await ServiceStorage.load();
    final deviceData = await DeviceStorage.load();
    final networkData = await NetworkStorage.load();
    if (!mounted) return;
    var handOver = false;
    setState(() {
      _services = serviceData.services;
      _routes = serviceData.routes;
      _devices = deviceData.devices;
      _networks = networkData.networks;
      _assignments = networkData.assignments;
      if (initial) {
        final route = widget.route;
        final fromRoute = route == null
            ? null
            : ServiceAccessDraft.fromRoute(route, _services);
        handOver = route != null && fromRoute == null;
        _reachabilityTouched = fromRoute != null;
        var draft = fromRoute ?? widget.draft ?? const ServiceAccessDraft();
        if (draft.sourceServiceId != null &&
            _serviceById(draft.sourceServiceId) == null) {
          draft = draft.copyWith(clearSourceServiceId: true);
        }
        final onDevice = _servicesOnInitialDevice(draft);
        if (draft.sourceServiceId == null && onDevice.length == 1) {
          draft = draft.copyWith(sourceServiceId: onDevice.single.id);
        }
        _draft = _withDefaultSourceEndpoint(draft);
        _syncControllers();
      }
      _loading = false;
    });
    if (handOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openAdvancedEditor();
      });
    } else if (initial && !_editing) {
      _prefillDirectTarget();
      _prefillPublicHost();
    }
  }

  /// Purpose: Copy the draft's text fields into the controllers.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: Overwrites the four controllers' text.
  /// Notes: Called when the draft is loaded and when a prefill changes a
  /// field the user has not typed in.
  void _syncControllers() {
    _targetsCtrl.text = _draft.targets.join('\n');
    _publicHostCtrl.text = _draft.publicHost ?? '';
    _publicPortCtrl.text = _draft.publicPort?.toString() ?? '';
    _notesCtrl.text = _draft.notes ?? '';
  }

  /// Purpose: Replace the draft and rebuild.
  /// Inputs: `next`.
  /// Returns: `void`.
  /// Side effects: Updates widget state.
  /// Notes: Internal helper used within this file only.
  void _update(ServiceAccessDraft next) => setState(() => _draft = next);

  /// Purpose: Look up a service by id.
  /// Inputs: `id`.
  /// Returns: `ServiceNode?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  ServiceNode? _serviceById(String? id) => id == null
      ? null
      : _services.where((service) => service.id == id).firstOrNull;

  /// Purpose: Look up a device by id.
  /// Inputs: `id`.
  /// Returns: `Device?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Device? _deviceById(String? id) => id == null
      ? null
      : _devices.where((device) => device.id == id).firstOrNull;

  /// Purpose: List the services on the draft's initial device.
  /// Inputs: `draft`.
  /// Returns: The services whose device is `draft.initialDeviceId`, by name;
  /// empty without one.
  /// Side effects: None.
  /// Notes: A path started from a device on the topology preselects its only
  /// service, and otherwise the source picker offers these first.
  List<ServiceNode> _servicesOnInitialDevice(ServiceAccessDraft draft) {
    final deviceId = draft.initialDeviceId;
    if (deviceId == null) return const [];
    return [
      for (final service in _services)
        if (service.deviceId == deviceId) service,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Purpose: Preselect the source endpoint when the choice is obvious.
  /// Inputs: `draft`.
  /// Returns: The draft, with a source endpoint when there was none and the
  /// source has exactly one endpoint or a primary one.
  /// Side effects: None.
  /// Notes: A source without endpoints stays without one.
  ServiceAccessDraft _withDefaultSourceEndpoint(ServiceAccessDraft draft) {
    if (draft.sourceEndpointId != null) return draft;
    final source = _serviceById(draft.sourceServiceId);
    if (source == null || source.endpoints.isEmpty) return draft;
    final endpoint = source.endpoints.length == 1
        ? source.endpoints.single
        : source.endpoints.where((endpoint) => endpoint.isPrimary).firstOrNull;
    return endpoint == null
        ? draft
        : draft.copyWith(sourceEndpointId: endpoint.id);
  }

  /// Purpose: Let the user pick the source service.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens the service picker sheet; updates the draft.
  /// Notes: A proxy or relay equal to the new source is cleared, since a
  /// service cannot pass traffic to itself. A path started from a device
  /// suggests that device's services first.
  Future<void> _pickSource() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await _showServicePicker(
      title: l10n.serviceAccessPickService,
      services: _services,
      suggestedIds: {
        for (final service in _servicesOnInitialDevice(_draft)) service.id,
      },
      selectedId: _draft.sourceServiceId,
    );
    if (picked == null) return;
    var next = _draft.copyWith(
      sourceServiceId: picked.id,
      clearSourceEndpointId: true,
    );
    if (next.proxyServiceId == picked.id) {
      next = next.copyWith(
        clearProxyServiceId: true,
        clearProxyEndpointId: true,
        clearProxyMethod: true,
      );
    }
    if (next.relayServiceId == picked.id) {
      next = next.copyWith(
        clearRelayServiceId: true,
        clearRelayEndpointId: true,
      );
    }
    _update(_withDefaultSourceEndpoint(next));
    _prefillDirectTarget();
  }

  /// Purpose: Switch the draft to another access pattern.
  /// Inputs: `pattern`.
  /// Returns: `void`.
  /// Side effects: Updates the draft and possibly prefilled fields.
  /// Notes: The reachability follows the pattern's default until the user
  /// picks one; a relay chosen for another pattern is dropped, and a single
  /// obvious proxy or relay is preselected. A LAN or VPN address the page
  /// suggested for direct access leaves with the direct pattern, unless the
  /// user edited it.
  void _selectPattern(ServiceAccessPattern pattern) {
    if (pattern == _draft.pattern) return;
    var next = _draft.copyWith(
      pattern: pattern,
      clearRelayServiceId: true,
      clearRelayEndpointId: true,
      clearRemoteDeviceId: pattern != ServiceAccessPattern.routerPortForward,
    );
    if (!_reachabilityTouched) {
      next = next.copyWith(reachability: pattern.defaultReachability);
    }
    final autoTarget = _autoTarget;
    if (_draft.pattern == ServiceAccessPattern.direct &&
        autoTarget != null &&
        _targetsCtrl.text.trim() == autoTarget) {
      _targetsCtrl.clear();
      next = next.copyWith(targets: const []);
    }
    _autoTarget = null;
    if (pattern.usesRelayService) {
      final suggested = serviceAccessRelaySuggestions(
        pattern,
        _services,
        _devices,
        sourceServiceId: next.sourceServiceId,
      );
      if (suggested.length == 1) {
        next = _withRelay(next, _serviceById(suggested.single)!);
      }
    }
    if (next.needsProxy && next.proxyServiceId == null) {
      next = _withSingleProxyCandidate(next);
    }
    _update(next);
    _prefillDirectTarget();
    _prefillPublicHost();
  }

  /// Purpose: Point the draft at a relay service with its default endpoint.
  /// Inputs: `draft`, `relay`.
  /// Returns: `ServiceAccessDraft`.
  /// Side effects: None.
  /// Notes: FRP gets the default ingress preselected; tunnels start without
  /// an endpoint, which stays optional for them.
  ServiceAccessDraft _withRelay(ServiceAccessDraft draft, ServiceNode relay) {
    final next = draft.copyWith(
      relayServiceId: relay.id,
      clearRelayEndpointId: true,
    );
    if (draft.pattern != ServiceAccessPattern.frp) return next;
    final ingress = serviceDefaultIngressEndpoint(relay);
    return ingress == null ? next : next.copyWith(relayEndpointId: ingress.id);
  }

  /// Purpose: Preselect the proxy when exactly one proxy-like service exists.
  /// Inputs: `draft`.
  /// Returns: `ServiceAccessDraft`.
  /// Side effects: None.
  /// Notes: More than one candidate is left to the user.
  ServiceAccessDraft _withSingleProxyCandidate(ServiceAccessDraft draft) {
    final candidates = serviceAccessProxySuggestions(
      _services,
      sourceServiceId: draft.sourceServiceId,
    );
    if (candidates.length != 1) return draft;
    return _withProxy(draft, _serviceById(candidates.single)!);
  }

  /// Purpose: Point the draft at a proxy service with its default endpoint.
  /// Inputs: `draft`, `proxy`.
  /// Returns: `ServiceAccessDraft`.
  /// Side effects: None.
  /// Notes: The proxy method returns to "derive from the service".
  ServiceAccessDraft _withProxy(ServiceAccessDraft draft, ServiceNode proxy) {
    final endpoint = serviceDefaultIngressEndpoint(proxy);
    return draft.copyWith(
      proxyServiceId: proxy.id,
      clearProxyMethod: true,
      clearProxyEndpointId: endpoint == null,
      proxyEndpointId: endpoint?.id,
    );
  }

  /// Purpose: Fill the targets with the direct-access suggestion when the
  /// field is still empty.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: May set the targets field and the draft.
  /// Notes: Only for the direct pattern; never overwrites typed text.
  void _prefillDirectTarget() {
    if (_draft.pattern != ServiceAccessPattern.direct) return;
    if (_targetsCtrl.text.trim().isNotEmpty) return;
    final suggestion = _directSuggestion();
    if (suggestion == null) return;
    _targetsCtrl.text = suggestion;
    _autoTarget = suggestion;
    _update(_draft.copyWith(targets: [suggestion]));
  }

  /// Purpose: Fill the FRP public host from the relay device's address when
  /// the field is still empty.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: May set the public host field and the draft.
  /// Notes: Only when the relay device has exactly one network assignment,
  /// so the guess cannot pick the wrong network.
  void _prefillPublicHost() {
    if (_draft.pattern != ServiceAccessPattern.frp) return;
    if (_publicHostCtrl.text.trim().isNotEmpty) return;
    final relay = _serviceById(_draft.relayServiceId);
    if (relay == null) return;
    final host = suggestedPublicHost(relay, _assignments);
    if (host == null) return;
    _publicHostCtrl.text = host;
    _update(_draft.copyWith(publicHost: host));
  }

  /// Purpose: Build the direct-access target suggestion for the current
  /// source.
  /// Inputs: None.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: Delegates to `suggestedDirectTarget`.
  String? _directSuggestion() {
    final source = _serviceById(_draft.sourceServiceId);
    if (source == null) return null;
    final endpoint = source.endpoints
        .where((endpoint) => endpoint.id == _draft.sourceEndpointId)
        .firstOrNull;
    return suggestedDirectTarget(
      source: source,
      endpoint: endpoint,
      assignments: _assignments,
      networks: _networks,
      reachability: _draft.reachability,
    );
  }

  /// Purpose: Let the user pick the proxy service.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens the service picker sheet; updates the draft.
  /// Notes: Proxy-like services are suggested first; any other service can
  /// still be picked.
  Future<void> _pickProxy() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await _showServicePicker(
      title: l10n.serviceAccessProxyService,
      services: [
        for (final service in _services)
          if (service.id != _draft.sourceServiceId) service,
      ],
      suggestedIds: serviceAccessProxySuggestions(
        _services,
        sourceServiceId: _draft.sourceServiceId,
      ).toSet(),
      selectedId: _draft.proxyServiceId,
    );
    if (picked != null) _update(_withProxy(_draft, picked));
  }

  /// Purpose: Let the user pick the relay service.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens the service picker sheet; updates the draft; may
  /// prefill the FRP public host.
  /// Notes: The pattern decides which services are suggested.
  Future<void> _pickRelay() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await _showServicePicker(
      title: _draft.pattern == ServiceAccessPattern.frp
          ? l10n.serviceAccessFrpServer
          : l10n.serviceAccessRelayOptional,
      services: [
        for (final service in _services)
          if (service.id != _draft.sourceServiceId) service,
      ],
      suggestedIds: serviceAccessRelaySuggestions(
        _draft.pattern,
        _services,
        _devices,
        sourceServiceId: _draft.sourceServiceId,
      ).toSet(),
      selectedId: _draft.relayServiceId,
    );
    if (picked == null) return;
    _update(_withRelay(_draft, picked));
    _prefillPublicHost();
  }

  /// Purpose: Create a proxy or relay service inline from a template and
  /// select it.
  /// Inputs: `templateId`; `deviceId` — the device the new service starts
  /// on; `asProxy` — select it as the proxy rather than the relay.
  /// Returns: `Future<void>`.
  /// Side effects: Pushes the service edit page, which persists the service;
  /// reloads the inventory; updates the draft.
  /// Notes: The service is saved whether or not this access path is saved
  /// afterwards — it is valid inventory on its own.
  Future<void> _createService({
    required String templateId,
    String? deviceId,
    required bool asProxy,
  }) async {
    final template = ServiceTemplateService.loadTemplates()
        .where((template) => template.id == templateId)
        .firstOrNull;
    final outcome = await Navigator.of(context).push<ServiceEditOutcome>(
      MaterialPageRoute(
        builder: (_) => ServiceEditPage(deviceId: deviceId, template: template),
      ),
    );
    final saved = outcome?.saved;
    if (saved == null) return;
    await _load();
    if (!mounted) return;
    final created = _serviceById(saved.id) ?? saved;
    _update(
      asProxy ? _withProxy(_draft, created) : _withRelay(_draft, created),
    );
    if (!asProxy) _prefillPublicHost();
  }

  /// Purpose: Add an endpoint to a service right away and select it.
  /// Inputs: `service`; `onAdded` — receives the draft and the new endpoint
  /// and returns the updated draft.
  /// Returns: `Future<void>`.
  /// Side effects: Shows the endpoint dialog; saves the service with the new
  /// endpoint; reloads the inventory; updates the draft.
  /// Notes: Re-reads the service before saving so an edit made elsewhere is
  /// not overwritten.
  Future<void> _addEndpointTo(
    ServiceNode service,
    ServiceAccessDraft Function(ServiceAccessDraft, ServiceEndpoint) onAdded,
  ) async {
    final endpoint = await showServiceEndpointDialog(
      context,
      defaultPrimary: service.endpoints.isEmpty,
    );
    if (endpoint == null) return;
    final data = await ServiceStorage.load();
    final latest =
        data.services.where((s) => s.id == service.id).firstOrNull ?? service;
    await ServiceStorage.addOrUpdateService(
      latest.copyWith(endpoints: [...latest.endpoints, endpoint]),
    );
    await _load();
    if (!mounted) return;
    _update(onAdded(_draft, endpoint));
  }

  /// Purpose: Save the access path as one route and close the page.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Persists the route; pops `true`. With blocking issues it
  /// shows them instead and saves nothing.
  /// Notes: Advisory warnings never block saving.
  Future<void> _save() async {
    if (_saving) return;
    final issues = serviceAccessDraftIssues(_draft, _services);
    if (issues.isNotEmpty) {
      setState(() => _showIssues = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.serviceAccessSaveFirst),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await ServiceStorage.addOrUpdateRoute(_draft.toRoute(services: _services));
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Purpose: Confirm and delete the route being edited.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Shows a confirmation dialog; deletes the route; pops
  /// `true`.
  /// Notes: Only offered in edit mode.
  Future<void> _delete() async {
    final route = widget.route;
    if (route == null) return;
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteServiceRoute),
        content: Text(l10n.deleteServiceRouteConfirm(route.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ServiceStorage.deleteRoute(route.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Purpose: Hand the current draft over to the advanced route editor.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Pushes the advanced editor; pops `true` when it saved or
  /// deleted.
  /// Notes: An edit keeps the route id (`route:`); a new path passes the
  /// unsaved route as `draft:`.
  Future<void> _openAdvancedEditor() async {
    final route = _draft.toRoute(services: _services);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _editing
            ? ServiceRouteEditPage(route: route)
            : ServiceRouteEditPage(draft: route),
      ),
    );
    if (!mounted) return;
    if (saved == true || (widget.route != null && _handedOver)) {
      Navigator.of(context).pop(saved == true);
    }
  }

  /// Purpose: Report whether this page only exists to hand a route over.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: True when the route could not be read into a draft; closing the
  /// advanced editor then closes this page too.
  bool get _handedOver =>
      widget.route != null &&
      ServiceAccessDraft.fromRoute(widget.route!, _services) == null;

  /// Purpose: Build the page scaffold.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Keep this cheap; the preview and warnings are derived from the
  /// draft on every build.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing ? l10n.serviceAccessPathEdit : l10n.serviceAccessPathAdd,
        ),
        actions: [
          if (_editing)
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(
            tooltip: l10n.save,
            icon: const Icon(Icons.save),
            onPressed: _loading ? null : _save,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, l10n),
    );
  }

  /// Purpose: Lay the form out in one column or two panes.
  /// Inputs: `context`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: On `useDetailTwoPane` windows the left pane (at
  /// `editFormLeftPaneWidth`) holds the choices — source and pattern — and
  /// the right pane the details, the preview with its warnings, and the
  /// actions. Both panes scroll. Pushed above the shell, so the body width is
  /// the raw window.
  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final screen = MediaQuery.sizeOf(context);
    final choices = [
      ..._buildSourceSection(context, l10n),
      ..._buildPatternSection(context, l10n),
    ];
    final details = [
      ..._buildDetailsSection(context, l10n),
      _buildPreviewCard(context, l10n),
      const SizedBox(height: 16),
      _buildActions(l10n),
    ];
    if (!useDetailTwoPane(screen.width, screen.height)) {
      return ListView(
        key: const Key('access-single-pane'),
        padding: const EdgeInsets.all(16),
        children: [...choices, ...details],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        key: const Key('access-two-pane'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: editFormLeftPaneWidth(constraints.maxWidth),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: choices,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: details,
            ),
          ),
        ],
      ),
    );
  }

  /// Purpose: Build a numbered section heading.
  /// Inputs: `context`, `number`, `title`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _sectionTitle(BuildContext context, int number, String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }

  /// Purpose: Build the source section: the service tile and its endpoint
  /// chips.
  /// Inputs: `context`, `l10n`.
  /// Returns: `List<Widget>`.
  /// Side effects: None.
  /// Notes: "Add endpoint" saves the endpoint onto the service immediately.
  List<Widget> _buildSourceSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final source = _serviceById(_draft.sourceServiceId);
    final missing =
        _showIssues &&
        serviceAccessDraftIssues(
          _draft,
          _services,
        ).contains(ServiceAccessDraftIssue.missingSource);
    return [
      _sectionTitle(context, 1, l10n.serviceAccessStepSource),
      _ServiceTile(
        key: const Key('access-source-picker'),
        service: source,
        device: _deviceById(source?.deviceId),
        placeholder: l10n.serviceAccessPickService,
        errorText: missing ? l10n.serviceAccessMissingSource : null,
        onTap: _services.isEmpty ? null : _pickSource,
      ),
      if (source != null) ...[
        const SizedBox(height: 8),
        _EndpointChips(
          keyPrefix: 'access-source-endpoint',
          service: source,
          selectedId: _draft.sourceEndpointId,
          emptyHint: l10n.serviceAccessNoEndpointsHint,
          addLabel: l10n.addServiceEndpoint,
          onSelected: (endpoint) {
            _update(
              endpoint == null
                  ? _draft.copyWith(clearSourceEndpointId: true)
                  : _draft.copyWith(sourceEndpointId: endpoint.id),
            );
          },
          onAdd: () => _addEndpointTo(
            source,
            (draft, endpoint) => draft.copyWith(sourceEndpointId: endpoint.id),
          ),
          allowNone: true,
          noneLabel: l10n.optionalNone,
        ),
      ],
      const SizedBox(height: 16),
    ];
  }

  /// Purpose: Build the pattern section: one card per pattern plus the
  /// custom multi-hop card.
  /// Inputs: `context`, `l10n`.
  /// Returns: `List<Widget>`.
  /// Side effects: None.
  /// Notes: The column count is `accessPatternColumns` of the section width;
  /// each row is an `IntrinsicHeight` so its cards share the tallest card's
  /// height, and a short last row keeps the other rows' card width.
  List<Widget> _buildPatternSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return [
      _sectionTitle(context, 2, l10n.serviceAccessStepPattern),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = accessPatternColumns(constraints.maxWidth);
          final cards = <Widget>[
            for (final pattern in ServiceAccessPattern.values)
              _PatternCard(
                key: ValueKey('access-pattern-${pattern.name}'),
                icon: serviceAccessPatternIcon(pattern),
                title: serviceAccessPatternLabel(l10n, pattern),
                description: serviceAccessPatternDescription(l10n, pattern),
                selected: _draft.pattern == pattern,
                onTap: () => _selectPattern(pattern),
              ),
            _PatternCard(
              key: const Key('access-pattern-custom'),
              icon: Icons.route,
              title: l10n.serviceAccessCustomPattern,
              description: l10n.serviceAccessCustomPatternDesc,
              selected: false,
              onTap: _openAdvancedEditor,
            ),
          ];
          return Column(
            children: [
              for (var start = 0; start < cards.length; start += columns)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: start + columns < cards.length ? listTileGap : 0,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = start; i < start + columns; i++) ...[
                          if (i > start) const SizedBox(width: listTileGap),
                          Expanded(
                            child: i < cards.length
                                ? cards[i]
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 16),
    ];
  }

  /// Purpose: Build the details section for the selected pattern.
  /// Inputs: `context`, `l10n`.
  /// Returns: `List<Widget>`.
  /// Side effects: None.
  /// Notes: Reachability always; then the proxy prefix, proxy, relay,
  /// ingress, router and public entry fields the pattern uses; then the
  /// targets and notes.
  List<Widget> _buildDetailsSection(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final pattern = _draft.pattern;
    final issues = _showIssues
        ? serviceAccessDraftIssues(_draft, _services)
        : const <ServiceAccessDraftIssue>[];
    final source = _serviceById(_draft.sourceServiceId);
    final proxy = _serviceById(_draft.proxyServiceId);
    final relay = _serviceById(_draft.relayServiceId);
    final relayTemplate = serviceAccessRelayTemplateId(pattern);
    final firstVps = _devices
        .where((device) => device.category == DeviceCategory.vps)
        .firstOrNull;
    final directSuggestion = pattern == ServiceAccessPattern.direct
        ? _directSuggestion()
        : null;
    return [
      _sectionTitle(context, 3, l10n.serviceAccessStepDetails),
      Text(
        l10n.serviceAccessReachability,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final reachability in ServiceReachability.values)
            ChoiceChip(
              key: ValueKey('access-reach-${reachability.name}'),
              label: Text(serviceReachabilityLabel(l10n, reachability)),
              selected: _draft.reachability == reachability,
              onSelected: (_) {
                _reachabilityTouched = true;
                _update(_draft.copyWith(reachability: reachability));
              },
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (pattern.allowsProxyPrefix)
        SwitchListTile(
          key: const Key('access-proxy-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.serviceAccessViaProxy),
          subtitle: Text(l10n.serviceAccessViaProxyHint),
          value: _draft.viaProxy,
          onChanged: (value) {
            var next = _draft.copyWith(viaProxy: value);
            if (value && next.proxyServiceId == null) {
              next = _withSingleProxyCandidate(next);
            }
            _update(next);
          },
        ),
      if (_draft.needsProxy) ...[
        const SizedBox(height: 4),
        _ServiceTile(
          key: const Key('access-proxy-picker'),
          service: proxy,
          device: _deviceById(proxy?.deviceId),
          placeholder: l10n.serviceAccessProxyService,
          errorText: issues.contains(ServiceAccessDraftIssue.missingProxy)
              ? l10n.serviceAccessMissingProxy
              : null,
          onTap: _pickProxy,
        ),
        if (proxy != null) ...[
          const SizedBox(height: 8),
          _EndpointChips(
            keyPrefix: 'access-proxy-endpoint',
            service: proxy,
            selectedId: _draft.proxyEndpointId,
            emptyHint: l10n.serviceAccessNoEndpointsHint,
            addLabel: l10n.addServiceEndpoint,
            onSelected: (endpoint) => _update(
              endpoint == null
                  ? _draft.copyWith(clearProxyEndpointId: true)
                  : _draft.copyWith(proxyEndpointId: endpoint.id),
            ),
            onAdd: () => _addEndpointTo(
              proxy,
              (draft, endpoint) => draft.copyWith(proxyEndpointId: endpoint.id),
            ),
            allowNone: true,
            noneLabel: l10n.optionalNone,
          ),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('access-create-proxy'),
            onPressed: () => _createService(
              templateId: 'caddy',
              deviceId: source?.deviceId,
              asProxy: true,
            ),
            icon: const Icon(Icons.add),
            label: Text(l10n.serviceAccessCreateProxy),
          ),
        ),
        const SizedBox(height: 8),
      ],
      if (pattern.usesRelayService) ...[
        _ServiceTile(
          key: const Key('access-relay-picker'),
          service: relay,
          device: _deviceById(relay?.deviceId),
          placeholder: pattern == ServiceAccessPattern.frp
              ? l10n.serviceAccessFrpServer
              : l10n.serviceAccessRelayOptional,
          errorText: issues.contains(ServiceAccessDraftIssue.missingRelay)
              ? l10n.serviceAccessMissingRelay
              : null,
          onTap: _pickRelay,
          onClear: pattern.requiresRelayService || relay == null
              ? null
              : () => _update(
                  _draft.copyWith(
                    clearRelayServiceId: true,
                    clearRelayEndpointId: true,
                  ),
                ),
        ),
        if (relay != null) ...[
          const SizedBox(height: 8),
          if (pattern == ServiceAccessPattern.frp)
            Text(
              l10n.serviceAccessIngress,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          if (pattern == ServiceAccessPattern.frp)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l10n.serviceAccessIngressHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          _EndpointChips(
            keyPrefix: pattern == ServiceAccessPattern.frp
                ? 'access-ingress'
                : 'access-relay-endpoint',
            service: relay,
            selectedId: pattern == ServiceAccessPattern.frp
                ? (_draft.relayEndpointId ??
                      serviceDefaultIngressEndpoint(relay)?.id)
                : _draft.relayEndpointId,
            emptyHint: l10n.serviceAccessNoEndpointsHint,
            addLabel: l10n.addServiceEndpoint,
            onSelected: (endpoint) => _update(
              endpoint == null
                  ? _draft.copyWith(clearRelayEndpointId: true)
                  : _draft.copyWith(relayEndpointId: endpoint.id),
            ),
            onAdd: () => _addEndpointTo(
              relay,
              (draft, endpoint) => draft.copyWith(relayEndpointId: endpoint.id),
            ),
            allowNone: pattern != ServiceAccessPattern.frp,
            noneLabel: l10n.optionalNone,
          ),
        ],
        if (relayTemplate != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('access-create-relay'),
              onPressed: () => _createService(
                templateId: relayTemplate,
                deviceId:
                    pattern == ServiceAccessPattern.frp ||
                        pattern == ServiceAccessPattern.pangolin
                    ? (firstVps?.id ?? source?.deviceId)
                    : source?.deviceId,
                asProxy: false,
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.serviceAccessCreateRelay),
            ),
          ),
        const SizedBox(height: 8),
      ],
      if (pattern == ServiceAccessPattern.routerPortForward) ...[
        DropdownButtonFormField<String?>(
          key: const Key('access-router'),
          isExpanded: true,
          initialValue: _draft.remoteDeviceId,
          decoration: InputDecoration(labelText: l10n.serviceAccessRouter),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.optionalNone),
            ),
            for (final device in serviceAccessRouterCandidates(_devices))
              DropdownMenuItem<String?>(
                value: device.id,
                child: Row(
                  children: [
                    Icon(deviceCategoryIcon(device.category), size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(device.name, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (value) => _update(
            value == null
                ? _draft.copyWith(clearRemoteDeviceId: true)
                : _draft.copyWith(remoteDeviceId: value),
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (pattern.requiresPublicPort) ...[
        TextField(
          key: const Key('access-public-host'),
          controller: _publicHostCtrl,
          decoration: InputDecoration(
            labelText: l10n.serviceAccessPublicHost,
            hintText: 'vps.example.com',
          ),
          onChanged: (value) {
            final host = value.trim();
            _update(
              host.isEmpty
                  ? _draft.copyWith(clearPublicHost: true)
                  : _draft.copyWith(publicHost: host),
            );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('access-public-port'),
          controller: _publicPortCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.serviceAccessPublicPort,
            hintText: '443',
            errorText:
                issues.contains(ServiceAccessDraftIssue.invalidPublicPort)
                ? l10n.serviceAccessInvalidPort
                : null,
          ),
          onChanged: (value) {
            final port = int.tryParse(value.trim());
            _update(
              port == null
                  ? _draft.copyWith(clearPublicPort: true)
                  : _draft.copyWith(publicPort: port),
            );
          },
        ),
        const SizedBox(height: 12),
      ],
      TextField(
        key: const Key('access-targets'),
        controller: _targetsCtrl,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: pattern.requiresPublicPort
              ? l10n.serviceDomains
              : l10n.serviceFinalUrl,
          hintText: pattern.requiresPublicPort
              ? 'media.example.com\nphotos.example.com'
              : 'https://app.example.com',
          helperText: pattern.requiresPublicPort
              ? l10n.serviceDomainsHint
              : l10n.serviceAccessTargetsHint,
          helperMaxLines: 3,
          errorText: issues.contains(ServiceAccessDraftIssue.missingTargets)
              ? l10n.serviceAccessTargetRequired
              : null,
        ),
        onChanged: (value) =>
            _update(_draft.copyWith(targets: _splitTargets(value))),
      ),
      if (directSuggestion != null &&
          !_draft.targets.contains(directSuggestion))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ActionChip(
              key: const Key('access-direct-suggestion'),
              avatar: const Icon(Icons.lightbulb_outline, size: 18),
              label: Text(l10n.serviceAccessUseSuggestion(directSuggestion)),
              onPressed: () {
                final targets = [..._draft.targets, directSuggestion];
                _targetsCtrl.text = targets.join('\n');
                _update(_draft.copyWith(targets: targets));
              },
            ),
          ),
        ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('access-notes'),
        controller: _notesCtrl,
        maxLines: 3,
        decoration: InputDecoration(labelText: l10n.deviceNotes),
        onChanged: (value) {
          final notes = value.trim();
          _update(
            notes.isEmpty
                ? _draft.copyWith(clearNotes: true)
                : _draft.copyWith(notes: value),
          );
        },
      ),
      const SizedBox(height: 16),
    ];
  }

  /// Purpose: Build the preview card: the chain, the lane and access level,
  /// and the advisory warnings.
  /// Inputs: `context`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Warnings come from `findServiceReferenceWarnings` run over the
  /// saved routes with this draft in place of the route it edits, narrowed to
  /// the entries that name the draft, plus `serviceAccessDraftWarnings`.
  Widget _buildPreviewCard(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final route = _draft.toRoute(services: _services);
    final lane = serviceAccessLaneForRoute(route);
    final warnings = <String>[
      for (final warning in _draftReferenceWarnings(route))
        serviceWarningLabel(l10n, warning),
      for (final warning in serviceAccessDraftWarnings(_draft, _services))
        serviceAccessDraftWarningLabel(l10n, warning),
    ];
    return Card(
      key: const Key('access-preview'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.serviceRoutePreview,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              serviceRouteChainPreview(
                route,
                services: _services,
                devices: _devices,
                hopFallback: (hop) => serviceHopFallbackLabel(l10n, hop),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: serviceAccessLaneColor(cs, lane),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${serviceAccessLaneLabel(l10n, lane)} · '
                    '${serviceAccessLevelLabel(l10n, route.accessLevel)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (warnings.isNotEmpty) ...[
              const Divider(height: 24),
              for (final warning in warnings)
                Padding(
                  key: const Key('access-warning'),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber, size: 18, color: cs.tertiary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(warning)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// Purpose: Find the reference warnings that concern the draft route.
  /// Inputs: `route` — the draft as a route.
  /// Returns: `List<ServiceWarning>`.
  /// Side effects: None.
  /// Notes: Kinds a blocking issue already covers are left out: a missing
  /// source, an empty route, a missing hop service, and — for patterns that
  /// require a target — a public route without one.
  List<ServiceWarning> _draftReferenceWarnings(ServiceRoute route) {
    final skipped = {
      ServiceWarningKind.missingSourceService,
      ServiceWarningKind.missingHopService,
      ServiceWarningKind.emptyRoute,
      if (_draft.pattern.requiresTargets)
        ServiceWarningKind.publicRouteMissingUrl,
    };
    final warnings = findServiceReferenceWarnings(
      services: _services,
      routes: [
        for (final saved in _routes)
          if (saved.id != route.id) saved,
        route,
      ],
      devices: _devices,
      networks: _networks,
    );
    return [
      for (final warning in warnings)
        if (!skipped.contains(warning.kind) &&
            (warning.name == route.name ||
                (warning.kind == ServiceWarningKind.duplicateFinalUrl &&
                    (warning.detail ?? '').split(', ').contains(route.name))))
          warning,
    ];
  }

  /// Purpose: Build the bottom action row: cancel, advanced editor, save.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Save stays enabled; tapping it with blocking issues shows them.
  Widget _buildActions(AppLocalizations l10n) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton.icon(
          key: const Key('access-advanced'),
          onPressed: _openAdvancedEditor,
          icon: const Icon(Icons.alt_route),
          label: Text(l10n.serviceAccessAdvancedEditor),
        ),
        FilledButton.icon(
          key: const Key('access-save'),
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save),
          label: Text(l10n.save),
        ),
      ],
    );
  }

  /// Purpose: Show the searchable service picker sheet.
  /// Inputs: `title`; `services` — the services to offer; `suggestedIds` —
  /// shown first under their own heading; `selectedId` — marked.
  /// Returns: The picked service, or null.
  /// Side effects: Opens a modal bottom sheet.
  /// Notes: Services are grouped by device.
  Future<ServiceNode?> _showServicePicker({
    required String title,
    required List<ServiceNode> services,
    required Set<String> suggestedIds,
    String? selectedId,
  }) {
    return showModalBottomSheet<ServiceNode>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ServicePickerSheet(
        title: title,
        services: services,
        devices: _devices,
        suggestedIds: suggestedIds,
        selectedId: selectedId,
      ),
    );
  }
}

/// Purpose: Return the icon a pattern card shows.
/// Inputs: `pattern`.
/// Returns: `IconData`.
/// Side effects: None.
/// Notes: The same icons the topology and route lists use for the route
/// methods behind each pattern.
IconData serviceAccessPatternIcon(ServiceAccessPattern pattern) =>
    switch (pattern) {
      ServiceAccessPattern.direct => Icons.near_me_outlined,
      ServiceAccessPattern.reverseProxy => Icons.alt_route,
      ServiceAccessPattern.cloudflareTunnel => Icons.cloud_sync,
      ServiceAccessPattern.pangolin => Icons.hub,
      ServiceAccessPattern.frp => Icons.swap_horiz,
      ServiceAccessPattern.routerPortForward => Icons.router,
      ServiceAccessPattern.tailscaleFunnel => Icons.vpn_lock,
    };

/// Purpose: Split the targets field into trimmed, non-empty entries.
/// Inputs: `value`.
/// Returns: `List<String>`.
/// Side effects: None.
/// Notes: One target per line, or comma-separated.
List<String> _splitTargets(String value) => value
    .split(RegExp(r'[\n,]+'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

class _ServiceTile extends StatelessWidget {
  final ServiceNode? service;
  final Device? device;
  final String placeholder;
  final String? errorText;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  /// Purpose: Create the tile that shows a chosen service or a prompt to
  /// choose one.
  /// Inputs: `service`, `device`; `placeholder` — shown when nothing is
  /// chosen; `errorText`; `onTap` — opens a picker; `onClear` — optional.
  /// Returns: A new `_ServiceTile`.
  /// Side effects: None.
  /// Notes: None.
  const _ServiceTile({
    super.key,
    required this.service,
    required this.device,
    required this.placeholder,
    this.errorText,
    this.onTap,
    this.onClear,
  });

  /// Purpose: Render the tile.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: The error text sits under the card in the error colour.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chosen = service;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: errorText != null ? cs.error : cs.outlineVariant,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(
                chosen == null
                    ? Icons.add_circle_outline
                    : iconForServiceIcon(chosen.icon),
              ),
            ),
            title: Text(
              chosen?.name ?? placeholder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: chosen == null
                ? null
                : Text(
                    [
                      device?.name ?? chosen.deviceId,
                      chosen.endpoints
                          .map((endpoint) => endpoint.portText)
                          .where((text) => text != '-')
                          .take(3)
                          .join(', '),
                    ].where((part) => part.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: onClear != null
                ? IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).deleteButtonTooltip,
                    onPressed: onClear,
                  )
                : const Icon(Icons.unfold_more),
            onTap: onTap,
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(
              errorText!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.error),
            ),
          ),
      ],
    );
  }
}

class _EndpointChips extends StatelessWidget {
  final String keyPrefix;
  final ServiceNode service;
  final String? selectedId;
  final String emptyHint;
  final String addLabel;
  final ValueChanged<ServiceEndpoint?> onSelected;
  final VoidCallback onAdd;
  final bool allowNone;
  final String noneLabel;

  /// Purpose: Create a row of endpoint choice chips with an add chip.
  /// Inputs: `keyPrefix` — chips are keyed `<prefix>-<endpoint id>`;
  /// `service`; `selectedId`; `emptyHint` — the add chip's label when the
  /// service has no endpoints; `addLabel`; `onSelected` — null means "none";
  /// `onAdd`; `allowNone` — offer a "none" chip; `noneLabel`.
  /// Returns: A new `_EndpointChips`.
  /// Side effects: None.
  /// Notes: None.
  const _EndpointChips({
    required this.keyPrefix,
    required this.service,
    required this.selectedId,
    required this.emptyHint,
    required this.addLabel,
    required this.onSelected,
    required this.onAdd,
    required this.allowNone,
    required this.noneLabel,
  });

  /// Purpose: Render the chips.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Each chip reads `label · port`.
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (allowNone && service.endpoints.isNotEmpty)
          ChoiceChip(
            key: ValueKey('$keyPrefix-none'),
            label: Text(noneLabel),
            selected: selectedId == null,
            onSelected: (_) => onSelected(null),
          ),
        for (final endpoint in service.endpoints)
          ChoiceChip(
            key: ValueKey('$keyPrefix-${endpoint.id}'),
            label: Text(
              '${endpoint.label ?? endpoint.protocol.name} · '
              '${endpoint.portText}',
            ),
            selected: endpoint.id == selectedId,
            onSelected: (_) => onSelected(endpoint),
          ),
        ActionChip(
          key: ValueKey('$keyPrefix-add'),
          avatar: const Icon(Icons.add, size: 18),
          label: Text(service.endpoints.isEmpty ? emptyHint : addLabel),
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _PatternCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  /// Purpose: Create one selectable access-pattern card.
  /// Inputs: `icon`, `title`, `description`, `selected`, `onTap`.
  /// Returns: A new `_PatternCard`.
  /// Side effects: None.
  /// Notes: None.
  const _PatternCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  /// Purpose: Render the card.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Icon row on top, then the title (up to two lines) and the
  /// description (up to three), so the card reads at the 150 dp minimum. The
  /// selected card gets a primary border, a tinted fill and a check mark, and
  /// announces itself as selected to screen readers.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Card(
        margin: EdgeInsets.zero,
        color: selected ? cs.primaryContainer.withValues(alpha: 0.45) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const Spacer(),
                    if (selected)
                      Icon(Icons.check_circle, color: cs.primary, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServicePickerSheet extends StatefulWidget {
  final String title;
  final List<ServiceNode> services;
  final List<Device> devices;
  final Set<String> suggestedIds;
  final String? selectedId;

  /// Purpose: Create the searchable service picker sheet.
  /// Inputs: `title`, `services`, `devices`, `suggestedIds`, `selectedId`.
  /// Returns: A new `_ServicePickerSheet`.
  /// Side effects: None.
  /// Notes: Pops the picked `ServiceNode`.
  const _ServicePickerSheet({
    required this.title,
    required this.services,
    required this.devices,
    required this.suggestedIds,
    required this.selectedId,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `_ServicePickerSheetState`.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<_ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<_ServicePickerSheet> {
  final _searchCtrl = TextEditingController();

  /// Purpose: Release the search controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the controller.
  /// Notes: None.
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Purpose: Return a service's device name.
  /// Inputs: `service`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Falls back to the raw device id.
  String _deviceName(ServiceNode service) =>
      widget.devices
          .where((device) => device.id == service.deviceId)
          .firstOrNull
          ?.name ??
      service.deviceId;

  /// Purpose: Report whether a service matches the search text.
  /// Inputs: `service`, `query` — lower-cased.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Matches the service name, its device name and its ports.
  bool _matches(ServiceNode service, String query) {
    if (query.isEmpty) return true;
    final text = [
      service.name,
      _deviceName(service),
      ...service.endpoints.map((endpoint) => endpoint.portText),
    ].join(' ').toLowerCase();
    return text.contains(query);
  }

  /// Purpose: Render the sheet: title, search field, suggested services,
  /// then every other service grouped by device.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Opens at `sheetInitialSize(window height, preferred: 0.82)`,
  /// capped at `sheetMaxSize`, like the template picker.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = _searchCtrl.text.trim().toLowerCase();
    final matching =
        [
          for (final service in widget.services)
            if (_matches(service, query)) service,
        ]..sort((a, b) {
          final deviceCmp = _deviceName(
            a,
          ).toLowerCase().compareTo(_deviceName(b).toLowerCase());
          if (deviceCmp != 0) return deviceCmp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    final suggested = [
      for (final service in matching)
        if (widget.suggestedIds.contains(service.id)) service,
    ];
    final others = [
      for (final service in matching)
        if (!widget.suggestedIds.contains(service.id)) service,
    ];
    final children = <Widget>[
      if (suggested.isNotEmpty) ...[
        _header(context, l10n.serviceAccessSuggested),
        for (final service in suggested) _tile(context, service),
        if (others.isNotEmpty)
          _header(context, l10n.serviceAccessOtherServices),
      ],
      for (var i = 0; i < others.length; i++) ...[
        if (suggested.isEmpty &&
            (i == 0 || others[i - 1].deviceId != others[i].deviceId))
          _header(context, _deviceName(others[i])),
        _tile(context, others[i]),
      ],
    ];
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: sheetInitialSize(
            MediaQuery.sizeOf(context).height,
            preferred: 0.82,
          ),
          minChildSize: 0.45,
          maxChildSize: sheetMaxSize,
          builder: (context, scrollController) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                key: const Key('access-picker-search'),
                controller: _searchCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.serviceAccessSearchServices,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Purpose: Build a group heading.
  /// Inputs: `context`, `text`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  /// Purpose: Build one service row.
  /// Inputs: `context`, `service`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Keyed `access-pick-<service id>`; tapping pops the service.
  Widget _tile(BuildContext context, ServiceNode service) => ListTile(
    key: ValueKey('access-pick-${service.id}'),
    leading: CircleAvatar(child: Icon(iconForServiceIcon(service.icon))),
    title: Text(service.name),
    subtitle: Text(
      [
        _deviceName(service),
        service.endpoints
            .map((endpoint) => endpoint.portText)
            .where((text) => text != '-')
            .take(3)
            .join(', '),
      ].where((part) => part.isNotEmpty).join(' · '),
    ),
    trailing: service.id == widget.selectedId
        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
        : null,
    onTap: () => Navigator.of(context).pop(service),
  );
}
