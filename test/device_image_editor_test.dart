import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:my_device/features/devices/views/device_image_editor_page.dart';
import 'package:my_device/l10n/app_localizations.dart';
import 'package:my_device/shared/utils/device_image_processing.dart';

/// Purpose: Build a test photo: a dark device on a plain light background.
/// Inputs: `width`, `height` and the device rectangle.
/// Returns: The decoded image.
/// Side effects: None.
/// Notes: None.
img.Image _photo({
  int width = 400,
  int height = 200,
  int x1 = 40,
  int y1 = 50,
  int x2 = 360,
  int y2 = 150,
}) {
  final photo = img.Image(width: width, height: height)
    ..clear(img.ColorRgb8(245, 245, 245));
  img.fillRect(
    photo,
    x1: x1,
    y1: y1,
    x2: x2,
    y2: y2,
    color: img.ColorRgb8(30, 30, 30),
  );
  return photo;
}

/// Purpose: Wrap an image as an edit request.
/// Inputs: `photo`.
/// Returns: A request with default settings.
/// Side effects: None.
/// Notes: None.
DeviceImageEditRequest _request(img.Image photo) => DeviceImageEditRequest(
  rgba: photo.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba),
  width: photo.width,
  height: photo.height,
);

/// Purpose: Measure the visible content of a processed PNG.
/// Inputs: `png`.
/// Returns: The decoded image and the width of its opaque bounding box.
/// Side effects: None.
/// Notes: None.
(img.Image, int) _decode(Uint8List png) {
  final image = img.decodePng(png)!;
  var minX = image.width, maxX = -1;
  for (final p in image) {
    if (p.a <= deviceImageAlphaThreshold) continue;
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
  }
  return (image, maxX < 0 ? 0 : maxX - minX + 1);
}

/// Purpose: Cover the image editor's pipeline and its page.
/// Inputs: None.
/// Returns: None.
/// Side effects: Registers unit and widget tests.
/// Notes: The page runs with a synchronous processor instead of an isolate.
void main() {
  group('processDeviceImage', () {
    test('removes the background and fits the device at the chosen size', () {
      final (image, contentWidth) = _decode(
        processDeviceImage(_request(_photo())),
      );
      expect(image.width, 512);
      expect(image.height, 512);
      expect(image.getPixel(0, 0).a, 0, reason: 'background removed');
      expect(image.getPixel(256, 256).a, 255);
      expect(contentWidth, closeTo(512 * deviceImageSafeFraction, 2));
    });

    test('a smaller scale leaves more margin', () {
      final (_, big) = _decode(
        processDeviceImage(_request(_photo()).copyWith(scale: 0.9)),
      );
      final (_, small) = _decode(
        processDeviceImage(_request(_photo()).copyWith(scale: 0.5)),
      );
      expect(big, greaterThan(small));
      expect(small, closeTo(256, 2));
    });

    test('with removal off the whole photo is kept', () {
      final (image, contentWidth) = _decode(
        processDeviceImage(
          _request(_photo()).copyWith(removeBackground: false, scale: 1),
        ),
      );
      expect(contentWidth, 512);
      // The light background survives above the device.
      final top = image.getPixel(256, 150);
      expect(top.a, 255);
      expect(top.r, greaterThan(200));
    });

    test('the crop picks one region of the source', () {
      // Two devices side by side; keep only the right one.
      final photo = img.Image(width: 400, height: 200)
        ..clear(img.ColorRgb8(245, 245, 245));
      img.fillRect(
        photo,
        x1: 20,
        y1: 20,
        x2: 180,
        y2: 180,
        color: img.ColorRgb8(200, 20, 20),
      );
      img.fillRect(
        photo,
        x1: 260,
        y1: 60,
        x2: 340,
        y2: 140,
        color: img.ColorRgb8(20, 20, 200),
      );
      final png = processDeviceImage(
        _request(photo).copyWith(crop: (0.5, 0.0, 0.5, 1.0)),
      );
      final (image, _) = _decode(png);
      final centre = image.getPixel(256, 256);
      expect(centre.b, greaterThan(150), reason: 'kept the blue device');
      expect(centre.r, lessThan(80));
    });

    test('a crop past the image is clamped to it', () {
      final request = _request(_photo()).copyWith(crop: (-0.5, -0.5, 2, 2));
      expect(cropRectOf(request), (0, 0, 400, 200));
      expect(cropRectOf(request.copyWith(crop: (0.25, 0.5, 0.5, 0.25))), (
        100,
        100,
        200,
        50,
      ));
    });

    test('the rounded mask replaces background removal', () {
      final photo = img.Image(width: 200, height: 400)
        ..clear(img.ColorRgb8(120, 90, 60)); // "wood", touches every edge
      final (image, _) = _decode(
        processDeviceImage(_request(photo).copyWith(roundRect: 0.2, scale: 1)),
      );
      // Corners of the phone are cut; its middle stays.
      final left = (512 - 256) ~/ 2;
      expect(image.getPixel(left + 1, 1).a, 0);
      expect(image.getPixel(256, 256).a, 255);
    });
  });

  group('DeviceImageEditorPage', () {
    Future<(List<DeviceImageEditRequest>, Future<Object?> Function())> pump(
      WidgetTester tester, {
      bool allowOriginal = false,
    }) async {
      final calls = <DeviceImageEditRequest>[];
      Future<Uint8List> processor(DeviceImageEditRequest r) async {
        calls.add(r);
        return processDeviceImage(r);
      }

      final photo = _photo();
      Object? popped;
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeviceImageEditorPage(
                      source: _request(photo),
                      displayBytes: img.encodePng(photo),
                      allowOriginal: allowOriginal,
                      processor: processor,
                    ),
                  ),
                );
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (calls, () async => done ? popped : 'not closed');
    }

    testWidgets('renders a small preview on open', (tester) async {
      final (calls, _) = await pump(tester);
      expect(calls, isNotEmpty);
      expect(
        calls.first.outputSize,
        DeviceImageEditorPageState.previewOutputSize,
      );
      expect(
        calls.first.maxSource,
        DeviceImageEditorPageState.previewMaxSource,
      );
    });

    testWidgets('switches update the request and re-render', (tester) async {
      final (calls, _) = await pump(tester);
      final state = tester.state<DeviceImageEditorPageState>(
        find.byType(DeviceImageEditorPage),
      );
      final before = calls.length;
      await tester.tap(
        find.byKey(const ValueKey('imageEditorRemoveBackground')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(state.request.removeBackground, isFalse);
      expect(calls.length, greaterThan(before));

      await tester.tap(find.byKey(const ValueKey('imageEditorRoundedCorners')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(
        state.request.roundRect,
        DeviceImageEditorPageState.roundRectFraction,
      );
    });

    testWidgets('Use returns the full-size PNG', (tester) async {
      final (calls, result) = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('imageEditorUse')));
      await tester.pumpAndSettle();
      final popped = await result();
      expect(popped, isA<DeviceImageEditorResult>());
      final png = (popped! as DeviceImageEditorResult).png!;
      expect(img.decodePng(png)!.width, 512);
      expect(calls.last.outputSize, 512);
    });

    testWidgets('Use Original is offered only when allowed', (tester) async {
      await pump(tester);
      expect(find.text('Use Original'), findsNothing);
    });

    testWidgets('Use Original returns a keep-original result', (tester) async {
      final (_, result) = await pump(tester, allowOriginal: true);
      await tester.tap(find.text('Use Original'));
      await tester.pumpAndSettle();
      final popped = await result();
      expect((popped! as DeviceImageEditorResult).keepOriginal, isTrue);
    });
  });
}
