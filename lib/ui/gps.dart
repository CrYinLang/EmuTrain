import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class SpeedometerPage extends StatefulWidget {
  const SpeedometerPage({super.key});

  @override
  State<SpeedometerPage> createState() => _SpeedometerPageState();
}

class _SpeedometerPageState extends State<SpeedometerPage> {
  // ── 核心数据 ──────────────────────────────────────────────────
  double _speedKmh = 0.0;
  double _maxSpeedKmh = 0.0;
  double _totalDistanceM = 0.0;
  double _avgSpeedKmh = 0.0;
  double _speedAccumulator = 0.0;
  int _speedSampleCount = 0;

  Position? _lastPosition;

  String _statusMsg = '点击开始测速';
  bool _isTracking = false;
  bool _hasPermission = false;

  StreamSubscription<Position>? _positionStream;
  Timer? _pollTimer;
  int _updateCount = 0;
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── 权限检查 ──────────────────────────────────────────────────
  Future<void> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _statusMsg = '请先开启设备定位服务');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _statusMsg = '位置权限被永久拒绝，请在系统设置中开启');
      return;
    }

    if (permission == LocationPermission.denied) {
      setState(() => _statusMsg = '需要位置权限才能测速');
      return;
    }

    setState(() {
      _hasPermission = true;
      _statusMsg = '点击开始测速';
    });
  }

  // ── 处理新位置数据 ────────────────────────────────────────────
  void _onPosition(Position position) {
    _updateCount++;
    final speedMs = position.speed < 0 ? 0.0 : position.speed;
    final speedKmh = speedMs * 3.6;

    // 计算移动距离
    double deltaDistance = 0.0;
    if (_lastPosition != null) {
      deltaDistance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      // 过滤 GPS 跳点：单次超 500m 忽略
      if (deltaDistance > 500) deltaDistance = 0;
    }
    _lastPosition = position;

    // 累计均速
    _speedSampleCount++;
    _speedAccumulator += speedKmh;
    final avg = _speedAccumulator / _speedSampleCount;

    setState(() {
      _speedKmh = speedKmh;
      _totalDistanceM += deltaDistance;
      _avgSpeedKmh = avg;
      _debugInfo = '更新#$_updateCount | ${speedMs.toStringAsFixed(2)} m/s';
      if (speedKmh > _maxSpeedKmh) _maxSpeedKmh = speedKmh;
      _statusMsg = '正在测速';
    });
  }

  // ── 开始追踪 ──────────────────────────────────────────────────
  void _startTracking() {
    setState(() {
      _isTracking = true;
      _statusMsg = '正在获取 GPS 信号…';
      _updateCount = 0;
      _debugInfo = '';
      _lastPosition = null;
      _totalDistanceM = 0.0;
      _avgSpeedKmh = 0.0;
      _maxSpeedKmh = 0.0;
      _speedAccumulator = 0.0;
      _speedSampleCount = 0;
    });

    LocationSettings locationSettings;
    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'GPS 速度计正在运行',
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
        setState(() => _statusMsg = 'Stream 失败，切换轮询…');
        _positionStream?.cancel();
        _startPollingFallback();
      },
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isTracking && _updateCount == 0) {
        setState(() => _statusMsg = 'Stream 无响应，切换轮询…');
        _positionStream?.cancel();
        _startPollingFallback();
      }
    });
  }

  // ── 备用轮询 ──────────────────────────────────────────────────
  void _startPollingFallback() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_isTracking) return;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            forceLocationManager: true,
          ),
        ).timeout(const Duration(seconds: 2));
        _onPosition(position);
      } catch (e) {
        if (mounted) setState(() => _debugInfo = '轮询错误: $e');
      }
    });
  }

  // ── 停止追踪 ──────────────────────────────────────────────────
  void _stopTracking() {
    _positionStream?.cancel();
    _pollTimer?.cancel();
    setState(() {
      _isTracking = false;
      _speedKmh = 0.0;
      _statusMsg = '已停止';
      _updateCount = 0;
    });
  }

  // ── UI ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS 速度计'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ── 当前速度 ──────────────────────────────────────
              Text(
                _speedKmh.toStringAsFixed(1),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 96,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'km/h',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _statusMsg,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (_debugInfo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _debugInfo,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                ),

              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 24),

              // ── 三项统计 ──────────────────────────────────────
              Row(
                children: [
                  _statCard(
                    context,
                    label: '最快时速',
                    value: _maxSpeedKmh.toStringAsFixed(1),
                    unit: 'km/h',
                    icon: Icons.speed,
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    context,
                    label: '移动距离',
                    value: _totalDistanceM < 1000
                        ? _totalDistanceM.toStringAsFixed(0)
                        : (_totalDistanceM / 1000).toStringAsFixed(2),
                    unit: _totalDistanceM < 1000 ? 'm' : 'km',
                    icon: Icons.route,
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    context,
                    label: '平均时速',
                    value: _avgSpeedKmh.toStringAsFixed(1),
                    unit: 'km/h',
                    icon: Icons.av_timer,
                  ),
                ],
              ),

              const Spacer(),

              // ── 按钮 ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: !_hasPermission
                      ? _checkPermission
                      : (_isTracking ? _stopTracking : _startTracking),
                  style: _isTracking
                      ? FilledButton.styleFrom(
                    backgroundColor: colorScheme.error,
                  )
                      : null,
                  child: Text(
                    !_hasPermission
                        ? '授权位置权限'
                        : (_isTracking ? '停止' : '开始'),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(
      BuildContext context, {
        required String label,
        required String value,
        required String unit,
        required IconData icon,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                unit,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
