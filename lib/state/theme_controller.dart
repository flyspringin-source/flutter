import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({bool? persistEnabled}) : _persistEnabled = persistEnabled;

  static const _prefsKey = 'theme_mode_v1';

  final bool? _persistEnabled;
  var _mode = ThemeMode.system;
  Future<void>? _loadFuture;

  ThemeMode get mode => _mode;

  Future<void> load() {
    return _loadFuture ??= _readPersisted();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
    await _persist();
  }

  Future<void> _readPersisted() async {
    if (!_canPersist) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      final next = _fromName(raw);
      if (next == null || next == _mode) {
        return;
      }
      _mode = next;
      notifyListeners();
    } catch (error) {
      debugPrint('Theme load failed: $error');
    }
  }

  Future<void> _persist() async {
    if (!_canPersist) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _mode.name);
    } catch (error) {
      debugPrint('Theme persist failed: $error');
    }
  }

  bool get _canPersist {
    if (_persistEnabled != null) {
      return _persistEnabled!;
    }
    return !_isWidgetTest;
  }

  bool get _isWidgetTest {
    try {
      return WidgetsBinding.instance.runtimeType.toString() ==
          'AutomatedTestWidgetsFlutterBinding';
    } catch (_) {
      return true;
    }
  }

  static ThemeMode? _fromName(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }
}
