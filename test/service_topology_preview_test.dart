import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/services/services/service_topology_layout.dart';
import 'package:my_device/features/services/views/service_topology_page.dart';
import 'package:my_device/features/services/views/service_topology_widgets.dart';
import 'package:my_device/l10n/app_localizations.dart';

import 'support/pump.dart';
import 'support/topology_fixtures.dart';

/// Purpose: Render the service topology of every fixture to PNG files and
/// write layout metrics next to them, for checking a layout change by eye.
/// Inputs: The `TOPOLOGY_PREVIEW` environment variable — the output folder;
/// without it every test is skipped.
/// Returns: None.
/// Side effects: Writes `<fixture>-grouped.png`, `<fixture>-flat.png` and
/// `metrics.json` into the output folder.
/// Notes: Loads Roboto and the Material icon font from the Flutter SDK so
/// labels and icons render as in the app (the test font draws boxes). Run
/// with `TOPOLOGY_PREVIEW=build/topology-preview flutter test
/// test/service_topology_preview_test.dart`.
void main() {
  final output = Platform.environment['TOPOLOGY_PREVIEW'];
  final skip = output == null || output.isEmpty;
  final samples = <String, SampleGraph Function()>{
    'homelab': homelabSample,
    'sample': buildSampleGraph,
    'frp': frpSample,
    'shared-vps': sharedVpsSample,
    'synthetic': syntheticSample,
  };
  final metrics = <String, Object>{};

  setUpAll(() async {
    if (skip) return;
    await _loadFonts();
  });

  tearDownAll(() async {
    if (skip) return;
    await File(
      '$output/metrics.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(metrics));
  });

  for (final entry in samples.entries) {
    for (final grouped in [true, false]) {
      final name = '${entry.key}-${grouped ? 'grouped' : 'flat'}';
      testWidgets(name, skip: skip, (tester) async {
        final sample = entry.value();
        final watch = Stopwatch()..start();
        final layout = ServiceTopologyLayout.build(
          sample.graph,
          sample.routes,
          1256,
          options: ServiceTopologyLayoutOptions(groupByDevice: grouped),
        );
        watch.stop();
        metrics[name] = {
          ...topologyMetrics(layout),
          'layoutMs': watch.elapsedMilliseconds,
        };
        await _render(tester, sample, grouped, '$output/$name.png');
      });
    }
  }
}

/// Purpose: Load Roboto and the Material icon font from the Flutter SDK.
/// Inputs: None.
/// Returns: `Future<void>`.
/// Side effects: Registers the fonts with the engine.
/// Notes: The SDK is found through `FLUTTER_ROOT`, else from the test
/// runner's own path (`<sdk>/bin/cache/artifacts/engine/<host>/...`). A
/// missing font is skipped.
Future<void> _loadFonts() async {
  var root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    var dir = File(Platform.resolvedExecutable).parent;
    while (dir.parent.path != dir.path &&
        !Directory('${dir.path}/bin/cache/artifacts').existsSync()) {
      dir = dir.parent;
    }
    root = dir.path;
  }
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final file in files) {
      final font = File('$fonts/$file');
      if (!font.existsSync()) continue;
      any = true;
      loader.addFont(
        font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    if (any) await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

/// Purpose: Pump the real topology page over a sample and save its canvas.
/// Inputs: `tester`, `sample`, `grouped`, `path` — the PNG to write.
/// Returns: `Future<void>`.
/// Side effects: Pumps widgets and writes a PNG file.
/// Notes: English UI on a 1280 × 900 window; the canvas repaint boundary is
/// captured at twice its size, so the whole canvas is saved whatever the
/// viewer's zoom.
Future<void> _render(
  WidgetTester tester,
  SampleGraph sample,
  bool grouped,
  String path,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: ThemeData(fontFamily: 'Roboto'),
        home: ServiceTopologyPage(
          graph: sample.graph,
          services: sample.services,
          devices: sample.devices,
          routes: sample.routes,
          onEditService: (_) async {},
          onEditRoute: (_) async {},
          onAddAccess: ({draft}) async {},
        ),
      ),
    ),
  );
  await pumpUntil(tester, find.byType(ServiceTopologyNodeCard));
  await settle(tester);
  if (!grouped) {
    await tester.tap(find.byKey(const Key('topology-group-by-device')));
    await settle(tester);
    await pumpUntil(tester, find.byType(ServiceTopologyNodeCard));
    await settle(tester);
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find
        .descendant(
          of: find.byKey(const Key('topology-canvas')),
          matching: find.byType(RepaintBoundary),
        )
        .first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File(path).create(recursive: true);
    await File(path).writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

/// Purpose: Measure how readable a layout's edges are.
/// Inputs: `layout`.
/// Returns: A JSON-ready map: canvas size, edge count, bends, total length,
/// crossings between edges, overlapping length of different edges on one
/// line, the smallest gap between parallel segments of different edges, and
/// the rank crossings the sweep left.
/// Side effects: None.
/// Notes: Two edges that share an end are still counted; the numbers are
/// for comparing two versions of the layout on the same graph.
Map<String, Object> topologyMetrics(ServiceTopologyLayout layout) {
  final segments = <({int edge, Offset a, Offset b})>[];
  var bends = 0;
  var length = 0.0;
  for (final (index, path) in layout.edgePaths.values.indexed) {
    bends += math.max(0, path.length - 2);
    for (var i = 1; i < path.length; i++) {
      length += (path[i] - path[i - 1]).distance;
      segments.add((edge: index, a: path[i - 1], b: path[i]));
    }
  }
  bool horizontal(({int edge, Offset a, Offset b}) s) =>
      (s.a.dy - s.b.dy).abs() < 0.01;
  double overlap(double a1, double a2, double b1, double b2) =>
      math.min(math.max(a1, a2), math.max(b1, b2)) -
      math.max(math.min(a1, a2), math.min(b1, b2));
  var crossings = 0;
  var shared = 0.0;
  var minGap = double.infinity;
  for (var i = 0; i < segments.length; i++) {
    for (var j = i + 1; j < segments.length; j++) {
      final s = segments[i];
      final t = segments[j];
      if (s.edge == t.edge) continue;
      final sh = horizontal(s);
      final th = horizontal(t);
      if (sh != th) {
        final h = sh ? s : t;
        final v = sh ? t : s;
        final x = v.a.dx;
        final y = h.a.dy;
        if (x > math.min(h.a.dx, h.b.dx) + 0.5 &&
            x < math.max(h.a.dx, h.b.dx) - 0.5 &&
            y > math.min(v.a.dy, v.b.dy) + 0.5 &&
            y < math.max(v.a.dy, v.b.dy) - 0.5) {
          crossings++;
        }
        continue;
      }
      final span = sh
          ? overlap(s.a.dx, s.b.dx, t.a.dx, t.b.dx)
          : overlap(s.a.dy, s.b.dy, t.a.dy, t.b.dy);
      if (span <= 0.5) continue;
      final gap = sh ? (s.a.dy - t.a.dy).abs() : (s.a.dx - t.a.dx).abs();
      if (gap < 0.01) {
        shared += span;
      } else {
        minGap = math.min(minGap, gap);
      }
    }
  }
  return {
    'size': [layout.size.width.round(), layout.size.height.round()],
    'edges': layout.edgePaths.length,
    'bends': bends,
    'length': length.round(),
    'crossings': crossings,
    'sharedLength': shared.round(),
    'minParallelGap': minGap.isFinite ? minGap : null,
    'rankCrossings': layout.crossings,
  }.map((key, value) => MapEntry(key, value ?? 'none'));
}
