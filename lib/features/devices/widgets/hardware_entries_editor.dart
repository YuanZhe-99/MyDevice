import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../l10n/app_localizations.dart';
import '../models/device.dart';
import '../views/chip_search_dialog.dart';
import '../../../app/flavor.dart';

/// Editable, ordered GPU and display lists; drafts belong to the parent form.
class HardwareEntriesEditor extends StatelessWidget {
  final List<GpuInfo>? gpus;
  final List<DisplayInfo>? displays;
  final List<GpuInfo> presets;
  final ValueChanged<List<GpuInfo>>? onGpusChanged;
  final ValueChanged<List<DisplayInfo>>? onDisplaysChanged;

  /// Purpose: Bind hardware rows to the device form's drafts.
  /// Inputs: One list and its change callback; GPU presets are optional.
  /// Returns: Editor widget.
  /// Side effects: None.
  /// Notes: Stable IDs retain form values across reordering and folding.
  const HardwareEntriesEditor({
    super.key,
    this.gpus,
    this.displays,
    this.presets = const [],
    this.onGpusChanged,
    this.onDisplaysChanged,
  });

  /// Purpose: Localize hardware kinds and roles.
  /// Inputs: Localization and serialized value.
  /// Returns: User-facing label.
  /// Side effects: None.
  /// Notes: Unknown future values remain visible.
  static String label(AppLocalizations l, String value) => switch (value) {
    'integrated' => l.hardwareIntegrated,
    'discrete' => l.hardwareDiscrete,
    'external' => l.hardwareExternal,
    'builtIn' => l.hardwareBuiltIn,
    'inner' => l.hardwareInner,
    'outer' => l.hardwareOuter,
    'unspecified' => l.hardwareUnspecified,
    _ => value,
  };

  /// Purpose: Build a text field whose draft survives parent rebuilds.
  /// Inputs: Stable key, label, value, callback, numeric flag.
  /// Returns: Field.
  /// Side effects: Callback updates parent draft.
  /// Notes: Empty text clears the optional field.
  Widget _field(
    String key,
    String title,
    Object? value,
    ValueChanged<String> change, {
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: _HardwareField(
      key: ValueKey(key),
      title: title,
      value: value?.toString() ?? '',
      numeric: numeric,
      change: change,
    ),
  );

  /// Purpose: Replace a GPU while retaining its identity and future fields.
  /// Inputs: Index and changed JSON fields.
  /// Returns: None.
  /// Side effects: Calls parent callback.
  /// Notes: Null fields are removed before parsing.
  void _gpu(int index, Map<String, dynamic> fields) {
    final entries = List<GpuInfo>.of(gpus!);
    final json = {...entries[index].toJson(), ...fields};
    json.removeWhere((key, value) => value == null || value == '');
    entries[index] = GpuInfo.fromJson(json);
    onGpusChanged!(entries);
  }

  /// Purpose: Replace a display while retaining its identity and future fields.
  /// Inputs: Index and changed fields.
  /// Returns: None.
  /// Side effects: Calls parent callback.
  /// Notes: Empty values clear optional fields.
  void _display(int index, Map<String, dynamic> fields) {
    final entries = List<DisplayInfo>.of(displays!);
    final json = {...entries[index].toJson(), ...fields};
    json.removeWhere((key, value) => value == null || value == '');
    entries[index] = DisplayInfo.fromJson(json);
    onDisplaysChanged!(entries);
  }

  /// Purpose: Build hardware rows and add/remove/reorder actions.
  /// Inputs: Context.
  /// Returns: Editor subtree.
  /// Side effects: User actions update parent drafts or open chip search.
  /// Notes: Specs remain independent between rows.
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                gpus != null ? l.gpuInfo : l.hardwareDisplays,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: l.hardwareAdd,
              icon: const Icon(Icons.add),
              onPressed: () {
                if (gpus != null) {
                  onGpusChanged!([...gpus!, GpuInfo(id: const Uuid().v4())]);
                } else {
                  onDisplaysChanged!([...displays!, DisplayInfo()]);
                }
              },
            ),
          ],
        ),
        for (var i = 0; i < (gpus?.length ?? displays!.length); i++)
          Card(
            key: ValueKey(gpus != null ? gpus![i].id : displays![i].id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${gpus != null ? l.gpuInfo : l.hardwareDisplays} ${i + 1}',
                        ),
                      ),
                      IconButton(
                        tooltip: l.hardwareMoveUp,
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: i == 0
                            ? null
                            : () {
                                if (gpus != null) {
                                  final list = List<GpuInfo>.of(gpus!);
                                  final item = list.removeAt(i);
                                  list.insert(i - 1, item);
                                  onGpusChanged!(list);
                                } else {
                                  final list = List<DisplayInfo>.of(displays!);
                                  final item = list.removeAt(i);
                                  list.insert(i - 1, item);
                                  onDisplaysChanged!(list);
                                }
                              },
                      ),
                      IconButton(
                        tooltip: l.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          if (gpus != null) {
                            onGpusChanged!(
                              List<GpuInfo>.of(gpus!)..removeAt(i),
                            );
                          } else {
                            onDisplaysChanged!(
                              List<DisplayInfo>.of(displays!)..removeAt(i),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  if (gpus != null) ...[
                    _field(
                      '${gpus![i].id}-model',
                      l.gpuModel,
                      gpus![i].model,
                      (v) => _gpu(i, {'model': v}),
                    ),
                    _field(
                      '${gpus![i].id}-arch',
                      l.gpuArchitecture,
                      gpus![i].architecture,
                      (v) => _gpu(i, {'architecture': v}),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: gpus![i].kind,
                      decoration: InputDecoration(labelText: l.hardwareKind),
                      items:
                          {
                                'unspecified',
                                'integrated',
                                'discrete',
                                'external',
                                gpus![i].kind,
                              }
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(label(l, v)),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => _gpu(i, {'kind': v}),
                    ),
                    _field(
                      '${gpus![i].id}-notes',
                      l.hardwareNotes,
                      gpus![i].notes,
                      (v) => _gpu(i, {'notes': v}),
                    ),
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(labelText: l.gpuInfo),
                      items: [
                        for (var p = 0; p < presets.length; p++)
                          DropdownMenuItem(
                            value: p,
                            child: Text(presets[p].model ?? 'GPU'),
                          ),
                      ],
                      isExpanded: true,
                      onChanged: (v) {
                        if (v != null) {
                          _gpu(i, {
                            'model': presets[v].model,
                            'architecture': presets[v].architecture,
                          });
                        }
                      },
                    ),
                    if (AppFlavor.isFull)
                      TextButton.icon(
                        icon: const Icon(Icons.travel_explore),
                        label: Text(l.fetchFromInternet),
                        onPressed: () async {
                          final result = await showGpuSearchDialog(
                            context,
                            initialQuery: gpus![i].model ?? '',
                            presets: presets,
                          );
                          if (result != null && context.mounted) {
                            final currentIndex = gpus!.indexWhere(
                              (g) => g.id == gpus![i].id,
                            );
                            if (currentIndex < 0) return;
                            _gpu(currentIndex, {
                              'model': result.model,
                              'architecture': result.architecture,
                            });
                          }
                        },
                      ),
                  ] else ...[
                    _field(
                      '${displays![i].id}-name',
                      l.hardwareDisplayName,
                      displays![i].name,
                      (v) => _display(i, {'name': v}),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: displays![i].role,
                      decoration: InputDecoration(labelText: l.hardwareRole),
                      items:
                          {
                                'unspecified',
                                'builtIn',
                                'inner',
                                'outer',
                                'external',
                                displays![i].role,
                              }
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(label(l, v)),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => _display(i, {'role': v}),
                    ),
                    _field(
                      '${displays![i].id}-size',
                      l.screenSize,
                      displays![i].screenSize,
                      (v) => _display(i, {'screenSize': v}),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            '${displays![i].id}-w',
                            '${l.screenResolution} W',
                            displays![i].screenResolutionW,
                            (v) => _display(i, {
                              'screenResolutionW': int.tryParse(v),
                            }),
                            numeric: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _field(
                            '${displays![i].id}-h',
                            '${l.screenResolution} H',
                            displays![i].screenResolutionH,
                            (v) => _display(i, {
                              'screenResolutionH': int.tryParse(v),
                            }),
                            numeric: true,
                          ),
                        ),
                      ],
                    ),
                    _field(
                      '${displays![i].id}-hz',
                      l.hardwareRefreshRate,
                      displays![i].refreshRate,
                      (v) => _display(i, {'refreshRate': double.tryParse(v)}),
                      numeric: true,
                    ),
                    _field(
                      '${displays![i].id}-notes',
                      l.hardwareNotes,
                      displays![i].notes,
                      (v) => _display(i, {'notes': v}),
                    ),
                    if (displays![i].ppi != null)
                      Text('${l.ppi}: ${displays![i].ppi!.toStringAsFixed(0)}'),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HardwareField extends StatefulWidget {
  final String title;
  final String value;
  final bool numeric;
  final ValueChanged<String> change;

  /// Purpose: Hold a controller-backed hardware field.
  /// Inputs: Label, draft value and change callback.
  /// Returns: Field widget.
  /// Side effects: None.
  /// Notes: Stable key preserves cursor across parent updates.
  const _HardwareField({
    super.key,
    required this.title,
    required this.value,
    required this.numeric,
    required this.change,
  });

  /// Purpose: Create controller state.
  /// Inputs: None.
  /// Returns: State.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<_HardwareField> createState() => _HardwareFieldState();
}

class _HardwareFieldState extends State<_HardwareField> {
  late final TextEditingController _controller;

  /// Purpose: Seed field text.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Creates controller.
  /// Notes: None.
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  /// Purpose: Reflect preset changes without resetting typed text or cursor.
  /// Inputs: Previous widget.
  /// Returns: None.
  /// Side effects: Updates controller for externally changed draft values.
  /// Notes: Numeric partial input is retained until a different draft arrives.
  @override
  void didUpdateWidget(_HardwareField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      if (!widget.numeric ||
          num.tryParse(_controller.text) != num.tryParse(widget.value)) {
        _controller.text = widget.value;
      }
    }
  }

  /// Purpose: Release controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes controller.
  /// Notes: None.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Purpose: Build a controlled hardware input.
  /// Inputs: Context.
  /// Returns: Field.
  /// Side effects: Editing invokes parent callback.
  /// Notes: None.
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _controller,
    decoration: InputDecoration(labelText: widget.title),
    keyboardType: widget.numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    onChanged: widget.change,
  );
}
