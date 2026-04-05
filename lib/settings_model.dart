// lib/settings_model.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsModel extends ChangeNotifier {
  static final SettingsModel _instance = SettingsModel._internal();
  factory SettingsModel() => _instance;
  SettingsModel._internal();

  // ── 默认值 ────────────────────────────────────────────────────
  bool _forceLocationManager = false; // false = FLP（推荐）; true = 老LocationManager
  double _pollIntervalSeconds = 1.0;  // 轮询间隔，0.1 ~ 5.0 秒

  bool get forceLocationManager => _forceLocationManager;
  double get pollIntervalSeconds => _pollIntervalSeconds;

  // ── 加载持久化数据 ────────────────────────────────────────────
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _forceLocationManager = prefs.getBool('forceLocationManager') ?? false;
    _pollIntervalSeconds = prefs.getDouble('pollIntervalSeconds') ?? 1.0;
    notifyListeners();
  }

  // ── 修改并持久化 ──────────────────────────────────────────────
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
