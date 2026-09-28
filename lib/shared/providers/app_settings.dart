import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai/services/on_device_ai_service.dart';
import '../../features/devices/services/device_storage.dart';

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  /// Purpose: Create an app settings notifier instance.
  /// Inputs: None.
  /// Returns: A new `AppSettingsNotifier` instance.
  /// Side effects: Starts loading persisted settings into state.
  /// Notes: Initializes with default settings before async persistence loads.
  AppSettingsNotifier() : super(const AppSettings()) {
    _loadPersisted();
  }

  /// Purpose: Create a notifier that starts from fixed settings.
  /// Inputs: `settings`.
  /// Returns: A new `AppSettingsNotifier` instance.
  /// Side effects: None; nothing is read from disk.
  /// Notes: For tests that override `appSettingsProvider`. Setters still
  /// persist through `DeviceStorage`.
  AppSettingsNotifier.fixed(super.settings);

  /// Purpose: Load persisted into the current workflow or state.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Reads `storage_config.json`; pushes the on-device AI
  /// preferences into `OnDeviceAiService`.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadPersisted() async {
    final modeStr = await DeviceStorage.getThemeMode();
    final localeTag = await DeviceStorage.getLocaleTag();
    final onDeviceAiEnabled = await DeviceStorage.getOnDeviceAiEnabled();
    final onDeviceAiPreferFast = await DeviceStorage.getOnDeviceAiPreferFast();

    final themeMode = switch (modeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    Locale? locale;
    if (localeTag != null) {
      final parts = localeTag.split('_');
      locale = parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    }

    state = AppSettings(
      themeMode: themeMode,
      locale: locale,
      onDeviceAiEnabled: onDeviceAiEnabled,
      onDeviceAiPreferFast: onDeviceAiPreferFast,
    );
    final ai = OnDeviceAiService.instance;
    await ai.setPreferFast(onDeviceAiPreferFast);
    await ai.setEnabled(onDeviceAiEnabled);
  }

  /// Purpose: Update theme mode with the provided value.
  /// Inputs: `mode`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    final str = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => null,
    };
    DeviceStorage.setThemeMode(str);
  }

  /// Purpose: Update locale with the provided value.
  /// Inputs: `locale`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  void setLocale(Locale? locale) {
    state = state.copyWith(locale: locale, clearLocale: locale == null);
    if (locale == null) {
      DeviceStorage.setLocaleTag(null);
    } else {
      final tag = locale.countryCode != null
          ? '${locale.languageCode}_${locale.countryCode}'
          : locale.languageCode;
      DeviceStorage.setLocaleTag(tag);
    }
  }

  /// Purpose: Turn on-device AI on or off.
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Persists the preference and switches `OnDeviceAiService`.
  /// Notes: Off by default. Switching off cancels anything running; the
  /// insight cards then render nothing.
  void setOnDeviceAiEnabled(bool enabled) {
    state = state.copyWith(onDeviceAiEnabled: enabled);
    DeviceStorage.setOnDeviceAiEnabled(enabled);
    OnDeviceAiService.instance.setEnabled(enabled);
  }

  /// Purpose: Prefer the faster on-device model where both sizes are served.
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Persists the preference; the service re-probes.
  /// Notes: Android only.
  void setOnDeviceAiPreferFast(bool enabled) {
    state = state.copyWith(onDeviceAiPreferFast: enabled);
    DeviceStorage.setOnDeviceAiPreferFast(enabled);
    OnDeviceAiService.instance.setPreferFast(enabled);
  }
}

class AppSettings {
  final ThemeMode themeMode;
  final Locale? locale;

  /// Whether on-device AI (the insight cards) is on. Device-local.
  final bool onDeviceAiEnabled;

  /// Whether the faster on-device model is preferred (Android).
  final bool onDeviceAiPreferFast;

  /// Purpose: Create an app settings instance.
  /// Inputs: `themeMode`, `locale`, `onDeviceAiEnabled`,
  /// `onDeviceAiPreferFast`.
  /// Returns: A new `AppSettings` instance.
  /// Side effects: None.
  /// Notes: None.
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.onDeviceAiEnabled = false,
    this.onDeviceAiPreferFast = false,
  });

  /// Purpose: Create a copy with selected fields replaced.
  /// Inputs: `clearLocale`.
  /// Returns: `AppSettings`.
  /// Side effects: None.
  /// Notes: None.
  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? onDeviceAiEnabled,
    bool? onDeviceAiPreferFast,
    bool clearLocale = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : (locale ?? this.locale),
      onDeviceAiEnabled: onDeviceAiEnabled ?? this.onDeviceAiEnabled,
      onDeviceAiPreferFast: onDeviceAiPreferFast ?? this.onDeviceAiPreferFast,
    );
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
      (ref) => AppSettingsNotifier(),
    );
