// journey_detail_page.dart

import 'package:flutter/material.dart';

import 'journey_model.dart';
import 'ui/linemap.dart';

class JourneyDetailPage extends StatelessWidget {
  final Journey journey;

  const JourneyDetailPage({super.key, required this.journey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${journey.trainCode} 次列车详情'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: _JourneyDetailContent(journey: journey),
    );
  }
}

class _JourneyDetailContent extends StatefulWidget {
  final Journey journey;

  const _JourneyDetailContent({required this.journey});

  @override
  State<_JourneyDetailContent> createState() => __JourneyDetailContentState();
}

class __JourneyDetailContentState extends State<_JourneyDetailContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 以下方法从原 JourneyCard 复制，保持完全一致
  String _getJourneyStatus() {
    final journey = widget.journey;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final travelDay = DateTime(
      journey.travelDate.year,
      journey.travelDate.month,
      journey.travelDate.day,
    );

    if (travelDay.isBefore(today)) {
      return '已过期';
    }

    if (travelDay == today) {
      final departureTime = _parseTime(journey.departureTime);
      if (departureTime == null) return '今天';

      final actualDeparture = DateTime(
        journey.travelDate.year,
        journey.travelDate.month,
        journey.travelDate.day,
        departureTime.hour,
        departureTime.minute,
      );

      final arrivalTime = _parseTime(journey.arrivalTime);
      if (arrivalTime == null) return '今天';

      int dayOffset = 0;
      final totalDuration = journey.getTotalDuration();
      if (totalDuration.contains('跨')) {
        final match = RegExp(r'跨(\d+)天').firstMatch(totalDuration);
        if (match != null) {
          dayOffset = int.tryParse(match.group(1) ?? '0') ?? 0;
        }
      }

      final actualArrival = DateTime(
        journey.travelDate.year,
        journey.travelDate.month,
        journey.travelDate.day + dayOffset,
        arrivalTime.hour,
        arrivalTime.minute,
      );

      if (now.isAfter(actualArrival)) {
        return '已到达';
      } else if (now.isAfter(actualDeparture)) {
        return '已上车';
      } else {
        return '今天';
      }
    }

    final difference = travelDay.difference(today).inDays;
    if (difference == 1) {
      return '明天';
    } else if (difference == 2) {
      return '后天';
    } else if (difference > 0) {
      return '$difference天后';
    } else {
      return '今天';
    }
  }

  DateTime? _parseTime(String timeStr) {
    if (timeStr.isEmpty || timeStr == '--:--') return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return DateTime(2000, 1, 1, hour, minute);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '已过期':
      case '已到达':
        return Colors.red;
      case '已上车':
        return Colors.green;
      case '今天':
        return Colors.orange;
      case '明天':
      case '后天':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStationStatus(
    StationDetail station,
    Journey journey,
    bool isFrom,
    bool isTo,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final travelDay = DateTime(
      journey.travelDate.year,
      journey.travelDate.month,
      journey.travelDate.day,
    );

    if (travelDay.isBefore(today)) {
      return '已过';
    }

    if (travelDay == today) {
      final arrivalTime = _parseTime(station.arrivalTime);
      final departureTime = _parseTime(station.departureTime);

      if (arrivalTime != null && departureTime != null) {
        int dayOffset = station.dayDifference;
        final actualArrival = DateTime(
          journey.travelDate.year,
          journey.travelDate.month,
          journey.travelDate.day + dayOffset,
          arrivalTime.hour,
          arrivalTime.minute,
        );

        final actualDeparture = DateTime(
          journey.travelDate.year,
          journey.travelDate.month,
          journey.travelDate.day + dayOffset,
          departureTime.hour,
          departureTime.minute,
        );

        if (now.isAfter(actualDeparture)) {
          return '已过';
        } else if (now.isAfter(actualArrival)) {
          return station.stayTime > 0 ? '停站中' : '已到';
        } else {
          return '未到';
        }
      }
    }

    return '';
  }

  Color _getStationStatusColor(String status) {
    switch (status) {
      case '已过':
        return Colors.red;
      case '已到':
      case '停站中':
        return Colors.green;
      case '未到':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _normalizeStationName(String name) {
    return name.replaceAll('站', '').trim();
  }

  Widget _buildSeatInfoDisplay(Journey journey) {
    final Map<String, String> seatTypeNames = {
      'swz_num': '商务座',
      'zy_num': '一等座',
      'ze_num': '二等座',
      'gr_num': '高级软卧',
      'rw_num': '软卧',
      'yw_num': '硬卧',
      'rz_num': '软座',
      'yz_num': '硬座',
      'wz_num': '无座',
      'tz_num': '特等座',
      'gg_num': '优选一等座',
      'srrb_num': '动卧',
    };

    final seatType = journey.seatType;
    final seatInfo = journey.seatInfo;

    if (seatType.isEmpty) {
      return Text(
        '未选择座位',
        style: TextStyle(fontSize: 16, color: Theme.of(context).hintColor),
      );
    }

    final seatName = seatTypeNames[seatType] ?? '未知座位';
    String displayText = seatName;
    if (seatType != 'wz_num' && seatInfo.isNotEmpty) {
      displayText += ' $seatInfo';
    }

    return Text(
      displayText,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    );
  }

  int _getIntervalStationCount() {
    final journey = widget.journey;

    if (journey.fromStation == journey.toStation) {
      return journey.stations.length;
    }

    final fromIndex = journey.stations.indexWhere(
      (station) =>
          _normalizeStationName(station.stationName) ==
          _normalizeStationName(journey.fromStation),
    );
    final toIndex = journey.stations.indexWhere(
      (station) =>
          _normalizeStationName(station.stationName) ==
          _normalizeStationName(journey.toStation),
    );

    final startIndex = fromIndex >= 0 ? fromIndex : 0;
    final endIndex = toIndex >= 0 && toIndex >= startIndex
        ? toIndex
        : journey.stations.length - 1;

    return endIndex - startIndex + 1;
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDialogInfoRow(
    String label,
    String value, {
    bool isBoldRed = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: isBoldRed
                  ? const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final journey = widget.journey;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _getJourneyStatus();
    final statusColor = _getStatusColor(status);

    // 获取起始终到区间的站点索引
    final fromIndex = journey.stations.indexWhere(
      (station) =>
          _normalizeStationName(station.stationName) ==
          _normalizeStationName(journey.fromStation),
    );
    final toIndex = journey.stations.indexWhere(
      (station) =>
          _normalizeStationName(station.stationName) ==
          _normalizeStationName(journey.toStation),
    );

    final startIndex = fromIndex >= 0 ? fromIndex : 0;
    final endIndex = toIndex >= 0 && toIndex >= startIndex
        ? toIndex
        : journey.stations.length - 1;

    final intervalStations = (journey.fromStation == journey.toStation)
        ? journey.stations
        : journey.stations.sublist(startIndex, endIndex + 1);

    final baseDayDiff = startIndex >= 0 && startIndex < journey.stations.length
        ? journey.stations[startIndex].dayDifference
        : 0;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 行程状态信息
            _buildInfoSection('行程状态', Icons.access_time, [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Center(
                  child: Text(
                    '当前状态: $status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // 行程基本信息
            _buildInfoSection('行程信息', Icons.info_outline, [
              // 第一行：车次和时长
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '车次${journey.trainCode}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '时长${journey.getTotalDuration().replaceAll('\n', ' ')}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              ),

              // 第二行：始终站
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '始终站',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${journey.fromStation}站->${journey.toStation}站',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 第三行：乘车日期
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '乘车日期:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${journey.travelDate.year}-${journey.travelDate.month.toString().padLeft(2, '0')}-${journey.travelDate.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

              // 第四行：列车时间
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '列车时间',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${journey.departureTime}->${journey.arrivalTime}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // 第五行：座位信息
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '座位信息:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildSeatInfoDisplay(journey),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // 站点详情
            _buildInfoSection('站点详情', Icons.train, [
              Column(
                children: intervalStations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final station = entry.value;
                  final isFrom = station.stationName == journey.fromStation;
                  final isTo = station.stationName == journey.toStation;
                  final relativeDayDiff = station.dayDifference - baseDayDiff;
                  final stationStatus = _getStationStatus(
                    station,
                    journey,
                    isFrom,
                    isTo,
                  );
                  final stationStatusColor = _getStationStatusColor(
                    stationStatus,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isFrom || isTo
                            ? Colors.blue.shade300
                            : Colors.grey.shade300,
                        width: isFrom || isTo ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // 站点序号和状态
                        Column(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isFrom || isTo
                                    ? Colors.blue
                                    : Colors.grey.shade400,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (stationStatus.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: stationStatusColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  stationStatus,
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: stationStatusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 12),

                        // 站点信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${station.stationName}站',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isFrom || isTo
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isFrom || isTo
                                          ? Colors.blue.shade700
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    ),
                                  ),
                                  if (isFrom) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '上车站',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (isTo) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '下车站',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '到达: ${station.arrivalTime}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                  if (station.stayTime > 0)
                                    Text(
                                      '停站: ${station.stayTime}分',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).hintColor,
                                      ),
                                    ),
                                  Text(
                                    '发车: ${station.departureTime}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                ],
                              ),
                              if (relativeDayDiff > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '跨天: +$relativeDayDiff天',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ]),

            const SizedBox(height: 16),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showDetailDialog(context);
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('查看详情'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showRouteMapDialog(context);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('线路走向图'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRouteMapDialog(BuildContext context) {
    final journey = widget.journey;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: LineMapDialog(journey: journey),
        ),
      ),
    );
  }

  void _showDetailDialog(BuildContext context) {
    final journey = widget.journey;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${journey.trainCode} 次列车详情'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDialogInfoRow('车次', journey.trainCode),
                _buildDialogInfoRow(
                  '时长',
                  journey.getTotalDuration().replaceAll('\n', ' '),
                ),
                _buildDialogInfoRow(
                  '始终站',
                  '${journey.fromStation}站->${journey.toStation}站',
                ),
                _buildDialogInfoRow(
                  '乘车日期',
                  '${journey.travelDate.year}-${journey.travelDate.month.toString().padLeft(2, '0')}-${journey.travelDate.day.toString().padLeft(2, '0')}',
                  isBoldRed: true,
                ),
                _buildDialogInfoRow(
                  '列车时间',
                  '${journey.departureTime}->${journey.arrivalTime}',
                ),
                _buildDialogInfoRow(
                  '站点数量',
                  '区间${_getIntervalStationCount()}个 / 全程${journey.stations.length}个',
                ),
                _buildDialogInfoRow(
                  '添加方式',
                  journey.isStation ? '车站查询' : '车次查询',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
