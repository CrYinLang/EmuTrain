// lib/ui/gps.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../speed_service.dart';

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
  // 折叠 ≈ 1/3，展开 ≈ 全屏（0.8）
  static const double _collapsedRatio = 1 / 3;
  static const double _expandedRatio = 0.8;
  static const double _snapThreshold = 0.5; // 超过此比例判定为展开

  double _panelRatio = _collapsedRatio;
  double _dragStartRatio = _collapsedRatio;
  bool _isExpanded = false;

  late AnimationController _snapController;
  late Animation<double> _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _snapAnimation = _snapController.drive(CurveTween(curve: Curves.easeOutCubic));

    final service = Provider.of<SpeedService>(context, listen: false);
    if (!service.hasPermission) service.checkPermission();
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  // ── 拖拽处理 ──────────────────────────────────────────────────
  void _onDragStart(DragStartDetails _) {
    _snapController.stop();
    _dragStartRatio = _panelRatio;
  }

  void _onDragUpdate(DragUpdateDetails details, double availableHeight) {
    final delta = -details.delta.dy / availableHeight;
    setState(() {
      _panelRatio = (_panelRatio + delta)
          .clamp(_collapsedRatio - 0.05, _expandedRatio + 0.05);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    bool shouldExpand;

    if (velocity < -400) {
      shouldExpand = true; // 快速上滑 → 展开
    } else if (velocity > 400) {
      shouldExpand = false; // 快速下滑 → 折叠
    } else {
      shouldExpand = _panelRatio > _snapThreshold;
    }

    final startRatio = _panelRatio;
    final endRatio = shouldExpand ? _expandedRatio : _collapsedRatio;

    _snapAnimation = Tween<double>(begin: startRatio, end: endRatio)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_snapController);

    _snapController
      ..reset()
      ..forward();

    _snapAnimation.addListener(() {
      setState(() => _panelRatio = _snapAnimation.value);
    });

    setState(() => _isExpanded = shouldExpand);
  }

  // ── 返回拦截 ──────────────────────────────────────────────────
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

  // ── Build ─────────────────────────────────────────────────────
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
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: '设置',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _SpeedometerSettingsPage(),
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
                    // ── 地图层 ──────────────────────────────────
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: mapH,
                      child: _TrackMapView(service: service),
                    ),

                    // ── 速度仪面板 ──────────────────────────────
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
//  轨迹地图视图
// ══════════════════════════════════════════════════════════════════
class _TrackMapView extends StatelessWidget {
  final SpeedService service;
  const _TrackMapView({required this.service});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF1A1F2E) : const Color(0xFFE8EDF5),
      child: service.trackPoints.length < 2
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
              service.isTracking ? '等待 GPS 信号…' : '开始测速后显示轨迹',
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            ),
          ],
        ),
      )
          : CustomPaint(
        painter: _TrackPainter(
          points: service.trackPoints,
          trackColor: colorScheme.primary,
          isDark: isDark,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  轨迹 Painter
// ══════════════════════════════════════════════════════════════════
class _TrackPainter extends CustomPainter {
  final List<TrackPoint> points;
  final Color trackColor;
  final bool isDark;

  _TrackPainter({
    required this.points,
    required this.trackColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // 计算经纬度边界，留 10% 内边距
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();

    // 防止单点或极短距离时除零
    final effectiveLat = latSpan < 1e-7 ? 1e-7 : latSpan;
    final effectiveLng = lngSpan < 1e-7 ? 1e-7 : lngSpan;

    const padding = 0.1; // 10% 内边距
    final drawW = size.width * (1 - padding * 2);
    final drawH = size.height * (1 - padding * 2);
    final offsetX = size.width * padding;
    final offsetY = size.height * padding;

    // 保持纵横比（以纬度为基准，经度需要按纬度余弦修正）
    final latCos = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final scaleX = drawW / (effectiveLng * latCos);
    final scaleY = drawH / effectiveLat;
    final scale = math.min(scaleX, scaleY);
    final usedW = effectiveLng * latCos * scale;
    final usedH = effectiveLat * scale;
    final centerOffX = offsetX + (drawW - usedW) / 2;
    final centerOffY = offsetY + (drawH - usedH) / 2;

    Offset toCanvas(TrackPoint p) {
      final x = centerOffX + (p.longitude - minLng) * latCos * scale;
      // 纬度越大越靠上，y 轴反向
      final y = centerOffY + (maxLat - p.latitude) * scale;
      return Offset(x, y);
    }

    // 画轨迹发光底（稍宽、半透明）
    final glowPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.25)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(toCanvas(points.first).dx, toCanvas(points.first).dy);
    for (int i = 1; i < points.length; i++) {
      final o = toCanvas(points[i]);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, glowPaint);

    // 画主轨迹线
    final linePaint = Paint()
      ..color = trackColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);

    // 画起点小圆（空心圆）
    final startPt = toCanvas(points.first);
    canvas.drawCircle(
      startPt,
      5,
      Paint()
        ..color = trackColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      startPt,
      5,
      Paint()
        ..color = trackColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // 画当前位置实心圆（稍大、带白边）
    final endPt = toCanvas(points.last);
    canvas.drawCircle(
      endPt,
      7,
      Paint()
        ..color = isDark ? Colors.white : Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      endPt,
      5,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.points.length != points.length;
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
          // ── 拖拽把手 ──────────────────────────────────────────
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

          // ── 面板内容 ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    // 当前速度
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

                    // 三项统计
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
                              : (service.totalDistanceM / 1000)
                              .toStringAsFixed(2),
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

                    // 按钮
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
//  速度计设置页（暂无内容）
// ══════════════════════════════════════════════════════════════════
class _SpeedometerSettingsPage extends StatelessWidget {
  const _SpeedometerSettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('速度计设置'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          '暂无设置项',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
