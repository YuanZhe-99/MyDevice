import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../models/device.dart';
import '../services/preset_service.dart';
import 'device_avatar.dart';

/// What the user picked in the thumbnail chooser.
class TemplateImageChoice {
  /// The chosen bundled asset, or null for "Automatic" (match by identity).
  final String? asset;

  /// Purpose: Create a template image choice instance.
  /// Inputs: `asset` — the chosen thumbnail, or null for automatic matching.
  /// Returns: A new `TemplateImageChoice` instance.
  /// Side effects: None.
  /// Notes: Wrapped so a dismissed sheet (null) differs from "Automatic".
  const TemplateImageChoice(this.asset);
}

/// Purpose: Let the user choose a bundled thumbnail for a device by hand.
/// Inputs: `context`; the device's `category`, `brand`, `model` and `name`
/// used to rank candidates; `current` — the thumbnail chosen so far.
/// Returns: The choice, or null when the sheet was dismissed.
/// Side effects: Shows a modal bottom sheet; loads the template catalog.
/// Notes: Used when automatic matching misses (a device named differently
/// from its template). Candidates come from
/// [PresetService.rankTemplateImageCandidates], so the closest thumbnails
/// come first but every bundled one is reachable through the search field.
Future<TemplateImageChoice?> showTemplateImagePicker(
  BuildContext context, {
  required DeviceCategory category,
  String? brand,
  String? model,
  String? name,
  String? current,
}) async {
  final templates = await PresetService.loadTemplates();
  if (!context.mounted) return null;
  return showModalBottomSheet<TemplateImageChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => TemplateImagePickerSheet(
      templates: templates,
      category: category,
      brand: brand,
      model: model,
      name: name,
      current: current,
    ),
  );
}

/// Searchable grid of bundled thumbnails, best candidates first.
class TemplateImagePickerSheet extends StatefulWidget {
  final List<DeviceTemplate> templates;
  final DeviceCategory category;
  final String? brand;
  final String? model;
  final String? name;
  final String? current;

  /// Purpose: Create a template image picker sheet instance.
  /// Inputs: The loaded `templates`, the device identity for ranking, and
  /// the `current` choice to highlight.
  /// Returns: A new `TemplateImagePickerSheet` instance.
  /// Side effects: None.
  /// Notes: Public so widget tests can pump it without a route.
  const TemplateImagePickerSheet({
    super.key,
    required this.templates,
    required this.category,
    this.brand,
    this.model,
    this.name,
    this.current,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new `State` instance.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<TemplateImagePickerSheet> createState() =>
      _TemplateImagePickerSheetState();
}

class _TemplateImagePickerSheetState extends State<TemplateImagePickerSheet> {
  String _query = '';
  late final List<DeviceTemplate> _ranked;

  /// Every template name that shares a thumbnail, keyed by the asset, so a
  /// search for a sibling model still finds the file it borrows.
  late final Map<String, List<String>> _namesByImage;

  /// Purpose: Rank the candidates once when the sheet opens.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Initializes the ranked list and the name index.
  /// Notes: None.
  @override
  void initState() {
    super.initState();
    _ranked = PresetService.rankTemplateImageCandidates(
      widget.templates,
      brand: widget.brand,
      model: widget.model,
      name: widget.name,
    );
    _namesByImage = {};
    for (final t in widget.templates) {
      final image = t.image;
      if (image == null) continue;
      _namesByImage.putIfAbsent(image, () => []).addAll([
        t.name,
        if (t.brand != null) t.brand!,
        if (t.model != null) t.model!,
      ]);
    }
  }

  /// Purpose: Provide the candidates that match the search field.
  /// Inputs: None.
  /// Returns: `List<DeviceTemplate>` in rank order.
  /// Side effects: None.
  /// Notes: Matches the name, brand or model of any template sharing the
  /// thumbnail. Internal helper used within this file only.
  List<DeviceTemplate> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _ranked;
    return _ranked.where((t) {
      final names = _namesByImage[t.image] ?? const [];
      return names.any((n) => n.toLowerCase().contains(q));
    }).toList();
  }

  /// Purpose: Build the searchable thumbnail grid.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Updates widget state as the user types.
  /// Notes: The first tile is always "Automatic", showing what matching
  /// would pick (or the category icon when it picks nothing).
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = _filtered;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: sheetInitialSize(
        MediaQuery.sizeOf(context).height,
        preferred: 0.7,
      ),
      maxChildSize: sheetMaxSize,
      minChildSize: 0.3,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.deviceChooseThumbnail,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.deviceThumbnailSearch,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 104,
                mainAxisExtent: 112,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _Tile(
                    selected: widget.current == null,
                    label: l10n.deviceThumbnailAutomatic,
                    avatar: DeviceAvatar(
                      category: widget.category,
                      brand: widget.brand,
                      model: widget.model,
                      name: widget.name,
                      size: 56,
                    ),
                    onTap: () =>
                        Navigator.pop(context, const TemplateImageChoice(null)),
                  );
                }
                final t = items[index - 1];
                return _Tile(
                  selected: widget.current == t.image,
                  label: t.name,
                  avatar: DeviceAvatar(
                    category: t.category,
                    templateImage: t.image,
                    size: 56,
                  ),
                  onTap: () =>
                      Navigator.pop(context, TemplateImageChoice(t.image)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final bool selected;
  final String label;
  final Widget avatar;
  final VoidCallback onTap;

  /// Purpose: Create a thumbnail tile instance.
  /// Inputs: `selected`, `label`, the `avatar` preview and `onTap`.
  /// Returns: A new `_Tile` instance.
  /// Side effects: None.
  /// Notes: None.
  const _Tile({
    required this.selected,
    required this.label,
    required this.avatar,
    required this.onTap,
  });

  /// Purpose: Build one selectable thumbnail with its name.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None.
  /// Notes: The current choice gets a primary-coloured outline.
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            avatar,
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
