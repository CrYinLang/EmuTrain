// lib/speed_service.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'settings_model.dart';
import 'track_record.dart';

/// 轨迹点：经纬度 + 对应速度
class TrackPoint {
  final double latitude;
  final double longitude;
  final double speedKmh;

  const TrackPoint({
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
  });
}

class SpeedService extends ChangeNotifier {
  // ── 单例 ──────────────────────────────────────────────────────
  static final SpeedService _instance = SpeedService._internal();
  factory SpeedService() => _instance;
  SpeedService._internal();

  // ── 状态数据 ──────────────────────────────────────────────────
  double speedKmh = 0.0;
  double maxSpeedKmh = 0.0;
  double totalDistanceM = 0.0;
  double avgSpeedKmh = 0.0;
  double _speedAccumulator = 0.0;
  int _speedSampleCount = 0;

  final List<TrackPoint> trackPoints = [];

  Position? _lastPosition;
  bool isTracking = false;
  bool hasPermission = false;
  String statusMsg = '点击开始测速';
  String debugInfo = '';
  int _updateCount = 0;

  /// 最近一次保存结果（用于 UI 提示）
  bool? lastSaveResult; // null=未保存过, true=保存成功, false=距离不足未保存

  DateTime? _trackingStartTime;

  StreamSubscription<Position>? _positionStream;
  Timer? _pollTimer;

  // ── 权限检查 ──────────────────────────────────────────────────
  Future<void> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      statusMsg = '请先开启设备定位服务';
      hasPermission = false;
      notifyListeners();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      statusMsg = '位置权限被永久拒绝，请在系统设置中开启';
      hasPermission = false;
      notifyListeners();
      return;
    }

    if (permission == LocationPermission.denied) {
      statusMsg = '需要位置权限才能测速';
      hasPermission = false;
      notifyListeners();
      return;
    }

    hasPermission = true;
    statusMsg = isTracking ? '正在测速' : '点击开始测速';
    notifyListeners();
  }

  // ── 开始追踪 ──────────────────────────────────────────────────
  void startTracking() {
    isTracking = true;
    statusMsg = '正在获取 GPS 信号…';
    _updateCount = 0;
    debugInfo = '';
    _lastPosition = null;
    totalDistanceM = 0.0;
    avgSpeedKmh = 0.0;
    maxSpeedKmh = 0.0;
    speedKmh = 0.0;
    _speedAccumulator = 0.0;
    _speedSampleCount = 0;
    lastSaveResult = null;
    trackPoints.clear();
    _trackingStartTime = DateTime.now();
    notifyListeners();

    final settings = SettingsModel();

    LocationSettings locationSettings;
    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        // ✅ 使用设置中的模式开关
        forceLocationManager: settings.forceLocationManager,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'GPS 速度计正在后台运行',
          notificationTitle: '速度计',
          enableWakeLock: true,
        ),
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPosition,
      onError: (error) {
        statusMsg = 'Stream 失败，切换轮询…';
        notifyListeners();
        _positionStream?.cancel();
        _startPollingFallback();
      },
    );

    // Stream 20秒无响应再切换，给真实GPS足够冷启动时间
    Future.delayed(const Duration(seconds: 20), () {
      if (isTracking && _updateCount == 0) {
        statusMsg = 'Stream 无响应，切换轮询…';
        notifyListeners();
        _positionStream?.cancel();
        _startPollingFallback();
      }
    });
  }

  // ── 备用轮询（读取设置中的间隔和模式）────────────────────────
  void _startPollingFallback() {
    final settings = SettingsModel();
    _pollTimer?.cancel();

    final intervalMs =
        (settings.pollIntervalSeconds * 1000).round().clamp(100, 5000);

    _pollTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) async {
      if (!isTracking) return;
      try {
        LocationSettings ls;
        if (Platform.isAndroid) {
          ls = AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            // ✅ 修复原始bug：从设置读取，默认false走FLP
            forceLocationManager: settings.forceLocationManager,
          );
        } else if (Platform.isIOS) {
          ls = AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            pauseLocationUpdatesAutomatically: false,
          );
        } else {
          ls = const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
          );
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: ls,
        ).timeout(Duration(seconds: (settings.pollIntervalSeconds * 3).ceil().clamp(5, 15)));

        _onPosition(position);
      } catch (e) {
        debugInfo = '轮询错误: $e';
        notifyListeners();
      }
    });
  }

  // ── 处理新位置数据 ────────────────────────────────────────────
  void _onPosition(Position position) {
    _updateCount++;
    final speedMs = position.speed < 0 ? 0.0 : position.speed;
    final currentSpeedKmh = speedMs * 3.6;

    double deltaDistance = 0.0;
    if (_lastPosition != null) {
      deltaDistance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (deltaDistance > 500) deltaDistance = 0;
    }
    _lastPosition = position;

    _speedSampleCount++;
    _speedAccumulator += currentSpeedKmh;

    speedKmh = currentSpeedKmh;
    totalDistanceM += deltaDistance;
    avgSpeedKmh = _speedAccumulator / _speedSampleCount;
    debugInfo = '更新#$_updateCount | ${speedMs.toStringAsFixed(2)} m/s';
    if (currentSpeedKmh > maxSpeedKmh) maxSpeedKmh = currentSpeedKmh;
    statusMsg = '正在测速';

    trackPoints.add(TrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      speedKmh: currentSpeedKmh,
    ));

    notifyListeners();
  }

  // ── 停止追踪并保存 ────────────────────────────────────────────
  Future<void> stopTracking() async {
    _positionStream?.cancel();
    _pollTimer?.cancel();
    isTracking = false;
    speedKmh = 0.0;
    _updateCount = 0;

    // 尝试保存
    if (trackPoints.isNotEmpty && _trackingStartTime != null) {
      final record = TrackRecord(
        id: _trackingStartTime!.millisecondsSinceEpoch.toString(),
        startTime: _trackingStartTime!,
        endTime: DateTime.now(),
        maxSpeedKmh: maxSpeedKmh,
        avgSpeedKmh: avgSpeedKmh,
        totalDistanceM: totalDistanceM,
        points: List.unmodifiable(trackPoints),
      );
      lastSaveResult = await TrackRecord.save(record);
      statusMsg = lastSaveResult! ? '已停止并保存记录' : '已停止（距离不足100m，未保存）';
    } else {
      statusMsg = '已停止';
    }

    notifyListeners();
  }
}
