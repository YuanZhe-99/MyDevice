import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/devices/services/device_storage.dart';

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _loadPersisted();
  }

  Future<void> _loadPersisted() async {
    final modeStr = await DeviceStorage.getThemeMode();
    final localeTag = await DeviceStorage.getLocaleTag();

    final themeMode = switch (modeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    Locale? locale;
    if (localeTag != null) {
      final parts = localeTag.split('_');
      locale =
          parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    }

    state = AppSettings(themeMode: themeMode, locale: locale);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    final str = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => null,
    };
    DeviceStorage.setThemeMode(str);
  }

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
}

class AppSettings {
  final ThemeMode themeMode;
  final Locale? locale;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : (locale ?? this.locale),
    );
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(),
);
