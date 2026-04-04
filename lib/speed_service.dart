// lib/ui/speed_service.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// 轨迹点：经纬度 + 对应速度（用于将来按速度着色）
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

  // ── 状态数据（Widget 直接读取）────────────────────────────────
  double speedKmh = 0.0;
  double maxSpeedKmh = 0.0;
  double totalDistanceM = 0.0;
  double avgSpeedKmh = 0.0;
  double _speedAccumulator = 0.0;
  int _speedSampleCount = 0;

  /// 历史轨迹点列表，每次 GPS 更新追加一个
  final List<TrackPoint> trackPoints = [];

  Position? _lastPosition;
  bool isTracking = false;
  bool hasPermission = false;
  String statusMsg = '点击开始测速';
  String debugInfo = '';
  int _updateCount = 0;

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
    trackPoints.clear(); // 新一次记录，清空旧轨迹
    notifyListeners();

    LocationSettings locationSettings;
    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: false,
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

    Future.delayed(const Duration(seconds: 5), () {
      if (isTracking && _updateCount == 0) {
        statusMsg = 'Stream 无响应，切换轮询…';
        notifyListeners();
        _positionStream?.cancel();
        _startPollingFallback();
      }
    });
  }

  // ── 备用轮询 ──────────────────────────────────────────────────
  void _startPollingFallback() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!isTracking) return;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            forceLocationManager: true,
          ),
        ).timeout(const Duration(seconds: 10));
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

    // 追加轨迹点
    trackPoints.add(TrackPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      speedKmh: currentSpeedKmh,
    ));

    notifyListeners();
  }

  // ── 停止追踪 ──────────────────────────────────────────────────
  void stopTracking() {
    _positionStream?.cancel();
    _pollTimer?.cancel();
    isTracking = false;
    speedKmh = 0.0;
    statusMsg = '已停止';
    _updateCount = 0;
    notifyListeners();
  }
}
