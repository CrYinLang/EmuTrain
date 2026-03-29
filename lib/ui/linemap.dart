// linemap.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import '../journey_model.dart';

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
            constraints: const BoxConstraints(
              maxWidth: 600,
              maxHeight: 700,
            ),
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
                // 内容区域
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

class LineMapContent extends StatefulWidget {
  final Journey journey;

  const LineMapContent({super.key, required this.journey});

  @override
  State<LineMapContent> createState() => _LineMapContentState();
}

class _LineMapContentState extends State<LineMapContent> {
  List<Map<String, dynamic>> _filteredStations = [];
  List<Map<String, dynamic>> _fullRouteStations = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int? _selectedStationIndex;
  final Map<int, bool> _stationLabelsVisible = {};

  @override
  void initState() {
    super.initState();
    _loadRouteMapData();
  }

  Future<bool> _hasAnomalousSegments() async {
    for (int i = 1; i < _fullRouteStations.length; i++) {
      final prevStation = _fullRouteStations[i - 1];
      final currentStation = _fullRouteStations[i];

      if (prevStation['hasLocation'] == true &&
          currentStation['hasLocation'] == true) {
        final dx = (currentStation['relativeX'] - prevStation['relativeX']) * 100;
        final dy = (currentStation['relativeY'] - prevStation['relativeY']) * 100;
        final segmentLength = sqrt(dx * dx + dy * dy);

        bool isEasy = await _getSetting('show_real_train_map');

        if (segmentLength > 30 && isEasy) {
          return true;
        }
      }
    }
    return false;
  }

  List<String> _getAnomalousSegmentInfo() {
    final List<String> anomalies = [];

    for (int i = 1; i < _fullRouteStations.length; i++) {
      final prevStation = _fullRouteStations[i - 1];
      final currentStation = _fullRouteStations[i];

      if (prevStation['hasLocation'] == true &&
          currentStation['hasLocation'] == true) {
        final dx = (currentStation['relativeX'] - prevStation['relativeX']) * 100;
        final dy = (currentStation['relativeY'] - prevStation['relativeY']) * 100;
        final segmentLength = sqrt(dx * dx + dy * dy);

        if (segmentLength > 30) {
          anomalies.add(
              '${prevStation['name']} → ${currentStation['name']}: '
                  '${segmentLength.toStringAsFixed(2)}单位'
          );
        }
      }
    }
    return anomalies;
  }

  Future<void> _loadRouteMapData() async {
    try {
      final fullStationsFromApi = await _fetchStationsFromApi(
        widget.journey.trainCode,
      ).timeout(const Duration(seconds: 10));

      final filteredStations = _filterApiStations(
        fullStationsFromApi,
        widget.journey.stations,
      );

      final fullRouteWithLocation = await _matchStationsWithLocalData(
        fullStationsFromApi,
      );

      final filteredWithLocation = await _matchStationsWithLocalData(
        filteredStations,
      );

      final positionedFullRoute = _calculateRelativePositions(
        fullRouteWithLocation,
      );
      final positionedFiltered = _calculatePositionsUsingFullRouteRange(
        filteredWithLocation,
        fullRouteWithLocation,
      );

      setState(() {
        _fullRouteStations = positionedFullRoute;
        _filteredStations = positionedFiltered;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hasAnomalousSegments().then((hasAnomaly) {
          if (hasAnomaly) {
            _showAnomalyAlert();
          }
        });
      });

    } catch (e) {
      try {
        final fallbackData = _createFallbackStationData();
        final filteredStations = _filterApiStations(
          fallbackData,
          widget.journey.stations,
        );

        final filteredWithLocation = await _matchStationsWithLocalData(
          filteredStations,
        );

        final positionedFiltered = _calculateEvenPositions(filteredWithLocation);

        setState(() {
          _fullRouteStations = positionedFiltered;
          _filteredStations = positionedFiltered;
          _isLoading = false;
          _errorMessage = '';
        });
      } catch (fallbackError) {
        setState(() {
          _errorMessage = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showAnomalyAlert() {
    final anomalies = _getAnomalousSegmentInfo();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
                ...anomalies.map((anomaly) =>
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• $anomaly'),
                    )
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _calculatePositionsUsingFullRouteRange(
    List<Map<String, dynamic>> targetStations,
    List<Map<String, dynamic>> fullRouteStations,
  ) {
    if (targetStations.isEmpty) return [];

    // 使用完整路线的有效站点来计算坐标范围
    final validFullStations = fullRouteStations
        .where((s) => s['hasLocation'] == true)
        .toList();

    if (validFullStations.isEmpty) {
      return _calculateEvenPositions(targetStations);
    }

    // 计算完整路线的坐标范围
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    double minLat = double.infinity;
    double maxLat = -double.infinity;

    for (final station in validFullStations) {
      final lng = station['longitude'] as double;
      final lat = station['latitude'] as double;

      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
    }

    final lngRange = maxLng - minLng;
    final latRange = maxLat - minLat;

    final targetAspectRatio = 1.8;
    final currentAspectRatio = lngRange / latRange;
    double adjustedLngRange = lngRange;
    double adjustedLatRange = latRange;

    if (currentAspectRatio > targetAspectRatio) {
      adjustedLatRange = lngRange / targetAspectRatio;
    } else {
      adjustedLngRange = latRange * targetAspectRatio;
    }

    final lngCenter = (minLng + maxLng) / 2;
    final latCenter = (minLat + maxLat) / 2;

    final adjustedMinLng = lngCenter - adjustedLngRange / 2;
    final adjustedMaxLng = lngCenter + adjustedLngRange / 2;
    final adjustedMinLat = latCenter - adjustedLatRange / 2;
    final adjustedMaxLat = latCenter + adjustedLatRange / 2;

    final lngMargin = adjustedLngRange * 0.1;
    final latMargin = adjustedLatRange * 0.1;

    final finalMinLng = adjustedMinLng - lngMargin;
    final finalMaxLng = adjustedMaxLng + lngMargin;
    final finalMinLat = adjustedMinLat - latMargin;
    final finalMaxLat = adjustedMaxLat + latMargin;

    final finalLngRange = finalMaxLng - finalMinLng;
    final finalLatRange = finalMaxLat - finalMinLat;

    final List<Map<String, dynamic>> positionedStations = [];
    for (int i = 0; i < targetStations.length; i++) {
      final station = targetStations[i];
      double x = 0.5;
      double y = 0.5;

      if (station['hasLocation'] == true) {
        final lng = station['longitude'] as double;
        final lat = station['latitude'] as double;

        if (finalLngRange > 0) {
          x = (lng - finalMinLng) / finalLngRange;
        }
        if (finalLatRange > 0) {
          y = 1.0 - (lat - finalMinLat) / finalLatRange;
        }

        x = x.clamp(0.0, 1.0);
        y = y.clamp(0.0, 1.0);
      } else {
        x = 0.5;
        y = i / (targetStations.length - 1);
      }

      positionedStations.add({
        ...station,
        'relativeX': x,
        'relativeY': y,
        'index': i,
      });
    }

    return positionedStations;
  }

  List<Map<String, dynamic>> _filterApiStations(
    List<Map<String, dynamic>> apiStations,
    List<StationDetail> journeyStations,
  ) {
    final journeyStationNames = journeyStations.map((station) {
      return station.stationName.replaceAll('站', '').trim();
    }).toList();

    final filtered = apiStations.where((apiStation) {
      final apiStationName =
          (apiStation['stationName'] as String?)?.replaceAll('站', '').trim() ??
          '';
      final isInJourney = journeyStationNames.contains(apiStationName);

      return isInJourney;
    }).toList();

    filtered.sort((a, b) {
      final aName =
          (a['stationName'] as String?)?.replaceAll('站', '').trim() ?? '';
      final bName =
          (b['stationName'] as String?)?.replaceAll('站', '').trim() ?? '';

      final aIndex = journeyStationNames.indexOf(aName);
      final bIndex = journeyStationNames.indexOf(bName);

      return aIndex.compareTo(bIndex);
    });

    return filtered;
  }

  Future<bool> _getSetting(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  Future<List<Map<String, dynamic>>> _fetchStationsFromApi(
      String trainNumber,
      ) async {
    try {
      bool real = await _getSetting('show_real_train_map');
      final url = Uri.parse(real
          ? 'https://rail.moefactory.com/api/trainDetails/queryTrainRoutes'
          : ''
      );

      final response = await http.post(url, body: {"trainNumber": trainNumber});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 200 && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else {
          return _createFallbackStationData();
        }
      } else {
        return _createFallbackStationData();
      }
    } catch (e) {
      return _createFallbackStationData();
    }
  }

  List<Map<String, dynamic>> _createFallbackStationData() {
    final List<Map<String, dynamic>> fallbackStations = [];

    for (int i = 0; i < widget.journey.stations.length; i++) {
      final station = widget.journey.stations[i];

      fallbackStations.add({
        'stationName': station.stationName,
        'railwayLineName': widget.journey.trainCode,
        'isViaStation': true,
        'arrivalTime': station.arrivalTime,
        'departureTime': station.departureTime,
        'stationSequence': i + 1,
      });
    }

    return fallbackStations;
  }

  Future<List<Map<String, dynamic>>> _matchStationsWithLocalData(List<Map<String, dynamic>> apiStations,) async {
    try {
      final jsonString = await rootBundle.loadString('assets/stations.json');
      final List<dynamic> allStations = json.decode(jsonString);

      final List<Map<String, dynamic>> matchedStations = [];

      for (final apiStation in apiStations) {
        final stationName = apiStation['stationName']?.toString() ?? '未知车站';
        final cleanName = stationName.replaceAll('站', '').trim();

        dynamic matched;
        try {
          matched = allStations.firstWhere((station) {
            final jsonName = station['name']?.toString() ?? '';
            final cleanJsonName = jsonName.replaceAll('站', '').trim();
            return cleanJsonName == cleanName;
          }, orElse: () => null);
        } catch (e) {
          matched = null;
        }

        if (matched != null) {
          final location = matched['location']?.toString() ?? '';
          final coords = location.split(',');
          double longitude = 0;
          double latitude = 0;

          if (coords.length == 2) {
            longitude = double.tryParse(coords[0]) ?? 0;
            latitude = double.tryParse(coords[1]) ?? 0;
          }

          matchedStations.add({
            'name': stationName,
            'location': location,
            'city': matched['city'] ?? '',
            'telecode': matched['telecode'] ?? '',
            'longitude': longitude,
            'latitude': latitude,
            'hasLocation': location.isNotEmpty && coords.length == 2,
            // 保留API数据
            'railwayLineName': apiStation['railwayLineName'] ?? '未知走向',
            'distance': apiStation['distance'] ?? 0,
            'isViaStation': apiStation['isViaStation'] ?? true,
            'arrivalTime': apiStation['arrivalTime'],
            'departureTime': apiStation['departureTime'],
          });
        } else {
          matchedStations.add({
            'name': stationName,
            'location': null,
            'city': '',
            'telecode': '',
            'longitude': 0,
            'latitude': 0,
            'hasLocation': false,
            // 保留API数据
            'railwayLineName': apiStation['railwayLineName'] ?? '未知走向',
            'distance': apiStation['distance'] ?? 0,
            'isViaStation': apiStation['isViaStation'] ?? true,
            'arrivalTime': apiStation['arrivalTime'],
            'departureTime': apiStation['departureTime'],
          });
        }
      }

      return matchedStations;
    } catch (e) {
      // 如果匹配失败，返回原始数据（无坐标）
      return apiStations
          .map(
            (station) => {
              ...station,
              'name': station['stationName'] ?? '未知车站',
              'location': null,
              'city': '',
              'telecode': '',
              'longitude': 0,
              'latitude': 0,
              'hasLocation': false,
            },
          )
          .toList();
    }
  }

  // 计算相对位置
  List<Map<String, dynamic>> _calculateRelativePositions(List<Map<String, dynamic>> stations) {
    if (stations.isEmpty) return [];
    final validStations = stations.where((s) => s['hasLocation'] == true).toList();

    if (validStations.isEmpty) {return _calculateEvenPositions(stations);}

    double minLng = double.infinity;
    double maxLng = -double.infinity;
    double minLat = double.infinity;
    double maxLat = -double.infinity;

    for (final station in validStations) {
      final lng = station['longitude'] as double;
      final lat = station['latitude'] as double;

      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
    }

    final lngRange = maxLng - minLng;
    final latRange = maxLat - minLat;

    final targetAspectRatio = 1.8;
    final currentAspectRatio = lngRange / latRange;
    double adjustedLngRange = lngRange;
    double adjustedLatRange = latRange;

    if (currentAspectRatio > targetAspectRatio) {
      adjustedLatRange = lngRange / targetAspectRatio;
    } else {
      adjustedLngRange = latRange * targetAspectRatio;
    }

    final lngCenter = (minLng + maxLng) / 2;
    final latCenter = (minLat + maxLat) / 2;

    final adjustedMinLng = lngCenter - adjustedLngRange / 2;
    final adjustedMaxLng = lngCenter + adjustedLngRange / 2;
    final adjustedMinLat = latCenter - adjustedLatRange / 2;
    final adjustedMaxLat = latCenter + adjustedLatRange / 2;

    final lngMargin = adjustedLngRange * 0.1;
    final latMargin = adjustedLatRange * 0.1;

    final finalMinLng = adjustedMinLng - lngMargin;
    final finalMaxLng = adjustedMaxLng + lngMargin;
    final finalMinLat = adjustedMinLat - latMargin;
    final finalMaxLat = adjustedMaxLat + latMargin;

    final finalLngRange = finalMaxLng - finalMinLng;
    final finalLatRange = finalMaxLat - finalMinLat;

    final List<Map<String, dynamic>> positionedStations = [];
    for (int i = 0; i < stations.length; i++) {
      final station = stations[i];
      double x = 0.5;
      double y = 0.5;

      if (station['hasLocation'] == true) {
        final lng = station['longitude'] as double;
        final lat = station['latitude'] as double;

        if (finalLngRange > 0) {
          x = (lng - finalMinLng) / finalLngRange;
        }
        if (finalLatRange > 0) {
          y = 1.0 - (lat - finalMinLat) / finalLatRange;
        }

        x = x.clamp(0.0, 1.0);
        y = y.clamp(0.0, 1.0);
      } else {
        x = 0.5;
        y = i / (stations.length - 1);
      }

      positionedStations.add({
        ...station,
        'relativeX': x,
        'relativeY': y,
        'index': i,
      });
    }

    return positionedStations;
  }

  // 均匀分布计算
  List<Map<String, dynamic>> _calculateEvenPositions(
    List<Map<String, dynamic>> stations,
  ) {
    return stations.asMap().entries.map((entry) {
      final i = entry.key;
      final station = entry.value;

      return {
        ...station,
        'relativeX': 0.1 + 0.8 * (i / (stations.length - 1)),
        'relativeY': 0.5,
        'index': i,
      };
    }).toList();
  }

  // 处理空白处点击
  void _handleBackgroundTap() {
    setState(() {
      // 隐藏所有标签
      _stationLabelsVisible.clear();
      _selectedStationIndex = null;
    });
  }

  // 自动管理标签显示
  void _autoManageLabels(
    int clickedIndex,
    double containerWidth,
    double containerHeight,
  ) {
    setState(() {
      // 如果点击的是当前已选中的站点，则隐藏标签
      if (_selectedStationIndex == clickedIndex) {
        _stationLabelsVisible.clear();
        _selectedStationIndex = null;
      } else {
        // 隐藏所有标签
        _stationLabelsVisible.clear();

        // 显示点击的站点标签
        _stationLabelsVisible[clickedIndex] = true;
        _selectedStationIndex = clickedIndex;

        // 检查附近站点，如果距离过近也显示
        for (int i = 0; i < _filteredStations.length; i++) {
          if (i != clickedIndex &&
              _isTooClose(i, clickedIndex, containerWidth, containerHeight)) {
            _stationLabelsVisible[i] = true;
          }
        }
      }
    });
  }

  // 检查两个站点是否距离过近
  bool _isTooClose(
    int index1,
    int index2,
    double containerWidth,
    double containerHeight,
  ) {
    final station1 = _filteredStations[index1];
    final station2 = _filteredStations[index2];

    final x1 = (station1['relativeX'] as double) * containerWidth;
    final y1 = (station1['relativeY'] as double) * containerHeight;
    final x2 = (station2['relativeX'] as double) * containerWidth;
    final y2 = (station2['relativeY'] as double) * containerHeight;

    final distance = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));

    // 根据标签大小调整距离阈值
    return distance < 10;
  }

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
                  maxWidth: 400,
                  maxHeight: 400,
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
                child: GestureDetector(
                  onTap: _handleBackgroundTap,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest.shortestSide;
                      final squareSize = Size(size, size);

                      return Stack(
                        children: [
                          // 透明背景层捕获点击事件
                          Container(
                            width: squareSize.width,
                            height: squareSize.height,
                            color: Colors.transparent,
                          ),

                          // 绘制完整路线连线（背景）
                          CustomPaint(
                            size: squareSize,
                            painter: _FullRouteLinePainter(_fullRouteStations),
                          ),
                          ..._buildStationMarkers(
                            squareSize.width,
                            squareSize.height,
                          ),
                          ..._buildStationLabels(
                            squareSize.width,
                            squareSize.height,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStationMarkers(
    double containerWidth,
    double containerHeight,
  ) {
    return _filteredStations.map((station) {
      final x = station['relativeX'] as double;
      final y = station['relativeY'] as double;
      final index = station['index'] as int;
      final isViaStation = station['isViaStation'] as bool? ?? true;

      final pixelX = x * containerWidth;
      final pixelY = y * containerHeight;

      return Positioned(
        left: pixelX - 8,
        top: pixelY - 8,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              _autoManageLabels(index, containerWidth, containerHeight),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isViaStation ? Colors.blue : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(77),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildStationLabels(
    double containerWidth,
    double containerHeight,
  ) {
    return _filteredStations.map((station) {
      final x = station['relativeX'] as double;
      final y = station['relativeY'] as double;
      final index = station['index'] as int;
      final name = station['name'] as String;
      final hasLocation = station['hasLocation'] as bool? ?? false;
      final city = station['city'] as String;
      final arrivalTime = station['arrivalTime'];
      final departureTime = station['departureTime'];
      final isViaStation = station['isViaStation'] as bool? ?? true;

      // 只显示被选中的标签或距离过近的标签
      final isVisible = _stationLabelsVisible[index] ?? false;
      if (!isVisible) {
        return const SizedBox.shrink();
      }

      final pixelX = x * containerWidth;
      final pixelY = y * containerHeight;

      // 智能计算标签位置
      final labelPosition = _calculateLabelPosition(
        index,
        pixelX,
        pixelY,
        containerWidth,
        containerHeight,
      );

      return Positioned(
        left: labelPosition.dx,
        top: labelPosition.dy,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _autoManageLabels(index, containerWidth, containerHeight);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(100),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
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
                        fontSize: 10,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!hasLocation) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.warning_amber,
                        size: 8,
                        color: Colors.orange,
                      ),
                    ],
                  ],
                ),
                if (city.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$city市',
                    style: const TextStyle(fontSize: 8, color: Colors.black),
                  ),
                ],
                if (arrivalTime != null || departureTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${arrivalTime ?? ''} - ${departureTime ?? ''}',
                    style: const TextStyle(fontSize: 8, color: Colors.black),
                  ),
                ],
                if (!isViaStation) ...[
                  const SizedBox(height: 2),
                  const Text(
                    '经停站',
                    style: TextStyle(fontSize: 8, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  // 计算标签位置
  Offset _calculateLabelPosition(
    int index,
    double pixelX,
    double pixelY,
    double containerWidth,
    double containerHeight,
  ) {
    const labelWidth = 80.0;
    const labelHeight = 40.0;
    const margin = 8.0;

    // 定义位置优先级：右 > 左 > 上 > 下
    final List<Offset> positions = [
      // 右侧
      Offset(pixelX + margin, pixelY - labelHeight / 2),
      // 左侧
      Offset(pixelX - labelWidth - margin, pixelY - labelHeight / 2),
      // 上方
      Offset(pixelX - labelWidth / 2, pixelY - labelHeight - margin),
      // 下方
      Offset(pixelX - labelWidth / 2, pixelY + margin),
    ];

    // 按优先级检查位置是否合适
    for (final position in positions) {
      if (position.dx >= 0 &&
          position.dx + labelWidth <= containerWidth &&
          position.dy >= 0 &&
          position.dy + labelHeight <= containerHeight) {
        return position;
      }
    }

    // 如果所有位置都不合适，强制显示在右侧，但调整到边界内
    double x = pixelX + margin;
    double y = pixelY - labelHeight / 2;

    // 确保在边界内
    x = x.clamp(margin, containerWidth - labelWidth - margin);
    y = y.clamp(margin, containerHeight - labelHeight - margin);

    return Offset(x, y);
  }
}

// 完整路线连线绘制器（蓝色线条）
class _FullRouteLinePainter extends CustomPainter {
  final List<Map<String, dynamic>> stations;

  _FullRouteLinePainter(this.stations);

  @override
  void paint(Canvas canvas, Size size) {
    final validStations = stations
        .where((s) => s['hasLocation'] == true)
        .toList();
    if (validStations.length < 2) return;

    final paint = Paint()
      ..color = Colors.blue.shade600
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    final firstStation = validStations.first;
    final startX = (firstStation['relativeX'] as double) * size.width;
    final startY = (firstStation['relativeY'] as double) * size.height;
    path.moveTo(startX, startY);

    for (int i = 1; i < validStations.length; i++) {
      final station = validStations[i];
      final x = (station['relativeX'] as double) * size.width;
      final y = (station['relativeY'] as double) * size.height;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}