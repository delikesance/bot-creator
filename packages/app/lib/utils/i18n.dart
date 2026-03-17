import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'trad/en.dart';
import 'trad/fr.dart';

/// Locales supportees
enum AppLocale {
  en('English', 'en'),
  fr('Français', 'fr');

  final String label;
  final String code;

  const AppLocale(this.label, this.code);
}

enum AppLocalePreference {
  system('Automatic', 'system'),
  en('English', 'en'),
  fr('Français', 'fr');

  final String label;
  final String code;

  const AppLocalePreference(this.label, this.code);
}

/// Translations for all strings in the app
class AppStrings {
  static const Map<String, Map<String, String>> _translations = {
    'en': appStringsEn,
    'fr': appStringsFr,
  };

  static String _get(String key, {AppLocale locale = AppLocale.en}) {
    return _translations[locale.code]?[key] ?? _translations['en']?[key] ?? key;
  }

  static String t(String key, {AppLocale? locale}) {
    return _get(key, locale: locale ?? _currentLocale);
  }

  static String tr(
    String key, {
    AppLocale? locale,
    Map<String, String> params = const {},
  }) {
    var value = t(key, locale: locale);
    for (final entry in params.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    return value;
  }

  static AppLocale _currentLocale = AppLocale.en;

  static AppLocale get currentLocale => _currentLocale;

  static void setCurrentLocale(AppLocale locale) {
    _currentLocale = locale;
  }

  static List<AppLocale> get availableLocales => AppLocale.values;

  static AppLocale detectSystemLocale(Locale? systemLocale) {
    if (systemLocale == null) return AppLocale.en;

    final langCode = systemLocale.languageCode.toLowerCase();
    switch (langCode) {
      case 'fr':
        return AppLocale.fr;
      case 'en':
      default:
        return AppLocale.en;
    }
  }
}

/// Provider for managing app locale with ChangeNotifier
class LocaleProvider extends ChangeNotifier {
  static const String _key = 'app_locale';

  AppLocalePreference _preference = AppLocalePreference.system;
  AppLocale _locale = AppLocale.en;

  AppLocalePreference get preference => _preference;

  AppLocale get locale => _locale;

  LocaleProvider() {
    _locale = AppStrings.detectSystemLocale(
      ui.PlatformDispatcher.instance.locale,
    );
    AppStrings.setCurrentLocale(_locale);
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    final savedPreference = AppLocalePreference.values.firstWhere(
      (value) => value.code == saved,
      orElse: () => AppLocalePreference.system,
    );

    await _applyPreference(savedPreference, persist: false, notify: true);
  }

  AppLocale _resolveLocale(AppLocalePreference preference) {
    switch (preference) {
      case AppLocalePreference.fr:
        return AppLocale.fr;
      case AppLocalePreference.en:
        return AppLocale.en;
      case AppLocalePreference.system:
        return AppStrings.detectSystemLocale(
          ui.PlatformDispatcher.instance.locale,
        );
    }
  }

  Future<void> _applyPreference(
    AppLocalePreference preference, {
    required bool persist,
    required bool notify,
  }) async {
    _preference = preference;
    _locale = _resolveLocale(preference);
    AppStrings.setCurrentLocale(_locale);

    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      if (preference == AppLocalePreference.system) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, preference.code);
      }
    }

    if (notify) {
      notifyListeners();
    }
  }

  Future<void> setPreference(AppLocalePreference preference) async {
    await _applyPreference(preference, persist: true, notify: true);
  }

  Future<void> resetToSystem() async {
    await _applyPreference(
      AppLocalePreference.system,
      persist: true,
      notify: true,
    );
  }
}