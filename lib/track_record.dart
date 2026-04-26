// lib/track_record.dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'speed_service.dart';

/// 一次行程记录
class TrackRecord {
  final String id; // 时间戳字符串，同时作为文件夹名
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

  /// 摘要信息，写入 meta.json（不含 points）
  Map<String, dynamic> toMetaJson() => {
    'id': id,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'maxSpeedKmh': maxSpeedKmh,
    'avgSpeedKmh': avgSpeedKmh,
    'totalDistanceM': totalDistanceM,
  };

  /// 轨迹点列表，写入 points.json
  List<Map<String, dynamic>> toPointsJson() => points
      .map((p) => {'lat': p.latitude, 'lng': p.longitude, 'spd': p.speedKmh})
      .toList();

  factory TrackRecord.fromJson({
    required Map<String, dynamic> meta,
    required List<dynamic> pointsList,
  }) => TrackRecord(
    id: meta['id'] as String,
    startTime: DateTime.parse(meta['startTime'] as String),
    endTime: DateTime.parse(meta['endTime'] as String),
    maxSpeedKmh: (meta['maxSpeedKmh'] as num).toDouble(),
    avgSpeedKmh: (meta['avgSpeedKmh'] as num).toDouble(),
    totalDistanceM: (meta['totalDistanceM'] as num).toDouble(),
    points: pointsList
        .map(
          (e) => TrackPoint(
            latitude: (e['lat'] as num).toDouble(),
            longitude: (e['lng'] as num).toDouble(),
            speedKmh: (e['spd'] as num).toDouble(),
          ),
        )
        .toList(),
  );

  /// 只从 meta.json 构建，points 为空列表（用于列表页轻量加载）
  factory TrackRecord.fromMetaOnly(Map<String, dynamic> meta) => TrackRecord(
    id: meta['id'] as String,
    startTime: DateTime.parse(meta['startTime'] as String),
    endTime: DateTime.parse(meta['endTime'] as String),
    maxSpeedKmh: (meta['maxSpeedKmh'] as num).toDouble(),
    avgSpeedKmh: (meta['avgSpeedKmh'] as num).toDouble(),
    totalDistanceM: (meta['totalDistanceM'] as num).toDouble(),
    points: const [],
  );

  // ── 路径工具 ──────────────────────────────────────────────────

  /// tracks 根目录
  static Future<Directory> _tracksDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/tracks');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 某条记录的子目录（不保证存在）
  static Future<Directory> _recordDir(String id) async {
    final root = await _tracksDir();
    return Directory('${root.path}/$id');
  }

  // ── 持久化接口 ────────────────────────────────────────────────

  /// 保存一条记录（距离 < 100m 时跳过，返回 false）
  static Future<bool> save(TrackRecord record) async {
    if (record.totalDistanceM < 100) return false;

    final dir = await _recordDir(record.id);
    await dir.create(recursive: true);

    await File(
      '${dir.path}/meta.json',
    ).writeAsString(jsonEncode(record.toMetaJson()));
    await File(
      '${dir.path}/points.json',
    ).writeAsString(jsonEncode(record.toPointsJson()));

    return true;
  }

  /// 读取所有记录的摘要，按时间倒序（不加载轨迹点，适合列表页）
  static Future<List<TrackRecord>> loadAllMeta() async {
    final root = await _tracksDir();
    final entries = root.listSync().whereType<Directory>().toList();

    // 文件夹名即时间戳，直接倒序排
    entries.sort((a, b) => b.path.compareTo(a.path));

    final records = <TrackRecord>[];
    for (final dir in entries) {
      final metaFile = File('${dir.path}/meta.json');
      if (!await metaFile.exists()) continue;
      try {
        final meta = jsonDecode(await metaFile.readAsString());
        records.add(TrackRecord.fromMetaOnly(meta as Map<String, dynamic>));
      } catch (_) {}
    }
    return records;
  }

  /// 读取单条完整记录（含轨迹点），用于详情页 / 地图展示
  static Future<TrackRecord?> loadFull(String id) async {
    final dir = await _recordDir(id);
    final metaFile = File('${dir.path}/meta.json');
    final pointsFile = File('${dir.path}/points.json');

    if (!await metaFile.exists() || !await pointsFile.exists()) return null;
    try {
      final meta =
          jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      final points = jsonDecode(await pointsFile.readAsString()) as List;
      return TrackRecord.fromJson(meta: meta, pointsList: points);
    } catch (_) {
      return null;
    }
  }

  /// 删除一条记录（整个子目录）
  static Future<void> delete(String id) async {
    final dir = await _recordDir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// 删除全部记录
  static Future<void> deleteAll() async {
    final root = await _tracksDir();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
