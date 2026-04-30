import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../devices/models/device.dart';
import '../../devices/services/device_storage.dart';
import '../models/dataset.dart';
import '../services/dataset_storage.dart';

/// Common emoji options for quick pick.
const _emojiOptions = [
  '📁',
  '💾',
  '🎵',
  '🎬',
  '📷',
  '📚',
  '🎮',
  '💻',
  '📦',
  '🗂️',
  '🔒',
  '☁️',
  '📝',
  '🎨',
  '🏠',
  '🔧',
];

class DataSetEditPage extends StatefulWidget {
  final DataSet? dataSet;

  const DataSetEditPage({super.key, this.dataSet});

  @override
  State<DataSetEditPage> createState() => _DataSetEditPageState();
}

class _DataSetEditPageState extends State<DataSetEditPage> {
  final _nameController = TextEditingController();
  String _emoji = '📁';

  /// deviceId → set of selected storage indices
  final Map<String, Set<int>> _selectedStorages = {};

  List<Device> _devices = [];
  bool _loading = true;

  bool get _isEditing => widget.dataSet != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.dataSet!.name;
      _emoji = widget.dataSet!.emoji;
      for (final link in widget.dataSet!.storageLinks) {
        _selectedStorages[link.deviceId] = Set.of(link.storageIndices);
      }
    }
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final data = await DeviceStorage.load();
    if (!mounted) return;
    setState(() {
      _devices = data.devices.where((d) => d.storage.isNotEmpty).toList();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final links = <DataSetStorageLink>[];
    final existingLinks = {
      for (final link
          in widget.dataSet?.storageLinks ?? const <DataSetStorageLink>[])
        link.deviceId: link,
    };
    for (final entry in _selectedStorages.entries) {
      if (entry.value.isNotEmpty) {
        links.add(
          DataSetStorageLink(
            deviceId: entry.key,
            storageIndices: entry.value.toList()..sort(),
            extraJson: existingLinks[entry.key]?.extraJson ?? const {},
          ),
        );
      }
    }

    final ds =
        (_isEditing ? widget.dataSet! : DataSet(name: name, emoji: _emoji))
            .copyWith(name: name, emoji: _emoji, storageLinks: links);

    await DataSetStorage.addOrUpdate(ds);
    AutoSyncService.instance.notifySaved();
    if (mounted) Navigator.pop(context, true);
  }

  void _pickEmoji() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(AppLocalizations.of(context)!.dataSetEmoji),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojiOptions.map((e) {
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.pop(ctx, e),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
    if (picked != null) setState(() => _emoji = picked);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editDataSet : l10n.addDataSet),
        actions: [TextButton(onPressed: _save, child: Text(l10n.save))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Emoji + Name ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _pickEmoji,
                      child: Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: l10n.dataSetName,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Storage selection ──
                Text(
                  l10n.dataSetStorages,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (_devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.dataSetNoDeviceStorages,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ..._devices.map((device) {
                  final selected = _selectedStorages[device.id] ?? {};
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            device.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        ...List.generate(device.storage.length, (i) {
                          final st = device.storage[i];
                          final checked = selected.contains(i);
                          return CheckboxListTile(
                            value: checked,
                            title: Text(st.displayString),
                            dense: true,
                            onChanged: (val) {
                              setState(() {
                                final set = _selectedStorages.putIfAbsent(
                                  device.id,
                                  () => {},
                                );
                                if (val == true) {
                                  set.add(i);
                                } else {
                                  set.remove(i);
                                }
                              });
                            },
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
