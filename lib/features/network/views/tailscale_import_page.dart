import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../devices/models/device.dart';
import '../../devices/widgets/device_category_icon.dart';
import '../../devices/services/device_storage.dart';
import '../models/network.dart';
import '../services/network_storage.dart';
import '../services/tailscale_csv.dart';

class TailscaleImportPage extends StatefulWidget {
  final String networkId;
  final List<Map<String, String>> rows;
  final DeviceData devices;
  final List<NetworkDevice> assignments;

  /// Purpose: Show an import preview with explicit inventory matching.
  /// Inputs: Parsed rows and current inventory snapshot.
  /// Returns: Preview page.
  /// Side effects: None.
  /// Notes: No writes occur until save.
  const TailscaleImportPage({
    super.key,
    required this.networkId,
    required this.rows,
    required this.devices,
    required this.assignments,
  });

  /// Purpose: Create preview state.
  /// Inputs: None.
  /// Returns: State.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<TailscaleImportPage> createState() => _TailscaleImportPageState();
}

class _TailscaleImportPageState extends State<TailscaleImportPage> {
  final Map<int, String> _targets = {};
  final Map<int, Device> _created = {};
  final Map<int, Set<String>> _columns = {};
  final Map<int, ({String reason, List<String> ids})> _matches = {};
  final Map<int, String> _names = {};
  final Map<int, String> _os = {};
  final Map<int, DeviceCategory> _categories = {};
  bool _saving = false;
  String? _error;

  /// Purpose: Suggest unambiguous stable-ID or exact-name matches.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Seeds preview choices.
  /// Notes: Unmatched and ambiguous rows default to skip.
  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.rows.length; i++) {
      final row = widget.rows[i];
      final match = TailscaleCsv.match(
        row,
        widget.devices.devices,
        widget.assignments,
      );
      _matches[i] = match;
      _targets[i] = match.ids.length == 1 ? match.ids.single : 'skip';
      _columns[i] = row.keys.where((k) => k != 'Device ID').toSet();
      _names[i] = row['Device name']!.trim();
      _os[i] = [
        row['OS'],
        row['OS Version'],
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
      _categories[i] = DeviceCategory.other;
    }
  }

  /// Purpose: Save devices before atomically batching their network memberships.
  /// Inputs: None.
  /// Returns: Completion.
  /// Side effects: Creates chosen devices and writes network data.
  /// Notes: New IDs remain stable on retries; partial failure keeps this preview open.
  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fresh = await DeviceStorage.load();
      final net = await NetworkStorage.load();
      if (!net.networks.any(
        (n) => n.id == widget.networkId && n.type == NetworkType.tailscale,
      )) {
        throw StateError('Target Tailscale network no longer exists');
      }
      final updates = <NetworkDevice>[];
      final used = <String>{};
      final additions = <Device>[];
      for (var i = 0; i < widget.rows.length; i++) {
        final choice = _targets[i]!;
        if (choice == 'skip') continue;
        final row = widget.rows[i];
        final device = choice == 'new'
            ? _created.putIfAbsent(
                i,
                () => Device(
                  id: const Uuid().v4(),
                  name: _names[i]!.trim(),
                  category: _categories[i]!,
                  os: _os[i]!.trim().isEmpty ? null : _os[i]!.trim(),
                ),
              )
            : fresh.devices.where((d) => d.id == choice).firstOrNull;
        if (device == null || !device.isInService) {
          throw StateError('Selected device is no longer in service');
        }
        if (!used.add(device.id)) {
          throw StateError('Multiple rows target the same device');
        }
        if (device.name.trim().isEmpty) {
          throw StateError('Device name is required');
        }
        if (choice == 'new' && !fresh.devices.any((d) => d.id == device.id)) {
          additions.add(device);
        }
        final existing = net.assignments
            .where(
              (a) => a.networkId == widget.networkId && a.deviceId == device.id,
            )
            .firstOrNull;
        final preview = widget.assignments
            .where((a) => a.deviceId == device.id)
            .firstOrNull;
        if (jsonEncode(preview?.toJson()) != jsonEncode(existing?.toJson())) {
          throw StateError(
            'Membership changed since preview; reopen the import',
          );
        }
        updates.add(
          TailscaleCsv.assignment(
            row,
            widget.networkId,
            device.id,
            existing: existing,
            selectedColumns: _columns[i],
          ),
        );
      }
      for (final device in additions) {
        await DeviceStorage.addOrUpdate(device);
      }
      await NetworkStorage.setAssignments(
        updates,
        expectedAssignments: widget.assignments,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Purpose: Render each imported row and its selected inventory target.
  /// Inputs: Context.
  /// Returns: Preview UI.
  /// Side effects: User choices update drafts; save persists selected rows.
  /// Notes: Existing hardware and lifecycle fields are never overwritten.
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final selected = _targets.values.where((v) => v != 'skip').length;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.networkImportCsv),
        actions: [
          TextButton(
            onPressed: _saving || selected == 0 ? null : _save,
            child: Text(l.save),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: formMaxWidth),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l.networkImportPreview),
              Wrap(
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            for (final i in _targets.keys) {
                              _targets[i] = 'skip';
                            }
                          }),
                    child: Text(l.networkImportSkipAll),
                  ),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            for (final i in _targets.keys) {
                              _targets[i] = _matches[i]!.ids.length == 1
                                  ? _matches[i]!.ids.single
                                  : 'skip';
                            }
                          }),
                    child: Text(l.networkImportAutoMatch),
                  ),
                ],
              ),
              Text(
                '${l.networkImportDetails}: ${widget.rows.length} · '
                '${l.networkImportNew}: ${_targets.values.where((v) => v == 'new').length} · '
                '${l.networkImportUpdate}: ${_targets.values.where((v) => v != 'new' && v != 'skip').length} · '
                '${l.networkImportSkip}: ${widget.rows.length - selected}',
              ),
              if (_saving) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  '${l.networkImportFailed}: $_error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              for (var i = 0; i < widget.rows.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.rows[i]['Device name']!,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(widget.rows[i]['Tailscale IPs'] ?? ''),
                        Text(_matchLabel(l, i)),
                        DropdownButtonFormField<String>(
                          initialValue: _targets[i],
                          key: ValueKey('target-$i-${_targets[i]}'),
                          decoration: InputDecoration(
                            labelText: l.networkImportTarget,
                          ),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: 'skip',
                              child: Text(l.networkImportSkip),
                            ),
                            DropdownMenuItem(
                              value: 'new',
                              child: Text(l.networkImportNew),
                            ),
                            for (final d in widget.devices.devices.where(
                              (d) => d.isInService,
                            ))
                              DropdownMenuItem(
                                value: d.id,
                                child: Text(d.name),
                              ),
                          ],
                          onChanged: _saving
                              ? null
                              : (v) =>
                                    setState(() => _targets[i] = v ?? 'skip'),
                        ),
                        if (_targets[i] != 'skip') ...[
                          if (widget.assignments.any(
                            (a) =>
                                a.tailscale['Device ID'] ==
                                    widget.rows[i]['Device ID'] &&
                                a.deviceId != _targets[i],
                          ))
                            Text(l.networkImportReassign),
                          if (_targets.values
                                      .where((v) => v == _targets[i])
                                      .length >
                                  1 &&
                              _targets[i] != 'new')
                            Text(
                              l.networkImportDuplicate,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          if (_targets[i] == 'new') ...[
                            TextFormField(
                              key: ValueKey('new-name-$i'),
                              initialValue: _names[i],
                              decoration: InputDecoration(
                                labelText: l.networkImportDeviceName,
                              ),
                              onChanged: _saving
                                  ? null
                                  : (v) {
                                      _names[i] = v;
                                      _created.remove(i);
                                    },
                            ),
                            DropdownButtonFormField<DeviceCategory>(
                              initialValue: _categories[i],
                              decoration: InputDecoration(
                                labelText: l.networkImportCategory,
                              ),
                              items: DeviceCategory.values
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(deviceCategoryLabel(l, v)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _saving
                                  ? null
                                  : (v) {
                                      _categories[i] =
                                          v ?? DeviceCategory.other;
                                      _created.remove(i);
                                    },
                            ),
                            TextFormField(
                              key: ValueKey('new-os-$i'),
                              initialValue: _os[i],
                              decoration: InputDecoration(labelText: l.os),
                              onChanged: _saving
                                  ? null
                                  : (v) {
                                      _os[i] = v;
                                      _created.remove(i);
                                    },
                            ),
                          ],
                          ExpansionTile(
                            key: ValueKey('changes-$i'),
                            title: Text(l.networkImportChanges),
                            subtitle: Text(l.networkImportKeepHint),
                            children: [
                              for (final entry in widget.rows[i].entries.where(
                                (e) => e.key != 'Device ID',
                              ))
                                CheckboxListTile(
                                  key: ValueKey('column-$i-${entry.key}'),
                                  title: Text(entry.key),
                                  subtitle: Text(
                                    '${_oldValue(i, entry.key) ?? l.hardwareUnspecified} → '
                                    '${entry.value.isEmpty ? l.networkImportEmpty : entry.value}',
                                  ),
                                  value: _columns[i]!.contains(entry.key),
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(() {
                                          if (v == true) {
                                            _columns[i]!.add(entry.key);
                                          } else {
                                            _columns[i]!.remove(entry.key);
                                          }
                                        }),
                                ),
                            ],
                          ),
                        ],
                        ExpansionTile(
                          title: Text(l.networkImportDetails),
                          children: [
                            SelectableText(
                              const JsonEncoder.withIndent(
                                '  ',
                              ).convert(widget.rows[i]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Purpose: Explain the initial automatic match and ambiguous candidates.
  /// Inputs: Localization and row index.
  /// Returns: Review label.
  /// Side effects: None.
  /// Notes: Target selection remains editable even for node-ID matches.
  String _matchLabel(AppLocalizations l, int i) {
    final match = _matches[i]!;
    if (match.ids.isEmpty) return l.networkImportNoMatch;
    final reason = switch (match.reason) {
      'id' => l.networkImportMatchId,
      'normalized' => l.networkImportMatchNormalized,
      _ => l.networkImportMatchName,
    };
    final names = match.ids
        .map((id) => widget.devices.devices.firstWhere((d) => d.id == id).name)
        .join(', ');
    return '${match.ids.length > 1 ? l.networkImportAmbiguous : reason}: $names';
  }

  /// Purpose: Read a field's existing effective value for an honest before/after preview.
  /// Inputs: Row index and original CSV column.
  /// Returns: Existing text or null.
  /// Side effects: None.
  /// Notes: Raw metadata is secondary to editable membership fields.
  String? _oldValue(int i, String column) {
    final a = widget.assignments
        .where((a) => a.deviceId == _targets[i])
        .firstOrNull;
    if (a == null) return null;
    return switch (column) {
      'Device name' => a.hostname,
      'Tailscale IPs' =>
        a.ipAddresses.isEmpty ? a.ipAddress : a.ipAddresses.join(','),
      'Exit node' => a.isExitNode.toString(),
      _ => a.tailscale[column]?.toString(),
    };
  }
}
