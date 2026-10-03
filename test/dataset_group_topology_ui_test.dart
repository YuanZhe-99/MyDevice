import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/datasets/services/dataset_topology.dart';
import 'package:my_device/features/datasets/views/dataset_list_page.dart';
import 'package:my_device/features/datasets/views/dataset_topology_page.dart';
import 'package:my_device/l10n/app_localizations.dart';
import 'package:my_device/shared/widgets/topology_canvas_viewer.dart';

import 'dataset_topology_test.dart' show placementFixture;
import 'support/fake_storage.dart';
import 'support/pump.dart';

/// Purpose: Test the grouped data set list and the data set topology page.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app storage directory.
/// Notes: Driven in Simplified Chinese, like the other page tests.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final f = placementFixture();

  group('grouped list', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await seedAppDir(
        'mydevice_dataset_group_ui',
        devices: f.devices,
        datasets: f.dataSets,
      );
    });

    tearDown(() => deleteSeededDir(tempDir));

    /// Purpose: Pick a grouping mode from the app-bar menu.
    /// Inputs: `tester`, `mode`.
    /// Returns: `Future<void>`.
    /// Side effects: Taps the menu and the item.
    /// Notes: Waits until `storage_config.json` holds the choice.
    Future<void> pick(WidgetTester tester, String mode) async {
      await tester.tap(find.byKey(const Key('dataset-group')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('dataset-group-mode-$mode')));
      await settle(tester);
      // The preference is written on the real event loop.
      for (var i = 0; i < 40; i++) {
        final stored = readSeededConfig(tempDir)['datasetGroupMode'];
        if (stored == (mode == 'none' ? null : mode)) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
    }

    testWidgets('groups by device and by storage, and remembers it', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpPageAt(
        tester,
        412,
        915,
        page: const DataSetListPage(),
        ready: find.text('Photos'),
      );
      expect(
        find.byKey(const ValueKey('dataset-group-device:nas')),
        findsNothing,
      );

      await pick(tester, 'device');
      for (final key in [
        'device:nas',
        'device:pc',
        'device:laptop',
        'unlinked',
      ]) {
        expect(
          find.byKey(ValueKey('dataset-group-$key')),
          findsOneWidget,
          reason: key,
        );
      }
      // Photos is on the NAS and the desktop, so it shows in both groups.
      expect(find.text('Photos'), findsNWidgets(2));
      expect(
        find.textContaining(l10n.dataSetAlsoOn('Desktop')),
        findsOneWidget,
      );
      expect(find.text(l10n.dataSetSingleCopy), findsOneWidget); // Docs
      expect(readSeededConfig(tempDir)['datasetGroupMode'], 'device');

      await pick(tester, 'storage');
      expect(
        find.byKey(const ValueKey('dataset-group-storage:nas:1')),
        findsOneWidget,
      );
      expect(find.text('Music'), findsNWidgets(2));
      expect(readSeededConfig(tempDir)['datasetGroupMode'], 'storage');

      await pick(tester, 'none');
      expect(find.text('Photos'), findsOneWidget);
      expect(
        readSeededConfig(tempDir).containsKey('datasetGroupMode'),
        isFalse,
      );
    });
  });

  group('topology page', () {
    /// Purpose: Pump the topology page over the fixture.
    /// Inputs: `tester`; `width`, `height`; `edited` — collects edited ids.
    /// Returns: `Future<void>`.
    /// Side effects: Pumps the tree.
    /// Notes: None.
    Future<void> pumpTopology(
      WidgetTester tester, {
      double width = 1280,
      double height = 800,
      List<String>? edited,
    }) => pumpPageAt(
      tester,
      width,
      height,
      page: DataSetTopologyPage(
        dataSets: f.dataSets,
        devices: f.devices,
        onEditDataSet: (ds) async => edited?.add(ds.id),
      ),
      ready: find.byType(TopologyCanvasViewer),
    );

    Finder box(String id) => find.byKey(ValueKey('dataset-topology-node-$id'));

    /// Purpose: Read whether a box is drawn dimmed.
    /// Inputs: `tester`, `id`.
    /// Returns: `bool`.
    /// Side effects: None.
    /// Notes: Reads the box's `Opacity`.
    bool dimmed(WidgetTester tester, String id) =>
        tester
            .widget<Opacity>(
              find.descendant(of: box(id), matching: find.byType(Opacity)),
            )
            .opacity <
        1;

    final photosOnNas = DataSetTopologyLayout.copyNodeId('photos', 'nas', 0);
    final photosOnPc = DataSetTopologyLayout.copyNodeId('photos', 'pc', 0);
    final musicOnNas = DataSetTopologyLayout.copyNodeId('music', 'nas', 1);

    testWidgets('draws devices, storages and copies, nested', (tester) async {
      await pumpTopology(tester);
      expect(box('device:nas'), findsOneWidget);
      expect(box('storage:nas:1'), findsOneWidget);
      expect(box(photosOnNas), findsOneWidget);
      expect(box('device:phone'), findsNothing);
      final nas = tester.getRect(box('device:nas'));
      final copy = tester.getRect(box(musicOnNas));
      expect(nas.contains(copy.center), isTrue);
    });

    testWidgets('a copy lights its data set everywhere, and edits refresh', (
      tester,
    ) async {
      final edited = <String>[];
      await pumpTopology(tester, edited: edited);
      await tester.tap(box(photosOnPc));
      await settle(tester);
      expect(dimmed(tester, photosOnNas), isFalse);
      expect(dimmed(tester, 'device:nas'), isFalse);
      expect(dimmed(tester, musicOnNas), isTrue);
      expect(dimmed(tester, 'device:laptop'), isTrue);

      final pane = find.byKey(const Key('dataset-topology-details-pane'));
      expect(pane, findsOneWidget);
      await tester.tap(
        find.descendant(
          of: pane,
          matching: find.byKey(const ValueKey('dataset-topology-edit-photos')),
        ),
      );
      await settle(tester);
      expect(edited, ['photos']);

      // A tap on empty canvas clears the selection.
      await tester.tapAt(
        tester.getBottomRight(find.byType(TopologyCanvasViewer)) -
            const Offset(8, 8),
      );
      await settle(tester);
      expect(
        find.byKey(const Key('dataset-topology-details-empty')),
        findsOneWidget,
      );
      expect(dimmed(tester, musicOnNas), isFalse);
    });

    testWidgets('a storage header selects the storage', (tester) async {
      await pumpTopology(tester);
      await tester.tapAt(
        tester.getTopLeft(box('storage:nas:1')) + const Offset(12, 12),
      );
      await settle(tester);
      expect(dimmed(tester, musicOnNas), isFalse);
      expect(dimmed(tester, photosOnPc), isTrue);
      expect(
        find.byKey(const ValueKey('dataset-topology-card-music')),
        findsOneWidget,
      );
    });

    testWidgets('a phone opens the details in a sheet', (tester) async {
      await pumpTopology(tester, width: 412, height: 915);
      await tester.tap(box(photosOnNas));
      await settle(tester);
      expect(
        find.byKey(const Key('dataset-topology-details-sheet')),
        findsOneWidget,
      );
    });

    testWidgets('the device filter narrows the canvas', (tester) async {
      await pumpTopology(tester);
      await tester.tap(find.byKey(const Key('dataset-topology-filter')));
      await settle(tester);
      await tester.tap(
        find.byKey(const ValueKey('dataset-topology-filter-device-laptop')),
      );
      await settle(tester);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await settle(tester);
      expect(box('device:nas'), findsNothing);
      expect(box('device:laptop'), findsOneWidget);
    });
  });
}
