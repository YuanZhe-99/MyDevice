import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/services/preset_service.dart';
import 'package:my_device/features/devices/widgets/device_avatar.dart';

import '../tool/device_image_check.dart';
import '../tool/prepare_device_image.dart';

/// Purpose: Cover template thumbnails end to end: parsing, the circle and
/// transparency rules, the preparation pipeline, matching, and avatar priority.
/// Inputs: None.
/// Returns: None.
/// Side effects: Registers unit and widget tests.
/// Notes: Every bundled thumbnail is checked against the same rules as
/// `tool/validate_json.dart`.
void main() {
  const templates = [
    DeviceTemplate(
      name: 'iPhone 15 Pro',
      category: DeviceCategory.phone,
      brand: 'Apple',
      model: 'iPhone 15 Pro',
      image: 'assets/device_images/pro.png',
    ),
    DeviceTemplate(
      name: 'iPhone 15',
      category: DeviceCategory.phone,
      brand: 'Apple',
      model: 'iPhone 15',
      image: 'assets/device_images/base.png',
    ),
    DeviceTemplate(
      name: 'iPad Pro 13" (M4)',
      category: DeviceCategory.tablet,
      brand: 'Apple',
      model: 'iPad Pro 13" (M4)',
      image: 'assets/device_images/ipad.png',
    ),
    DeviceTemplate(
      name: 'Hetzner CX22',
      category: DeviceCategory.vps,
      brand: 'Hetzner',
      model: 'CX22',
    ),
  ];

  group('DeviceTemplate.image', () {
    test('parses the optional image key', () {
      final t = DeviceTemplate.fromJson({
        'name': 'X',
        'category': 'phone',
        'image': 'assets/device_images/x.png',
      });
      expect(t.image, 'assets/device_images/x.png');
      expect(
        DeviceTemplate.fromJson({'name': 'Y', 'category': 'phone'}).image,
        isNull,
      );
    });

    test('every bundled thumbnail exists and passes the circle rules', () {
      final raw = jsonDecode(
        File('assets/presets/device_templates.json').readAsStringSync(),
      ) as List;
      for (final entry in raw.cast<Map<String, dynamic>>()) {
        final image = entry['image'] as String?;
        if (image == null) continue;
        final decoded = img.decodePng(File(image).readAsBytesSync());
        expect(decoded, isNotNull, reason: image);
        expect(checkDeviceImage(decoded!), isEmpty, reason: image);
      }
    });
  });

  group('checkDeviceImage', () {
    test('rejects an opaque background', () {
      final opaque = img.Image(width: 256, height: 256, numChannels: 4)
        ..clear(img.ColorRgba8(255, 255, 255, 255));
      expect(checkDeviceImage(opaque), isNotEmpty);
    });

    test('rejects visible pixels outside the circle', () {
      final image = img.Image(width: 256, height: 256, numChannels: 4);
      // Just inside the corner, clear of the corner pixel itself but well
      // outside the inscribed circle.
      image.setPixelRgba(12, 12, 0, 0, 0, 255);
      final problems = checkDeviceImage(image);
      expect(problems.single, contains('outside the avatar circle'));
    });

    test('rejects an image without alpha', () {
      final rgb = img.Image(width: 256, height: 256);
      expect(checkDeviceImage(rgb).single, contains('no alpha'));
    });
  });

  group('prepareDeviceImage', () {
    test('removes a plain background and fits content inside the circle', () {
      // A wide dark "device" on a white photo background with a white
      // screen inside it; the inner white must survive the flood fill.
      final photo = img.Image(width: 800, height: 400)
        ..clear(img.ColorRgb8(250, 250, 250));
      img.fillRect(photo, x1: 50, y1: 100, x2: 750, y2: 300,
          color: img.ColorRgb8(20, 20, 20));
      img.fillRect(photo, x1: 100, y1: 150, x2: 700, y2: 250,
          color: img.ColorRgb8(250, 250, 250));

      final result = prepareDeviceImage(photo);
      expect(result.width, deviceImageSize);
      expect(checkDeviceImage(result), isEmpty);
      final centre = result.getPixel(128, 128);
      expect(centre.a, 255, reason: 'enclosed white screen was removed');
      expect(centre.r, greaterThan(200));
    });

    test('keeps an already transparent render', () {
      final render = img.Image(width: 300, height: 600, numChannels: 4);
      img.fillRect(render, x1: 20, y1: 20, x2: 280, y2: 580,
          color: img.ColorRgba8(250, 250, 250, 255));
      final result = prepareDeviceImage(render);
      expect(checkDeviceImage(result), isEmpty);
      expect(result.getPixel(128, 128).a, 255);
    });
  });

  group('matchTemplateImage', () {
    test('matches brand and model exactly after normalizing', () {
      expect(
        PresetService.matchTemplateImage(
          templates,
          brand: 'apple',
          model: 'iphone-15 pro',
        ),
        'assets/device_images/pro.png',
      );
      expect(
        PresetService.matchTemplateImage(
          templates,
          brand: 'Apple',
          model: 'iPad Pro 13 M4',
        ),
        'assets/device_images/ipad.png',
      );
    });

    test('does not let a base model claim a Pro photo', () {
      expect(
        PresetService.matchTemplateImage(
          templates,
          brand: 'Apple',
          model: 'iPhone 15',
        ),
        'assets/device_images/base.png',
      );
      expect(
        PresetService.matchTemplateImage(
          templates,
          brand: 'Apple',
          model: 'iPhone',
        ),
        isNull,
      );
    });

    test('falls back to the device name, then brand+model as a name', () {
      expect(
        PresetService.matchTemplateImage(templates, name: 'iPhone 15 Pro'),
        'assets/device_images/pro.png',
      );
      expect(
        PresetService.matchTemplateImage(
          [
            const DeviceTemplate(
              name: 'Apple iPhone 15 Pro',
              category: DeviceCategory.phone,
              image: 'assets/device_images/named.png',
            ),
          ],
          brand: 'Apple',
          model: 'iPhone 15 Pro',
          name: 'My phone',
        ),
        'assets/device_images/named.png',
      );
    });

    test('templates without an image and unknown devices give null', () {
      expect(
        PresetService.matchTemplateImage(
          templates,
          brand: 'Hetzner',
          model: 'CX22',
        ),
        isNull,
      );
      expect(PresetService.matchTemplateImage(templates), isNull);
    });
  });

  group('DeviceAvatar', () {
    Future<void> pump(WidgetTester tester, DeviceAvatar avatar) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: avatar))),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('emoji beats a matching template thumbnail', (tester) async {
      await tester.runAsync(PresetService.loadTemplates);
      final match = PresetService.cachedTemplates!.firstWhere(
        (t) => t.image != null,
        orElse: () => const DeviceTemplate(
          name: '',
          category: DeviceCategory.other,
        ),
      );
      await pump(
        tester,
        DeviceAvatar(
          category: DeviceCategory.phone,
          emoji: '📱',
          brand: match.brand,
          model: match.model,
        ),
      );
      expect(find.text('📱'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a matching device shows its template thumbnail', (
      tester,
    ) async {
      await tester.runAsync(PresetService.loadTemplates);
      final match = PresetService.cachedTemplates!
          .where((t) => t.image != null)
          .firstOrNull;
      if (match == null) return; // No thumbnails bundled yet.
      await pump(
        tester,
        DeviceAvatar(
          category: match.category,
          brand: match.brand,
          model: match.model,
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, match.image);
    });

    testWidgets('an unmatched device keeps the category icon', (tester) async {
      await pump(
        tester,
        const DeviceAvatar(
          category: DeviceCategory.phone,
          brand: 'Nobody',
          model: 'Nothing 0',
        ),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
