// lib/ui/gps.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../settings_model.dart';
import '../speed_service.dart';
import '../track_record.dart';

// ══════════════════════════════════════════════════════════════════
//  SpeedometerPage
// ══════════════════════════════════════════════════════════════════
class SpeedometerPage extends StatefulWidget {
  const SpeedometerPage({super.key});

  @override
  State<SpeedometerPage> createState() => _SpeedometerPageState();
}

class _SpeedometerPageState extends State<SpeedometerPage>
    with SingleTickerProviderStateMixin {
  static const double _collapsedRatio = 1 / 3;
  static const double _expandedRatio = 0.8;
  static const double _snapThreshold = 0.5;

  double _panelRatio = _collapsedRatio;
  double _dragStartRatio = _collapsedRatio;
  bool _isExpanded = true;

  late AnimationController _snapController;
  late Animation<double> _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _snapAnimation = _snapController.drive(
      CurveTween(curve: Curves.easeOutCubic),
    );

    final service = Provider.of<SpeedService>(context, listen: false);
    if (!service.hasPermission) service.checkPermission();
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    _snapController.stop();
    _dragStartRatio = _panelRatio;
  }

  void _onDragUpdate(DragUpdateDetails details, double availableHeight) {
    final delta = -details.delta.dy / availableHeight;
    setState(() {
      _panelRatio = (_panelRatio + delta).clamp(
        _collapsedRatio - 0.05,
        _expandedRatio + 0.05,
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    bool shouldExpand;

    if (velocity < -400) {
      shouldExpand = true;
    } else if (velocity > 400) {
      shouldExpand = false;
    } else {
      shouldExpand = _panelRatio > _snapThreshold;
    }

    final startRatio = _panelRatio;
    final endRatio = shouldExpand ? _expandedRatio : _collapsedRatio;

    _snapAnimation = Tween<double>(
      begin: startRatio,
      end: endRatio,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_snapController);

    _snapController
      ..reset()
      ..forward();

    _snapAnimation.addListener(() {
      setState(() => _panelRatio = _snapAnimation.value);
    });

    setState(() => _isExpanded = shouldExpand);
  }

  Future<bool> _onWillPop(SpeedService service) async {
    if (!service.isTracking) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('后台继续记录'),
        content: const Text('离开页面后，速度计将在后台继续记录数据，返回后可查看完整记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('留在页面'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('后台运行'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SpeedService>(
      builder: (context, service, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final shouldPop = await _onWillPop(service);
            if (shouldPop && context.mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('GPS 速度计'),
              centerTitle: true,
              actions: [
                // ── 历史记录按钮 ──────────────────────────────
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: '历史记录',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TrackHistoryPage()),
                  ),
                ),
                // ── 设置按钮 ──────────────────────────────────
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: '设置',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SpeedometerSettingsPage(),
                    ),
                  ),
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final availH = constraints.maxHeight;
                final panelH = availH * _panelRatio;
                final mapH = availH - panelH;

                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: mapH,
                      child: _TrackMapView(service: service),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: panelH,
                      child: _SpeedometerPanel(
                        service: service,
                        isExpanded: _isExpanded,
                        onDragStart: _onDragStart,
                        onDragUpdate: (d) => _onDragUpdate(d, availH),
                        onDragEnd: _onDragEnd,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  轨迹地图视图（支持双指缩放 / 旋转 / 单指平移 / 双击复位）
// ══════════════════════════════════════════════════════════════════
class _TrackMapView extends StatefulWidget {
  final SpeedService service;

  const _TrackMapView({required this.service});

  @override
  State<_TrackMapView> createState() => _TrackMapViewState();
}

class _TrackMapViewState extends State<_TrackMapView> {
  // 变换状态
  double _scale = 1.0;
  double _rotation = 0.0; // 弧度
  Offset _offset = Offset.zero;

  // 手势起始快照
  double _startScale = 1.0;
  double _startRotation = 0.0;
  Offset _startOffset = Offset.zero;
  Offset _focalPointStart = Offset.zero;

  // 是否处于自动追踪模式（新轨迹点进来时自动重置视图）
  bool _autoFollow = true;
  int _lastPointCount = 0;

  @override
  void didUpdateWidget(_TrackMapView old) {
    super.didUpdateWidget(old);
    final newCount = widget.service.trackPoints.length;
    // 有新轨迹点且用户没有手动操作过，保持自动适配
    if (_autoFollow && newCount != _lastPointCount) {
      _lastPointCount = newCount;
      // 让 painter 重绘即可，视图始终自适应
    }
  }

  void _resetView() {
    setState(() {
      _scale = 1.0;
      _rotation = 0.0;
      _offset = Offset.zero;
      _autoFollow = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF1A1F2E) : const Color(0xFFE8EDF5),
      child: widget.service.trackPoints.length < 2
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 48,
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.service.isTracking ? '等待 GPS 信号…' : '开始测速后显示轨迹',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.35),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // ── 手势层 ──────────────────────────────────────
                GestureDetector(
                  // 双击复位
                  onDoubleTap: _resetView,
                  // 双指缩放 + 旋转
                  onScaleStart: (details) {
                    _startScale = _scale;
                    _startRotation = _rotation;
                    _startOffset = _offset;
                    _focalPointStart = details.focalPoint;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      _autoFollow = false;
                      _scale = (_startScale * details.scale).clamp(0.2, 20.0);
                      _rotation = _startRotation + details.rotation;
                      // 平移：跟随焦点移动
                      final focalDelta = details.focalPoint - _focalPointStart;
                      _offset = _startOffset + focalDelta;
                    });
                  },
                  child: CustomPaint(
                    painter: _TrackPainter(
                      points: widget.service.trackPoints,
                      trackColor: colorScheme.primary,
                      isDark: isDark,
                      scale: _autoFollow ? 1.0 : _scale,
                      rotation: _autoFollow ? 0.0 : _rotation,
                      offset: _autoFollow ? Offset.zero : _offset,
                      autoFit: _autoFollow,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),

                // ── 复位按钮（手动操作后显示）──────────────────
                if (!_autoFollow)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _resetView,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.my_location,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  轨迹 Painter（支持变换矩阵）
// ══════════════════════════════════════════════════════════════════
class _TrackPainter extends CustomPainter {
  final List<TrackPoint> points;
  final Color trackColor;
  final bool isDark;
  final double scale;
  final double rotation;
  final Offset offset;
  final bool autoFit; // true = 忽略变换，自动适配窗口

  _TrackPainter({
    required this.points,
    required this.trackColor,
    required this.isDark,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.offset = Offset.zero,
    this.autoFit = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // 计算轨迹包围盒
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    if (latRange == 0 && lngRange == 0) return;

    const padding = 24.0;
    final drawW = size.width - padding * 2;
    final drawH = size.height - padding * 2;

    // 基础坐标转换（自适应模式下铺满画布）
    Offset toBase(TrackPoint p) {
      final x = lngRange == 0
          ? size.width / 2
          : padding + (p.longitude - minLng) / lngRange * drawW;
      final y = latRange == 0
          ? size.height / 2
          : padding + (1 - (p.latitude - minLat) / latRange) * drawH;
      return Offset(x, y);
    }

    // 应用变换矩阵（缩放 + 旋转 + 平移，以画布中心为原点）
    Offset transform(Offset base) {
      if (autoFit) return base;
      final center = Offset(size.width / 2, size.height / 2);
      final translated = base - center;
      final cosA = math.cos(rotation);
      final sinA = math.sin(rotation);
      final rotated = Offset(
        translated.dx * cosA - translated.dy * sinA,
        translated.dx * sinA + translated.dy * cosA,
      );
      return center + rotated * scale + offset;
    }

    canvas.save();

    // 轨迹线
    final linePaint = Paint()
      ..color = trackColor.withValues(alpha: 0.85)
      ..strokeWidth = autoFit
          ? 3.0
          : (3.0 / math.max(scale, 0.5)).clamp(1.0, 6.0)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final firstPt = transform(toBase(points.first));
    path.moveTo(firstPt.dx, firstPt.dy);
    for (final p in points.skip(1)) {
      final o = transform(toBase(p));
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, linePaint);

    // 起点（绿色圆）
    canvas.drawCircle(
      transform(toBase(points.first)),
      6,
      Paint()..color = Colors.green,
    );

    // 终点（红色圆）
    canvas.drawCircle(
      transform(toBase(points.last)),
      6,
      Paint()..color = Colors.red,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.points.length != points.length ||
      old.trackColor != trackColor ||
      old.scale != scale ||
      old.rotation != rotation ||
      old.offset != offset ||
      old.autoFit != autoFit;
}

// ══════════════════════════════════════════════════════════════════
//  速度仪面板（可拖拽）
// ══════════════════════════════════════════════════════════════════
class _SpeedometerPanel extends StatelessWidget {
  final SpeedService service;
  final bool isExpanded;
  final void Function(DragStartDetails) onDragStart;
  final void Function(DragUpdateDetails) onDragUpdate;
  final void Function(DragEndDetails) onDragEnd;

  const _SpeedometerPanel({
    required this.service,
    required this.isExpanded,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141218) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: onDragStart,
            onVerticalDragUpdate: onDragUpdate,
            onVerticalDragEnd: onDragEnd,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    Text(
                      service.speedKmh.toStringAsFixed(1),
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'km/h',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      service.statusMsg,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (service.debugInfo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          service.debugInfo,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _statCard(
                          context,
                          label: '最快时速',
                          value: service.maxSpeedKmh.toStringAsFixed(1),
                          unit: 'km/h',
                          icon: Icons.speed,
                        ),
                        const SizedBox(width: 10),
                        _statCard(
                          context,
                          label: '移动距离',
                          value: service.totalDistanceM < 1000
                              ? service.totalDistanceM.toStringAsFixed(0)
                              : (service.totalDistanceM / 1000).toStringAsFixed(
                                  2,
                                ),
                          unit: service.totalDistanceM < 1000 ? 'm' : 'km',
                          icon: Icons.route,
                        ),
                        const SizedBox(width: 10),
                        _statCard(
                          context,
                          label: '平均时速',
                          value: service.avgSpeedKmh.toStringAsFixed(1),
                          unit: 'km/h',
                          icon: Icons.av_timer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: !service.hasPermission
                            ? service.checkPermission
                            : (service.isTracking
                                  ? service.stopTracking
                                  : service.startTracking),
                        style: service.isTracking
                            ? FilledButton.styleFrom(
                                backgroundColor: colorScheme.error,
                              )
                            : null,
                        child: Text(
                          !service.hasPermission
                              ? '授权位置权限'
                              : (service.isTracking ? '停止' : '开始'),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
          child: Column(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
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
              const SizedBox(height: 2),
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

// ══════════════════════════════════════════════════════════════════
//  设置页面
// ══════════════════════════════════════════════════════════════════
class SpeedometerSettingsPage extends StatefulWidget {
  const SpeedometerSettingsPage({super.key});

  @override
  State<SpeedometerSettingsPage> createState() =>
      _SpeedometerSettingsPageState();
}

class _SpeedometerSettingsPageState extends State<SpeedometerSettingsPage> {
  @override
  void initState() {
    super.initState();
    // ✅ 打开设置页时从 SharedPreferences 加载最新值，确保显示正确
    SettingsModel().load();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: SettingsModel(),
      child: Consumer<SettingsModel>(
        builder: (context, settings, _) {
          return Scaffold(
            appBar: AppBar(title: const Text('速度计设置'), centerTitle: true),
            body: ListView(
              children: [
                // ── 分组：定位模式 ────────────────────────────
                _SectionHeader(title: '定位模式'),
                SwitchListTile(
                  title: const Text('强制使用 LocationManager'),
                  subtitle: const Text(
                    '关闭（推荐）：使用 Google Fused Location Provider，精度高、省电\n'
                    '开启：使用旧版 LocationManager，适合部分模拟位置场景',
                  ),
                  value: settings.forceLocationManager,
                  onChanged: (v) => settings.setForceLocationManager(v),
                  secondary: Icon(
                    settings.forceLocationManager
                        ? Icons.location_searching
                        : Icons.my_location,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),

                // ── 分组：轮询频率 ────────────────────────────
                _SectionHeader(title: '定位频率'),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '查询间隔：${_formatInterval(settings.pollIntervalSeconds)}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '值越小定位越频繁，但耗电更快。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Slider(
                        value: settings.pollIntervalSeconds,
                        min: 0.1,
                        max: 5.0,
                        divisions: 49,
                        // 步长 0.1
                        label: _formatInterval(settings.pollIntervalSeconds),
                        onChanged: (v) => settings.setPollIntervalSeconds(v),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '0.1 秒（最快）',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            '5.0 秒（省电）',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),

                // ── 分组：存储说明 ────────────────────────────
                _SectionHeader(title: '行程记录'),
                ListTile(
                  leading: const Icon(Icons.save_outlined),
                  title: const Text('自动保存规则'),
                  subtitle: const Text('停止后若移动距离 ≥ 100 m，自动保存本次行程记录。'),
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('查看历史记录'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TrackHistoryPage()),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatInterval(double s) {
    if (s < 1.0) return '${(s * 1000).round()} ms';
    return '${s.toStringAsFixed(s == s.roundToDouble() ? 0 : 1)} 秒';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  历史记录页
// ══════════════════════════════════════════════════════════════════
class TrackHistoryPage extends StatefulWidget {
  const TrackHistoryPage({super.key});

  @override
  State<TrackHistoryPage> createState() => _TrackHistoryPageState();
}

class _TrackHistoryPageState extends State<TrackHistoryPage> {
  List<TrackRecord>? _records;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await TrackRecord.loadAll();
    if (mounted) setState(() => _records = records);
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条行程记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await TrackRecord.delete(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('历史记录'), centerTitle: true),
      body: _records == null
          ? const Center(child: CircularProgressIndicator())
          : _records!.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history,
                    size: 56,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '暂无记录',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '移动距离 ≥ 100m 的行程会在停止后自动保存',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _records!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final r = _records![index];
                return _RecordCard(
                  record: r,
                  onDelete: () => _delete(r.id),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TrackDetailPage(record: r),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  记录卡片
// ══════════════════════════════════════════════════════════════════
class _RecordCard extends StatelessWidget {
  final TrackRecord record;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _RecordCard({
    required this.record,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final duration = record.endTime.difference(record.startTime);
    final distStr = record.totalDistanceM < 1000
        ? '${record.totalDistanceM.toStringAsFixed(0)} m'
        : '${(record.totalDistanceM / 1000).toStringAsFixed(2)} km';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 时间 + 删除按钮
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(record.startTime),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(duration),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: colorScheme.error.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 三项统计
              Row(
                children: [
                  _miniStat(context, Icons.straighten, distStr, '距离'),
                  _miniStat(
                    context,
                    Icons.speed,
                    '${record.maxSpeedKmh.toStringAsFixed(1)} km/h',
                    '最高速',
                  ),
                  _miniStat(
                    context,
                    Icons.av_timer,
                    '${record.avgSpeedKmh.toStringAsFixed(1)} km/h',
                    '平均速',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} '
        '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

// ══════════════════════════════════════════════════════════════════
//  行程详情页（轨迹回放）
// ══════════════════════════════════════════════════════════════════
class TrackDetailPage extends StatelessWidget {
  final TrackRecord record;

  const TrackDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final duration = record.endTime.difference(record.startTime);
    final distStr = record.totalDistanceM < 1000
        ? '${record.totalDistanceM.toStringAsFixed(0)} m'
        : '${(record.totalDistanceM / 1000).toStringAsFixed(2)} km';

    return Scaffold(
      appBar: AppBar(
        title: Text(_formatDate(record.startTime)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── 轨迹地图（支持手势）──────────────────────────────
          Expanded(child: _TrackDetailMapView(points: record.points)),

          // ── 数据卡片 ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141218) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 时间段
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatTime(record.startTime)} → ${_formatTime(record.endTime)}  （${_formatDuration(duration)}）',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 四项数据
                Row(
                  children: [
                    _detailStat(context, distStr, '移动距离', Icons.straighten),
                    _detailStat(
                      context,
                      '${record.maxSpeedKmh.toStringAsFixed(1)}\nkm/h',
                      '最高速',
                      Icons.speed,
                    ),
                    _detailStat(
                      context,
                      '${record.avgSpeedKmh.toStringAsFixed(1)}\nkm/h',
                      '平均速',
                      Icons.av_timer,
                    ),
                    _detailStat(
                      context,
                      '${record.points.length}',
                      'GPS点数',
                      Icons.location_on_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailStat(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.year}-${_p(dt.month)}-${_p(dt.day)}';

  String _formatTime(DateTime dt) => '${_p(dt.hour)}:${_p(dt.minute)}';

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}

// ══════════════════════════════════════════════════════════════════
//  历史轨迹地图（支持双指缩放 / 旋转 / 平移 / 双击复位）
// ══════════════════════════════════════════════════════════════════
class _TrackDetailMapView extends StatefulWidget {
  final List<TrackPoint> points;

  const _TrackDetailMapView({required this.points});

  @override
  State<_TrackDetailMapView> createState() => _TrackDetailMapViewState();
}

class _TrackDetailMapViewState extends State<_TrackDetailMapView> {
  double _scale = 1.0;
  double _rotation = 0.0;
  Offset _offset = Offset.zero;

  double _startScale = 1.0;
  double _startRotation = 0.0;
  Offset _startOffset = Offset.zero;
  Offset _focalPointStart = Offset.zero;
  bool _transformed = false;

  void _reset() => setState(() {
    _scale = 1.0;
    _rotation = 0.0;
    _offset = Offset.zero;
    _transformed = false;
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF1A1F2E) : const Color(0xFFE8EDF5),
      child: widget.points.length < 2
          ? const Center(child: Text('轨迹点不足，无法绘制'))
          : Stack(
              children: [
                GestureDetector(
                  onDoubleTap: _reset,
                  onScaleStart: (d) {
                    _startScale = _scale;
                    _startRotation = _rotation;
                    _startOffset = _offset;
                    _focalPointStart = d.focalPoint;
                  },
                  onScaleUpdate: (d) {
                    setState(() {
                      _transformed = true;
                      _scale = (_startScale * d.scale).clamp(0.2, 20.0);
                      _rotation = _startRotation + d.rotation;
                      _offset =
                          _startOffset + (d.focalPoint - _focalPointStart);
                    });
                  },
                  child: CustomPaint(
                    painter: _TrackPainter(
                      points: widget.points,
                      trackColor: colorScheme.primary,
                      isDark: isDark,
                      scale: _transformed ? _scale : 1.0,
                      rotation: _transformed ? _rotation : 0.0,
                      offset: _transformed ? _offset : Offset.zero,
                      autoFit: !_transformed,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                if (_transformed)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _reset,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.my_location,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
