import 'package:device_preview/device_preview.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../shared/providers/app_settings.dart';
import 'router.dart';
import 'theme.dart';

class MyDeviceApp extends ConsumerWidget {
  /// Purpose: Create a my device app instance.
  /// Inputs: None.
  /// Returns: A new `MyDeviceApp` instance.
  /// Side effects: None.
  /// Notes: None.
  const MyDeviceApp({super.key});

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  /// `DynamicColorBuilder` supplies the wallpaper scheme (Material You); it is
  /// used on Android only, because on Windows and macOS the plugin falls back
  /// to the system accent color, which would replace the app's own seed.
  /// Everywhere else, and on Android 11 or older, the seed scheme applies.
  /// The user's interface style (Material 3 or Expressive, 1.7.0) selects
  /// the theme variant; both share the same colors.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final allowDynamic =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp.router(
        title: 'MyDevice!!!!!',
        debugShowCheckedModeBanner: false,

        // Theme
        theme: AppTheme.light(
          allowDynamic ? lightDynamic : null,
          settings.uiStyle,
        ),
        darkTheme: AppTheme.dark(
          allowDynamic ? darkDynamic : null,
          settings.uiStyle,
        ),
        themeMode: settings.themeMode,

        // Localization
        locale: settings.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,

        // DevicePreview
        builder: DevicePreview.appBuilder,

        // Routing
        routerConfig: appRouter,
      ),
    );
  }
}
