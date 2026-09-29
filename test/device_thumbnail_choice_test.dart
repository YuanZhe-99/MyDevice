import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/models/device.dart';
import 'package:my_device/features/devices/services/preset_service.dart';
import 'package:my_device/features/devices/widgets/device_avatar.dart';
import 'package:my_device/features/devices/widgets/template_image_picker.dart';
import 'package:my_device/l10n/app_localizations.dart';

/// Purpose: Cover the hand-picked thumbnail: candidate ranking, the stored
/// `templateImage` field, avatar priority and the chooser sheet.
/// Inputs: None.
/// Returns: None.
/// Side effects: Registers unit and widget tests.
/// Notes: Automatic matching stays exact (see `device_image_test.dart`);
/// only the chooser is fuzzy.
void main() {
  const templates = [
    DeviceTemplate(
      name: 'Mac Mini (M4 Pro)',
      category: DeviceCategory.desktop,
      brand: 'Apple',
      model: 'Mac mini (M4 Pro)',
      image: 'assets/device_images/mini.png',
    ),
    DeviceTemplate(
      name: 'Mac Mini (M4)',
      category: DeviceCategory.desktop,
      brand: 'Apple',
      model: 'Mac mini (M4)',
      image: 'assets/device_images/mini.png',
    ),
    DeviceTemplate(
      name: 'Galaxy S24',
      category: DeviceCategory.phone,
      brand: 'Samsung',
      model: 'Galaxy S24',
      image: 'assets/device_images/s24.png',
    ),
    DeviceTemplate(
      name: 'Mac Studio',
      category: DeviceCategory.desktop,
      brand: 'Apple',
      model: 'Mac Studio',
      image: 'assets/device_images/studio.png',
    ),
    DeviceTemplate(
      name: 'Hetzner CX22',
      category: DeviceCategory.vps,
      brand: 'Hetzner',
      model: 'CX22',
    ),
  ];

  group('rankTemplateImageCandidates', () {
    test('ranks shared words first and keeps every thumbnail once', () {
      final ranked = PresetService.rankTemplateImageCandidates(
        templates,
        name: 'My mac mini',
      );
      expect(ranked.map((t) => t.image), [
        'assets/device_images/mini.png',
        'assets/device_images/studio.png',
        'assets/device_images/s24.png',
      ]);
    });

    test('an exact identity match comes first', () {
      final ranked = PresetService.rankTemplateImageCandidates(
        templates,
        brand: 'Apple',
        model: 'Mac Studio',
      );
      expect(ranked.first.image, 'assets/device_images/studio.png');
    });

    test('the brand counts as a shared word; ties keep catalog order', () {
      final ranked = PresetService.rankTemplateImageCandidates(
        templates,
        brand: 'Samsung',
        name: 'Studio phone',
      );
      // Galaxy S24 shares "samsung", Mac Studio shares "studio": one word
      // each, so catalog order decides; the Mac mini shares nothing.
      expect(ranked.map((t) => t.image), [
        'assets/device_images/s24.png',
        'assets/device_images/studio.png',
        'assets/device_images/mini.png',
      ]);
    });

    test('an empty identity keeps catalog order', () {
      final ranked = PresetService.rankTemplateImageCandidates(templates);
      expect(ranked.map((t) => t.image), [
        'assets/device_images/mini.png',
        'assets/device_images/s24.png',
        'assets/device_images/studio.png',
      ]);
    });

    test('isTemplateImage accepts only bundled assets', () {
      expect(
        PresetService.isTemplateImage(
          templates,
          'assets/device_images/s24.png',
        ),
        isTrue,
      );
      expect(
        PresetService.isTemplateImage(templates, 'assets/device_images/x.png'),
        isFalse,
      );
    });
  });

  group('Device.templateImage', () {
    test('round-trips through JSON and is omitted when null', () {
      final device = Device(
        name: 'Office box',
        category: DeviceCategory.desktop,
        templateImage: 'assets/device_images/mini.png',
      );
      final json = device.toJson();
      expect(json['templateImage'], 'assets/device_images/mini.png');
      expect(Device.fromJson(json).templateImage, device.templateImage);

      final plain = Device(name: 'Plain', category: DeviceCategory.other);
      expect(plain.toJson().containsKey('templateImage'), isFalse);
    });

    test('copyWith keeps or clears it', () {
      final device = Device(
        name: 'Office box',
        category: DeviceCategory.desktop,
        templateImage: 'assets/device_images/mini.png',
      );
      expect(device.copyWith(name: 'Renamed').templateImage, isNotNull);
      expect(device.copyWith(clearTemplateImage: true).templateImage, isNull);
    });

    test('a device made from a template keeps the template thumbnail', () {
      final device = templates[2].toDevice();
      expect(device.templateImage, 'assets/device_images/s24.png');
      expect(templates[4].toDevice().templateImage, isNull);
    });
  });

  group('DeviceAvatar with a chosen thumbnail', () {
    Future<void> pump(WidgetTester tester, DeviceAvatar avatar) async {
      await tester.runAsync(PresetService.loadTemplates);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: avatar)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the chosen thumbnail for a device matching nothing', (
      tester,
    ) async {
      await tester.runAsync(PresetService.loadTemplates);
      final asset = PresetService.cachedTemplates!
          .firstWhere((t) => t.image != null)
          .image!;
      await pump(
        tester,
        DeviceAvatar(
          category: DeviceCategory.other,
          templateImage: asset,
          name: 'Something unrelated',
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, asset);
    });

    testWidgets('ignores a thumbnail that is no longer bundled', (
      tester,
    ) async {
      await pump(
        tester,
        const DeviceAvatar(
          category: DeviceCategory.phone,
          templateImage: 'assets/device_images/removed-in-a-later-release.png',
          brand: 'Nobody',
          model: 'Nothing 0',
        ),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
    });
  });

  group('TemplateImagePickerSheet', () {
    Future<TemplateImageChoice?> open(
      WidgetTester tester, {
      String? current,
      Future<void> Function()? act,
    }) async {
      TemplateImageChoice? result;
      var closed = false;
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
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<TemplateImageChoice>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => TemplateImagePickerSheet(
                      templates: templates,
                      category: DeviceCategory.desktop,
                      name: 'mac mini',
                      current: current,
                    ),
                  );
                  closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await act?.call();
      await tester.pumpAndSettle();
      return closed ? result : null;
    }

    testWidgets('lists Automatic first, then candidates by rank', (
      tester,
    ) async {
      await open(tester);
      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      final auto = labels.indexOf('Automatic');
      final mini = labels.indexOf('Mac Mini (M4 Pro)');
      final s24 = labels.indexOf('Galaxy S24');
      expect(auto, greaterThanOrEqualTo(0));
      expect(mini, greaterThan(auto));
      expect(s24, greaterThan(mini));
      expect(find.text('Mac Mini (M4)'), findsNothing, reason: 'shares a file');
    });

    testWidgets('searching a sibling name finds the file it borrows', (
      tester,
    ) async {
      await open(
        tester,
        act: () async {
          await tester.enterText(find.byType(TextField), 'Mini (M4)');
        },
      );
      expect(find.text('Mac Mini (M4 Pro)'), findsOneWidget);
      expect(find.text('Galaxy S24'), findsNothing);
    });

    testWidgets('tapping a thumbnail returns it; Automatic returns null', (
      tester,
    ) async {
      final chosen = await open(
        tester,
        act: () => tester.tap(find.text('Galaxy S24')),
      );
      expect(chosen?.asset, 'assets/device_images/s24.png');

      final automatic = await open(
        tester,
        current: 'assets/device_images/s24.png',
        act: () => tester.tap(find.text('Automatic')),
      );
      expect(automatic, isNotNull);
      expect(automatic!.asset, isNull);
    });
  });
}
