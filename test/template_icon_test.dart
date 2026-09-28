import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/services/preset_service.dart';
import 'package:my_device/features/services/widgets/service_avatar.dart';

/// Purpose: Verify bundled vectors render and custom service icons remain intact.
/// Inputs: None.
/// Returns: None.
/// Side effects: Registers asset and widget tests; optionally writes a preview.
/// Notes: Set TEMPLATE_ICON_PREVIEW=true to export the light/dark contact sheet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every template asset decodes to visible artwork', () async {
    expect(serviceTemplateIconAssets, isNotEmpty);
    final brands = await PresetService.loadBrands();
    final assets = {
      ...serviceTemplateIconAssets.values,
      ...brands.map((brand) => brand.logo).whereType<String>(),
    };
    for (final asset in assets) {
      if (!asset.endsWith('.svg')) {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        final pixels = (await frame.image.toByteData())!;
        var transparent = 0;
        var visible = 0;
        for (var i = 3; i < pixels.lengthInBytes; i += 4) {
          if (pixels.getUint8(i) == 0) transparent++;
          if (pixels.getUint8(i) > 0) visible++;
        }
        expect(visible, greaterThan(0), reason: asset);
        expect(
          transparent,
          greaterThan(0),
          reason: '$asset needs transparency',
        );
        frame.image.dispose();
        codec.dispose();
        continue;
      }
      final picture = await vg.loadPicture(
        SvgStringLoader(await rootBundle.loadString(asset)),
        null,
      );
      expect(picture.size.width, greaterThan(0), reason: asset);
      expect(picture.size.height, greaterThan(0), reason: asset);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(64 / picture.size.width, 64 / picture.size.height);
      canvas.drawPicture(picture.picture);
      final scaled = recorder.endRecording();
      final image = await scaled.toImage(64, 64);
      final pixels = (await image.toByteData())!;
      var visible = 0;
      for (var i = 3; i < pixels.lengthInBytes; i += 4) {
        if (pixels.getUint8(i) > 0) visible++;
      }
      expect(visible, greaterThan(0), reason: asset);
      image.dispose();
      scaled.dispose();
      picture.picture.dispose();
    }
  });

  testWidgets('custom and unknown service icons keep their fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            ServiceAvatar(templateId: 'jellyfin', icon: 'terminal'),
            ServiceAvatar(templateId: 'future-template', icon: 'cloud'),
          ],
        ),
      ),
    );
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byIcon(Icons.terminal), findsOneWidget);
    expect(find.byIcon(Icons.cloud), findsOneWidget);
  });

  testWidgets('brand artwork fits wholly inside its circle in both themes', (
    tester,
  ) async {
    final entries = serviceTemplateIconAssets.entries.toList();
    if (Platform.environment['TEMPLATE_ICON_PREVIEW'] == 'true' &&
        Platform.isWindows) {
      await tester.runAsync(() async {
        final font = File(
          '${Platform.environment['WINDIR']}/Fonts/segoeui.ttf',
        );
        if (await font.exists()) {
          final loader = FontLoader('Preview')
            ..addFont(
              font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
            );
          await loader.load();
        }
      });
    }
    final rows = (entries.length / 8).ceil();
    final height = rows * 100.0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(1280, height);
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Row(
            children: [
              for (final brightness in Brightness.values)
                Expanded(
                  child: Theme(
                    data: ThemeData(
                      brightness: brightness,
                      fontFamily: 'Preview',
                    ),
                    child: Builder(
                      builder: (context) => Material(
                        child: Wrap(
                          children: [
                            for (final entry in entries)
                              SizedBox(
                                width: 80,
                                height: 100,
                                child: Column(
                                  children: [
                                    const SizedBox(height: 8),
                                    ServiceAvatar(
                                      templateId: entry.key,
                                      size: 56,
                                    ),
                                    Text(
                                      entry.key,
                                      style: const TextStyle(fontSize: 9),
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      for (final asset in serviceTemplateIconAssets.values.toSet()) {
        if (!asset.endsWith('.svg')) {
          await precacheImage(
            AssetImage(asset),
            tester.element(find.byType(Row).first),
          );
          continue;
        }
        await svg.cache.putIfAbsent(
          SvgAssetLoader(asset).cacheKey(null),
          () => SvgAssetLoader(asset).loadBytes(null),
        );
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final artwork = find.byWidgetPredicate(
      (widget) => widget is SvgPicture || widget is Image,
    );
    expect(artwork, findsNWidgets(entries.length * 2));
    for (final element in artwork.evaluate()) {
      final mark = tester.getRect(find.byWidget(element.widget));
      final circle = tester.getRect(
        find.ancestor(
          of: find.byWidget(element.widget),
          matching: find.byType(CircleAvatar),
        ),
      );
      expect(
        (mark.topLeft - circle.center).distance,
        lessThan(circle.width / 2),
      );
      expect(
        (mark.bottomRight - circle.center).distance,
        lessThan(circle.width / 2),
      );
    }
    if (Platform.environment['TEMPLATE_ICON_PREVIEW'] == 'true') {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          'build/template-icons.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
