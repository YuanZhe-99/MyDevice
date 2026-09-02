import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_device/l10n/app_localizations.dart';
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

  Future<void> pumpAt(WidgetTester tester, double width, double height) async {
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
                    Scaffold(body: Center(child: Text('page $path'))),
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a phone in portrait keeps the bottom navigation bar', (
    tester,
  ) async {
    await pumpAt(tester, 412, 915); // Pixel 9
    expect(find.byType(NavigationBar), findsOneWidget);
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
}
