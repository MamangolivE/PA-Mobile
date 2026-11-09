import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mode tema (terang/gelap) disimpan di perangkat dengan shared_preferences,
// sehingga pilihan pengguna tetap ada setelah aplikasi ditutup.
class ThemeProvider extends ChangeNotifier {
  // Kunci penyimpanan. Juga dimasukkan ke allowList di main.dart.
  static const String kunciMode = 'mode_tema';

  ThemeProvider({required SharedPreferencesWithCache prefs})
      : _prefs = prefs,
  // Dibaca sinkron karena nilainya sudah ada di cache (dibuat sebelum runApp).
        _themeMode = _bacaMode(prefs);

  final SharedPreferencesWithCache _prefs;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Enum disimpan sebagai namanya ('light' / 'dark' / 'system').
  // Jika belum pernah disimpan atau isinya tidak dikenal, dipakai mode terang.
  static ThemeMode _bacaMode(SharedPreferencesWithCache prefs) {
    final String? nama = prefs.getString(kunciMode);
    return ThemeMode.values.asNameMap()[nama] ?? ThemeMode.light;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners(); // tampilan langsung berganti
    try {
      await _prefs.setString(kunciMode, mode.name); // pilihan disimpan
    } catch (_) {
      // Gagal menyimpan tidak boleh mengganggu aplikasi.
    }
  }

  Future<void> toggleTheme() =>
      setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
}