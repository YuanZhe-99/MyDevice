import 'package:myapps_ai_ui/myapps_ai_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/app_settings.dart';
import '../services/genai_backend.dart';
import '../services/insight_service.dart';
import '../services/on_device_ai_service.dart';
import 'ai_source_controls.dart';
import '../services/ai_insights_cache.dart';

/// The rows of the *On-device AI* Settings section: the switch, the model
/// status with its actions, the size preference, the notes, a collapsed
/// technical-details tile, and "Clear generated insights". Ported from
/// MyAnime!!!!!.
///
/// Renders nothing on a platform that cannot have an on-device model
/// (Windows, Linux, web); the Settings page shows a one-line note there
/// instead.
class AiSettingsTiles extends ConsumerStatefulWidget {
  /// Purpose: Create the AI settings rows.
  /// Inputs: None.
  /// Returns: A new `AiSettingsTiles`.
  /// Side effects: None.
  /// Notes: Reads `OnDeviceAiService.instance` through
  /// `onDeviceAiServiceProvider` and the insight store through
  /// `aiInsightStoreProvider`, so tests can substitute fakes.
  const AiSettingsTiles({super.key});

  /// Purpose: Create the state object.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<AiSettingsTiles> createState() => _AiSettingsTilesState();
}

class _AiSettingsTilesState extends ConsumerState<AiSettingsTiles> {
  /// Purpose: Refresh the model status when Settings opens.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: One forced status probe, only while the switch is on.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ai = ref.read(onDeviceAiServiceProvider);
      if (ai.enabled) ai.refreshStatus(localeTag: _localeTag());
    });
  }

  /// Purpose: Return the app's current locale as a tag such as `zh_TW`.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _localeTag() {
    final l = Localizations.localeOf(context);
    return l.countryCode == null
        ? l.languageCode
        : '${l.languageCode}_${l.countryCode}';
  }

  /// Purpose: Word a model status.
  /// Inputs: `status`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: `unsupported` only reaches here on iOS and macOS older than 26.
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

  /// Purpose: Build the rows.
  /// Inputs: `context`.
  /// Returns: A `Column` of tiles, or an empty box on unsupported platforms.
  /// Side effects: None.
  /// Notes: Rebuilds whenever the service notifies.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final ai = ref.watch(onDeviceAiServiceProvider);

    final backend = OnDeviceAiService.sourceBackend;
    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) => MyAppsAiSettingsSkeleton(
        enabled: settings.onDeviceAiEnabled,
        master: MyAppsAiPreference(
          title: l10n.aiUseOnDevice,
          description: l10n.aiUseOnDeviceDesc,
          value: settings.onDeviceAiEnabled,
          onChanged: notifier.setOnDeviceAiEnabled,
        ),
        source: [
          AiSourceControls(
            backend: backend,
            onSelected: (id) async {
              final backend = OnDeviceAiService.sourceBackend;
              if (backend.selection.global == id) return;
              await ai.setEnabled(false);
              await backend.select(id);
              await ai.setEnabled(settings.onDeviceAiEnabled);
              if ((await AiInsightsCache.load()).entries.isEmpty) return;
              if (!context.mounted) return;
              final clear = await confirmClearAfterSourceChange(
                context,
                AiClearAfterSwitchLabels(
                  title: l10n.aiClearInsights,
                  body: l10n.aiSourceClearBody,
                  clear: l10n.aiClearInsights,
                  keep: l10n.aiSourceKeep,
                ),
              );
              if (clear) await ref.read(aiInsightStoreProvider).clearAll();
            },
          ),
          if (ai.report.hasSizeChoice)
            MyAppsAiPreference(
              icon: Icons.speed_outlined,
              title: l10n.aiPreferFast,
              description: l10n.aiPreferFastBody,
              value: settings.onDeviceAiPreferFast,
              onChanged: notifier.setOnDeviceAiPreferFast,
            ),
        ],
        features: [
          if (ai.report.status == GenAiStatus.notEnabled)
            ListTile(subtitle: Text(l10n.aiTurnOnAppleIntelligence)),
          if (ai.downloading && ai.downloadProgress != null)
            ListTile(
              subtitle: Text(
                l10n.aiDownloadedBytes(
                  (ai.downloadProgress!.bytes / (1024 * 1024)).toStringAsFixed(
                    1,
                  ),
                ),
              ),
            ),
          MyAppsAiCapabilityTile(
            title: l10n.aiSectionTitle,
            statusText: _statusLabel(ai.report.status, l10n),
            icon: Icons.auto_awesome_outlined,
            action: ai.report.status == GenAiStatus.downloadable
                ? FilledButton(
                    onPressed: ai.downloading ? null : ai.download,
                    child: Text(l10n.aiDownload),
                  )
                : TextButton(
                    onPressed: () => ai.refreshStatus(localeTag: _localeTag()),
                    child: Text(l10n.aiCheckAgain),
                  ),
          ),
          if (backend.selection.global == 'auto' ||
              backend.selection.global == 'system')
            MyAppsAiModelNotes(
              downloadNote: l10n.aiDownloadNote,
              storageNote: l10n.aiModelStorageNote,
            ),
        ],
        diagnostics: MyAppsAiDiagnostics(
          title: l10n.aiTechnicalDetails,
          groups: [
            AiDiagnosticGroup(backend.selection.global, [
              'status: ${ai.report.status.name} (${ai.report.code})',
              if (ai.report.detail != null) 'detail: ${ai.report.detail}',
              if (ai.report.variant != null) 'variant: ${ai.report.variant}',
              if (ai.report.served != null) 'served: ${ai.report.served}',
              if (ai.report.refused != null) 'refused: ${ai.report.refused}',
              if (ai.report.baseModelName != null)
                'model: ${ai.report.baseModelName}',
              if (ai.report.tokenLimit != null)
                'tokenLimit: ${ai.report.tokenLimit}',
              if (ai.coreInfo?.versionName != null)
                l10n.aiCoreVersion(ai.coreInfo!.versionName!),
              if (ai.coreInfo?.device != null) 'device: ${ai.coreInfo!.device}',
            ]),
          ],
        ),
        data: [
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: Text(l10n.aiClearInsights),
            subtitle: Text(l10n.aiClearInsightsBody),
            onTap: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              await ref.read(aiInsightStoreProvider).clearAll();
              messenger?.showSnackBar(
                SnackBar(content: Text(l10n.aiClearInsightsDone)),
              );
            },
          ),
        ],
      ),
    );
  }
}
