import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/ai/services/ai_insights_cache.dart';
import 'package:my_device/features/ai/services/genai_backend.dart';
import 'package:my_device/features/ai/services/insight_prompts.dart';
import 'package:my_device/features/ai/services/insight_service.dart';
import 'package:my_device/features/ai/services/on_device_ai_service.dart';
import 'package:my_device/features/ai/widgets/ai_insight_card.dart';
import 'package:my_device/l10n/app_localizations.dart';
import 'package:my_device/shared/providers/app_settings.dart';

import 'on_device_ai_test.dart' show FakeBackend;

/// Purpose: Test the insight card's states on each platform.
/// Inputs: None.
/// Returns: None.
/// Side effects: None; the cache is in memory.
/// Notes: `debugDefaultTargetPlatformOverride` picks the platform.
void main() {
  late FakeBackend backend;
  late OnDeviceAiService ai;
  late AiInsightStore store;

  setUp(() {
    backend = FakeBackend();
    ai = OnDeviceAiService(backend: backend);
    store = AiInsightStore(
      ai: ai,
      load: () async => AiInsights(),
      save: (_) async {},
      clear: () async {},
    );
    debugDefaultTargetPlatformOverride = null;
  });

  int generations() =>
      backend.calls.where((c) => c.startsWith('generate:')).length;

  Future<void> pump(
    WidgetTester tester, {
    bool enabled = true,
    bool compact = false,
  }) async {
    if (enabled) await ai.setEnabled(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWithValue(
            AppSettingsNotifier.fixed(AppSettings(onDeviceAiEnabled: enabled)),
          ),
          onDeviceAiServiceProvider.overrideWithValue(ai),
          aiInsightStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: ListView(
              children: [
                AiInsightCard(
                  module: InsightModule.deviceFinance,
                  compact: compact,
                  sections: const [
                    AiInsightSection('Flow', {'flowSummary'}),
                    AiInsightSection('Subs', {'subSummary'}),
                  ],
                  buildRequest: (language, now) => AiInsightRequest(
                    facts: const InsightFacts(
                      module: InsightModule.deviceFinance,
                      lines: ['- spending 100 CNY'],
                      slots: [
                        InsightSlot('flowSummary', 'Trend.'),
                        InsightSlot('subSummary', 'Subs.'),
                      ],
                    ),
                    language: language,
                    now: now,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders nothing while on-device AI is off', (tester) async {
    await pump(tester, enabled: false);
    expect(find.byType(Card), findsNothing);
    expect(backend.calls, isEmpty);
  });

  testWidgets('renders nothing on Windows', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await pump(tester);
    expect(find.byType(Card), findsNothing);
    expect(generations(), 0);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('generates and shows grouped lines with the label', (
    tester,
  ) async {
    backend.generateReplies.add('1: Spending is down.\n2: One subscription.');
    await pump(tester);
    expect(generations(), 1);
    expect(find.text('Flow'), findsOneWidget);
    expect(find.text('Subs'), findsOneWidget);
    expect(find.text('Spending is down.'), findsOneWidget);
    expect(find.text('One subscription.'), findsOneWidget);
    expect(
      find.textContaining('Generated on this device — may be wrong'),
      findsOneWidget,
    );
  });

  testWidgets('regenerate runs the model again', (tester) async {
    backend.generateReplies.addAll(['1: First.', '1: Second.']);
    await pump(tester);
    await tester.tap(find.byTooltip('Regenerate'));
    await tester.pumpAndSettle();
    expect(generations(), 2);
    expect(find.text('Second.'), findsOneWidget);
  });

  testWidgets('compact starts collapsed with one preview line', (
    tester,
  ) async {
    backend.generateReplies.add('1: Spending is down.\n2: One subscription.');
    await pump(tester, compact: true);
    expect(find.text('Spending is down.'), findsOneWidget);
    expect(find.text('One subscription.'), findsNothing);
    expect(find.text('Flow'), findsNothing);
    await tester.tap(find.text('AI insight'));
    await tester.pumpAndSettle();
    expect(find.text('One subscription.'), findsOneWidget);
    expect(find.text('Flow'), findsOneWidget);
  });

  testWidgets('a model that needs a download shows a notice instead', (
    tester,
  ) async {
    backend.status = const GenAiStatusReport(GenAiStatus.downloadable);
    await pump(tester);
    expect(find.text('Needs a one-time download'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(generations(), 0);
  });
}
