// linemap.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../journey_model.dart';
import '../main.dart';

class LineMapDialog extends StatelessWidget {
  final Journey journey;

  const LineMapDialog({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Material(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: kToolbarHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${journey.trainCode}次列车走向图',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildRouteSummary(context, journey),
                        const SizedBox(height: 16),
                        Expanded(child: LineMapContent(journey: journey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteSummary(BuildContext context, Journey journey) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.train, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${journey.trainCode}次 • ${journey.fromStation} → ${journey.toStation}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '全程${journey.getTotalDuration()} • ${journey.stations.length}个站点',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
class LineMapContent extends StatefulWidget {
  final Journey journey;

  const LineMapContent({super.key, required this.journey});

  @override
  State<LineMapContent> createState() => _LineMapContentState();
}

class _LineMapContentState extends State<LineMapContent> {
  /// 停车站（用户行程中的站，带时间信息，isViaStation==false）
  List<Map<String, dynamic>> _filteredStations = [];

  /// 全路线所有站（含途径小站，isViaStation字段来自API原始值）
  List<Map<String, dynamic>> _fullRouteStations = [];

  bool _isLoading = true;
  String _errorMessage = '';
  int? _selectedStationIndex;
  final Map<int, bool> _stationLabelsVisible = {};

  final TransformationController _transformationController =
      TransformationController();
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadRouteMapData();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  // ==================== 跨天时间解析 ====================

  /// 将 "HH:mm" 解析为绝对 DateTime，以 [refBase] 为基准处理跨天。
  /// 若候选时间比 refBase 早超过2小时，认为已过午夜，自动加一天。
  static DateTime? _parseRelative(DateTime refBase, String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    var t = DateTime(refBase.year, refBase.month, refBase.day, h, m);
    if (t.isBefore(refBase.subtract(const Duration(hours: 2)))) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  /// 计算每个停车站的时间状态（与 _filteredStations 等长）。
  /// 返回值：'past' | 'current' | 'future'
  List<String> _computeStationStatuses() {
    final now = DateTime.now();
    final n = _filteredStations.length;
    if (n == 0) return [];

    // 找第一站时间作为初始基准
    DateTime refBase = now;
    for (final s in _filteredStations) {
      final raw = (s['departureTime'] ?? s['arrivalTime']) as String?;
      if (raw != null && raw.isNotEmpty) {
        final p = raw.split(':');
        if (p.length >= 2) {
          final h = int.tryParse(p[0]);
          final m = int.tryParse(p[1]);
          if (h != null && m != null) {
            refBase = DateTime(now.year, now.month, now.day, h, m);
            break;
          }
        }
      }
    }

    // 逐站累积解析绝对时间
    final List<DateTime?> deps = List.filled(n, null);
    final List<DateTime?> arrs = List.filled(n, null);
    DateTime prev = refBase;
    for (int i = 0; i < n; i++) {
      final s = _filteredStations[i];
      final arr = _parseRelative(prev, s['arrivalTime'] as String?);
      final dep = _parseRelative(arr ?? prev, s['departureTime'] as String?);
      arrs[i] = arr;
      deps[i] = dep;
      prev = dep ?? arr ?? prev;
    }

    // 确定每站状态
    final statuses = List<String>.filled(n, 'future');
    int lastPast = -1;
    for (int i = 0; i < n; i++) {
      final ref = deps[i] ?? arrs[i];
      if (ref != null && ref.isBefore(now)) {
        statuses[i] = 'past';
        lastPast = i;
      }
    }
    if (lastPast >= 0 &&
        lastPast + 1 < n &&
        statuses[lastPast + 1] == 'future') {
      statuses[lastPast + 1] = 'current';
    }

    return statuses;
  }

  // ==================== 数据加载 ====================

  Future<void> _loadRouteMapData() async {
    try {
      final fullFromApi = await _fetchStationsFromApi(
        widget.journey.trainCode,
      ).timeout(const Duration(seconds: 10));

      // 停车站：从全量API结果中筛选，注入 journey 时间信息
      final filtered = _filterApiStations(fullFromApi, widget.journey.stations);

      // 本地坐标匹配
      final fullWithLoc = await _matchStationsWithLocalData(fullFromApi);
      final filteredWithLoc = await _matchStationsWithLocalData(filtered);

      // 坐标归一化
      final positionedFull = _calcPositions(fullWithLoc, fullWithLoc);
      final positionedFiltered = _calcPositions(filteredWithLoc, fullWithLoc);

      setState(() {
        _fullRouteStations = positionedFull;
        _filteredStations = positionedFiltered;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hasAnomalousSegments().then((bad) {
          if (bad && mounted) _showAnomalyAlert();
        });
      });
    } catch (e) {
      // Fallback：直接用 journey.stations 均匀排列
      try {
        final fallback = _buildFallback();
        setState(() {
          _fullRouteStations = fallback;
          _filteredStations = fallback;
          _isLoading = false;
        });
      } catch (_) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _buildFallback() {
    final stations = widget.journey.stations;
    final n = stations.length;
    return List.generate(n, (i) {
      final s = stations[i];
      return {
        'stationName': s.stationName,
        'name': s.stationName,
        'isViaStation': false,
        'arrivalTime': s.arrivalTime,
        'departureTime': s.departureTime,
        'stationSequence': i + 1,
        'hasLocation': true,
        'city': '',
        'longitude': 0.0,
        'latitude': 0.0,
        'relativeX': n > 1 ? 0.1 + 0.8 * (i / (n - 1)) : 0.5,
        'relativeY': 0.5,
        'index': i,
      };
    });
  }

  // ==================== 异常检测 ====================

  Future<bool> _hasAnomalousSegments() async {
    final bool isReal = await _getSetting('show_real_train_map');
    if (!isReal) return false;
    for (int i = 1; i < _fullRouteStations.length; i++) {
      final a = _fullRouteStations[i - 1];
      final b = _fullRouteStations[i];
      if (a['hasLocation'] == true && b['hasLocation'] == true) {
        final dx =
            ((b['relativeX'] as double) - (a['relativeX'] as double)) * 100;
        final dy =
            ((b['relativeY'] as double) - (a['relativeY'] as double)) * 100;
        if (sqrt(dx * dx + dy * dy) > 30) return true;
      }
    }
    return false;
  }

  List<String> _getAnomalousSegmentInfo() {
    final List<String> res = [];
    for (int i = 1; i < _fullRouteStations.length; i++) {
      final a = _fullRouteStations[i - 1];
      final b = _fullRouteStations[i];
      if (a['hasLocation'] == true && b['hasLocation'] == true) {
        final dx =
            ((b['relativeX'] as double) - (a['relativeX'] as double)) * 100;
        final dy =
            ((b['relativeY'] as double) - (a['relativeY'] as double)) * 100;
        final len = sqrt(dx * dx + dy * dy);
        if (len > 30) {
          res.add('${a['name']} → ${b['name']}: ${len.toStringAsFixed(2)}单位');
        }
      }
    }
    return res;
  }

  void _showAnomalyAlert() {
    final anomalies = _getAnomalousSegmentInfo();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('走向图数据异常'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('检测到以下异常线段，可能影响显示效果：'),
              const SizedBox(height: 12),
              ...anomalies.map(
                (a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $a'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '请联系技术支持。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // ==================== 站点标记构建 ====================

  List<Widget> _buildStationMarkers(double cw, double ch) {
    final bool showVia = _currentScale > 1.8;
    final statuses = _computeStationStatuses();
    final List<Widget> markers = [];

    // ---- 途径小站（_fullRouteStations 中 isViaStation==true 的站） ----
    // 只在缩放超过阈值时显示，视觉大小固定。
    if (showVia) {
      for (final st in _fullRouteStations) {
        final isVia = st['isViaStation'] as bool? ?? false;
        if (!isVia) continue;
        final rx = st['relativeX'] as double?;
        final ry = st['relativeY'] as double?;
        if (rx == null || ry == null || st['hasLocation'] != true) continue;

        final double dotSize = 7.0 / _currentScale;
        final double px = rx * cw;
        final double py = ry * ch;

        markers.add(
          Positioned(
            left: px - dotSize / 2,
            top: py - dotSize / 2,
            child: IgnorePointer(
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: (0.8 / _currentScale).clamp(0.3, 1.2),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // ---- 停车站（_filteredStations，始终显示） ----
    for (int i = 0; i < _filteredStations.length; i++) {
      final st = _filteredStations[i];
      final rx = st['relativeX'] as double?;
      final ry = st['relativeY'] as double?;
      if (rx == null || ry == null || st['hasLocation'] != true) continue;

      final int index = (st['index'] as int?) ?? i;
      final double px = rx * cw;
      final double py = ry * ch;

      // 视觉圆点大小（恒定14px屏幕像素）
      final double dotSize = 14.0 / _currentScale;
      // 触控热区（恒定44px，更好点击）
      final double hitSize = 44.0 / _currentScale;

      final String status = i < statuses.length ? statuses[i] : 'future';
      final Color dotColor = switch (status) {
        'past' => Colors.orange,
        'current' => Colors.green,
        _ => Colors.blue.shade600,
      };

      markers.add(
        Positioned(
          left: px - hitSize / 2,
          top: py - hitSize / 2,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleLabel(index),
            child: SizedBox(
              width: hitSize,
              height: hitSize,
              child: Center(
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: (2.0 / _currentScale).clamp(0.5, 2.0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(80),
                        blurRadius: 3 / _currentScale,
                        offset: Offset(0, 1 / _currentScale),
                      ),
                    ],
                  ),
                  // 序号：仅当视觉圆点够大时渲染（避免溢出）
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        // 字号恒定约5px屏幕像素
                        fontSize: (5.0 / _currentScale).clamp(2.0, 5.5),
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  void _toggleLabel(int index) {
    setState(() {
      if (_selectedStationIndex == index) {
        _stationLabelsVisible.clear();
        _selectedStationIndex = null;
      } else {
        _stationLabelsVisible.clear();
        _stationLabelsVisible[index] = true;
        _selectedStationIndex = index;
      }
    });
  }

  // ==================== 标签构建 ====================

  List<Widget> _buildStationLabels(double cw, double ch) {
    final List<Widget> labels = [];
    for (final st in _filteredStations) {
      final index = (st['index'] as int?) ?? 0;
      if (!(_stationLabelsVisible[index] ?? false)) continue;

      final rx = st['relativeX'] as double?;
      final ry = st['relativeY'] as double?;
      if (rx == null || ry == null) continue;

      final double px = rx * cw;
      final double py = ry * ch;

      // 所有尺寸除以 scale，使标签在屏幕上保持固定视觉大小
      final double fs1 = 11.0 / _currentScale; // 站名字号
      final double fs2 = 9.0 / _currentScale; // 副文字字号
      final double padH = 8.0 / _currentScale;
      final double padV = 5.0 / _currentScale;
      final double radius = 6.0 / _currentScale;
      final double borderW = 1.0 / _currentScale;
      final double lw = 96.0 / _currentScale; // 估算标签宽
      final double lh = 52.0 / _currentScale; // 估算标签高
      final double mg = 8.0 / _currentScale;

      final Offset pos = _pickLabelPos(px, py, lw, lh, mg, cw, ch);

      final String name = (st['name'] as String?) ?? '';
      final bool hasLoc = st['hasLocation'] as bool? ?? false;
      final String city = (st['city'] as String?) ?? '';
      final String? arr = st['arrivalTime'] as String?;
      final String? dep = st['departureTime'] as String?;

      labels.add(
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onTap: () => _toggleLabel(index),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(242),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: Colors.grey.shade400, width: borderW),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 6 / _currentScale,
                    offset: Offset(0, 2 / _currentScale),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$name站',
                        style: TextStyle(
                          fontSize: fs1,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                      if (!hasLoc)
                        Padding(
                          padding: EdgeInsets.only(left: 2 / _currentScale),
                          child: Icon(
                            Icons.warning_amber,
                            size: 9 / _currentScale,
                            color: Colors.orange,
                          ),
                        ),
                    ],
                  ),
                  if (city.isNotEmpty)
                    Text(
                      '$city市',
                      style: TextStyle(
                        fontSize: fs2,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  if (arr != null || dep != null)
                    Text(
                      '${arr ?? ""} - ${dep ?? ""}',
                      style: TextStyle(
                        fontSize: fs2,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return labels;
  }

  Offset _pickLabelPos(
    double px,
    double py,
    double lw,
    double lh,
    double mg,
    double cw,
    double ch,
  ) {
    final candidates = [
      Offset(px + mg, py - lh / 2), // 右
      Offset(px - lw - mg, py - lh / 2), // 左
      Offset(px - lw / 2, py - lh - mg), // 上
      Offset(px - lw / 2, py + mg), // 下
    ];
    for (final p in candidates) {
      if (p.dx >= 0 && p.dx + lw <= cw && p.dy >= 0 && p.dy + lh <= ch) {
        return p;
      }
    }
    return Offset(
      (px + mg).clamp(0.0, cw - lw),
      (py - lh / 2).clamp(0.0, ch - lh),
    );
  }

  // ==================== 坐标计算 ====================

  /// 以 [refStations] 的经纬度范围为基准，把 [targetStations] 的经纬度映射到 [0,1] 坐标。
  List<Map<String, dynamic>> _calcPositions(
    List<Map<String, dynamic>> targetStations,
    List<Map<String, dynamic>> refStations,
  ) {
    if (targetStations.isEmpty) return [];

    final valid = refStations
        .where(
          (s) =>
              s['hasLocation'] == true &&
              ((s['longitude'] as num).toDouble() != 0 ||
                  (s['latitude'] as num).toDouble() != 0),
        )
        .toList();

    if (valid.isEmpty) return _evenPositions(targetStations);

    double minLng = double.infinity, maxLng = -double.infinity;
    double minLat = double.infinity, maxLat = -double.infinity;
    for (final s in valid) {
      final lng = (s['longitude'] as num).toDouble();
      final lat = (s['latitude'] as num).toDouble();
      minLng = min(minLng, lng);
      maxLng = max(maxLng, lng);
      minLat = min(minLat, lat);
      maxLat = max(maxLat, lat);
    }

    final lngR = maxLng - minLng;
    final latR = maxLat - minLat;
    if (lngR == 0 || latR == 0) return _evenPositions(targetStations);

    const ar = 1.8;
    double adjLng = lngR, adjLat = latR;
    if (lngR / latR > ar) {
      adjLat = lngR / ar;
    } else {
      adjLng = latR * ar;
    }
    final lcx = (minLng + maxLng) / 2;
    final lcy = (minLat + maxLat) / 2;
    final fMinLng = lcx - adjLng * 0.6;
    final fMaxLng = lcx + adjLng * 0.6;
    final fMinLat = lcy - adjLat * 0.6;
    final fMaxLat = lcy + adjLat * 0.6;
    final fLngR = fMaxLng - fMinLng;
    final fLatR = fMaxLat - fMinLat;

    return List.generate(targetStations.length, (i) {
      final st = targetStations[i];
      double x = 0.5, y = 0.5;
      if (st['hasLocation'] == true) {
        final lng = (st['longitude'] as num).toDouble();
        final lat = (st['latitude'] as num).toDouble();
        if (lng != 0 || lat != 0) {
          x = ((lng - fMinLng) / fLngR).clamp(0.0, 1.0);
          y = (1.0 - (lat - fMinLat) / fLatR).clamp(0.0, 1.0);
        }
      }
      return {...st, 'relativeX': x, 'relativeY': y, 'index': i};
    });
  }

  List<Map<String, dynamic>> _evenPositions(
    List<Map<String, dynamic>> stations,
  ) {
    final n = stations.length;
    return stations
        .asMap()
        .entries
        .map(
          (e) => {
            ...e.value,
            'relativeX': n > 1 ? 0.1 + 0.8 * (e.key / (n - 1)) : 0.5,
            'relativeY': 0.5,
            'index': e.key,
            'hasLocation': true,
          },
        )
        .toList();
  }

  // ==================== API / 数据处理 ====================

  /// 从 API 全量结果中筛选停车站，并注入 journey 的时间信息。
  List<Map<String, dynamic>> _filterApiStations(
    List<Map<String, dynamic>> apiStations,
    List<StationDetail> journeyStations,
  ) {
    final journeyNames = journeyStations
        .map((s) => s.stationName.replaceAll('站', '').trim())
        .toList();

    final filtered = apiStations.where((api) {
      final name =
          (api['stationName'] as String?)?.replaceAll('站', '').trim() ?? '';
      return journeyNames.contains(name);
    }).toList();

    filtered.sort((a, b) {
      final na =
          (a['stationName'] as String?)?.replaceAll('站', '').trim() ?? '';
      final nb =
          (b['stationName'] as String?)?.replaceAll('站', '').trim() ?? '';
      return journeyNames.indexOf(na).compareTo(journeyNames.indexOf(nb));
    });

    return filtered.map((s) {
      final name =
          (s['stationName'] as String?)?.replaceAll('站', '').trim() ?? '';
      final idx = journeyNames.indexOf(name);
      final js = idx >= 0 ? journeyStations[idx] : null;
      return {
        ...s,
        'isViaStation': false, // 筛出的都是停车站
        'arrivalTime': js?.arrivalTime ?? s['arrivalTime'],
        'departureTime': js?.departureTime ?? s['departureTime'],
      };
    }).toList();
  }

  Future<bool> _getSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  Future<List<Map<String, dynamic>>> _fetchStationsFromApi(
    String trainNumber,
  ) async {
    try {
      final bool real = await _getSetting('show_real_train_map');
      if (!real) return _createFallbackStationData();
      final url = Uri.parse(
        'https://rail.moefactory.com/api/trainDetails/queryTrainRoutes',
      );
      final response = await http.post(url, body: {'trainNumber': trainNumber});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (_) {}
    return _createFallbackStationData();
  }

  List<Map<String, dynamic>> _createFallbackStationData() {
    return List.generate(widget.journey.stations.length, (i) {
      final s = widget.journey.stations[i];
      return {
        'stationName': s.stationName,
        'railwayLineName': widget.journey.trainCode,
        'isViaStation': false,
        'arrivalTime': s.arrivalTime,
        'departureTime': s.departureTime,
        'stationSequence': i + 1,
      };
    });
  }

  Future<List<Map<String, dynamic>>> _matchStationsWithLocalData(
    List<Map<String, dynamic>> apiStations,
  ) async {
    try {
      final List<dynamic> all = await DataFileHelper.loadStations();

      return apiStations.map((api) {
        final clean = (api['stationName'] as String? ?? '')
            .replaceAll('站', '')
            .trim();
        final matched = all.cast<Map<String, dynamic>>().firstWhere(
          (s) =>
              (s['name'] as String? ?? '').replaceAll('站', '').trim() == clean,
          orElse: () => <String, dynamic>{},
        );

        if (matched.isNotEmpty) {
          final loc = matched['location']?.toString() ?? '';
          final coords = loc.split(',');
          final lng = coords.length == 2
              ? (double.tryParse(coords[0]) ?? 0.0)
              : 0.0;
          final lat = coords.length == 2
              ? (double.tryParse(coords[1]) ?? 0.0)
              : 0.0;
          return {
            ...api,
            'name': api['stationName'],
            'location': loc,
            'city': matched['city'] ?? '',
            'telecode': matched['telecode'] ?? '',
            'longitude': lng,
            'latitude': lat,
            'hasLocation':
                loc.isNotEmpty && coords.length == 2 && (lng != 0 || lat != 0),
          };
        } else {
          return {
            ...api,
            'name': api['stationName'],
            'location': null,
            'city': '',
            'telecode': '',
            'longitude': 0.0,
            'latitude': 0.0,
            'hasLocation': false,
          };
        }
      }).toList();
    } catch (_) {
      return apiStations
          .map(
            (s) => {
              ...s,
              'hasLocation': false,
              'longitude': 0.0,
              'latitude': 0.0,
            },
          )
          .toList();
    }
  }

  // ==================== UI ====================

  void _handleBackgroundTap() {
    setState(() {
      _stationLabelsVisible.clear();
      _selectedStationIndex = null;
    });
  }

  double _getRotationAngle(Matrix4 m) => atan2(m.storage[1], m.storage[0]);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载走向图...'),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRouteMapData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 440,
                  maxHeight: 440,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.8,
                    maxScale: 6.0,
                    boundaryMargin: const EdgeInsets.all(80),
                    panEnabled: true,
                    scaleEnabled: true,
                    onInteractionUpdate: (_) {
                      final matrix = _transformationController.value;
                      final scale = matrix.getMaxScaleOnAxis();
                      // 锁定旋转
                      if (_getRotationAngle(matrix).abs() > 0.001) {
                        final translation = matrix.getTranslation();
                        _transformationController.value = Matrix4.identity()
                          ..setEntry(0, 3, translation.x)  // 设置平移X
                          ..setEntry(1, 3, translation.y)  // 设置平移Y
                          ..scale(scale, scale, 1.0);  // 提供三个参数
                      }
                      setState(() {
                        _currentScale = _transformationController.value
                            .getMaxScaleOnAxis();
                      });
                    },
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final side = constraints.biggest.shortestSide;
                        final sz = Size(side, side);
                        final statuses = _computeStationStatuses();
                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: _handleBackgroundTap,
                              child: Container(
                                width: sz.width,
                                height: sz.height,
                                color: Colors.transparent,
                              ),
                            ),
                            // 全路线底线
                            CustomPaint(
                              size: sz,
                              painter: _FullRouteLinePainter(
                                _fullRouteStations,
                              ),
                            ),
                            // 彩色分段覆盖
                            CustomPaint(
                              size: sz,
                              painter: _SegmentedLinePainter(
                                filteredStations: _filteredStations,
                                fullRouteStations: _fullRouteStations,
                                statuses: statuses,
                              ),
                            ),
                            ..._buildStationMarkers(sz.width, sz.height),
                            ..._buildStationLabels(sz.width, sz.height),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Painter：全路线底线（蓝色，经过所有站含途径站）
// ============================================================
class _FullRouteLinePainter extends CustomPainter {
  final List<Map<String, dynamic>> stations;

  const _FullRouteLinePainter(this.stations);

  @override
  void paint(Canvas canvas, Size size) {
    final valid = stations.where((s) => s['hasLocation'] == true).toList();
    if (valid.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue.shade300
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(
      (valid.first['relativeX'] as double) * size.width,
      (valid.first['relativeY'] as double) * size.height,
    );
    for (int i = 1; i < valid.length; i++) {
      path.lineTo(
        (valid[i]['relativeX'] as double) * size.width,
        (valid[i]['relativeY'] as double) * size.height,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FullRouteLinePainter old) =>
      old.stations != stations;
}

// ============================================================
// Painter：按时间状态分段着色（沿全路线子路径，不直连停车站）
// ============================================================
class _SegmentedLinePainter extends CustomPainter {
  final List<Map<String, dynamic>> filteredStations;
  final List<Map<String, dynamic>> fullRouteStations;
  final List<String> statuses;

  const _SegmentedLinePainter({
    required this.filteredStations,
    required this.fullRouteStations,
    required this.statuses,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (filteredStations.length < 2) return;

    final fullValid = fullRouteStations
        .where((s) => s['hasLocation'] == true)
        .toList();
    if (fullValid.length < 2) return;

    // 建立站名→索引映射
    final Map<String, int> idx = {};
    for (int i = 0; i < fullValid.length; i++) {
      final name =
          ((fullValid[i]['name'] ?? fullValid[i]['stationName']) as String? ??
          '');
      if (name.isNotEmpty) idx[name] = i;
    }

    for (int fi = 1; fi < filteredStations.length; fi++) {
      final from = filteredStations[fi - 1];
      final to = filteredStations[fi];
      final ts = fi < statuses.length ? statuses[fi] : 'future';

      final Color color = switch (ts) {
        'past' => Colors.orange,
        'current' => Colors.green,
        _ => throw UnimplementedError(),
      };

      final fromName = ((from['name'] ?? from['stationName']) as String? ?? '');
      final toName = ((to['name'] ?? to['stationName']) as String? ?? '');
      final fi0 = idx[fromName];
      final ti0 = idx[toName];

      final paint = Paint()
        ..color = color
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (fi0 != null && ti0 != null && fi0 < ti0) {
        final path = Path();
        path.moveTo(
          (fullValid[fi0]['relativeX'] as double) * size.width,
          (fullValid[fi0]['relativeY'] as double) * size.height,
        );
        for (int k = fi0 + 1; k <= ti0; k++) {
          path.lineTo(
            (fullValid[k]['relativeX'] as double) * size.width,
            (fullValid[k]['relativeY'] as double) * size.height,
          );
        }
        canvas.drawPath(path, paint);
      } else if (from['hasLocation'] == true && to['hasLocation'] == true) {
        canvas.drawLine(
          Offset(
            (from['relativeX'] as double) * size.width,
            (from['relativeY'] as double) * size.height,
          ),
          Offset(
            (to['relativeX'] as double) * size.width,
            (to['relativeY'] as double) * size.height,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedLinePainter old) =>
      old.statuses != statuses ||
      old.filteredStations != filteredStations ||
      old.fullRouteStations != fullRouteStations;
}
