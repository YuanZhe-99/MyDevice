import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/datasets/models/dataset.dart';
import 'package:my_device/features/datasets/views/dataset_list_page.dart';
import 'package:my_device/features/network/models/network.dart';
import 'package:my_device/features/network/views/network_list_page.dart';

import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test multi-column rendering of the network and dataset lists.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: The network tile has the narrowest minimum (300 dp), so a tablet in
/// landscape is the case that separates it from the others — three columns
/// where the device and dataset lists get two. The dataset tile keeps its
/// swipe-to-delete at one column and a trailing menu above it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await seedAppDir(
      'mydevice_columns_more_ui',
      networks: [
        for (var i = 1; i <= 4; i++)
          Network(
            id: 'n$i',
            name: '网络 $i',
            type: NetworkType.values[i % NetworkType.values.length],
            subnet: '10.0.$i.0/24',
            modifiedAt: DateTime.utc(2026, 7, 1),
          ),
      ],
      datasets: [
        for (var i = 1; i <= 4; i++)
          DataSet(
            id: 's$i',
            name: '数据集 $i',
            emoji: '📁',
            modifiedAt: DateTime.utc(2026, 7, 1),
          ),
      ],
    );
  });

  tearDown(() {
    deleteSeededDir(tempDir);
  });

  final tiles = find.byType(ListTile);

  group('network list', () {
    Future<void> pumpAt(WidgetTester tester, double w, double h) => pumpPageAt(
      tester,
      w,
      h,
      page: const NetworkListPage(),
      ready: find.text('网络 2'),
    );

    testWidgets('a Z Fold 8 in landscape carries two columns', (tester) async {
      await pumpAt(tester, 933, 704);
      final first = tester.getTopLeft(tiles.at(0));
      final second = tester.getTopLeft(tiles.at(1));
      final third = tester.getTopLeft(tiles.at(2));
      expect(second.dy, first.dy);
      expect(second.dx, greaterThan(first.dx));
      expect(third.dy, greaterThan(first.dy));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tablet in landscape carries three at 300 dp', (
      tester,
    ) async {
      // 1024 − 81 rail − 16 padding = 927 ≥ 300 × 3 + 12 × 2 = 924.
      await pumpAt(tester, 1024, 768);
      final first = tester.getTopLeft(tiles.at(0));
      final third = tester.getTopLeft(tiles.at(2));
      final fourth = tester.getTopLeft(tiles.at(3));
      expect(third.dy, first.dy);
      expect(fourth.dy, greaterThan(first.dy));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone stays on one column with no control', (tester) async {
      await pumpAt(tester, 412, 915); // Pixel 9
      expect(find.byIcon(Icons.view_column_outlined), findsNothing);
      expect(
        tester.getCenter(tiles.at(1)).dy,
        greaterThan(tester.getCenter(tiles.at(0)).dy),
      );
    });
  });

  group('dataset list', () {
    Future<void> pumpAt(WidgetTester tester, double w, double h) => pumpPageAt(
      tester,
      w,
      h,
      page: const DataSetListPage(),
      ready: find.text('数据集 2'),
    );

    testWidgets('a Z Fold 8 in landscape carries two columns with a menu', (
      tester,
    ) async {
      await pumpAt(tester, 933, 704);
      final first = tester.getTopLeft(tiles.at(0));
      final second = tester.getTopLeft(tiles.at(1));
      expect(second.dy, first.dy);
      expect(second.dx, greaterThan(first.dx));
      expect(find.byType(Dismissible), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone keeps swipe-to-delete on one column', (tester) async {
      await pumpAt(tester, 411, 914);
      expect(find.byIcon(Icons.view_column_outlined), findsNothing);
      expect(find.byType(Dismissible), findsWidgets);
      expect(
        tester.getCenter(tiles.at(1)).dy,
        greaterThan(tester.getCenter(tiles.at(0)).dy),
      );
    });
  });
}
