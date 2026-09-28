import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/ai/services/ai_insights_cache.dart';
import 'package:my_device/features/ai/services/genai_backend.dart';
import 'package:my_device/features/ai/services/insight_language.dart';
import 'package:my_device/features/ai/services/insight_prompts.dart';
import 'package:my_device/features/ai/services/insight_service.dart';
import 'package:my_device/features/ai/services/on_device_ai_service.dart';

import 'on_device_ai_test.dart' show FakeBackend;

const _en = InsightLanguage('en_US', 'English', 'en');

/// Purpose: Build a services-card request with one fact line.
/// Inputs: `fact`, optional `language` and `now`.
/// Returns: `AiInsightRequest`.
/// Side effects: None.
/// Notes: Test helper.
AiInsightRequest _request(
  String fact, {
  InsightLanguage language = _en,
  DateTime? now,
}) => AiInsightRequest(
  facts: InsightFacts(
    module: InsightModule.services,
    lines: ['- $fact'],
    slots: const [
      InsightSlot('trend', 'Describe the trend.'),
      InsightSlot('advice', 'One suggestion.'),
    ],
  ),
  language: language,
  now: now ?? DateTime(2026, 9, 28, 9),
);

/// Purpose: Test the insight store: caching, regeneration and failures.
/// Inputs: None.
/// Returns: None.
/// Side effects: None; the cache is in memory.
/// Notes: Uses the fake backend from `on_device_ai_test.dart`.
void main() {
  late FakeBackend backend;
  late OnDeviceAiService ai;
  late AiInsights saved;
  late int saves;
  late AiInsightStore store;

  int generations() =>
      backend.calls.where((c) => c.startsWith('generate:')).length;

  setUp(() async {
    backend = FakeBackend();
    ai = OnDeviceAiService(backend: backend);
    await ai.setEnabled(true);
    saved = AiInsights();
    saves = 0;
    store = AiInsightStore(
      ai: ai,
      load: () async => saved,
      save: (value) async {
        saved = value;
        saves++;
      },
      clear: () async => saved = AiInsights(),
      clock: () => DateTime.utc(2026, 9, 28, 1),
    );
  });

  test('generates once, caches, and answers from the cache after', () async {
    backend.generateReplies.add('1: The setup is steady.\n2: Keep it tidy.');
    await store.ensure(_request('services 3'));
    expect(generations(), 1);
    final state = store.stateOf(InsightModule.services);
    expect(state.phase, AiInsightPhase.ready);
    expect(state.entry!.lines, ['The setup is steady.', 'Keep it tidy.']);
    expect(state.entry!.slots, ['trend', 'advice']);
    expect(saves, 1);

    await store.ensure(_request('services 3'));
    expect(generations(), 1);

    // A fresh store over the same file does not regenerate either.
    final reopened = AiInsightStore(ai: ai, load: () async => saved);
    await reopened.ensure(_request('services 3'));
    expect(generations(), 1);
    expect(reopened.stateOf(InsightModule.services).entry!.lines.length, 2);
  });

  test('new facts, a new day, or a new model regenerate', () async {
    backend.generateReplies.addAll([
      '1: One.',
      '1: Two.',
      '1: Three.',
    ]);
    await store.ensure(_request('services 3'));
    await store.ensure(_request('services 4'));
    expect(generations(), 2);
    await store.ensure(
      _request('services 4', now: DateTime(2026, 9, 29, 9)),
    );
    expect(generations(), 3);

    final a = insightFingerprint(_request('x'), 'stable/full · nano-v3');
    final b = insightFingerprint(_request('x'), 'stable/full · nano-v4');
    final c = insightFingerprint(
      _request('x', language: const InsightLanguage('ja_JP', 'Japanese', 'ja')),
      'stable/full · nano-v3',
    );
    expect({a, b, c}.length, 3);
  });

  test('regenerate forces a run even when the cache matches', () async {
    backend.generateReplies.addAll(['1: First.', '1: Second.']);
    await store.ensure(_request('services 3'));
    await store.ensure(_request('services 3'), force: true);
    expect(generations(), 2);
    expect(store.stateOf(InsightModule.services).entry!.lines, ['Second.']);
  });

  test('a guardrail refusal is cached as skipped', () async {
    backend.generateReplies.add(const GenAiException(GenAiFailure.guardrail));
    await store.ensure(_request('services 3'));
    final state = store.stateOf(InsightModule.services);
    expect(state.phase, AiInsightPhase.ready);
    expect(state.entry!.status, AiInsightStatus.skipped);
    await store.ensure(_request('services 3'));
    expect(generations(), 1);
  });

  test('a failure keeps the previous text as stale and is not cached', () async {
    backend.generateReplies.addAll([
      '1: Old.',
      const GenAiException(GenAiFailure.failed),
    ]);
    await store.ensure(_request('services 3'));
    await store.ensure(_request('services 4'));
    final state = store.stateOf(InsightModule.services);
    expect(state.phase, AiInsightPhase.failed);
    expect(state.failure, GenAiFailure.failed);
    expect(state.stale, isTrue);
    expect(state.entry!.lines, ['Old.']);
    expect(saves, 1);
    // A real failure is not retried by another page build.
    await store.ensure(_request('services 4'));
    expect(generations(), 2);
  });

  test('unusable output is a failure', () async {
    backend.generateReplies.add('这一行不是英文，所以不能用。');
    await store.ensure(_request('services 3'));
    expect(store.stateOf(InsightModule.services).phase, AiInsightPhase.failed);
    expect(saves, 0);
  });

  test('rapid changes run at most one extra generation', () async {
    backend.hold = Completer<String>();
    final first = store.ensure(_request('a'));
    await Future<void>.delayed(Duration.zero);
    unawaited(store.ensure(_request('b')));
    unawaited(store.ensure(_request('c')));
    await Future<void>.delayed(Duration.zero);
    expect(
      store.stateOf(InsightModule.services).phase,
      AiInsightPhase.generating,
    );
    final hold = backend.hold!;
    backend.hold = null;
    backend.generateReplies.add('1: For c.');
    hold.complete('1: For a.');
    await first;
    expect(generations(), 2);
    expect(backend.calls.last, contains('- c'));
    final state = store.stateOf(InsightModule.services);
    expect(state.phase, AiInsightPhase.ready);
    expect(state.entry!.lines, ['For c.']);
    expect(
      saved.entries[InsightModule.services]!.fingerprint,
      insightFingerprint(_request('c'), modelIdentityOf(ai.report)),
    );
  });

  test('nothing runs while on-device AI is off', () async {
    await ai.setEnabled(false);
    backend.calls.clear();
    await store.ensure(_request('services 3'));
    expect(backend.calls, isEmpty);
    expect(store.stateOf(InsightModule.services).phase, AiInsightPhase.idle);
  });

  test('clearAll forgets everything', () async {
    backend.generateReplies.addAll(['1: One.', '1: Again.']);
    await store.ensure(_request('services 3'));
    await store.clearAll();
    expect(saved.entries, isEmpty);
    expect(store.stateOf(InsightModule.services).entry, isNull);
    await store.ensure(_request('services 3'));
    expect(generations(), 2);
  });

  test('Traditional Chinese output is converted', () async {
    final tw = InsightLanguage.forLocale(const Locale('zh', 'TW'))!;
    expect(tw.localeTag, 'zh_TW');
    backend.generateReplies.add('1: 设备运行稳定。');
    await store.ensure(_request('services 3', language: tw));
    expect(store.stateOf(InsightModule.services).entry!.lines, ['設備運行穩定。']);
  });

  group('language choice', () {
    test('Apple rejecting Traditional falls back to Simplified + convert', () {
      final l = InsightLanguage.forLocale(
        const Locale('zh', 'TW'),
        localeSupported: false,
      )!;
      expect(l.localeTag, 'zh_CN');
      expect(l.toTraditional, isTrue);
    });

    test('an unsupported other language skips the card', () {
      expect(
        InsightLanguage.forLocale(const Locale('ja'), localeSupported: false),
        isNull,
      );
    });
  });

  group('reply parsing', () {
    test('keeps numbered lines in the right script only', () {
      final parsed = parseInsightReply(
        '**1:** 体重在下降。\n2: This is English.\n2: 继续保持。\n9: 多余的。',
        2,
        'zh',
      );
      expect(parsed, {1: '体重在下降。', 2: '继续保持。'});
    });

    test('drops over-long lines rather than truncating', () {
      final parsed = parseInsightReply('1: ${'a' * 240}', 1, 'en');
      expect(parsed, isEmpty);
    });

    test('quoted English titles do not fail a Chinese sentence', () {
      const line = '1: 先完成 Weekly report review 和 Team sync meeting。';
      expect(parseInsightReply(line, 1, 'zh'), isEmpty);
      expect(
        parseInsightReply(
          line,
          1,
          'zh',
          quotedTerms: const ['Weekly report review', 'Team sync meeting'],
        ),
        {1: '先完成 Weekly report review 和 Team sync meeting。'},
      );
    });

    test('the prompt lists facts, questions, then the reply template', () {
      final prompt = insightPrompt(_request('services 3').facts);
      expect(
        prompt,
        'Facts:\n- services 3\n\nQuestions:\n1. Describe the trend.\n'
        '2. One suggestion.\n\nReply with exactly 2 lines, one per question, '
        'in this form:\n1: <sentence>\n2: <sentence>\n',
      );
      expect(insightInstructions(_en), contains('English'));
      expect(insightInstructions(_en), contains('never invent numbers'));
      expect(insightInstructions(_en), contains('Do not repeat'));
    });

    test('period and bold numbering are read, not stripped as lists', () {
      // v1.5.0 ran `stripMarkdown` first, which removed `1. ` as a list
      // marker and left every line unnumbered.
      final parsed = parseInsightReply(
        '1. 今天先处理房租。\n**2.** 然后改简历。\n3) 分段完成。',
        3,
        'zh',
      );
      expect(parsed, {1: '今天先处理房租。', 2: '然后改简历。', 3: '分段完成。'});
    });

    test('a number alone on a line takes the next line as its answer', () {
      final parsed = parseInsightReply(
        '1:\n\nThe trend is down.\n2.\nKeep going.',
        2,
        'en',
      );
      expect(parsed, {1: 'The trend is down.', 2: 'Keep going.'});
    });

    test('unnumbered prose is taken in order only when nothing is numbered', () {
      expect(
        parseInsightReply(
          'Answer:\nThe trend is down.\n\nKeep going.\nExtra line.',
          2,
          'en',
        ),
        {1: 'The trend is down.', 2: 'Keep going.'},
      );
      // One numbered line means the model did number; the rest is ignored.
      expect(
        parseInsightReply('Intro line.\n2: Keep going.', 2, 'en'),
        {2: 'Keep going.'},
      );
    });

    test('an echoed question is not an answer', () {
      final parsed = parseInsightReply(
        '1: Describe the trend.\n2: Keep going.',
        2,
        'en',
        asks: const ['Describe the trend.', 'One suggestion.'],
      );
      expect(parsed, {2: 'Keep going.'});
    });

    test('a one-character quoted term is left in place', () {
      // Removing "a" from every word would leave no Latin letters to check.
      final parsed = parseInsightReply(
        '1: Start with a, then rest.',
        1,
        'en',
        quotedTerms: const ['a'],
      );
      expect(parsed, {1: 'Start with a, then rest.'});
    });
  });

  group('fallback facts', () {
    const plain = InsightFacts(
      module: InsightModule.services,
      lines: ['- plain'],
      slots: [
        InsightSlot('trend', 'Describe the trend.'),
        InsightSlot('advice', 'One suggestion.'),
      ],
    );
    AiInsightRequest withFallback() => AiInsightRequest(
      facts: _request('services 3').facts,
      language: _en,
      now: DateTime(2026, 9, 28, 9),
      fallbackFacts: plain,
    );

    test('a guardrail on the titled facts retries the plain ones', () async {
      backend.generateReplies.addAll([
        const GenAiException(GenAiFailure.guardrail),
        '1: Plain answer.',
      ]);
      await store.ensure(withFallback());
      final state = store.stateOf(InsightModule.services);
      expect(state.phase, AiInsightPhase.ready);
      expect(state.entry!.status, AiInsightStatus.ok);
      expect(state.entry!.lines, ['Plain answer.']);
      expect(state.entry!.slots, ['trend']);
      expect(generations(), 2);
      expect(backend.calls.last, contains('- plain'));
    });

    test('an unusable reply retries the plain facts once', () async {
      backend.generateReplies.addAll(['全是中文的回答。', '2: Plain tip.']);
      await store.ensure(withFallback());
      final state = store.stateOf(InsightModule.services);
      expect(state.phase, AiInsightPhase.ready);
      expect(state.entry!.lines, ['Plain tip.']);
      expect(state.entry!.slots, ['advice']);
      expect(generations(), 2);
    });

    test('a guardrail on the plain facts too is cached as skipped', () async {
      backend.generateReplies.addAll([
        const GenAiException(GenAiFailure.guardrail),
        const GenAiException(GenAiFailure.guardrail),
      ]);
      await store.ensure(withFallback());
      expect(store.stateOf(InsightModule.services).entry!.status,
          AiInsightStatus.skipped);
      await store.ensure(withFallback());
      expect(generations(), 2);
    });

    test('an empty reply to the plain facts is a failure, run once', () async {
      backend.generateReplies.addAll(['', '']);
      await store.ensure(withFallback());
      expect(store.stateOf(InsightModule.services).phase, AiInsightPhase.failed);
      await store.ensure(withFallback());
      expect(generations(), 2);
    });

    test('without fallback facts nothing is retried', () async {
      backend.generateReplies.add('');
      await store.ensure(_request('services 3'));
      expect(store.stateOf(InsightModule.services).phase, AiInsightPhase.failed);
      expect(generations(), 1);
    });
  });
}
