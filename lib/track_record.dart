// lib/track_record.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'speed_service.dart';

/// 一次行程记录
class TrackRecord {
  final String id;           // 唯一ID（时间戳字符串）
  final DateTime startTime;
  final DateTime endTime;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final double totalDistanceM;
  final List<TrackPoint> points;

  const TrackRecord({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.totalDistanceM,
    required this.points,
  });

  // ── 序列化 ────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'maxSpeedKmh': maxSpeedKmh,
    'avgSpeedKmh': avgSpeedKmh,
    'totalDistanceM': totalDistanceM,
    'points': points
        .map((p) => {
      'lat': p.latitude,
      'lng': p.longitude,
      'spd': p.speedKmh,
    })
        .toList(),
  };

  factory TrackRecord.fromJson(Map<String, dynamic> json) => TrackRecord(
    id: json['id'] as String,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    maxSpeedKmh: (json['maxSpeedKmh'] as num).toDouble(),
    avgSpeedKmh: (json['avgSpeedKmh'] as num).toDouble(),
    totalDistanceM: (json['totalDistanceM'] as num).toDouble(),
    points: (json['points'] as List)
        .map((e) => TrackPoint(
      latitude: (e['lat'] as num).toDouble(),
      longitude: (e['lng'] as num).toDouble(),
      speedKmh: (e['spd'] as num).toDouble(),
    ))
        .toList(),
  );

  // ── 持久化工具 ────────────────────────────────────────────────
  static const _kIndexKey = 'track_record_index';

  /// 保存一条记录（仅距离 >= 100m 才保存）
  static Future<bool> save(TrackRecord record) async {
    if (record.totalDistanceM < 100) return false;

    final prefs = await SharedPreferences.getInstance();

    // 保存记录本体
    final key = 'track_record_${record.id}';
    await prefs.setString(key, jsonEncode(record.toJson()));

    // 更新索引
    final index = prefs.getStringList(_kIndexKey) ?? [];
    index.add(record.id);
    await prefs.setStringList(_kIndexKey, index);

    return true;
  }

  /// 读取所有记录（按时间倒序）
  static Future<List<TrackRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getStringList(_kIndexKey) ?? [];
    final records = <TrackRecord>[];

    for (final id in index.reversed) {
      final raw = prefs.getString('track_record_$id');
      if (raw != null) {
        try {
          records.add(TrackRecord.fromJson(jsonDecode(raw)));
        } catch (_) {}
      }
    }
    return records;
  }

  /// 删除一条记录
  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('track_record_$id');
    final index = prefs.getStringList(_kIndexKey) ?? [];
    index.remove(id);
    await prefs.setStringList(_kIndexKey, index);
  }
}
