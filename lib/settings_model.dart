// lib/settings_model.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsModel extends ChangeNotifier {
  static final SettingsModel _instance = SettingsModel._internal();
  factory SettingsModel() => _instance;
  SettingsModel._internal();

  bool _forceLocationManager = false;
  double _pollIntervalSeconds = 1.0;

  bool get forceLocationManager => _forceLocationManager;
  double get pollIntervalSeconds => _pollIntervalSeconds;

  // ✅ 可安全重复调用，每次都从 SharedPreferences 同步最新值
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _forceLocationManager = prefs.getBool('forceLocationManager') ?? false;
    _pollIntervalSeconds = prefs.getDouble('pollIntervalSeconds') ?? 1.0;
    notifyListeners();
  }

  Future<void> setForceLocationManager(bool value) async {
    _forceLocationManager = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('forceLocationManager', value);
    notifyListeners();
  }

  Future<void> setPollIntervalSeconds(double value) async {
    _pollIntervalSeconds = value.clamp(0.1, 5.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pollIntervalSeconds', _pollIntervalSeconds);
    notifyListeners();
  }
}
