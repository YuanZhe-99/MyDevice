import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/device.dart';
import '../services/chip_search_service.dart';

/// Shows a dialog to search for a CPU online.
/// Returns CpuInfo if user selects a result, null if cancelled.
Future<CpuInfo?> showCpuSearchDialog(
  BuildContext context, {
  String? initialQuery,
  required List<CpuInfo> presets,
}) {
  return showDialog<CpuInfo>(
    context: context,
    builder: (_) => _ChipSearchDialog(
      mode: _ChipMode.cpu,
      initialQuery: initialQuery,
      cpuPresets: presets,
      gpuPresets: const [],
    ),
  );
}

/// Shows a dialog to search for a GPU online.
/// Returns GpuInfo if user selects a result, null if cancelled.
Future<GpuInfo?> showGpuSearchDialog(
  BuildContext context, {
  String? initialQuery,
  required List<GpuInfo> presets,
}) {
  return showDialog<GpuInfo>(
    context: context,
    builder: (_) => _ChipSearchDialog(
      mode: _ChipMode.gpu,
      initialQuery: initialQuery,
      cpuPresets: const [],
      gpuPresets: presets,
    ),
  );
}

enum _ChipMode { cpu, gpu }

class _ChipSearchDialog extends StatefulWidget {
  final _ChipMode mode;
  final String? initialQuery;
  final List<CpuInfo> cpuPresets;
  final List<GpuInfo> gpuPresets;

  const _ChipSearchDialog({
    required this.mode,
    this.initialQuery,
    required this.cpuPresets,
    required this.gpuPresets,
  });

  @override
  State<_ChipSearchDialog> createState() => _ChipSearchDialogState();
}

class _ChipSearchDialogState extends State<_ChipSearchDialog> {
  late final TextEditingController _queryCtrl;
  List<ChipSearchResult> _results = [];
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController(text: widget.initialQuery ?? '');
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
      _results = [];
    });

    try {
      final results = widget.mode == _ChipMode.cpu
          ? await ChipSearchService.searchCpu(query, widget.cpuPresets)
          : await ChipSearchService.searchGpu(query, widget.gpuPresets);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        if (results.isEmpty) {
          _error = AppLocalizations.of(context)!.searchNoResults;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e.toString();
      });
    }
  }

  void _select(ChipSearchResult result) {
    if (widget.mode == _ChipMode.cpu) {
      Navigator.of(context).pop(result.toCpuInfo());
    } else {
      Navigator.of(context).pop(result.toGpuInfo());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isCpu = widget.mode == _ChipMode.cpu;
    final title = isCpu ? l10n.searchCpuInfo : l10n.searchGpuInfo;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 480,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: isCpu
                            ? l10n.searchCpuHint
                            : l10n.searchGpuHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _searching ? null : _search,
                    child: Text(l10n.searchButton),
                  ),
                ],
              ),
            ),
            // Results
            Expanded(child: _buildResults(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(AppLocalizations l10n) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const SizedBox.shrink();
    }

    final isCpu = widget.mode == _ChipMode.cpu;

    return ListView.builder(
      itemCount: _results.length,
      padding: const EdgeInsets.only(bottom: 8),
      itemBuilder: (_, i) {
        final r = _results[i];
        final subtitle = isCpu
            ? [
                if (r.architecture != null) r.architecture!,
                if (r.frequency != null) r.frequency!,
                if (r.performanceCores != null || r.efficiencyCores != null)
                  _coresLabel(r),
                if (r.threads != null) '${r.threads}T',
              ].join(' · ')
            : r.architecture ?? '';

        return ListTile(
          leading: Icon(
            r.source == 'preset' ? Icons.storage : Icons.public,
            size: 20,
            color: r.source == 'preset'
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.tertiary,
          ),
          title: Text(
            r.model ?? '?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: subtitle.isNotEmpty
              ? Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : null,
          trailing: r.source != 'preset'
              ? Chip(
                  label: Text(r.source,
                      style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                )
              : null,
          dense: true,
          onTap: () => _select(r),
        );
      },
    );
  }

  String _coresLabel(ChipSearchResult r) {
    final p = r.performanceCores;
    final e = r.efficiencyCores;
    if (p != null && e != null) return '${p}P+${e}E';
    if (p != null) return '${p}C';
    if (e != null) return '${e}E';
    return '';
  }
}
