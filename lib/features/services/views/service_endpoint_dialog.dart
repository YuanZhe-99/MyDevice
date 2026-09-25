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
Future<ServiceEndpoint?> showServiceEndpointDialog(
  BuildContext context, {
  ServiceEndpoint? initial,
  required bool defaultPrimary,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final labelCtrl = TextEditingController(text: initial?.label ?? '');
  final bindCtrl = TextEditingController(text: initial?.bindAddress ?? '');
  final portCtrl = TextEditingController(text: initial?.port?.toString() ?? '');
  final portEndCtrl = TextEditingController(
    text: initial?.portEnd?.toString() ?? '',
  );
  final pathCtrl = TextEditingController(text: initial?.path ?? '');
  var protocol = initial?.protocol ?? ServiceProtocol.http;
  var transport = initial?.transport ?? ServiceTransport.tcp;
  var scope = initial?.scope ?? ServiceScope.lan;
  var primary = initial?.isPrimary ?? defaultPrimary;

  final result = await showDialog<ServiceEndpoint>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(
          initial == null ? l10n.addServiceEndpoint : l10n.editServiceEndpoint,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(
                  labelText: l10n.serviceEndpointLabel,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ServiceProtocol>(
                initialValue: protocol,
                decoration: InputDecoration(labelText: l10n.serviceProtocol),
                items: ServiceProtocol.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => protocol = value);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ServiceTransport>(
                initialValue: transport,
                decoration: InputDecoration(labelText: l10n.serviceTransport),
                items: ServiceTransport.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => transport = value);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: portCtrl,
                      decoration: InputDecoration(labelText: l10n.servicePort),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: portEndCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.servicePortEnd,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bindCtrl,
                decoration: InputDecoration(
                  labelText: l10n.serviceBindAddress,
                  hintText: '0.0.0.0',
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
              DropdownButtonFormField<ServiceScope>(
                initialValue: scope,
                decoration: InputDecoration(labelText: l10n.serviceScope),
                items: ServiceScope.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => scope = value);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: primary,
                title: Text(l10n.servicePrimaryEndpoint),
                onChanged: (value) =>
                    setDialogState(() => primary = value ?? false),
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
                ServiceEndpoint(
                  id: initial?.id,
                  label: _emptyToNull(labelCtrl.text),
                  protocol: protocol,
                  transport: transport,
                  bindAddress: _emptyToNull(bindCtrl.text),
                  port: int.tryParse(portCtrl.text.trim()),
                  portEnd: int.tryParse(portEndCtrl.text.trim()),
                  path: _emptyToNull(pathCtrl.text),
                  scope: scope,
                  isPrimary: primary,
                  extraJson: initial?.extraJson ?? const {},
                ),
              );
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    ),
  );

  labelCtrl.dispose();
  bindCtrl.dispose();
  portCtrl.dispose();
  portEndCtrl.dispose();
  pathCtrl.dispose();
  return result;
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
