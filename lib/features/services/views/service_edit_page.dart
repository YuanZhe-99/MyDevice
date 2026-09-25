import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/utils/detail_layout.dart';
import '../../devices/models/device.dart';
import '../../devices/services/device_storage.dart';
import '../models/service.dart';
import '../services/service_storage.dart';
import '../services/service_template_service.dart';
import 'service_endpoint_dialog.dart';
import 'service_topology_widgets.dart';

/// What the service edit page did, returned when it pops.
///
/// Callers that only reload can test for a non-null result; the guided
/// access-path page uses [saved] to select a service it just created inline.
class ServiceEditOutcome {
  /// The service as saved, or null when the page deleted it.
  final ServiceNode? saved;

  /// Whether the page deleted the service.
  final bool deleted;

  /// Purpose: Create an edit-page result.
  /// Inputs: `saved` — the saved service; `deleted` — true after a delete.
  /// Returns: A new `ServiceEditOutcome`.
  /// Side effects: None.
  /// Notes: Exactly one of the two is set by the page.
  const ServiceEditOutcome({this.saved, this.deleted = false});
}

class ServiceEditPage extends StatefulWidget {
  final ServiceNode? service;
  final String? deviceId;
  final ServiceTemplate? template;

  /// Purpose: Create a service edit page instance.
  /// Inputs: `service` — the service to edit, or null to add one;
  /// `deviceId` — the device a new service starts on; `template` — a template
  /// a new service starts from.
  /// Returns: A new `ServiceEditPage` instance.
  /// Side effects: None.
  /// Notes: Pops a [ServiceEditOutcome] after a save or a delete, and nothing
  /// when the user backs out. `template` is ignored when editing.
  const ServiceEditPage({
    super.key,
    this.service,
    this.deviceId,
    this.template,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `State` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  @override
  State<ServiceEditPage> createState() => _ServiceEditPageState();
}

class _ServiceEditPageState extends State<ServiceEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _composeCtrl;
  late final TextEditingController _iconCtrl;
  List<Device> _devices = [];
  List<ServiceEndpoint> _endpoints = [];
  String? _deviceId;
  String? _templateId;
  String? _icon;
  ServiceKind _kind = ServiceKind.custom;
  ServiceRuntime? _runtime;
  ServiceState _state = ServiceState.active;
  bool _loading = true;

  /// Purpose: Edit ing and refresh local state when needed.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  bool get _editing => widget.service != null;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Registers listeners and may kick off asynchronous loading.
  /// Notes: Guard any post-await UI updates with `mounted` when needed.
  @override
  void initState() {
    super.initState();
    final service = widget.service;
    _nameCtrl = TextEditingController(text: service?.name ?? '');
    _notesCtrl = TextEditingController(text: service?.notes ?? '');
    _composeCtrl = TextEditingController(text: service?.dockerCompose ?? '');
    _iconCtrl = TextEditingController(text: service?.icon ?? '');
    _deviceId = service?.deviceId ?? widget.deviceId;
    _templateId = service?.templateId;
    _icon = service?.icon;
    _kind = service?.kind ?? ServiceKind.custom;
    _runtime = service?.runtime;
    _state = service?.state ?? ServiceState.active;
    _endpoints = List<ServiceEndpoint>.of(service?.endpoints ?? const []);
    final template = widget.template;
    if (service == null && template != null) _assignTemplate(template);
    _loadDevices();
  }

  /// Purpose: Release listeners, controllers, and other owned resources.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Releases owned resources and unregisters listeners.
  /// Notes: Call the superclass implementation in the expected lifecycle order.
  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _composeCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  /// Purpose: Load devices into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadDevices() async {
    final data = await DeviceStorage.load();
    if (!mounted) return;
    final devices = data.devices.where((device) => device.isInService).toList();
    setState(() {
      _devices = devices;
      _deviceId ??= devices.firstOrNull?.id;
      _loading = false;
    });
  }

  /// Purpose: Apply a picked template to the form and rebuild.
  /// Inputs: `template`.
  /// Returns: `void`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  void _applyTemplate(ServiceTemplate template) {
    setState(() => _assignTemplate(template));
  }

  /// Purpose: Copy a template's name, icon, kind, runtime, endpoints and
  /// Compose example into the form fields.
  /// Inputs: `template`.
  /// Returns: `void`.
  /// Side effects: Mutates the form state without rebuilding; callers wrap it
  /// in `setState` unless they run before the first build.
  /// Notes: Internal helper used within this file only. Endpoints get fresh
  /// ids, so two services made from one template never share endpoint ids.
  void _assignTemplate(ServiceTemplate template) {
    _templateId = template.id;
    _nameCtrl.text = template.name;
    _icon = template.icon;
    _iconCtrl.text = template.icon;
    _kind = template.kind;
    _runtime = template.runtime;
    _endpoints = [
      for (final endpoint in template.endpoints)
        ServiceEndpoint(
          label: endpoint.label,
          protocol: endpoint.protocol,
          transport: endpoint.transport,
          bindAddress: endpoint.bindAddress,
          port: endpoint.port,
          portEnd: endpoint.portEnd,
          path: endpoint.path,
          networkId: endpoint.networkId,
          scope: endpoint.scope,
          isPrimary: endpoint.isPrimary,
          notes: endpoint.notes,
        ),
    ];
    if ((template.dockerCompose ?? '').isNotEmpty) {
      _composeCtrl.text = template.dockerCompose!;
    }
  }

  /// Purpose: Provide the internal template name helper for this file.
  /// Inputs: `id`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  String _templateName(String id) =>
      ServiceTemplateService.loadTemplates()
          .where((template) => template.id == id)
          .firstOrNull
          ?.name ??
      id;

  /// Purpose: Pick template from user-provided input.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _pickTemplate() async {
    final template = await showModalBottomSheet<ServiceTemplate>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ServiceTemplatePicker(),
    );
    if (template != null) _applyTemplate(template);
  }

  /// Purpose: Save the relevant data to the relevant storage or service layer.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deviceId == null) return;
    final existing = widget.service;
    final service = ServiceNode(
      id: existing?.id,
      deviceId: _deviceId!,
      name: _nameCtrl.text.trim(),
      templateId: _templateId,
      icon: _icon,
      kind: _kind,
      runtime: _runtime,
      state: _state,
      endpoints: _endpoints,
      tags: existing?.tags ?? const [],
      notes: _emptyToNull(_notesCtrl.text),
      dockerCompose: _emptyToNull(_composeCtrl.text),
      extraJson: existing?.extraJson ?? const {},
    );
    await ServiceStorage.addOrUpdateService(service);
    if (mounted) Navigator.of(context).pop(ServiceEditOutcome(saved: service));
  }

  /// Purpose: Delete the relevant data from the relevant storage or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Opens or updates routes, dialogs, or other UI flows. Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  Future<void> _delete() async {
    final service = widget.service;
    if (service == null) return;
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteService),
        content: Text(l10n.deleteServiceConfirm(service.name)),
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
      await ServiceStorage.deleteService(service.id);
      if (mounted) {
        Navigator.of(context).pop(const ServiceEditOutcome(deleted: true));
      }
    }
  }

  /// Purpose: Provide the internal copy compose helper for this file.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Future<void> _copyCompose() async {
    await Clipboard.setData(ClipboardData(text: _composeCtrl.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.serviceComposeCopied),
      ),
    );
  }

  /// Purpose: Add endpoint through the current flow.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _addEndpoint() async {
    final endpoint = await showServiceEndpointDialog(
      context,
      defaultPrimary: _endpoints.isEmpty,
    );
    if (endpoint != null) setState(() => _endpoints.add(endpoint));
  }

  /// Purpose: Edit endpoint and refresh local state when needed.
  /// Inputs: `index`.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _editEndpoint(int index) async {
    final endpoint = await showServiceEndpointDialog(
      context,
      initial: _endpoints[index],
      defaultPrimary: _endpoints.isEmpty,
    );
    if (endpoint != null) setState(() => _endpoints[index] = endpoint);
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l10n.editService : l10n.addService),
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
          : Form(key: _formKey, child: _buildFormBody(context, l10n)),
    );
  }

  /// Purpose: Build the form body in whichever layout the window calls for.
  /// Inputs: `context`, `l10n`.
  /// Returns: `Widget` — always inside the one `Form`.
  /// Side effects: None beyond building widgets.
  /// Notes: Internal helper used within this file only. Two panes that
  /// **both scroll**: the identity half (name through state) is seven blocks
  /// and ~476 dp, too tall to pin at the 480 dp split floor the way the
  /// device edit page pins its three, so the left pane is a plain scroll view
  /// rather than a fixed column. The pane width is `editFormLeftPaneWidth`,
  /// wider than a detail pane because it holds dropdowns rather than a card
  /// of text. Pushed above the shell: the body width is the raw window.
  Widget _buildFormBody(BuildContext context, AppLocalizations l10n) {
    final screen = MediaQuery.sizeOf(context);
    final identity = _buildIdentityFields(l10n);
    final details = _buildDetailFields(context, l10n);
    if (!useDetailTwoPane(screen.width, screen.height)) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [...identity, ...details],
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
                children: identity,
              ),
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

  /// Purpose: Build the identity half of the form: name, device, template,
  /// icon and kind, icon name, runtime, state.
  /// Inputs: `l10n`.
  /// Returns: `List<Widget>` ready to spread into a list or column.
  /// Side effects: None beyond building widgets.
  /// Notes: Internal helper used within this file only. Extracted from
  /// `build` unchanged so both layouts share it.
  List<Widget> _buildIdentityFields(AppLocalizations l10n) {
    return [
      TextFormField(
        controller: _nameCtrl,
        decoration: InputDecoration(labelText: l10n.serviceName),
        validator: (value) => value == null || value.trim().isEmpty
            ? l10n.serviceNameRequired
            : null,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _deviceId,
        decoration: InputDecoration(labelText: l10n.serviceDevice),
        items: _devices
            .map(
              (device) =>
                  DropdownMenuItem(value: device.id, child: Text(device.name)),
            )
            .toList(),
        onChanged: (value) => setState(() => _deviceId = value),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _pickTemplate,
        icon: const Icon(Icons.category_outlined),
        label: Text(
          _templateId == null
              ? l10n.serviceTemplate
              : '${l10n.serviceTemplate}: ${_templateName(_templateId!)}',
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          CircleAvatar(child: Icon(iconForServiceIcon(_icon))),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<ServiceKind>(
              initialValue: _kind,
              decoration: InputDecoration(labelText: l10n.serviceKind),
              items: ServiceKind.values
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value.name)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _kind = value);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _iconCtrl,
        decoration: InputDecoration(
          labelText: l10n.serviceIcon,
          hintText: 'dns, cloud, source, theaters...',
        ),
        onChanged: (value) => setState(() => _icon = _emptyToNull(value)),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<ServiceRuntime>(
        initialValue: _runtime,
        decoration: InputDecoration(labelText: l10n.serviceRuntime),
        items: [
          DropdownMenuItem<ServiceRuntime>(
            value: null,
            child: Text(l10n.optionalNone),
          ),
          for (final value in ServiceRuntime.values)
            DropdownMenuItem(value: value, child: Text(value.name)),
        ],
        onChanged: (value) => setState(() => _runtime = value),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<ServiceState>(
        initialValue: _state,
        decoration: InputDecoration(labelText: l10n.serviceState),
        items: ServiceState.values
            .map(
              (value) =>
                  DropdownMenuItem(value: value, child: Text(value.name)),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) setState(() => _state = value);
        },
      ),
      const SizedBox(height: 24),
    ];
  }

  /// Purpose: Build the detail half of the form: the endpoints list, notes,
  /// the Docker Compose editor and the save button.
  /// Inputs: `context`, `l10n`.
  /// Returns: `List<Widget>` ready to spread into a `ListView`.
  /// Side effects: None beyond building widgets.
  /// Notes: Internal helper used within this file only. Extracted from
  /// `build` unchanged so both layouts share it.
  List<Widget> _buildDetailFields(BuildContext context, AppLocalizations l10n) {
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              l10n.serviceEndpoints,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton.icon(
            onPressed: _addEndpoint,
            icon: const Icon(Icons.add),
            label: Text(l10n.addServiceEndpoint),
          ),
        ],
      ),
      for (var i = 0; i < _endpoints.length; i++)
        Card(
          child: ListTile(
            title: Text(
              '${_endpoints[i].protocol.name}/${_endpoints[i].portText}',
            ),
            subtitle: Text(
              [
                _endpoints[i].label,
                _endpoints[i].bindAddress,
                _endpoints[i].path,
              ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() => _endpoints.removeAt(i)),
            ),
            onTap: () => _editEndpoint(i),
          ),
        ),
      const SizedBox(height: 16),
      TextField(
        controller: _notesCtrl,
        decoration: InputDecoration(labelText: l10n.deviceNotes),
        maxLines: 4,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              l10n.serviceDockerCompose,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: l10n.copyServiceCompose,
            onPressed: _composeCtrl.text.isEmpty ? null : _copyCompose,
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      TextField(
        controller: _composeCtrl,
        decoration: InputDecoration(
          hintText: 'services:\n  app:\n    image: ...',
          border: const OutlineInputBorder(),
        ),
        minLines: 6,
        maxLines: 14,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.save),
        label: Text(l10n.save),
      ),
    ];
  }
}

/// Purpose: Provide the internal empty to null helper for this file.
/// Inputs: `value`.
/// Returns: `String?`.
/// Side effects: May update UI state or trigger user-facing flows.
/// Notes: Internal helper used within this file only.
String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

class _ServiceTemplatePicker extends StatefulWidget {
  /// Purpose: Create a service template picker instance.
  /// Inputs: None.
  /// Returns: A new `_ServiceTemplatePicker` instance.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  const _ServiceTemplatePicker();

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `State` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  @override
  State<_ServiceTemplatePicker> createState() => _ServiceTemplatePickerState();
}

class _ServiceTemplatePickerState extends State<_ServiceTemplatePicker> {
  final _searchCtrl = TextEditingController();
  ServiceKind? _kind;

  /// Purpose: Release listeners, controllers, and other owned resources.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Releases owned resources and unregisters listeners.
  /// Notes: Call the superclass implementation in the expected lifecycle order.
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Purpose: Provide the internal filtered templates helper for this file.
  /// Inputs: None.
  /// Returns: `List<ServiceTemplate>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  List<ServiceTemplate> get _filteredTemplates {
    final query = _searchCtrl.text.trim().toLowerCase();
    final templates = ServiceTemplateService.loadTemplates().where((template) {
      final matchesKind = _kind == null || template.kind == _kind;
      final matchesQuery =
          query.isEmpty ||
          template.name.toLowerCase().contains(query) ||
          template.id.toLowerCase().contains(query) ||
          template.tags.any((tag) => tag.toLowerCase().contains(query));
      return matchesKind && matchesQuery;
    }).toList();
    templates.sort((a, b) {
      if (a.featured != b.featured) return a.featured ? -1 : 1;
      final kindCmp = a.kind.index.compareTo(b.kind.index);
      if (kindCmp != 0) return kindCmp;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return templates;
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state. Updates widget state and triggers a rebuild.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              Text(
                l10n.servicePickTemplate,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.searchTemplatePlaceholder,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(l10n.filterAll),
                      selected: _kind == null,
                      onSelected: (_) => setState(() => _kind = null),
                    ),
                    const SizedBox(width: 8),
                    for (final kind in ServiceKind.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(kind.name),
                          selected: _kind == kind,
                          onSelected: (_) => setState(() => _kind = kind),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filteredTemplates.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.add)),
                        title: Text(l10n.serviceCustom),
                        subtitle: Text(l10n.serviceCustomTemplateDesc),
                        onTap: () => Navigator.pop(context),
                      );
                    }
                    final template = _filteredTemplates[index - 1];
                    final endpointText = template.endpoints
                        .map(
                          (endpoint) =>
                              '${endpoint.protocol.name}/${endpoint.portText}',
                        )
                        .join(', ');
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(iconForServiceIcon(template.icon)),
                      ),
                      title: Text(template.name),
                      subtitle: Text(
                        [
                          template.kind.name,
                          if (endpointText.isNotEmpty) endpointText,
                          if (template.featured) l10n.serviceFeaturedTemplate,
                        ].join(' · '),
                      ),
                      trailing: template.dockerCompose?.isNotEmpty == true
                          ? const Icon(Icons.description_outlined)
                          : null,
                      onTap: () => Navigator.pop(context, template),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
