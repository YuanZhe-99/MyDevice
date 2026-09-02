import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../services/device_search_service.dart';

/// Shows the device search dialog.
/// Returns a map of field names → values to apply, or null if cancelled.
Future<Map<String, dynamic>?> showDeviceSearchDialog(
  BuildContext context, {
  String? initialQuery,
  String? currentBrand,
  String? currentModel,
  String? currentChipset,
  String? currentGpu,
  String? currentRam,
  String? currentStorage,
  String? currentScreenSize,
  int? currentScreenResW,
  int? currentScreenResH,
  String? currentBattery,
  String? currentOs,
  DateTime? currentReleaseDate,
  String? currentImagePath,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _SearchDialog(
      initialQuery: initialQuery,
      currentBrand: currentBrand,
      currentModel: currentModel,
      currentChipset: currentChipset,
      currentGpu: currentGpu,
      currentRam: currentRam,
      currentStorage: currentStorage,
      currentScreenSize: currentScreenSize,
      currentScreenResW: currentScreenResW,
      currentScreenResH: currentScreenResH,
      currentBattery: currentBattery,
      currentOs: currentOs,
      currentReleaseDate: currentReleaseDate,
      currentImagePath: currentImagePath,
    ),
  );
}

enum _Phase { search, preview }

class _SearchDialog extends StatefulWidget {
  final String? initialQuery;
  final String? currentBrand;
  final String? currentModel;
  final String? currentChipset;
  final String? currentGpu;
  final String? currentRam;
  final String? currentStorage;
  final String? currentScreenSize;
  final int? currentScreenResW;
  final int? currentScreenResH;
  final String? currentBattery;
  final String? currentOs;
  final DateTime? currentReleaseDate;
  final String? currentImagePath;

  /// Purpose: Create a search dialog instance.
  /// Inputs: None.
  /// Returns: A new `_SearchDialog` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  const _SearchDialog({
    this.initialQuery,
    this.currentBrand,
    this.currentModel,
    this.currentChipset,
    this.currentGpu,
    this.currentRam,
    this.currentStorage,
    this.currentScreenSize,
    this.currentScreenResW,
    this.currentScreenResH,
    this.currentBattery,
    this.currentOs,
    this.currentReleaseDate,
    this.currentImagePath,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `State` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  late final TextEditingController _queryController;

  _Phase _phase = _Phase.search;

  // Search phase
  List<DeviceSearchResult> _results = [];
  List<DeviceSourceOutcome> _outcomes = const [];
  bool _searching = false;
  String? _error;

  // Preview phase
  DeviceSearchResult? _selected;
  bool _fetchingDetail = false;
  final Map<String, bool> _toggles = {};
  bool _fetchingImage = false;
  String? _fetchedImagePath;
  ImageProvider? _imagePreview;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Registers listeners and may kick off asynchronous loading.
  /// Notes: Guard any post-await UI updates with `mounted` when needed.
  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery ?? '');
  }

  /// Purpose: Release listeners, controllers, and other owned resources.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Releases owned resources and unregisters listeners.
  /// Notes: Call the superclass implementation in the expected lifecycle order.
  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  /// Purpose: Search for the requested result using the current query or filters.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
      _results = [];
      _outcomes = const [];
    });

    try {
      final response = await DeviceSearchService.search(query);
      if (!mounted) return;
      setState(() {
        _results = response.results;
        _outcomes = response.outcomes;
        _searching = false;
        if (response.results.isEmpty) {
          // Distinguish "every source is broken" from "nothing matched".
          // Collapsing both into "no results" is what hid the GSMArena
          // breakage, so an all-source failure names each reason instead.
          _error = response.allSourcesFailed
              ? _describeFailures(response.failures, everySource: true)
              : AppLocalizations.of(context)!.searchNoResults;
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

  /// Purpose: Turn per-source failures into one human-readable message.
  /// Inputs: `failures` — the outcomes whose status is not `ok`; `everySource`
  /// — whether no source at all succeeded.
  /// Returns: A newline-separated explanation, one line per source.
  /// Side effects: Reads localized strings from the current context.
  /// Notes: Each status maps to its own string so the user can tell a bot-wall
  /// apart from an outage apart from a scraper that needs updating — retrying
  /// helps for one of those and not the others. The heading differs by
  /// `everySource` so a partial failure alongside real results is not phrased
  /// as a total outage. Internal helper used within this file only.
  String _describeFailures(
    List<DeviceSourceOutcome> failures, {
    required bool everySource,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final heading = everySource
        ? l10n.searchAllSourcesFailed
        : l10n.searchPartialFailure;
    if (failures.isEmpty) return heading;
    final lines = failures.map(
      (f) => switch (f.status) {
        DeviceSearchStatus.blocked => l10n.searchSourceBlocked(f.source),
        DeviceSearchStatus.unreachable => l10n.searchSourceUnreachable(
          f.source,
        ),
        DeviceSearchStatus.markupChanged => l10n.searchSourceMarkupChanged(
          f.source,
        ),
        DeviceSearchStatus.ok => '',
      },
    );
    return [heading, ...lines.where((l) => l.isNotEmpty)].join('\n');
  }

  /// Purpose: Provide the internal select result helper for this file.
  /// Inputs: `result`.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _selectResult(DeviceSearchResult result) async {
    setState(() {
      _selected = result;
      _phase = _Phase.preview;
      _fetchingDetail = true;
      _fetchedImagePath = null;
      _imagePreview = null;
      _toggles.clear();
    });

    try {
      final detail = await DeviceSearchService.fetchDetail(result);
      if (!mounted) return;
      setState(() {
        _selected = detail;
        _fetchingDetail = false;
        _initToggles(detail);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchingDetail = false;
        _initToggles(result);
      });
    }
  }

  /// Purpose: Provide the internal init toggles helper for this file.
  /// Inputs: `r`.
  /// Returns: `void`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  void _initToggles(DeviceSearchResult r) {
    if (r.brand?.isNotEmpty == true) _toggles['brand'] = true;
    if (r.model?.isNotEmpty == true) _toggles['model'] = true;
    if (r.chipset?.isNotEmpty == true) _toggles['chipset'] = true;
    if (r.gpuName?.isNotEmpty == true) _toggles['gpu'] = true;
    if (r.ram?.isNotEmpty == true) _toggles['ram'] = true;
    if (r.storage?.isNotEmpty == true) _toggles['storage'] = true;
    if (r.screenSize?.isNotEmpty == true) _toggles['screenSize'] = true;
    if (r.screenResolutionW != null) _toggles['resolution'] = true;
    if (r.battery?.isNotEmpty == true) _toggles['battery'] = true;
    if (r.os?.isNotEmpty == true) _toggles['os'] = true;
    if (r.releaseDate != null) _toggles['releaseDate'] = true;
    if (r.imageUrl != null) _toggles['image'] = false; // off by default
  }

  /// Purpose: Fetch image from the relevant source.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Future<void> _fetchImage() async {
    if (_selected?.imageUrl == null) return;
    setState(() => _fetchingImage = true);
    try {
      final path = await ImageService.saveImageFromUrl(_selected!.imageUrl!);
      if (path != null && mounted) {
        final file = await ImageService.resolve(path);
        setState(() {
          _fetchedImagePath = path;
          _imagePreview = FileImage(file);
          _toggles['image'] = true;
          _fetchingImage = false;
        });
      } else {
        if (mounted) setState(() => _fetchingImage = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _fetchingImage = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// Purpose: Provide the internal apply helper for this file.
  /// Inputs: None.
  /// Returns: `void`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  void _apply() {
    if (_selected == null) return;
    final r = _selected!;
    final result = <String, dynamic>{};
    if (_toggles['brand'] == true && r.brand != null) {
      result['brand'] = r.brand;
    }
    if (_toggles['model'] == true && r.model != null) {
      result['model'] = r.model;
    }
    if (_toggles['chipset'] == true && r.chipset != null) {
      result['chipset'] = r.chipset;
    }
    if (_toggles['gpu'] == true && r.gpuName != null) {
      result['gpuName'] = r.gpuName;
    }
    if (_toggles['ram'] == true && r.ram != null) {
      result['ram'] = r.ram;
    }
    if (_toggles['storage'] == true && r.storage != null) {
      result['storage'] = r.storage;
    }
    if (_toggles['screenSize'] == true && r.screenSize != null) {
      result['screenSize'] = r.screenSize;
    }
    if (_toggles['resolution'] == true) {
      if (r.screenResolutionW != null) {
        result['screenResolutionW'] = r.screenResolutionW;
      }
      if (r.screenResolutionH != null) {
        result['screenResolutionH'] = r.screenResolutionH;
      }
    }
    if (_toggles['battery'] == true && r.battery != null) {
      result['battery'] = r.battery;
    }
    if (_toggles['os'] == true && r.os != null) {
      result['os'] = r.os;
    }
    if (_toggles['releaseDate'] == true && r.releaseDate != null) {
      result['releaseDate'] = r.releaseDate;
    }
    if (_toggles['image'] == true && _fetchedImagePath != null) {
      result['image'] = _fetchedImagePath;
    }
    Navigator.of(context).pop(result);
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The window less the soft keyboard is what the dialog can actually use;
    // the body height is derived from it rather than fixed, so a phone in
    // landscape gets a dialog that fits instead of one that overflows.
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: dialogInsetHorizontal,
        vertical: dialogInsetVertical,
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogMaxWidth,
        height: dialogBodyHeight(availableHeight, preferred: 560),
        child: _phase == _Phase.search
            ? _buildSearchView(l10n)
            : _buildPreviewView(l10n),
      ),
    );
  }

  // ──── Search view ────

  /// Purpose: Build and return search view for the current context.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildSearchView(AppLocalizations l10n) {
    return Column(
      children: [
        _buildHeader(l10n, showBack: false),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
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
        Expanded(child: _buildSearchResults(l10n)),
      ],
    );
  }

  /// Purpose: Build and return search results for the current context.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildSearchResults(AppLocalizations l10n) {
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
    // Some results came back, but not from every source. Say so rather than
    // letting a partial answer look complete.
    final failures = _outcomes.where((o) => o.failed).toList();
    return ListView.builder(
      itemCount: _results.length + (failures.isEmpty ? 0 : 1),
      padding: const EdgeInsets.only(bottom: 8),
      itemBuilder: (_, i) {
        if (i == _results.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              _describeFailures(failures, everySource: false),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final r = _results[i];
        return ListTile(
          leading: r.thumbnailUrl != null
              ? SizedBox(
                  width: 36,
                  height: 50,
                  child: Image.network(
                    r.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, e, s) =>
                        const Icon(Icons.phone_android, size: 20),
                  ),
                )
              : const SizedBox(width: 36, child: Icon(Icons.devices_outlined)),
          title: Text(
            r.name ?? '?',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [r.source, if (r.brand != null) r.brand!].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          dense: true,
          onTap: () => _selectResult(r),
        );
      },
    );
  }

  // ──── Preview view ────

  /// Purpose: Build and return preview view for the current context.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildPreviewView(AppLocalizations l10n) {
    final r = _selected;
    if (r == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildHeader(l10n, showBack: true),
        const Divider(height: 1),
        // Source badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Chip(
                label: Text(r.source),
                avatar: const Icon(Icons.public, size: 16),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _fetchingDetail
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(l10n.searchFetchingDetail),
                    ],
                  ),
                )
              : _buildFieldList(l10n, r),
        ),
        const Divider(height: 1),
        // Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _toggles.values.any((v) => v) && !_fetchingDetail
                    ? _apply
                    : null,
                child: Text(l10n.searchApply),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Purpose: Build and return field list for the current context.
  /// Inputs: `l10n`, `r`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildFieldList(AppLocalizations l10n, DeviceSearchResult r) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        if (r.brand?.isNotEmpty == true)
          _fieldTile('brand', l10n.deviceBrand, widget.currentBrand, r.brand!),
        if (r.model?.isNotEmpty == true)
          _fieldTile('model', l10n.deviceModel, widget.currentModel, r.model!),
        if (r.chipset?.isNotEmpty == true)
          _fieldTile(
            'chipset',
            l10n.cpuInfo,
            widget.currentChipset,
            r.chipset!,
          ),
        if (r.gpuName?.isNotEmpty == true)
          _fieldTile('gpu', l10n.gpuInfo, widget.currentGpu, r.gpuName!),
        if (r.ram?.isNotEmpty == true)
          _fieldTile('ram', l10n.ram, widget.currentRam, r.ram!),
        if (r.storage?.isNotEmpty == true)
          _fieldTile(
            'storage',
            l10n.storage,
            widget.currentStorage,
            r.storage!,
          ),
        if (r.screenSize?.isNotEmpty == true)
          _fieldTile(
            'screenSize',
            l10n.screenSize,
            widget.currentScreenSize,
            r.screenSize!,
          ),
        if (r.screenResolutionW != null && r.screenResolutionH != null)
          _fieldTile(
            'resolution',
            l10n.screenResolution,
            widget.currentScreenResW != null && widget.currentScreenResH != null
                ? '${widget.currentScreenResW} × ${widget.currentScreenResH}'
                : null,
            '${r.screenResolutionW} × ${r.screenResolutionH}',
          ),
        if (r.battery?.isNotEmpty == true)
          _fieldTile(
            'battery',
            l10n.battery,
            widget.currentBattery,
            r.battery!,
          ),
        if (r.os?.isNotEmpty == true)
          _fieldTile('os', l10n.os, widget.currentOs, r.os!),
        if (r.releaseDate != null)
          _fieldTile(
            'releaseDate',
            l10n.deviceReleaseDate,
            widget.currentReleaseDate != null
                ? DateFormat.yMd(
                    l10n.localeName,
                  ).format(widget.currentReleaseDate!)
                : null,
            DateFormat.yMd(l10n.localeName).format(r.releaseDate!),
          ),
        // Device image section
        if (r.imageUrl != null) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Checkbox(
                  value: _toggles['image'] ?? false,
                  onChanged: _fetchedImagePath != null
                      ? (v) => setState(() => _toggles['image'] = v ?? false)
                      : null,
                ),
                Expanded(
                  child: Text(
                    l10n.searchDeviceImage,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_fetchingImage)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (_fetchedImagePath == null)
                  TextButton.icon(
                    onPressed: _fetchImage,
                    icon: const Icon(Icons.download, size: 16),
                    label: Text(l10n.searchFetchImage),
                  ),
              ],
            ),
          ),
          if (_imagePreview != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (widget.currentImagePath != null) ...[
                    _imageColumn(
                      l10n.searchCurrent,
                      FutureBuilder<File>(
                        future: ImageService.resolve(widget.currentImagePath!),
                        builder: (context, snap) {
                          if (snap.hasData && snap.data!.existsSync()) {
                            return _imagePreviewFrame(
                              Image.file(
                                snap.data!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.image_not_supported_outlined,
                                ),
                              ),
                            );
                          }
                          return _imagePreviewFrame(
                            const Icon(Icons.image_not_supported_outlined),
                          );
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 16),
                    ),
                  ],
                  _imageColumn(
                    l10n.searchFetched,
                    _imagePreviewFrame(
                      Image(
                        image: _imagePreview!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  /// Purpose: Provide the internal image column helper for this file.
  /// Inputs: `label`, `image`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _imageColumn(String label, Widget image) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        image,
      ],
    );
  }

  /// Purpose: Provide the internal image preview frame helper for this file.
  /// Inputs: `child`.
  /// Returns: `Widget`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
  Widget _imagePreviewFrame(Widget child) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 64,
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant.withAlpha(140)),
        ),
        child: ClipOval(child: child),
      ),
    );
  }

  /// Purpose: Provide the internal field tile helper for this file.
  /// Inputs: `label`, `current`, `fetched`.
  /// Returns: `Widget`.
  /// Side effects: Updates widget state and triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  Widget _fieldTile(String key, String label, String? current, String fetched) {
    final l10n = AppLocalizations.of(context)!;
    return CheckboxListTile(
      value: _toggles[key] ?? false,
      onChanged: (v) => setState(() => _toggles[key] = v ?? false),
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (current != null && current.isNotEmpty)
            Text(
              '${l10n.searchCurrent}: $current',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            '${l10n.searchFetched}: $fetched',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  // ──── Header ────

  /// Purpose: Build and return header for the current context.
  /// Inputs: `l10n`.
  /// Returns: `Widget`.
  /// Side effects: Updates widget state and triggers a rebuild. Opens or updates routes, dialogs, or other UI flows.
  /// Notes: Internal helper used within this file only.
  Widget _buildHeader(AppLocalizations l10n, {required bool showBack}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => setState(() => _phase = _Phase.search),
              visualDensity: VisualDensity.compact,
            ),
          Icon(
            Icons.travel_explore,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.searchDeviceInfo,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
