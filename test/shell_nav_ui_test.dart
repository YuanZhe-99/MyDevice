import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_device/app/theme.dart';
import 'package:my_device/l10n/app_localizations.dart';
import 'package:my_device/shared/providers/app_settings.dart';
import 'package:my_device/shared/utils/adaptive_layout.dart';
import 'package:my_device/shared/widgets/shell_scaffold.dart';

/// Purpose: Test that the shell swaps its bottom bar for a rail on wide windows.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The rail is chosen on width alone, deliberately unlike the app-wide
/// split rule, so the cases worth pinning hardest are a phone in landscape and
/// a Z Fold 8 in portrait: both wide enough for a rail, neither allowed to
/// split. The five destinations are stubbed with empty pages so this exercises
/// the shell and nothing behind it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The Expressive bottom bar (the default style) has this key.
  const island = ValueKey('floatingNavBarIsland');

  Future<void> pumpAt(
    WidgetTester tester,
    double width,
    double height, {
    AppUiStyle uiStyle = AppUiStyle.expressive,
    bool wideBottom = false,
    bool railRight = false,
    bool alwaysSide = false,
    Widget Function(String path)? pageBuilder,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/devices',
      routes: [
        ShellRoute(
          builder: (context, state, child) => ShellScaffold(child: child),
          routes: [
            for (final path in const [
              '/devices',
              '/services',
              '/network',
              '/datasets',
              '/settings',
            ])
              GoRoute(
                path: path,
                builder: (context, state) =>
                    pageBuilder?.call(path) ??
                    Scaffold(body: Center(child: Text('page $path'))),
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsProvider.overrideWithValue(
            AppSettingsNotifier.fixed(
              AppSettings(
                uiStyle: uiStyle,
                expressiveWideBottomNav: wideBottom,
                navRailOnRight: railRight,
                alwaysSideNav: alwaysSide,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a phone in portrait keeps the bottom navigation bar', (
    tester,
  ) async {
    await pumpAt(tester, 412, 915); // Pixel 9
    expect(find.byKey(island), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Z Fold 8 unfolded moves navigation to the side', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same device in portrait still gets a rail', (tester) async {
    // 704 wide passes the width-only rail rule although the split rule
    // rejects the 3:4 shape; the two rules are independent on purpose.
    await pumpAt(tester, 704, 933);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('a phone in landscape gets a rail even though it cannot split', (
    tester,
  ) async {
    // The reason the rail has a rule of its own: at 412 logical pixels tall a
    // bottom bar would spend a fifth of the height, and width is what is spare.
    await pumpAt(tester, 915, 412);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('bottom bar style', () {
    testWidgets('the default Expressive style floats the bar as an island', (
      tester,
    ) async {
      await pumpAt(tester, 412, 915);
      expect(find.byKey(island), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      // Only the selected destination shows its label; the others are icons
      // with tooltips.
      expect(find.text('设备'), findsOneWidget);
      expect(find.text('服务'), findsNothing);
      expect(find.byTooltip('服务'), findsOneWidget);
    });

    testWidgets('the Material 3 style keeps the classic bar', (tester) async {
      await pumpAt(tester, 412, 915, uiStyle: AppUiStyle.material3);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byKey(island), findsNothing);
    });

    testWidgets('the rail ignores the setting', (tester) async {
      await pumpAt(tester, 933, 704);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byKey(island), findsNothing);
    });

    testWidgets('tapping an island destination navigates', (tester) async {
      await pumpAt(tester, 412, 915);
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('page /settings'), findsOneWidget);
    });
  });

  testWidgets('the rail carries the same five destinations, in order', (
    tester,
  ) async {
    await pumpAt(tester, 1600, 900); // desktop
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations, hasLength(5));
    expect(rail.selectedIndex, 0);
    expect(rail.groupAlignment, 0);
  });

  testWidgets('tapping a rail destination navigates', (tester) async {
    await pumpAt(tester, 933, 704);
    expect(find.text('page /devices'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.lan_outlined));
    await tester.pumpAndSettle();
    expect(find.text('page /network'), findsOneWidget);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.selectedIndex, 2);
  });
  group('wide-window navigation (1.7.1)', () {
    testWidgets('Expressive can keep its bottom bar on a wide window', (
      tester,
    ) async {
      await pumpAt(tester, 933, 704, wideBottom: true);
      expect(find.byKey(island), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('Material 3 ignores the wide bottom-bar setting', (
      tester,
    ) async {
      await pumpAt(
        tester,
        933,
        704,
        uiStyle: AppUiStyle.material3,
        wideBottom: true,
      );
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('the rail sits on the left by default', (tester) async {
      await pumpAt(tester, 933, 704);
      expect(tester.getTopLeft(find.byType(NavigationRail)).dx, 0);
    });

    for (final style in AppUiStyle.values) {
      testWidgets(
        'the always-side setting shows the rail on a phone (${style.name})',
        (tester) async {
          await pumpAt(tester, 412, 915, uiStyle: style, alwaysSide: true);
          expect(find.byType(NavigationRail), findsOneWidget);
          expect(find.byType(NavigationBar), findsNothing);
          expect(find.byKey(island), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('the always-side setting overrides the wide bottom bar', (
      tester,
    ) async {
      await pumpAt(tester, 933, 704, wideBottom: true, alwaysSide: true);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byKey(island), findsNothing);
    });

    for (final style in AppUiStyle.values) {
      testWidgets('the rail can sit on the right (${style.name})', (
        tester,
      ) async {
        await pumpAt(tester, 933, 704, uiStyle: style, railRight: true);
        final rail = tester.getRect(find.byType(NavigationRail));
        expect(rail.right, 933);
        expect(find.text('page /devices'), findsOneWidget);
      });
    }
  });

  group('content behind the floating bar (1.7.1)', () {
    Widget probe(String path) => Scaffold(
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('fab'),
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      body: Builder(
        builder: (context) => Text(
          'inset ${MediaQuery.paddingOf(context).bottom.round()}',
          key: const ValueKey('inset'),
          textDirection: TextDirection.ltr,
        ),
      ),
    );

    testWidgets('Expressive reports the bar height as bottom padding', (
      tester,
    ) async {
      await pumpAt(tester, 412, 915, pageBuilder: probe);
      final bar = tester.getRect(find.byKey(island));
      final text = tester.widget<Text>(find.byKey(const ValueKey('inset')));
      final inset = int.parse(text.data!.split(' ').last);
      expect(inset, greaterThanOrEqualTo(bar.height.floor()));
    });

    testWidgets('the floating action button clears the bar', (tester) async {
      await pumpAt(tester, 412, 915, pageBuilder: probe);
      final bar = tester.getRect(find.byKey(island));
      final fab = tester.getRect(find.byKey(const ValueKey('fab')));
      expect(fab.bottom, lessThanOrEqualTo(bar.top));
    });

    testWidgets('Material 3 reserves no extra bottom padding', (tester) async {
      await pumpAt(
        tester,
        412,
        915,
        uiStyle: AppUiStyle.material3,
        pageBuilder: probe,
      );
      final text = tester.widget<Text>(find.byKey(const ValueKey('inset')));
      expect(text.data, 'inset 0');
    });

    testWidgets('navBarAwarePadding adds the inset to the bottom', (
      tester,
    ) async {
      late EdgeInsets padded;
      await pumpAt(
        tester,
        412,
        915,
        pageBuilder: (_) => Scaffold(
          body: Builder(
            builder: (context) {
              padded = navBarAwarePadding(context, const EdgeInsets.all(8));
              return const SizedBox();
            },
          ),
        ),
      );
      final bar = tester.getRect(find.byKey(island));
      expect(padded.bottom, greaterThanOrEqualTo(8 + bar.height.floor()));
      expect(padded.top, 8);
    });
  });
}
