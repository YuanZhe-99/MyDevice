import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/service.dart';

/// Purpose: Show the endpoint editor dialog and return what the user saved.
/// Inputs: `context`; `initial` — the endpoint to edit, or null to add one;
/// `defaultPrimary` — whether a new endpoint starts marked primary.
/// Returns: `Future<ServiceEndpoint?>` — the edited or new endpoint, or null
/// when the user cancels.
/// Side effects: Shows a dialog; nothing is persisted here.
/// Notes: Shared by the service edit page and the guided access-path page's
/// inline "Add endpoint". An edited endpoint keeps its id and `extraJson`.
/// The dialog is its own stateful widget so its text controllers live until
/// the closing animation has finished; disposing them when `showDialog`
/// returns (as the pre-1.5.6 code did) let the fading dialog rebuild with
/// disposed controllers.
Future<ServiceEndpoint?> showServiceEndpointDialog(
  BuildContext context, {
  ServiceEndpoint? initial,
  required bool defaultPrimary,
}) {
  return showDialog<ServiceEndpoint>(
    context: context,
    builder: (_) => _ServiceEndpointDialog(
      initial: initial,
      defaultPrimary: defaultPrimary,
    ),
  );
}

class _ServiceEndpointDialog extends StatefulWidget {
  final ServiceEndpoint? initial;
  final bool defaultPrimary;

  /// Purpose: Create the endpoint editor dialog.
  /// Inputs: `initial` — the endpoint to edit, or null; `defaultPrimary` —
  /// the primary checkbox's start value for a new endpoint.
  /// Returns: A new `_ServiceEndpointDialog`.
  /// Side effects: None.
  /// Notes: Pops the built `ServiceEndpoint` on save.
  const _ServiceEndpointDialog({
    required this.initial,
    required this.defaultPrimary,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `_ServiceEndpointDialogState`.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<_ServiceEndpointDialog> createState() => _ServiceEndpointDialogState();
}

class _ServiceEndpointDialogState extends State<_ServiceEndpointDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _bindCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _portEndCtrl;
  late final TextEditingController _pathCtrl;
  late ServiceProtocol _protocol;
  late ServiceTransport _transport;
  late ServiceScope _scope;
  late bool _primary;

  /// Purpose: Seed the fields from the endpoint being edited, or defaults.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Creates the five text controllers.
  /// Notes: Defaults are `http`, `tcp`, `lan`, and `defaultPrimary`.
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _labelCtrl = TextEditingController(text: initial?.label ?? '');
    _bindCtrl = TextEditingController(text: initial?.bindAddress ?? '');
    _portCtrl = TextEditingController(text: initial?.port?.toString() ?? '');
    _portEndCtrl = TextEditingController(
      text: initial?.portEnd?.toString() ?? '',
    );
    _pathCtrl = TextEditingController(text: initial?.path ?? '');
    _protocol = initial?.protocol ?? ServiceProtocol.http;
    _transport = initial?.transport ?? ServiceTransport.tcp;
    _scope = initial?.scope ?? ServiceScope.lan;
    _primary = initial?.isPrimary ?? widget.defaultPrimary;
  }

  /// Purpose: Release the text controllers once the dialog is gone.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the five controllers.
  /// Notes: Runs after the route's exit animation, never during it.
  @override
  void dispose() {
    _labelCtrl.dispose();
    _bindCtrl.dispose();
    _portCtrl.dispose();
    _portEndCtrl.dispose();
    _pathCtrl.dispose();
    super.dispose();
  }

  /// Purpose: Pop the endpoint the fields describe.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: Closes the dialog with the result.
  /// Notes: Blank label, bind address and path become null; unparsable ports
  /// become null.
  void _submit() {
    final initial = widget.initial;
    Navigator.pop(
      context,
      ServiceEndpoint(
        id: initial?.id,
        label: _emptyToNull(_labelCtrl.text),
        protocol: _protocol,
        transport: _transport,
        bindAddress: _emptyToNull(_bindCtrl.text),
        port: int.tryParse(_portCtrl.text.trim()),
        portEnd: int.tryParse(_portEndCtrl.text.trim()),
        path: _emptyToNull(_pathCtrl.text),
        scope: _scope,
        isPrimary: _primary,
        extraJson: initial?.extraJson ?? const {},
      ),
    );
  }

  /// Purpose: Build the dialog.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Label, protocol, transport, port and port end, bind address,
  /// path, scope and the primary checkbox.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? l10n.addServiceEndpoint
            : l10n.editServiceEndpoint,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _labelCtrl,
              decoration: InputDecoration(labelText: l10n.serviceEndpointLabel),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ServiceProtocol>(
              initialValue: _protocol,
              decoration: InputDecoration(labelText: l10n.serviceProtocol),
              items: ServiceProtocol.values
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value.name)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _protocol = value);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ServiceTransport>(
              initialValue: _transport,
              decoration: InputDecoration(labelText: l10n.serviceTransport),
              items: ServiceTransport.values
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value.name)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _transport = value);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _portCtrl,
                    decoration: InputDecoration(labelText: l10n.servicePort),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _portEndCtrl,
                    decoration: InputDecoration(labelText: l10n.servicePortEnd),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bindCtrl,
              decoration: InputDecoration(
                labelText: l10n.serviceBindAddress,
                hintText: '0.0.0.0',
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
            DropdownButtonFormField<ServiceScope>(
              initialValue: _scope,
              decoration: InputDecoration(labelText: l10n.serviceScope),
              items: ServiceScope.values
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value.name)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _scope = value);
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _primary,
              title: Text(l10n.servicePrimaryEndpoint),
              onChanged: (value) => setState(() => _primary = value ?? false),
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

/// Purpose: Trim a field value and turn an empty result into null.
/// Inputs: `value`.
/// Returns: `String?`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
