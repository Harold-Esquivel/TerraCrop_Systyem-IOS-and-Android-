import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local display preference; independent of the agricultural/cloud data.
class AppAppearance extends ChangeNotifier {
  static const preferenceKey = 'terracrop_appearance_v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  ThemeMode mode = ThemeMode.light;
  bool saving = false;
  bool _disposed = false;
  int _revision = 0;

  bool get isDark => mode == ThemeMode.dark;

  Future<void> load() async {
    final revision = _revision;
    try {
      final saved = await _preferences.getString(preferenceKey);
      if (_disposed || revision != _revision) return;
      mode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (error) {
      debugPrint('No se pudo leer la apariencia: $error');
    }
  }

  Future<void> toggle() async {
    if (saving) return;
    final previous = mode;
    _revision++;
    mode = isDark ? ThemeMode.light : ThemeMode.dark;
    saving = true;
    notifyListeners();
    try {
      await _preferences.setString(preferenceKey, isDark ? 'dark' : 'light');
    } catch (_) {
      mode = previous;
      rethrow;
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
