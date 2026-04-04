// lib/ui/gps.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../speed_service.dart';

class SpeedometerPage extends StatefulWidget {
  const SpeedometerPage({super.key});

  @override
  State<SpeedometerPage> createState() => _SpeedometerPageState();
}

class _SpeedometerPageState extends State<SpeedometerPage> {
  @override
  void initState() {
    super.initState();
    // 进入页面时检查权限（如果 Service 还没有权限）
    final service = Provider.of<SpeedService>(context, listen: false);
    if (!service.hasPermission) {
      service.checkPermission();
    }
  }

  @override
  void dispose() {
    // ✅ 不取消 stream，Service 在后台继续运行
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<SpeedService>(
      builder: (context, service, _) {
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

                  // ── 当前速度 ──────────────────────────────────
                  Text(
                    service.speedKmh.toStringAsFixed(1),
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
                    service.statusMsg,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (service.debugInfo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        service.debugInfo,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                    ),

                  const SizedBox(height: 40),
                  const Divider(),
                  const SizedBox(height: 24),

                  // ── 三项统计 ──────────────────────────────────
                  Row(
                    children: [
                      _statCard(
                        context,
                        label: '最快时速',
                        value: service.maxSpeedKmh.toStringAsFixed(1),
                        unit: 'km/h',
                        icon: Icons.speed,
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        context,
                        label: '移动距离',
                        value: service.totalDistanceM < 1000
                            ? service.totalDistanceM.toStringAsFixed(0)
                            : (service.totalDistanceM / 1000).toStringAsFixed(2),
                        unit: service.totalDistanceM < 1000 ? 'm' : 'km',
                        icon: Icons.route,
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        context,
                        label: '平均时速',
                        value: service.avgSpeedKmh.toStringAsFixed(1),
                        unit: 'km/h',
                        icon: Icons.av_timer,
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ── 按钮 ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
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
      },
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
