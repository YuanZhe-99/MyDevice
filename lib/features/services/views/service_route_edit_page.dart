import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/detail_layout.dart';
import '../models/service.dart';
import '../services/service_analysis.dart';
import '../services/service_storage.dart';

class ServiceRouteEditPage extends StatefulWidget {
  final ServiceRoute? route;
  final ServiceNode? sourceService;

  /// Purpose: Create a service route edit page instance.
  /// Inputs: None.
  /// Returns: A new `ServiceRouteEditPage` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  const ServiceRouteEditPage({super.key, this.route, this.sourceService});

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
    final route = widget.route;
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
      _sourceServiceId ??= data.services.firstOrNull?.id;
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
    final existing = widget.route;
    final source = _selectedSource;
    final targets = _splitTargets(_finalUrlCtrl.text);
    final route = ServiceRoute(
      id: existing?.id,
      name: serviceRouteGeneratedName(
        sourceName: source?.name ?? existing?.name ?? '',
        hops: _hops,
        targets: targets,
      ),
      sourceServiceId: _sourceServiceId!,
      sourceEndpointId: _sourceEndpointId,
      hops: _hops,
      finalUrl: targets.firstOrNull,
      accessLevel: _accessLevel,
      notes: _emptyToNull(_notesCtrl.text),
      extraJson: serviceRouteExtraJsonWithTargets(
        existing?.extraJson ?? const {},
        targets,
      ),
    );
    await ServiceStorage.addOrUpdateRoute(route);
    if (mounted) Navigator.of(context).pop(true);
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

  /// Purpose: Show hop dialog in the current UI flow.
  /// Inputs: None.
  /// Returns: `Future<ServiceRouteHop?>`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Future<ServiceRouteHop?> _showHopDialog({ServiceRouteHop? initial}) async {
    final l10n = AppLocalizations.of(context)!;
    final labelCtrl = TextEditingController(text: initial?.label ?? '');
    final schemeCtrl = TextEditingController(text: initial?.scheme ?? '');
    final hostCtrl = TextEditingController(text: initial?.host ?? '');
    final portCtrl = TextEditingController(
      text: initial?.port?.toString() ?? '',
    );
    final pathCtrl = TextEditingController(text: initial?.path ?? '');
    final notesCtrl = TextEditingController(text: initial?.notes ?? '');
    var type = initial?.type ?? ServiceRouteHopType.manual;
    var method = initial?.method;
    var serviceId = initial?.serviceId;
    var endpointId = initial?.endpointId;

    final result = await showDialog<ServiceRouteHop>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final service = serviceId == null
              ? null
              : _services.where((s) => s.id == serviceId).firstOrNull;
          return AlertDialog(
            title: Text(initial == null ? l10n.addRouteHop : l10n.editRouteHop),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<ServiceRouteHopType>(
                    initialValue: type,
                    decoration: InputDecoration(labelText: l10n.routeHopType),
                    items: ServiceRouteHopType.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ServiceRouteMethod>(
                    initialValue: method,
                    decoration: InputDecoration(labelText: l10n.routeMethod),
                    items: [
                      DropdownMenuItem<ServiceRouteMethod>(
                        value: null,
                        child: Text(l10n.optionalNone),
                      ),
                      for (final value in ServiceRouteMethod.values)
                        DropdownMenuItem(value: value, child: Text(value.name)),
                    ],
                    onChanged: (value) => setDialogState(() => method = value),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: serviceId,
                    decoration: InputDecoration(
                      labelText: l10n.routeHopService,
                    ),
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(l10n.routeManualHop),
                      ),
                      for (final service in _services)
                        DropdownMenuItem(
                          value: service.id,
                          child: Text(service.name),
                        ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      serviceId = value;
                      final selected = value == null
                          ? null
                          : _services.where((s) => s.id == value).firstOrNull;
                      endpointId = selected?.endpoints.firstOrNull?.id;
                    }),
                  ),
                  if (service != null) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: endpointId,
                      decoration: InputDecoration(
                        labelText: l10n.serviceEndpoint,
                      ),
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
                      ],
                      onChanged: (value) =>
                          setDialogState(() => endpointId = value),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: labelCtrl,
                    decoration: InputDecoration(labelText: l10n.routeHopLabel),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: schemeCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.routeScheme,
                            hintText: 'https',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: portCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.servicePort,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hostCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.routeHost,
                      hintText: 'example.com',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pathCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.servicePath,
                      hintText: '/',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(labelText: l10n.deviceNotes),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    ctx,
                    ServiceRouteHop(
                      id: initial?.id,
                      type: type,
                      serviceId: serviceId,
                      endpointId: endpointId,
                      label: _emptyToNull(labelCtrl.text),
                      scheme: _emptyToNull(schemeCtrl.text),
                      host: _emptyToNull(hostCtrl.text),
                      port: int.tryParse(portCtrl.text.trim()),
                      path: _emptyToNull(pathCtrl.text),
                      method: method,
                      notes: _emptyToNull(notesCtrl.text),
                      extraJson: initial?.extraJson ?? const {},
                    ),
                  );
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );

    labelCtrl.dispose();
    schemeCtrl.dispose();
    hostCtrl.dispose();
    portCtrl.dispose();
    pathCtrl.dispose();
    notesCtrl.dispose();
    return result;
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
  /// endpoint, access level, final URL, preview) is five blocks and ~340 dp,
  /// too tall to pin at the split floor, so the left pane is a plain scroll
  /// view. The pane width is `editFormLeftPaneWidth`. Pushed above the
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
  /// endpoint, access level, final URL and the route preview card.
  /// Inputs: `context`, `l10n`, `source`.
  /// Returns: `List<Widget>` ready to spread into a list or column.
  /// Side effects: None beyond building widgets.
  /// Notes: Internal helper used within this file only. Extracted from
  /// `build` unchanged so both layouts share it.
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
              (value) =>
                  DropdownMenuItem(value: value, child: Text(value.name)),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _accessLevel = value);
        },
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
    return hop.type.name;
  }

  /// Purpose: Provide the internal hop subtitle helper for this file.
  /// Inputs: `hop`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _hopSubtitle(ServiceRouteHop hop) {
    final endpoint = _hopEndpoint(hop);
    return [
      hop.type.name,
      hop.method?.name,
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

  /// Purpose: Provide the internal route preview helper for this file.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _routePreview() {
    final source = _selectedSource;
    final endpoint = _selectedEndpoint;
    final parts = <String>[
      if (source != null)
        endpoint?.port != null
            ? '${source.name} ${endpoint!.portText}'
            : source.name,
      ..._hops.map(_hopTitle),
      ..._splitTargets(_finalUrlCtrl.text).map(compactAccessTargetLabel),
    ];
    return parts.isEmpty ? '-' : parts.join(' -> ');
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
