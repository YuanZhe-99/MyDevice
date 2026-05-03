import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_device/app/app.dart';

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
