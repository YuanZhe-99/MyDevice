import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/service.dart';
import '../services/service_storage.dart';

class ServiceRouteEditPage extends StatefulWidget {
  final ServiceRoute? route;
  final ServiceNode? sourceService;

  const ServiceRouteEditPage({super.key, this.route, this.sourceService});

  @override
  State<ServiceRouteEditPage> createState() => _ServiceRouteEditPageState();
}

class _ServiceRouteEditPageState extends State<ServiceRouteEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _finalUrlCtrl;
  late final TextEditingController _notesCtrl;
  List<ServiceNode> _services = [];
  List<ServiceRouteHop> _hops = [];
  String? _sourceServiceId;
  String? _sourceEndpointId;
  ServiceAccessLevel _accessLevel = ServiceAccessLevel.lan;
  bool _loading = true;

  bool get _editing => widget.route != null;

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    _nameCtrl = TextEditingController(text: route?.name ?? '');
    _finalUrlCtrl = TextEditingController(text: route?.finalUrl ?? '');
    _notesCtrl = TextEditingController(text: route?.notes ?? '');
    _sourceServiceId = route?.sourceServiceId ?? widget.sourceService?.id;
    _sourceEndpointId =
        route?.sourceEndpointId ??
        widget.sourceService?.endpoints.firstOrNull?.id;
    _accessLevel = route?.accessLevel ?? ServiceAccessLevel.lan;
    _hops = List<ServiceRouteHop>.of(route?.hops ?? const []);
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _finalUrlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

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

  ServiceNode? get _selectedSource => _sourceServiceId == null
      ? null
      : _services
            .where((service) => service.id == _sourceServiceId)
            .firstOrNull;

  ServiceEndpoint? get _selectedEndpoint {
    final source = _selectedSource;
    if (source == null || _sourceEndpointId == null) return null;
    return source.endpoints
        .where((endpoint) => endpoint.id == _sourceEndpointId)
        .firstOrNull;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sourceServiceId == null) return;
    final existing = widget.route;
    final route = ServiceRoute(
      id: existing?.id,
      name: _nameCtrl.text.trim(),
      sourceServiceId: _sourceServiceId!,
      sourceEndpointId: _sourceEndpointId,
      hops: _hops,
      finalUrl: _emptyToNull(_finalUrlCtrl.text),
      accessLevel: _accessLevel,
      notes: _emptyToNull(_notesCtrl.text),
      extraJson: existing?.extraJson ?? const {},
    );
    await ServiceStorage.addOrUpdateRoute(route);
    if (mounted) Navigator.of(context).pop(true);
  }

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

  Future<void> _addHop() async {
    final hop = await _showHopDialog();
    if (hop != null) setState(() => _hops.add(hop));
  }

  Future<void> _editHop(int index) async {
    final hop = await _showHopDialog(initial: _hops[index]);
    if (hop != null) setState(() => _hops[index] = hop);
  }

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
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: l10n.serviceRouteName,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? l10n.serviceNameRequired
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _sourceServiceId,
                    decoration: InputDecoration(
                      labelText: l10n.routeSourceService,
                    ),
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
                      _sourceEndpointId =
                          _selectedSource?.endpoints.firstOrNull?.id;
                    }),
                  ),
                  if (source != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _sourceEndpointId,
                      decoration: InputDecoration(
                        labelText: l10n.serviceEndpoint,
                      ),
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
                      onChanged: (value) =>
                          setState(() => _sourceEndpointId = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ServiceAccessLevel>(
                    initialValue: _accessLevel,
                    decoration: InputDecoration(
                      labelText: l10n.serviceAccessLevel,
                    ),
                    items: ServiceAccessLevel.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name),
                          ),
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
                      hintText: 'https://example.com',
                    ),
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
                              onPressed: i == 0
                                  ? null
                                  : () => _moveHop(i, i - 1),
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
                              onPressed: () =>
                                  setState(() => _hops.removeAt(i)),
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
                ],
              ),
            ),
    );
  }

  String _hopTitle(ServiceRouteHop hop) {
    if (hop.serviceId != null) {
      final service = _services.where((s) => s.id == hop.serviceId).firstOrNull;
      if (service != null) return service.name;
    }
    if (hop.label != null && hop.label!.isNotEmpty) return hop.label!;
    if (hop.host != null && hop.host!.isNotEmpty) return hop.host!;
    return hop.type.name;
  }

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

  ServiceEndpoint? _hopEndpoint(ServiceRouteHop hop) {
    if (hop.serviceId == null || hop.endpointId == null) return null;
    final service = _services.where((s) => s.id == hop.serviceId).firstOrNull;
    return service?.endpoints
        .where((endpoint) => endpoint.id == hop.endpointId)
        .firstOrNull;
  }

  void _moveHop(int from, int to) {
    setState(() {
      final hop = _hops.removeAt(from);
      _hops.insert(to, hop);
    });
  }

  String _routePreview() {
    final source = _selectedSource;
    final endpoint = _selectedEndpoint;
    final parts = <String>[
      if (source != null)
        endpoint?.port != null
            ? '${source.name} ${endpoint!.portText}'
            : source.name,
      ..._hops.map(_hopTitle),
      if (_finalUrlCtrl.text.trim().isNotEmpty) _finalUrlCtrl.text.trim(),
    ];
    return parts.isEmpty ? '-' : parts.join(' -> ');
  }
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
