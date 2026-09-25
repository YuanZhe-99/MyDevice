import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/detail_layout.dart';
import '../models/service.dart';
import '../services/service_access_patterns.dart';
import '../services/service_analysis.dart';
import '../services/service_labels.dart';
import '../services/service_storage.dart';
import 'service_access_path_page.dart';

class ServiceRouteEditPage extends StatefulWidget {
  final ServiceRoute? route;
  final ServiceNode? sourceService;
  final ServiceRoute? draft;

  /// Purpose: Create a service route edit page instance.
  /// Inputs: `route` — a saved route to edit; `sourceService` — the source a
  /// new route starts from; `draft` — an unsaved route to start from, handed
  /// over by the guided access-path page.
  /// Returns: A new `ServiceRouteEditPage` instance.
  /// Side effects: None.
  /// Notes: `route` wins over `draft`. Only `route` puts the page in edit
  /// mode (title, delete action, same id on save); a draft saves as a new
  /// route. Pops `true` after a save or a delete.
  const ServiceRouteEditPage({
    super.key,
    this.route,
    this.sourceService,
    this.draft,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `State` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  @override
  State<ServiceRouteEditPage> createState() => _ServiceRouteEditPageState();
}

class _ServiceRouteEditPageState extends State<ServiceRouteEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _finalUrlCtrl;
  late final TextEditingController _notesCtrl;
  List<ServiceNode> _services = [];
  List<ServiceRouteHop> _hops = [];
  String? _sourceServiceId;
  String? _sourceEndpointId;
  ServiceAccessLevel _accessLevel = ServiceAccessLevel.lan;
  ServiceAccessLane? _lane;
  bool _loading = true;

  /// Purpose: Edit ing and refresh local state when needed.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  bool get _editing => widget.route != null;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Registers listeners and may kick off asynchronous loading.
  /// Notes: Guard any post-await UI updates with `mounted` when needed.
  @override
  void initState() {
    super.initState();
    final route = widget.route ?? widget.draft;
    _finalUrlCtrl = TextEditingController(
      text: route == null ? '' : serviceRouteAccessTargets(route).join('\n'),
    );
    _notesCtrl = TextEditingController(text: route?.notes ?? '');
    _sourceServiceId = route?.sourceServiceId ?? widget.sourceService?.id;
    _sourceEndpointId =
        route?.sourceEndpointId ??
        widget.sourceService?.endpoints.firstOrNull?.id;
    _accessLevel = route?.accessLevel ?? ServiceAccessLevel.lan;
    _hops = List<ServiceRouteHop>.of(route?.hops ?? const []);
    _lane = route == null ? null : serviceRouteExplicitAccessLane(route);
    _load();
  }

  /// Purpose: Release listeners, controllers, and other owned resources.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Releases owned resources and unregisters listeners.
  /// Notes: Call the superclass implementation in the expected lifecycle order.
  @override
  void dispose() {
    _finalUrlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Purpose: Load the relevant data into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _load() async {
    final data = await ServiceStorage.load();
    if (!mounted) return;
    setState(() {
      _services = data.services;
      if (_selectedSource == null) {
        _sourceServiceId = data.services.firstOrNull?.id;
        _sourceEndpointId = null;
      }
      if (_sourceEndpointId != null && _selectedEndpoint == null) {
        _sourceEndpointId = null;
      }
      _sourceEndpointId ??= _selectedSource?.endpoints.firstOrNull?.id;
      _loading = false;
    });
  }

  /// Purpose: Provide the internal selected source helper for this file.
  /// Inputs: None.
  /// Returns: `ServiceNode?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  ServiceNode? get _selectedSource => _sourceServiceId == null
      ? null
      : _services
            .where((service) => service.id == _sourceServiceId)
            .firstOrNull;

  /// Purpose: Provide the internal selected endpoint helper for this file.
  /// Inputs: None.
  /// Returns: `ServiceEndpoint?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  ServiceEndpoint? get _selectedEndpoint {
    final source = _selectedSource;
    if (source == null || _sourceEndpointId == null) return null;
    return source.endpoints
        .where((endpoint) => endpoint.id == _sourceEndpointId)
        .firstOrNull;
  }

  /// Purpose: Save the relevant data to the relevant storage or service layer.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sourceServiceId == null) return;
    await ServiceStorage.addOrUpdateRoute(_buildRoute());
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Purpose: Build the route the form currently describes.
  /// Inputs: None.
  /// Returns: `ServiceRoute`.
  /// Side effects: None.
  /// Notes: Keeps the edited route's id and `extraJson`, a draft's
  /// `extraJson`, regenerates the name, stores the targets, and writes or
  /// removes the `accessLane` override from the lane dropdown. Used by save,
  /// the preview and the guided-editor check.
  ServiceRoute _buildRoute() {
    final existing = widget.route;
    final base = widget.route ?? widget.draft;
    final targets = _splitTargets(_finalUrlCtrl.text);
    return ServiceRoute(
      id: existing?.id,
      name: serviceRouteGeneratedName(
        sourceName: _selectedSource?.name ?? base?.name ?? '',
        hops: _hops,
        targets: targets,
      ),
      sourceServiceId: _sourceServiceId ?? '',
      sourceEndpointId: _sourceEndpointId,
      hops: _hops,
      finalUrl: targets.firstOrNull,
      accessLevel: _accessLevel,
      notes: _emptyToNull(_notesCtrl.text),
      extraJson: serviceRouteExtraJsonWithAccessLane(
        serviceRouteExtraJsonWithTargets(base?.extraJson ?? const {}, targets),
        _lane,
      ),
    );
  }

  /// Purpose: Open the guided access-path page on the current form state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Pushes `ServiceAccessPathPage`; pops `true` when it saved
  /// or deleted.
  /// Notes: Offered only when the form state fits an access pattern; an edit
  /// hands over the route itself so the id is kept.
  Future<void> _openGuidedEditor() async {
    final route = _buildRoute();
    final draft = ServiceAccessDraft.fromRoute(route, _services);
    if (draft == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _editing
            ? ServiceAccessPathPage(route: route)
            : ServiceAccessPathPage(draft: draft),
      ),
    );
    if (saved == true && mounted) Navigator.of(context).pop(true);
  }

  /// Purpose: Delete the relevant data from the relevant storage or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows. Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
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
    if (ok == true) {
      await ServiceStorage.deleteRoute(route.id);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  /// Purpose: Add hop through the current flow.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _addHop() async {
    final hop = await _showHopDialog();
    if (hop != null) setState(() => _hops.add(hop));
  }

  /// Purpose: Edit hop and refresh local state when needed.
  /// Inputs: `index`.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _editHop(int index) async {
    final hop = await _showHopDialog(initial: _hops[index]);
    if (hop != null) setState(() => _hops[index] = hop);
  }

  /// Purpose: Show the hop editor dialog and return what the user saved.
  /// Inputs: `initial` — the hop to edit, or null to add one.
  /// Returns: `Future<ServiceRouteHop?>` — null when the user cancels.
  /// Side effects: Shows a dialog; nothing is persisted here.
  /// Notes: The dialog is its own stateful widget, `_ServiceRouteHopDialog`,
  /// so its text controllers outlive the closing animation.
  Future<ServiceRouteHop?> _showHopDialog({ServiceRouteHop? initial}) {
    return showDialog<ServiceRouteHop>(
      context: context,
      builder: (_) =>
          _ServiceRouteHopDialog(initial: initial, services: _services),
    );
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state. Updates widget state and triggers a rebuild.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final source = _selectedSource;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l10n.editServiceRoute : l10n.addServiceRoute),
        actions: [
          if (_editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(key: _formKey, child: _buildFormBody(context, l10n, source)),
    );
  }

  /// Purpose: Build the form body in whichever layout the window calls for.
  /// Inputs: `context`, `l10n`, `source` — the selected source service.
  /// Returns: `Widget` — always inside the one `Form`.
  /// Side effects: None beyond building widgets.
  /// Notes: Internal helper used within this file only. Two panes that
  /// **both scroll**, like the service edit page: the source half (source,
  /// endpoint, access level, lane, final URL, preview) is six blocks and
  /// ~410 dp, too tall to pin at the split floor, so the left pane is a
  /// plain scroll view. The pane width is `editFormLeftPaneWidth`. Pushed above the
  /// shell: the body width is the raw window.
  Widget _buildFormBody(
    BuildContext context,
    AppLocalizations l10n,
    ServiceNode? source,
  ) {
    final screen = MediaQuery.sizeOf(context);
    final sourceFields = _buildSourceFields(context, l10n, source);
    final hopFields = _buildHopFields(context, l10n);
    if (!useDetailTwoPane(screen.width, screen.height)) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [...sourceFields, ...hopFields],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: editFormLeftPaneWidth(constraints.maxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: sourceFields,
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: hopFields,
            ),
          ),
        ],
      ),
    );
  }

  /// Purpose: Build the source half of the form: source service, its
  /// endpoint, access level, topology lane, final URL and the route preview
  /// card with the "Guided editor" action.
  /// Inputs: `context`, `l10n`, `source`.
  /// Returns: `List<Widget>` ready to spread into a list or column.
  /// Side effects: None beyond building widgets.
  /// Notes: Internal helper used within this file only. The lane dropdown
  /// writes or clears `extraJson['accessLane']`; the guided action appears
  /// only while the form state fits an access pattern.
  List<Widget> _buildSourceFields(
    BuildContext context,
    AppLocalizations l10n,
    ServiceNode? source,
  ) {
    return [
      DropdownButtonFormField<String>(
        initialValue: _sourceServiceId,
        decoration: InputDecoration(labelText: l10n.routeSourceService),
        items: _services
            .map(
              (service) => DropdownMenuItem(
                value: service.id,
                child: Text(service.name),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() {
          _sourceServiceId = value;
          _sourceEndpointId = _selectedSource?.endpoints.firstOrNull?.id;
        }),
      ),
      if (source != null) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _sourceEndpointId,
          decoration: InputDecoration(labelText: l10n.serviceEndpoint),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(l10n.optionalNone),
            ),
            for (final endpoint in source.endpoints)
              DropdownMenuItem(
                value: endpoint.id,
                child: Text(
                  '${endpoint.label ?? endpoint.protocol.name} · ${endpoint.portText}',
                ),
              ),
          ],
          onChanged: (value) => setState(() => _sourceEndpointId = value),
        ),
      ],
      const SizedBox(height: 12),
      DropdownButtonFormField<ServiceAccessLevel>(
        initialValue: _accessLevel,
        decoration: InputDecoration(labelText: l10n.serviceAccessLevel),
        items: ServiceAccessLevel.values
            .map(
              (value) => DropdownMenuItem(
                value: value,
                child: Text(serviceAccessLevelLabel(l10n, value)),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _accessLevel = value);
        },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<ServiceAccessLane?>(
        key: const Key('route-lane'),
        initialValue: _lane,
        decoration: InputDecoration(labelText: l10n.serviceAccessLaneField),
        items: [
          DropdownMenuItem<ServiceAccessLane?>(
            value: null,
            child: Text(l10n.serviceAccessLaneAuto),
          ),
          for (final lane in ServiceAccessLane.values)
            DropdownMenuItem<ServiceAccessLane?>(
              value: lane,
              child: Text(serviceAccessLaneLabel(l10n, lane)),
            ),
        ],
        onChanged: (value) => setState(() => _lane = value),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _finalUrlCtrl,
        decoration: InputDecoration(
          labelText: l10n.serviceFinalUrl,
          hintText: 'https://example.com\nhttps://app.example.com',
          helperText: l10n.serviceAccessTargetsHint,
        ),
        minLines: 2,
        maxLines: 4,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      Card(
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
              Text(_routePreview()),
              if (ServiceAccessDraft.fromRoute(_buildRoute(), _services) !=
                  null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const Key('route-guided-editor'),
                    onPressed: _openGuidedEditor,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(l10n.serviceAccessGuidedEditor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  /// Purpose: Build the hop half of the form: the hops list, notes and the
  /// save button.
  /// Inputs: `context`, `l10n`.
  /// Returns: `List<Widget>` ready to spread into a `ListView`.
  /// Side effects: None beyond building widgets.
  /// Notes: Internal helper used within this file only. Extracted from
  /// `build` unchanged so both layouts share it.
  List<Widget> _buildHopFields(BuildContext context, AppLocalizations l10n) {
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              l10n.routeHops,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton.icon(
            onPressed: _addHop,
            icon: const Icon(Icons.add),
            label: Text(l10n.addRouteHop),
          ),
        ],
      ),
      for (var i = 0; i < _hops.length; i++)
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(_hopTitle(_hops[i])),
            subtitle: Text(_hopSubtitle(_hops[i])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l10n.serviceMoveUp,
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: i == 0 ? null : () => _moveHop(i, i - 1),
                ),
                IconButton(
                  tooltip: l10n.serviceMoveDown,
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: i == _hops.length - 1
                      ? null
                      : () => _moveHop(i, i + 1),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _hops.removeAt(i)),
                ),
              ],
            ),
            onTap: () => _editHop(i),
          ),
        ),
      const SizedBox(height: 16),
      TextField(
        controller: _notesCtrl,
        decoration: InputDecoration(labelText: l10n.deviceNotes),
        maxLines: 4,
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.save),
        label: Text(l10n.save),
      ),
    ];
  }

  /// Purpose: Provide the internal hop title helper for this file.
  /// Inputs: `hop`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _hopTitle(ServiceRouteHop hop) {
    if (hop.serviceId != null) {
      final service = _services.where((s) => s.id == hop.serviceId).firstOrNull;
      if (service != null) return service.name;
    }
    if (hop.label != null && hop.label!.isNotEmpty) return hop.label!;
    if (hop.host != null && hop.host!.isNotEmpty) return hop.host!;
    return serviceHopTypeLabel(AppLocalizations.of(context)!, hop.type);
  }

  /// Purpose: Provide the internal hop subtitle helper for this file.
  /// Inputs: `hop`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _hopSubtitle(ServiceRouteHop hop) {
    final endpoint = _hopEndpoint(hop);
    final l10n = AppLocalizations.of(context)!;
    return [
      serviceHopTypeLabel(l10n, hop.type),
      if (hop.method != null) serviceRouteMethodUiLabel(l10n, hop.method!),
      if (endpoint != null) '${endpoint.protocol.name}/${endpoint.portText}',
      if (hop.host != null && hop.host!.isNotEmpty)
        '${hop.scheme != null ? '${hop.scheme}://' : ''}${hop.host}${hop.port != null ? ':${hop.port}' : ''}${hop.path ?? ''}',
      hop.notes,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  }

  /// Purpose: Provide the internal hop endpoint helper for this file.
  /// Inputs: `hop`.
  /// Returns: `ServiceEndpoint?`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  ServiceEndpoint? _hopEndpoint(ServiceRouteHop hop) {
    if (hop.serviceId == null || hop.endpointId == null) return null;
    final service = _services.where((s) => s.id == hop.serviceId).firstOrNull;
    return service?.endpoints
        .where((endpoint) => endpoint.id == hop.endpointId)
        .firstOrNull;
  }

  /// Purpose: Provide the internal move hop helper for this file.
  /// Inputs: `from`, `to`.
  /// Returns: `void`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  void _moveHop(int from, int to) {
    setState(() {
      final hop = _hops.removeAt(from);
      _hops.insert(to, hop);
    });
  }

  /// Purpose: Describe the form's route on one line for the preview card.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Delegates to `serviceRouteChainPreview`, localizing hops that
  /// have no service or label of their own.
  String _routePreview() {
    final l10n = AppLocalizations.of(context)!;
    return serviceRouteChainPreview(
      _buildRoute(),
      services: _services,
      hopFallback: (hop) => serviceHopFallbackLabel(l10n, hop),
    );
  }
}

class _ServiceRouteHopDialog extends StatefulWidget {
  final ServiceRouteHop? initial;
  final List<ServiceNode> services;

  /// Purpose: Create the hop editor dialog.
  /// Inputs: `initial` — the hop to edit, or null; `services` — the services
  /// a hop can reference.
  /// Returns: A new `_ServiceRouteHopDialog`.
  /// Side effects: None.
  /// Notes: Pops the built `ServiceRouteHop` on save; an edited hop keeps its
  /// id and `extraJson`.
  const _ServiceRouteHopDialog({required this.initial, required this.services});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `_ServiceRouteHopDialogState`.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<_ServiceRouteHopDialog> createState() => _ServiceRouteHopDialogState();
}

class _ServiceRouteHopDialogState extends State<_ServiceRouteHopDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _schemeCtrl;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _pathCtrl;
  late final TextEditingController _notesCtrl;
  late ServiceRouteHopType _type;
  ServiceRouteMethod? _method;
  String? _serviceId;
  String? _endpointId;

  /// Purpose: Seed the fields from the hop being edited, or defaults.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Creates the six text controllers.
  /// Notes: A new hop starts as a manual hop without a method.
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _labelCtrl = TextEditingController(text: initial?.label ?? '');
    _schemeCtrl = TextEditingController(text: initial?.scheme ?? '');
    _hostCtrl = TextEditingController(text: initial?.host ?? '');
    _portCtrl = TextEditingController(text: initial?.port?.toString() ?? '');
    _pathCtrl = TextEditingController(text: initial?.path ?? '');
    _notesCtrl = TextEditingController(text: initial?.notes ?? '');
    _type = initial?.type ?? ServiceRouteHopType.manual;
    _method = initial?.method;
    _serviceId = initial?.serviceId;
    _endpointId = initial?.endpointId;
  }

  /// Purpose: Release the text controllers once the dialog is gone.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the six controllers.
  /// Notes: Runs after the route's exit animation, never during it.
  @override
  void dispose() {
    _labelCtrl.dispose();
    _schemeCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _pathCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Purpose: Pop the hop the fields describe.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: Closes the dialog with the result.
  /// Notes: Blank text fields become null; an unparsable port becomes null.
  void _submit() {
    final initial = widget.initial;
    Navigator.pop(
      context,
      ServiceRouteHop(
        id: initial?.id,
        type: _type,
        serviceId: _serviceId,
        endpointId: _endpointId,
        label: _emptyToNull(_labelCtrl.text),
        scheme: _emptyToNull(_schemeCtrl.text),
        host: _emptyToNull(_hostCtrl.text),
        port: int.tryParse(_portCtrl.text.trim()),
        path: _emptyToNull(_pathCtrl.text),
        method: _method,
        notes: _emptyToNull(_notesCtrl.text),
        extraJson: initial?.extraJson ?? const {},
      ),
    );
  }

  /// Purpose: Build the dialog.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Hop type and method are localized. A service or endpoint id the
  /// inventory no longer has stays selectable as its raw id, so opening such
  /// a hop neither asserts nor drops the reference. The dropdowns are
  /// `isExpanded` so a long product or service name ellipsizes instead of
  /// overflowing a phone-width dialog.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = _serviceId == null
        ? null
        : widget.services.where((s) => s.id == _serviceId).firstOrNull;
    final serviceMissing = _serviceId != null && service == null;
    final endpointMissing =
        service != null &&
        _endpointId != null &&
        !service.endpoints.any((endpoint) => endpoint.id == _endpointId);
    return AlertDialog(
      title: Text(
        widget.initial == null ? l10n.addRouteHop : l10n.editRouteHop,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<ServiceRouteHopType>(
              isExpanded: true,
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.routeHopType),
              items: ServiceRouteHopType.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(serviceHopTypeLabel(l10n, value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ServiceRouteMethod>(
              isExpanded: true,
              initialValue: _method,
              decoration: InputDecoration(labelText: l10n.routeMethod),
              items: [
                DropdownMenuItem<ServiceRouteMethod>(
                  value: null,
                  child: Text(l10n.optionalNone),
                ),
                for (final value in ServiceRouteMethod.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(serviceRouteMethodUiLabel(l10n, value)),
                  ),
              ],
              onChanged: (value) => setState(() => _method = value),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _serviceId,
              decoration: InputDecoration(labelText: l10n.routeHopService),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(l10n.routeManualHop),
                ),
                for (final service in widget.services)
                  DropdownMenuItem(
                    value: service.id,
                    child: Text(service.name),
                  ),
                if (serviceMissing)
                  DropdownMenuItem(value: _serviceId, child: Text(_serviceId!)),
              ],
              onChanged: (value) => setState(() {
                _serviceId = value;
                final selected = value == null
                    ? null
                    : widget.services.where((s) => s.id == value).firstOrNull;
                _endpointId = selected?.endpoints.firstOrNull?.id;
              }),
            ),
            if (service != null) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _endpointId,
                decoration: InputDecoration(labelText: l10n.serviceEndpoint),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(l10n.optionalNone),
                  ),
                  for (final endpoint in service.endpoints)
                    DropdownMenuItem(
                      value: endpoint.id,
                      child: Text(
                        '${endpoint.label ?? endpoint.protocol.name} · ${endpoint.portText}',
                      ),
                    ),
                  if (endpointMissing)
                    DropdownMenuItem(
                      value: _endpointId,
                      child: Text(_endpointId!),
                    ),
                ],
                onChanged: (value) => setState(() => _endpointId = value),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _labelCtrl,
              decoration: InputDecoration(labelText: l10n.routeHopLabel),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _schemeCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.routeScheme,
                      hintText: 'https',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _portCtrl,
                    decoration: InputDecoration(labelText: l10n.servicePort),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hostCtrl,
              decoration: InputDecoration(
                labelText: l10n.routeHost,
                hintText: 'example.com',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pathCtrl,
              decoration: InputDecoration(
                labelText: l10n.servicePath,
                hintText: '/',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(labelText: l10n.deviceNotes),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

/// Purpose: Provide the internal split targets helper for this file.
/// Inputs: `value`.
/// Returns: `List<String>`.
/// Side effects: May update UI state or trigger user-facing flows.
/// Notes: Internal helper used within this file only.
List<String> _splitTargets(String value) => value
    .split(RegExp(r'[\n,]+'))
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

/// Purpose: Provide the internal empty to null helper for this file.
/// Inputs: `value`.
/// Returns: `String?`.
/// Side effects: May update UI state or trigger user-facing flows.
/// Notes: Internal helper used within this file only.
String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
