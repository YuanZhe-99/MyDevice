import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/app_settings.dart';
import '../services/ai_insights_cache.dart';
import '../services/genai_backend.dart';
import '../services/insight_language.dart';
import '../services/insight_prompts.dart';
import '../services/insight_service.dart';
import '../services/on_device_ai_service.dart';

/// A titled group of insight lines inside a card.
class AiInsightSection {
  /// The section heading.
  final String title;

  /// The slot ids whose lines belong here.
  final Set<String> slotIds;

  /// Purpose: Create a section.
  /// Inputs: `title`, `slotIds`.
  /// Returns: A new `AiInsightSection`.
  /// Side effects: None.
  /// Notes: Lines whose slot is in no section are shown first, ungrouped.
  const AiInsightSection(this.title, this.slotIds);
}

/// Builds a card's request for the current language and time, or returns
/// null when the module has nothing to talk about yet.
typedef AiInsightRequestBuilder =
    AiInsightRequest? Function(InsightLanguage language, DateTime now);

/// The on-device AI insight card shown on the Financial overview page and the
/// Services overview.
///
/// Renders nothing unless the platform can have an on-device model and the
/// user turned on-device AI on, so Windows (and every existing layout while
/// the switch is off) is unchanged. When the page's data or the date
/// changes, the card asks [AiInsightStore] to make itself
/// current; the store answers from `ai_insights.json` when the fingerprint
/// matches and only runs the model otherwise.
class AiInsightCard extends ConsumerStatefulWidget {
  /// Which card.
  final InsightModule module;

  /// Builds the request from the page's already-loaded data.
  final AiInsightRequestBuilder buildRequest;

  /// Optional grouping of lines by slot id.
  final List<AiInsightSection> sections;

  /// Collapsible, collapsed by default, showing one preview line (Finance's
  /// stacked phone layout, where height is scarce).
  final bool compact;

  /// Optional note under the lines, e.g. the cycle-estimate disclaimer.
  final String? footnote;

  /// Outer margin.
  final EdgeInsetsGeometry margin;

  /// Purpose: Create an insight card.
  /// Inputs: see fields.
  /// Returns: A new `AiInsightCard`.
  /// Side effects: None.
  /// Notes: Cheap to rebuild: the request is fingerprinted and compared with
  /// the cache before anything runs.
  const AiInsightCard({
    super.key,
    required this.module,
    required this.buildRequest,
    this.sections = const [],
    this.compact = false,
    this.footnote,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  /// Purpose: Create the state object.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends ConsumerState<AiInsightCard> {
  AiInsightRequest? _request;
  bool _ensureScheduled = false;
  bool _expanded = false;
  bool _couldGenerate = false;
  Timer? _boundaryTimer;
  OnDeviceAiService? _listened;

  /// Purpose: Stop timers and listeners.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Cancels the boundary timer; removes the service listener.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    _boundaryTimer?.cancel();
    _listened?.removeListener(_onServiceChanged);
    super.dispose();
  }

  /// Purpose: Rebuild when the model becomes usable.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May call `setState`, which re-runs [_scheduleEnsure].
  /// Notes: Covers the status probe finishing after the page opened.
  void _onServiceChanged() {
    final can = _listened?.canGenerate ?? false;
    if (can && !_couldGenerate && mounted) setState(() {});
    _couldGenerate = can;
  }

  /// Purpose: Follow the right `OnDeviceAiService` instance.
  /// Inputs: `ai`.
  /// Returns: None.
  /// Side effects: Moves the listener when the provider is overridden.
  /// Notes: Internal helper used within this file only.
  void _listenTo(OnDeviceAiService ai) {
    if (identical(_listened, ai)) return;
    _listened?.removeListener(_onServiceChanged);
    _listened = ai..addListener(_onServiceChanged);
    _couldGenerate = ai.canGenerate;
  }

  /// Purpose: Rebuild at the next moment the facts change by time alone.
  /// Inputs: `now`.
  /// Returns: None.
  /// Side effects: (Re)arms a one-shot timer.
  /// Notes: Local midnight, when the date in the facts (and so the
  /// fingerprint) changes; service days and daily costs follow the date.
  void _armBoundaryTimer(DateTime now) {
    _boundaryTimer?.cancel();
    final next = DateTime(now.year, now.month, now.day + 1);
    _boundaryTimer = Timer(next.difference(now) + const Duration(seconds: 1), () {
      if (mounted) setState(() {});
    });
  }

  /// Purpose: Ask the store to make this card current after the frame.
  /// Inputs: `store`.
  /// Returns: None.
  /// Side effects: Schedules one post-frame [AiInsightStore.ensure].
  /// Notes: Coalesces several builds in one frame into one call.
  void _scheduleEnsure(AiInsightStore store) {
    if (_ensureScheduled) return;
    _ensureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureScheduled = false;
      final request = _request;
      if (!mounted || request == null) return;
      unawaited(store.ensure(request));
    });
  }

  /// Purpose: Word a model status that stops the card from generating.
  /// Inputs: `status`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Same wording as the Settings rows.
  String _statusLabel(GenAiStatus status, AppLocalizations l10n) =>
      switch (status) {
        GenAiStatus.available => l10n.aiStatusAvailable,
        GenAiStatus.unavailable => l10n.aiStatusUnavailable,
        GenAiStatus.unreachable => l10n.aiStatusUnreachable,
        GenAiStatus.unknown => l10n.aiStatusUnknown,
        GenAiStatus.downloadable => l10n.aiStatusDownloadable,
        GenAiStatus.downloading => l10n.aiStatusDownloading,
        GenAiStatus.notEnabled => l10n.aiStatusNotEnabled,
        GenAiStatus.unsupported => l10n.aiStatusUnsupportedApple,
      };

  /// Purpose: Build the card.
  /// Inputs: `context`.
  /// Returns: The card, a one-line notice, or an empty box.
  /// Side effects: Rebuilds the request and schedules [AiInsightStore.ensure].
  /// Notes: Runs when the page rebuilds (its data changed), when settings or
  /// the locale change, at a time boundary, and when the model becomes usable.
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final ai = ref.watch(onDeviceAiServiceProvider);
    final store = ref.watch(aiInsightStoreProvider);
    _listenTo(ai);
    if (!platformMayHaveOnDeviceModel || !settings.onDeviceAiEnabled) {
      _request = null;
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    _armBoundaryTimer(now);
    final language = InsightLanguage.forLocale(
      Localizations.localeOf(context),
      localeSupported: ai.coreInfo?.localeSupported,
    );
    _request = language == null ? null : widget.buildRequest(language, now);
    if (_request != null) _scheduleEnsure(store);
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: Listenable.merge([ai, store]),
      builder: (context, _) {
        final status = ai.report.status;
        if (status == GenAiStatus.unsupported) return const SizedBox.shrink();
        if (status != GenAiStatus.available) {
          return _notice(
            context,
            _statusLabel(status, l10n),
            action: TextButton(
              onPressed: () => context.go('/settings'),
              child: Text(l10n.aiOpenSettings),
            ),
          );
        }
        if (language == null) {
          return _notice(context, l10n.aiLanguageUnsupported);
        }
        final request = _request;
        if (request == null) return const SizedBox.shrink();
        return _card(context, l10n, store, request);
      },
    );
  }

  /// Purpose: Build a one-line notice in place of the card.
  /// Inputs: `context`, `text`, optional `action`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Used when the model is not ready or cannot write the language.
  Widget _notice(BuildContext context, String text, {Widget? action}) {
    final theme = Theme.of(context);
    return Card(
      margin: widget.margin,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }

  /// Purpose: Build the insight card proper.
  /// Inputs: `context`, `l10n`, `store`, `request`.
  /// Returns: `Widget`.
  /// Side effects: None; the refresh button calls the store.
  /// Notes: Stale lines are dimmed while newer ones are generated.
  Widget _card(
    BuildContext context,
    AppLocalizations l10n,
    AiInsightStore store,
    AiInsightRequest request,
  ) {
    final theme = Theme.of(context);
    final state = store.stateOf(widget.module);
    final generating = state.phase == AiInsightPhase.generating;
    final entry = state.entry;
    final dim = generating || state.stale;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final header = Row(
      children: [
        Icon(
          Icons.auto_awesome_outlined,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.aiInsightTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.aiRegenerate,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: generating
              ? null
              : () => unawaited(store.ensure(request, force: true)),
        ),
        if (widget.compact)
          Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            color: theme.colorScheme.onSurfaceVariant,
          ),
      ],
    );

    final body = <Widget>[];
    if (entry != null && entry.status == AiInsightStatus.skipped) {
      body.add(Text(l10n.aiInsightSkipped, style: muted));
    } else if (entry != null && entry.lines.isNotEmpty) {
      final lineStyle = theme.textTheme.bodyMedium?.copyWith(
        color: dim
            ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
            : theme.colorScheme.onSurface,
      );
      final lines = [
        for (var i = 0; i < entry.lines.length; i++)
          (i < entry.slots.length ? entry.slots[i] : '', entry.lines[i]),
      ];
      final sectioned = {for (final s in widget.sections) ...s.slotIds};
      Widget bullet(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: lineStyle),
            Expanded(child: Text(text, style: lineStyle)),
          ],
        ),
      );
      if (widget.compact && !_expanded) {
        body.add(
          Text(
            lines.first.$2,
            style: lineStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      } else {
        for (final (slot, text) in lines) {
          if (!sectioned.contains(slot)) body.add(bullet(text));
        }
        for (final section in widget.sections) {
          final own = [
            for (final (slot, text) in lines)
              if (section.slotIds.contains(slot)) text,
          ];
          if (own.isEmpty) continue;
          body
            ..add(const SizedBox(height: 8))
            ..add(
              Text(
                section.title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            )
            ..addAll(own.map(bullet));
        }
      }
    } else if (state.phase != AiInsightPhase.failed) {
      body.add(Text(l10n.aiGenerating, style: muted));
    }

    if (state.phase == AiInsightPhase.failed) {
      final hint = switch (state.failure) {
        GenAiFailure.quota => l10n.aiQuotaHint,
        GenAiFailure.background => l10n.aiForegroundHint,
        _ => l10n.aiInsightFailed,
      };
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(hint, style: muted),
        ),
      );
    }

    final showDetails = !widget.compact || _expanded;
    if (showDetails && widget.footnote != null && entry != null) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(widget.footnote!, style: muted),
        ),
      );
    }
    if (showDetails && entry != null && entry.status == AiInsightStatus.ok) {
      final time = MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(entry.generatedAt.toLocal()),
      );
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${l10n.aiGeneratedLabel} · ${l10n.aiGeneratedAt(time)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Card(
      margin: widget.margin,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: widget.compact
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
              child: header,
            ),
          ),
          SizedBox(
            height: 2,
            child: generating
                ? const LinearProgressIndicator(minHeight: 2)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: body,
            ),
          ),
        ],
      ),
    );
  }
}
