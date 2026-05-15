import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_device/app/app.dart';

/// Purpose: Register the test cases defined in this file.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: This serves as the test entry point for the file.
void main() {
  testWidgets('App launches and shows Devices tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyDeviceApp()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('MyDevice!!!!!'), findsOneWidget);
  });
}
