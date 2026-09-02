import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/settings/views/license_page.dart'
    as app_license;
import 'package:my_device/features/settings/views/settings_page.dart';
import 'package:my_device/shared/utils/adaptive_layout.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test the settings page's list-detail layout on wide windows, and
/// the reading-width cap on the prose pages it hosts.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The privacy policy is the probe because it is the one hosted page
/// that touches neither the file system nor the network, so what these cases
/// measure is the layout and nothing else. The distinguishing assertion is
/// not that the page appeared — it appears in both modes — but whether the
/// first-level list is still on screen beside it. Driven in Simplified
/// Chinese (see `pumpPageAt`): `flutter_test`'s em-square font would overflow
/// the English option labels in the settings rows' trailing dropdowns.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  const theme = '主题'; // a row that only ever lives in the first-level list
  const privacy = '隐私政策';
  const placeholder = '从左侧列表中选择一项';

  setUp(() async {
    tempDir = await seedAppDir('mydevice_settings_ui');
    PackageInfo.setMockInitialValues(
      appName: 'MyDevice',
      packageName: 'com.example.my_device',
      version: '1.5.5',
      buildNumber: '44',
      buildSignature: '',
    );
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  Future<void> pumpAt(WidgetTester tester, double w, double h) => pumpPageAt(
    tester,
    w,
    h,
    page: const SettingsPage(),
    ready: find.text(theme),
  );

  testWidgets('a Z Fold 8 in landscape shows the placeholder beside the list', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(find.text(placeholder), findsOneWidget);
    expect(find.text(theme), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a row on a wide window hosts the page beside the list', (
    tester,
  ) async {
    await pumpAt(tester, 933, 704);
    final scrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    // The row sits below the fold and is not built yet, so the finder must
    // be allowed to match nothing until the scroll reaches it.
    await tester.scrollUntilVisible(
      find.text(privacy),
      200,
      scrollable: scrollable,
    );
    // Built within the cache extent is not on screen: bring the row fully
    // into view before tapping it.
    await tester.ensureVisible(find.text(privacy).first);
    await settle(tester);
    await tester.tap(find.text(privacy).first);
    await settle(tester);

    // The row's title and the hosted page's app bar title: two on screen.
    expect(find.text(privacy), findsNWidgets(2));
    // The list is still there (scrolled, so its first rows are not built),
    // to the left of the hosted page, which grew no back arrow.
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    final list = tester.getRect(find.text(privacy).first);
    final hosted = tester.getRect(find.byType(SelectableText));
    expect(hosted.left, greaterThan(list.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same device in portrait pushes the page full-screen', (
    tester,
  ) async {
    await pumpAt(tester, 704, 933);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.text(placeholder), findsNothing);
    final scrollable = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    // The row sits below the fold and is not built yet, so the finder must
    // be allowed to match nothing until the scroll reaches it.
    await tester.scrollUntilVisible(
      find.text(privacy),
      200,
      scrollable: scrollable,
    );
    // Built within the cache extent is not on screen: bring the row fully
    // into view before tapping it.
    await tester.ensureVisible(find.text(privacy).first);
    await settle(tester);
    await tester.tap(find.text(privacy).first);
    await settle(tester);
    // Full-screen: the list is gone and the page has a back arrow.
    expect(find.text(theme), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone is unchanged', (tester) async {
    await pumpAt(tester, 412, 915);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.text(placeholder), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the license page caps its prose at the reading width', (
    tester,
  ) async {
    await pumpPageAt(
      tester,
      1600,
      900,
      page: const app_license.LicensePage(),
      ready: find.byType(SelectableText),
    );
    final text = tester.getRect(find.byType(SelectableText));
    expect(text.width, lessThanOrEqualTo(readingMaxWidth - 32));
    expect(text.left, greaterThan(400));
    expect(tester.takeException(), isNull);
  });
}
