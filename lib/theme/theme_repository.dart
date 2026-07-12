import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'theme_settings.dart';

class ThemeRepository {
  ThemeRepository(this._preferences);

  static const _settingsKey = 'theme.settings.v1';

  final SharedPreferences _preferences;

  ThemeSettings load() {
    final encoded = _preferences.getString(_settingsKey);
    if (encoded == null) return const ThemeSettings();
    try {
      final json = jsonDecode(encoded);
      return json is Map<String, dynamic>
          ? ThemeSettings.fromJson(json)
          : const ThemeSettings();
    } on FormatException {
      return const ThemeSettings();
    }
  }

  Future<bool> save(ThemeSettings settings) =>
      _preferences.setString(_settingsKey, jsonEncode(settings.toJson()));
}
