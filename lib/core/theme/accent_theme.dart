import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AccentTheme {
  gold,
  silver,
  copper,
  emerald;

  String get label {
    switch (this) {
      case AccentTheme.gold:
        return 'Gold';
      case AccentTheme.silver:
        return 'Silver';
      case AccentTheme.copper:
        return 'Copper';
      case AccentTheme.emerald:
        return 'Emerald';
    }
  }

  Color get color {
    switch (this) {
      case AccentTheme.gold:
        return const Color(0xFFD4AF37);
      case AccentTheme.silver:
        return const Color(0xFFC0C0C0);
      case AccentTheme.copper:
        return const Color(0xFFB87333);
      case AccentTheme.emerald:
        return const Color(0xFF50C878);
    }
  }

  // Darker variant used for text on gold backgrounds
  Color get onAccent {
    switch (this) {
      case AccentTheme.gold:
      case AccentTheme.copper:
      case AccentTheme.emerald:
        return const Color(0xFF1A1A1A);
      case AccentTheme.silver:
        return const Color(0xFF1A1A1A);
    }
  }

  String get _prefsKey => 'accent_theme';

  static const _prefsKeyStatic = 'accent_theme';

  static AccentTheme fromString(String? value) {
    switch (value) {
      case 'silver':
        return AccentTheme.silver;
      case 'copper':
        return AccentTheme.copper;
      case 'emerald':
        return AccentTheme.emerald;
      default:
        return AccentTheme.gold;
    }
  }

  String toStorageString() => name;
}

class AccentThemeNotifier extends ChangeNotifier {
  AccentTheme _current = AccentTheme.gold;

  AccentTheme get current => _current;
  Color get accent => _current.color;
  Color get onAccent => _current.onAccent;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _current = AccentTheme.fromString(prefs.getString(AccentTheme._prefsKeyStatic));
    notifyListeners();
  }

  Future<void> setTheme(AccentTheme theme) async {
    if (_current == theme) return;
    _current = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AccentTheme._prefsKeyStatic, theme.toStorageString());
  }
}
