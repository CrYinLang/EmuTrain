import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────
// 数据模型
// ─────────────────────────────────────────────

class TicketData {
  String redId;
  String id;
  String startStation;
  String endStation;
  String checkGate;
  String ticketOffice;
  String trainNumber;
  double price;
  DateTime date;
  String time;
  String seatType;
  String berth;
  String seatCarriage;
  String seatNumber;
  String passengerName;
  String passengerId;
  String qrCodeId;
  bool isChild;
  bool isStudent;
  bool isDiscount;
  bool isRefund;
  bool isNet;

  TicketData({
    this.redId = '01X073561',
    this.id = '21077000060721X073561',
    this.checkGate = '1',
    this.ticketOffice = '武昌',
    this.startStation = '东方红',
    this.endStation = '卫星',
    this.trainNumber = '6224',
    this.price = 11.5,
    DateTime? date,
    this.time = '06:50',
    this.seatType = '新空调硬座',
    this.berth = '',
    this.seatCarriage = '01',
    this.seatNumber = '058',
    this.passengerName = '冷藏箱',
    this.passengerId = '330100200501011234',
    this.qrCodeId = 'https://github.com/BI7AQU/train-ticket-generator',
    this.isChild = false,
    this.isStudent = false,
    this.isDiscount = true,
    this.isRefund = false,
    this.isNet = true,
  }) : date = date ?? DateTime(2025, 7, 23);

  TicketData copyWith({
    String? redId, String? id, String? startStation, String? endStation,
    String? checkGate, String? ticketOffice, String? trainNumber,
    double? price, DateTime? date, String? time, String? seatType,
    String? berth, String? seatCarriage, String? seatNumber,
    String? passengerName, String? passengerId, String? qrCodeId,
    bool? isChild, bool? isStudent, bool? isDiscount, bool? isRefund, bool? isNet,
  }) => TicketData(
    redId: redId ?? this.redId, id: id ?? this.id,
    startStation: startStation ?? this.startStation,
    endStation: endStation ?? this.endStation,
    checkGate: checkGate ?? this.checkGate,
    ticketOffice: ticketOffice ?? this.ticketOffice,
    trainNumber: trainNumber ?? this.trainNumber,
    price: price ?? this.price, date: date ?? this.date,
    time: time ?? this.time, seatType: seatType ?? this.seatType,
    berth: berth ?? this.berth, seatCarriage: seatCarriage ?? this.seatCarriage,
    seatNumber: seatNumber ?? this.seatNumber,
    passengerName: passengerName ?? this.passengerName,
    passengerId: passengerId ?? this.passengerId,
    qrCodeId: qrCodeId ?? this.qrCodeId,
    isChild: isChild ?? this.isChild, isStudent: isStudent ?? this.isStudent,
    isDiscount: isDiscount ?? this.isDiscount, isRefund: isRefund ?? this.isRefund,
    isNet: isNet ?? this.isNet,
  );

  String get maskedId {
    if (passengerId.length < 14) return passengerId;
    return '${passengerId.substring(0, 10)}****${passengerId.substring(14)}';
  }

  String get formattedYear => date.year.toString();
  String get formattedMonth => date.month.toString().padLeft(2, '0');
  String get formattedDay => date.day.toString().padLeft(2, '0');
  String get paddedCarriage => seatCarriage.padLeft(2, '0');
  String get paddedSeatNumber => seatNumber.padLeft(3, '0');
}

// ─────────────────────────────────────────────
// 红票绘制器（报销凭证）
// ─────────────────────────────────────────────

class RedReceiptPainter extends CustomPainter {
  final TicketData ticketInfo;
  final ui.Image? backgroundImage;
  final ui.Image? qrImage;

  RedReceiptPainter({required this.ticketInfo, this.backgroundImage, this.qrImage});

  static const double canvasW = 900;
  static const double canvasH = 600;
  static const double leftOffset = 75;
  static const double topOffset = 50;

  final _rng = Random(42);

  void _drawText(Canvas canvas, String text, double x, double y,
      {TextStyle? style, double spacing = 0, Color color = Colors.black}) {
    double curX = x;
    for (int i = 0; i < text.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: text[i],
          style: (style ?? const TextStyle()).copyWith(
            color: color.withValues(alpha:0.75 + _rng.nextDouble() * 0.25),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(curX, y - (style?.fontSize ?? 14)));
      curX += tp.width + spacing;
    }
  }

  double _tw(String text, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    return tp.width;
  }

  double _stationSpacing(String s) {
    if (s.length >= 4) return -6;
    if (s.length == 3) return 10;
    return 65;
  }

  void _dashedRect(Canvas canvas, Paint paint, double x, double y, double w, double h) {
    const dash = 16.0, gap = 4.0;
    void line(Offset a, Offset b) {
      final dx = b.dx - a.dx, dy = b.dy - a.dy;
      final len = sqrt(dx * dx + dy * dy);
      final ux = dx / len, uy = dy / len;
      double d = 0; bool draw = true;
      while (d < len) {
        final s = draw ? dash : gap;
        final d2 = (d + s).clamp(0, len);
        if (draw) canvas.drawLine(Offset(a.dx + ux * d, a.dy + uy * d), Offset(a.dx + ux * d2, a.dy + uy * d2), paint);
        d += s; draw = !draw;
      }
    }
    line(Offset(x, y), Offset(x + w, y));
    line(Offset(x + w, y), Offset(x + w, y + h));
    line(Offset(x + w, y + h), Offset(x, y + h));
    line(Offset(x, y + h), Offset(x, y));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / canvasW, size.height / canvasH);
    canvas.drawRect(Rect.fromLTWH(0, 0, canvasW, canvasH), Paint()..color = Colors.white);
    if (backgroundImage != null) {
      canvas.drawImageRect(
        backgroundImage!,
        Rect.fromLTWH(0, 0, backgroundImage!.width.toDouble(), backgroundImage!.height.toDouble()),
        Rect.fromLTWH(0, 0, canvasW, canvasH),
        Paint()..filterQuality = FilterQuality.high,
      );
    }
    _drawDetails(canvas);
    canvas.restore();
  }

  void _drawDetails(Canvas canvas) {
    final sRed = TextStyle(fontFamily: 'Calibri', fontSize: 44, color: Colors.red.withValues(alpha:0.5), fontWeight: FontWeight.bold);
    final sSS34 = const TextStyle(fontFamily: 'SimSun', fontSize: 34);
    final sSH50 = const TextStyle(fontFamily: 'SimHei', fontSize: 50);
    final sFS34 = const TextStyle(fontFamily: 'FangSong', fontSize: 34);
    final sBx34 = const TextStyle(fontFamily: 'BxpzRegular', fontSize: 34);
    final sSS24 = const TextStyle(fontFamily: 'SimSun', fontSize: 24);
    final sSS32 = const TextStyle(fontFamily: 'SimSun', fontSize: 32);
    final sSS38 = const TextStyle(fontFamily: 'SimSun', fontSize: 38);
    final sSS28 = const TextStyle(fontFamily: 'SimSun', fontSize: 28);
    final sBx28 = const TextStyle(fontFamily: 'BxpzRegular', fontSize: 28);
    final sBx32 = const TextStyle(fontFamily: 'BxpzRegular', fontSize: 32);
    final sFS32 = const TextStyle(fontFamily: 'FangSong', fontSize: 32);
    final sTNR44 = const TextStyle(fontFamily: 'Times New Roman', fontSize: 44);
    final sTNR36 = const TextStyle(fontFamily: 'Times New Roman', fontSize: 36);

    // 票号
    _drawText(canvas, ticketInfo.redId, 80, 95, style: sRed, color: Colors.red.withValues(alpha:0.5));

    // 检票口
    if (ticketInfo.checkGate.isNotEmpty) {
      final t = '检票:${ticketInfo.checkGate}';
      _drawText(canvas, t, canvasW - _tw(t, sSS34) - 100, 85, style: sSS34);
    }

    // 站名
    final ss = ticketInfo.startStation, es = ticketInfo.endStation;
    _drawText(canvas, ss, ss.length == 5 ? 50 : 95, topOffset + 90, style: sSH50, spacing: _stationSpacing(ss));
    _drawText(canvas, es, es.length == 5 ? canvasW / 2 + 80 : canvasW / 2 + 120, topOffset + 90, style: sSH50, spacing: _stationSpacing(es));

    // 拼音
    String sp = PinyinHelper.getPinyin(ss, separator: '', format: PinyinFormat.WITHOUT_TONE);
    String ep = PinyinHelper.getPinyin(es, separator: '', format: PinyinFormat.WITHOUT_TONE);
    if (sp.isNotEmpty) sp = sp[0].toUpperCase() + sp.substring(1);
    if (ep.isNotEmpty) ep = ep[0].toUpperCase() + ep.substring(1);
    _drawText(canvas, sp, 200 - _tw(sp, sFS34) / 2, topOffset + 130, style: sFS34, spacing: -1);
    _drawText(canvas, ep, canvasW / 2 + 220 - _tw(ep, sFS34) / 2, topOffset + 130, style: sFS34, spacing: -1);

    // 车次
    final tnW = _tw(ticketInfo.trainNumber, sTNR44) + 2.0 * ticketInfo.trainNumber.length;
    _drawText(canvas, ticketInfo.trainNumber, canvasW / 2 - tnW / 2, topOffset + 92, style: sTNR44, spacing: 2);

    // 箭头
    final ap = Paint()..color = Colors.black..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawPath(Path()
      ..moveTo(canvasW / 2 - 63, topOffset + 105)
      ..lineTo(canvasW / 2 + 63, topOffset + 105)
      ..lineTo(canvasW / 2 + 48, topOffset + 100), ap);

    // 站字
    _drawText(canvas, '站', 275, topOffset + 85, style: sSS34);
    _drawText(canvas, '站', canvasW - 145, topOffset + 85, style: sSS34);

    // 日期时间
    _drawText(canvas, ticketInfo.formattedYear, leftOffset - 2, topOffset + 177, style: sBx34, spacing: -2);
    _drawText(canvas, ticketInfo.formattedMonth, leftOffset + 112, topOffset + 177, style: sBx34, spacing: -2);
    _drawText(canvas, ticketInfo.formattedDay, leftOffset + 181, topOffset + 177, style: sBx34, spacing: -2);
    _drawText(canvas, ticketInfo.time, leftOffset + 253, topOffset + 177, style: sBx34, spacing: -2);
    _drawText(canvas, '年', leftOffset + 83, topOffset + 175, style: sSS24);
    _drawText(canvas, '月', leftOffset + 156, topOffset + 175, style: sSS24);
    _drawText(canvas, '日', leftOffset + 223, topOffset + 175, style: sSS24);
    _drawText(canvas, '开', leftOffset + 357, topOffset + 175, style: sSS24);
    _drawText(canvas, '车', leftOffset + 523, topOffset + 175, style: sSS24);

    // 车厢
    _drawText(canvas, ticketInfo.paddedCarriage, canvasW / 2 + 107, topOffset + 177, style: sBx34, spacing: -2);

    // 座位
    final sn = ticketInfo.paddedSeatNumber;
    if (sn == '000') {
      _drawText(canvas, '无座', canvasW / 2 + 175, topOffset + 180,
          style: const TextStyle(fontFamily: 'SimSun', fontSize: 34, fontWeight: FontWeight.bold));
    } else {
      final last = sn[sn.length - 1];
      if (RegExp(r'[a-zA-Z]').hasMatch(last)) {
        final num = sn.substring(0, sn.length - 1);
        _drawText(canvas, num, canvasW / 2 + 175, topOffset + 177, style: sBx34, spacing: -3);
        _drawText(canvas, last, canvasW / 2 + 175 + _tw(num, sBx34), topOffset + 178, style: sTNR36, spacing: -3);
        _drawText(canvas, '号', leftOffset + 613, topOffset + 175, style: sSS24);
      } else if (ticketInfo.berth.isNotEmpty) {
        _drawText(canvas, sn, canvasW / 2 + 177, topOffset + 177, style: sBx34, spacing: -3);
        _drawText(canvas, '号${ticketInfo.berth}', canvasW / 2 + 177 + 60, topOffset + 180, style: sSS34, spacing: -3);
      } else {
        _drawText(canvas, sn, canvasW / 2 + 175, topOffset + 177, style: sBx34, spacing: -3);
        _drawText(canvas, '号', leftOffset + 613, topOffset + 175, style: sSS24);
      }
    }

    // 席别
    _drawText(canvas, ticketInfo.seatType, 650 - _tw(ticketInfo.seatType, sSS32) / 2, topOffset + 225, style: sSS32);

    // 票价
    _drawText(canvas, '￥', leftOffset + 7, topOffset + 226, style: sBx28);
    final price = ticketInfo.price.toStringAsFixed(1);
    final priceW = _tw(price, sBx34);
    _drawText(canvas, price, leftOffset + 38, topOffset + 227, style: sBx34, spacing: -2);
    _drawText(canvas, '元', leftOffset + 35 + priceW, topOffset + 225,
        style: const TextStyle(fontFamily: 'FangSong', fontSize: 24));

    if (ticketInfo.isStudent) _drawText(canvas, '学', canvasW / 2 - _tw('学', sSS34) - 45, topOffset + 225, style: sSS34);
    if (ticketInfo.isChild) _drawText(canvas, '孩', canvasW / 2 - _tw('孩', sSS34) - 45, topOffset + 225, style: sSS34);
    if (ticketInfo.isDiscount) _drawText(canvas, '折', canvasW / 2 - _tw('折', sSS34) + 5, topOffset + 225, style: sSS34);

    _drawText(canvas, '仅供报销使用', leftOffset, 365, style: sSS34);
    _drawText(canvas, '仅供纪念使用', 340, 325, style: sSS34);
    if (ticketInfo.isRefund) _drawText(canvas, '退票费', leftOffset, 323, style: sSS34);

    // 身份证 + 姓名
    final id = ticketInfo.maskedId;
    final idW = _tw(id, sBx32);
    _drawText(canvas, id, leftOffset, 405, style: sBx32, spacing: -3);
    _drawText(canvas, ticketInfo.passengerName, leftOffset + idW + 10 - 53, 408, style: sSS38);

    // 虚线框
    const dW = 500.0, dH = 80.0, dL = 95.0;
    _dashedRect(canvas, Paint()..color = Colors.black..strokeWidth = 1..style = PaintingStyle.stroke, dL, 425, dW, dH);
    final t1 = '报销凭证 遗失不补';
    _drawText(canvas, t1, dL + dW / 2 - _tw(t1, sSS28) / 2, 455, style: sSS28);
    final t2 = '退票改签时须交回车站';
    _drawText(canvas, t2, dL + dW / 2 - _tw(t2, sSS28) / 2, 493, style: sSS28);

    // 二维码
    if (qrImage != null) {
      canvas.drawImageRect(
        qrImage!,
        Rect.fromLTWH(0, 0, qrImage!.width.toDouble(), qrImage!.height.toDouble()),
        const Rect.fromLTWH(dL + dW + 65, 365, 180, 180),
        Paint()..filterQuality = FilterQuality.high,
      );
    }

    // 下票号
    _drawText(canvas, '${ticketInfo.id} JM', leftOffset, canvasH - 63, style: sFS32);
  }

  @override
  bool shouldRepaint(covariant RedReceiptPainter old) => true;
}

// ─────────────────────────────────────────────
// 蓝票绘制器（报销凭证）
// ─────────────────────────────────────────────

class BlueReceiptPainter extends CustomPainter {
  final TicketData ticketInfo;
  final ui.Image? backgroundImage;
  final ui.Image? qrImage;

  BlueReceiptPainter({required this.ticketInfo, this.backgroundImage, this.qrImage});

  static const double canvasW = 856;
  static const double canvasH = 540;
  static const double leftOffset = 80;

  double get topOffset => ticketInfo.checkGate.isNotEmpty ? 45 : 35;

  final _rng = Random(42);

  void _drawText(Canvas canvas, String text, double x, double y,
      {TextStyle? style, double spacing = 0, Color? color}) {
    double curX = x;
    for (int i = 0; i < text.length; i++) {
      final alpha = 0.75 + _rng.nextDouble() * 0.25;
      final tp = TextPainter(
        text: TextSpan(
          text: text[i],
          style: (style ?? const TextStyle()).copyWith(color: (color ?? Colors.black).withValues(alpha:alpha)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(curX, y - (style?.fontSize ?? 14)));
      curX += tp.width + spacing;
    }
  }

  double _tw(String text, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    return tp.width;
  }

  double _stationSpacing(String s) {
    if (s.length >= 4) return -6;
    if (s.length == 3) return 10;
    return 65;
  }

  void _trapezoid(Canvas canvas, double x, double y, double w, double h, double offset, String dir) {
    final path = Path();
    if (dir == 'left') {
      path.moveTo(x, y - h / 2 + offset); path.lineTo(x + w, y - h / 2);
      path.lineTo(x + w, y + h / 2); path.lineTo(x, y + h / 2 - offset);
    } else {
      path.moveTo(x, y - h / 2 + offset); path.lineTo(x - w, y - h / 2);
      path.lineTo(x - w, y + h / 2); path.lineTo(x, y + h / 2 - offset);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFADD8E6).withValues(alpha:0.2)..style = PaintingStyle.fill);
  }

  void _dashedRect(Canvas canvas, Paint paint, double x, double y, double w, double h) {
    const dash = 13.3, gap = 4.3;
    void line(Offset a, Offset b) {
      final dx = b.dx - a.dx, dy = b.dy - a.dy;
      final len = sqrt(dx * dx + dy * dy);
      final ux = dx / len, uy = dy / len;
      double d = 0; bool draw = true;
      while (d < len) {
        final s = draw ? dash : gap;
        final d2 = (d + s).clamp(0, len);
        if (draw) canvas.drawLine(Offset(a.dx + ux * d, a.dy + uy * d), Offset(a.dx + ux * d2, a.dy + uy * d2), paint);
        d += s; draw = !draw;
      }
    }
    line(Offset(x, y), Offset(x + w, y));
    line(Offset(x + w, y), Offset(x + w, y + h));
    line(Offset(x + w, y + h), Offset(x, y + h));
    line(Offset(x, y + h), Offset(x, y));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / canvasW, size.height / canvasH);
    canvas.drawRect(Rect.fromLTWH(0, 0, canvasW, canvasH), Paint()..color = Colors.white);

    // 水印背景
    if (backgroundImage != null) {
      canvas.saveLayer(Rect.fromLTWH(0, 0, canvasW, canvasH), Paint()..color = Colors.white.withValues(alpha:0.05));
      canvas.drawImageRect(backgroundImage!,
          Rect.fromLTWH(0, 0, backgroundImage!.width.toDouble(), backgroundImage!.height.toDouble()),
          const Rect.fromLTWH(40, 100, canvasW - 80, canvasH - 200),
          Paint()..filterQuality = FilterQuality.high);
      canvas.restore();
    }

    // 圆角矩形
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(20, 10, canvasW - 40, canvasH - 20), const Radius.circular(20)),
      Paint()..color = const Color(0xFFADD8E6).withValues(alpha:0.2),
    );

    // 梯形凸起
    _trapezoid(canvas, 10, canvasH * 0.2, 10, 40, 5, 'left');
    _trapezoid(canvas, canvasW - 10, canvasH * 0.2, 10, 40, 5, 'right');
    _trapezoid(canvas, 10, canvasH * 0.8, 10, 40, 5, 'left');
    _trapezoid(canvas, canvasW - 10, canvasH * 0.8, 10, 40, 5, 'right');

    // 斜线纹理
    final lp = Paint()..color = const Color(0xFFADD8E6).withValues(alpha:0.5)..strokeWidth = 1;
    const angle = -pi / 6;
    double bx = 0;
    for (double i = 20; i < canvasW - 20; i += 5) {
      double ex = i + canvasH * tan(angle), ey = canvasH - 10;
      if (ex < 20) { ex = 21; ey = 10 + (i - 30) / tan(-angle); }
      canvas.drawLine(Offset(i, 10), Offset(ex, ey), lp);
      bx = ex;
    }
    for (double i = bx + 5; i < canvasW - 20; i += 5) {
      double ex = i + canvasH * tan(-angle), ey = 10;
      if (ex > canvasW - 20) { ex = canvasW - 20; ey = canvasH - 10 - (canvasW - 30 - i) / tan(-angle); }
      canvas.drawLine(Offset(i, canvasH - 10), Offset(ex, ey), lp);
    }

    // 下方深蓝色
    final bp = Paint()..color = const Color(0xFF94CAE0);
    final bottomPath = Path()
      ..moveTo(30, canvasH * 0.9)
      ..lineTo(canvasW - 20, canvasH * 0.9)
      ..lineTo(canvasW - 20, canvasH - 20)
      ..arcToPoint(Offset(canvasW - 50, canvasH - 10), radius: const Radius.circular(20))
      ..lineTo(50, canvasH - 10)
      ..arcToPoint(const Offset(20, canvasH - 30), radius: const Radius.circular(20))
      ..lineTo(20, canvasH * 0.9)
      ..close();
    canvas.drawPath(bottomPath, bp);

    _drawDetails(canvas);
    canvas.restore();
  }

  void _drawDetails(Canvas canvas) {
    final to = topOffset;
    final sRed = TextStyle(fontFamily: 'Calibri', fontSize: 42, color: Colors.red.withValues(alpha:0.5), fontWeight: FontWeight.bold);
    final sSS32 = const TextStyle(fontFamily: 'SimSun', fontSize: 32);
    final sSH45 = const TextStyle(fontFamily: 'SimHei', fontSize: 45);
    final sFS30 = const TextStyle(fontFamily: 'FangSong', fontSize: 30);
    final sSS42 = const TextStyle(fontFamily: 'SimSun', fontSize: 42);
    final sSH40 = const TextStyle(fontFamily: 'SimHei', fontSize: 40);
    final sSS30 = const TextStyle(fontFamily: 'SimSun', fontSize: 30);
    final sFS21 = const TextStyle(fontFamily: 'FangSong', fontSize: 21);
    final sSS28 = const TextStyle(fontFamily: 'SimSun', fontSize: 28);
    final sSS36 = const TextStyle(fontFamily: 'SimSun', fontSize: 36);
    final sFS40 = const TextStyle(fontFamily: 'FangSong', fontSize: 40);
    final sFS25 = const TextStyle(fontFamily: 'FangSong', fontSize: 25);

    _drawText(canvas, ticketInfo.redId, 80, 70, style: sRed, color: Colors.red.withValues(alpha:0.5));

    if (ticketInfo.checkGate.isNotEmpty) {
      final t = '检票:${ticketInfo.checkGate}';
      _drawText(canvas, t, canvasW - _tw(t, sSS32) - 100, 70, style: sSS32);
    }

    final ss = ticketInfo.startStation, es = ticketInfo.endStation;
    _drawText(canvas, ss, ss.length == 5 ? 70 : 110, to + 80, style: sSH45, spacing: _stationSpacing(ss));
    _drawText(canvas, es, es.length == 5 ? canvasW / 2 + 80 : canvasW / 2 + 120, to + 80, style: sSH45, spacing: _stationSpacing(es));

    String sp = PinyinHelper.getPinyin(ss, separator: '', format: PinyinFormat.WITHOUT_TONE);
    String ep = PinyinHelper.getPinyin(es, separator: '', format: PinyinFormat.WITHOUT_TONE);
    if (sp.isNotEmpty) sp = sp[0].toUpperCase() + sp.substring(1);
    if (ep.isNotEmpty) ep = ep[0].toUpperCase() + ep.substring(1);
    _drawText(canvas, sp, 200 - _tw(sp, sFS30) / 2, to + 115, style: sFS30, spacing: -1);
    _drawText(canvas, ep, canvasW / 2 + 220 - _tw(ep, sFS30) / 2, to + 115, style: sFS30, spacing: -1);

    final tnW = _tw(ticketInfo.trainNumber, sSS42) + 2.0 * ticketInfo.trainNumber.length;
    _drawText(canvas, ticketInfo.trainNumber, canvasW / 2 - tnW / 2, to + 85, style: sSS42, spacing: 2);

    final ap = Paint()..color = Colors.black..strokeWidth = 2..style = PaintingStyle.stroke;
    canvas.drawPath(Path()
      ..moveTo(canvasW / 2 - 63, to + 100)
      ..lineTo(canvasW / 2 + 63, to + 100)
      ..lineTo(canvasW / 2 + 48, to + 95), ap);

    _drawText(canvas, '站', 270, to + 76, style: sSS30);
    _drawText(canvas, '站', canvasW - 160, to + 76, style: sSS30);

    _drawText(canvas, ticketInfo.formattedYear, leftOffset + 10, to + 167, style: sSH40, spacing: -2);
    _drawText(canvas, ticketInfo.formattedMonth, leftOffset + 118, to + 167, style: sSH40, spacing: -2);
    _drawText(canvas, ticketInfo.formattedDay, leftOffset + 180, to + 167, style: sSH40, spacing: -2);
    _drawText(canvas, ticketInfo.time, leftOffset + 248, to + 167, style: sSH40, spacing: -2);
    _drawText(canvas, '年', leftOffset + 90, to + 161, style: sFS21);
    _drawText(canvas, '月', leftOffset + 155, to + 161, style: sFS21);
    _drawText(canvas, '日', leftOffset + 218, to + 161, style: sFS21);
    _drawText(canvas, '开', leftOffset + 345, to + 161, style: sFS21);
    _drawText(canvas, '车', leftOffset + 515, to + 161, style: sFS21);

    _drawText(canvas, ticketInfo.paddedCarriage, canvasW / 2 + 120, to + 164, style: sSH40, spacing: -2);

    final sn = ticketInfo.paddedSeatNumber;
    if (sn == '000') {
      _drawText(canvas, '无座', canvasW / 2 + 182, to + 161,
          style: const TextStyle(fontFamily: 'FangSong', fontSize: 32));
    } else {
      final last = sn[sn.length - 1];
      if (RegExp(r'[a-zA-Z]').hasMatch(last)) {
        final num = sn.substring(0, sn.length - 1);
        _drawText(canvas, num, canvasW / 2 + 182, to + 164, style: sSH40, spacing: -3);
        _drawText(canvas, last, canvasW / 2 + 182 + _tw(num, sSH40), to + 164, style: sSS32, spacing: -3);
      } else {
        _drawText(canvas, sn, canvasW / 2 + 182, to + 164, style: sSH40, spacing: -3);
      }
      _drawText(canvas, '号', leftOffset + 594, to + 161, style: sFS21);
    }

    _drawText(canvas, ticketInfo.seatType, 650 - _tw(ticketInfo.seatType, sSS28) / 2, to + 210, style: sSS28);

    _drawText(canvas, '¥', leftOffset + 15, to + 210, style: sSH40);
    final price = ticketInfo.price.toStringAsFixed(1);
    _drawText(canvas, price, leftOffset + 50, to + 210, style: sSH40, spacing: -2);
    _drawText(canvas, '元', leftOffset + 42 + _tw(price, sSH40), to + 205, style: sFS21);

    final cp = Paint()..color = Colors.black..strokeWidth = 1.5..style = PaintingStyle.stroke;
    if (ticketInfo.isStudent) {
      final sw = _tw('学', sSS32);
      _drawText(canvas, '学', canvasW / 2 - sw - 60, to + 205, style: sSS32);
      canvas.drawCircle(Offset(canvasW / 2 - sw / 2 - 60, to + 193), 17, cp);
    }
    if (ticketInfo.isChild) {
      final cw = _tw('孩', sSS32);
      _drawText(canvas, '孩', canvasW / 2 - cw - 60, to + 205, style: sSS32);
      canvas.drawCircle(Offset(canvasW / 2 - cw / 2 - 60, to + 193), 17, cp);
    }
    if (ticketInfo.isDiscount) {
      final dw = _tw('惠', sSS32);
      _drawText(canvas, '惠', canvasW / 2 - dw - 20, to + 205, style: sSS32);
      canvas.drawCircle(Offset(canvasW / 2 - dw / 2 - 20, to + 193), 17, cp);
    }

    _drawText(canvas, '仅供纪念使用', 340, 300, style: sSS32);
    if (ticketInfo.isRefund) _drawText(canvas, '退票费', leftOffset, 295, style: sSS32);
    _drawText(canvas, '仅供报销使用', leftOffset, 337, style: sSS32);

    final id = ticketInfo.maskedId;
    final idW = _tw(id, sFS40);
    _drawText(canvas, id, leftOffset, 383, style: sFS40, spacing: -3);
    _drawText(canvas, ticketInfo.passengerName, leftOffset + idW + 10 - 48, 383, style: sSS36);

    const dW = 490.0, dH = 74.0, dL = 108.0;
    _dashedRect(canvas, Paint()..color = Colors.black..strokeWidth = 1..style = PaintingStyle.stroke, dL, 395, dW, dH);
    final t1 = '报销凭证 遗失不补';
    _drawText(canvas, t1, dL + dW / 2 - _tw(t1, sSS28) / 2, 424, style: sSS28);
    final t2 = '退票改签时须交回车站';
    _drawText(canvas, t2, dL + dW / 2 - _tw(t2, sSS28) / 2, 460, style: sSS28);

    if (qrImage != null) {
      canvas.drawImageRect(
        qrImage!,
        Rect.fromLTWH(0, 0, qrImage!.width.toDouble(), qrImage!.height.toDouble()),
        const Rect.fromLTWH(dL + dW + 65, 330, 140, 140),
        Paint()..filterQuality = FilterQuality.high,
      );
    }

    _drawText(canvas, '${ticketInfo.id} JM', leftOffset, canvasH - 25, style: sFS25);
  }

  @override
  bool shouldRepaint(covariant BlueReceiptPainter old) => true;
}

// ─────────────────────────────────────────────
// 票面 Widget（含二维码 + 背景图加载）
// ─────────────────────────────────────────────

enum TicketType { red, blue }

class TicketWidget extends StatefulWidget {
  final TicketData ticketInfo;
  final TicketType type;
  final GlobalKey repaintKey;

  const TicketWidget({super.key, required this.ticketInfo, required this.type, required this.repaintKey});

  @override
  State<TicketWidget> createState() => _TicketWidgetState();
}

class _TicketWidgetState extends State<TicketWidget> {
  ui.Image? _bgImage;
  ui.Image? _qrImage;

  @override
  void initState() { super.initState(); _loadAll(); }

  @override
  void didUpdateWidget(covariant TicketWidget old) {
    super.didUpdateWidget(old);
    if (old.type != widget.type || old.ticketInfo.qrCodeId != widget.ticketInfo.qrCodeId) {
      _loadAll();
    } else if (old.ticketInfo != widget.ticketInfo) {
      _generateQr();
    }
  }

  Future<void> _loadAll() async { await _loadBg(); await _generateQr(); }

  Future<void> _loadBg() async {
    final asset = widget.type == TicketType.red ? 'assets/ticket/redTicket.png' : 'assets/ticket/CRH.jpg';
    try {
      final data = await DefaultAssetBundle.of(context).load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _bgImage = frame.image);
    } catch (_) {}
  }

  Future<void> _generateQr() async {
    final text = widget.ticketInfo.qrCodeId.isEmpty ? 'TICKET' : widget.ticketInfo.qrCodeId;
    try {
      final recorder = ui.PictureRecorder();
      QrPainter(
        data: text,
        version: QrVersions.auto,
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xB3000000)),
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xB3000000)),
      ).paint(Canvas(recorder), const Size(200, 200));
      final img = await recorder.endRecording().toImage(200, 200);
      if (mounted) setState(() => _qrImage = img);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: widget.repaintKey,
      child: AspectRatio(
        aspectRatio: widget.type == TicketType.red ? 900 / 600 : 856 / 540,
        child: CustomPaint(
          painter: widget.type == TicketType.red
              ? RedReceiptPainter(ticketInfo: widget.ticketInfo, backgroundImage: _bgImage, qrImage: _qrImage)
              : BlueReceiptPainter(ticketInfo: widget.ticketInfo, backgroundImage: _bgImage, qrImage: _qrImage),
        ),
      ),
    );
  }
}

Future<Uint8List?> captureTicketImage(GlobalKey key, {double pixelRatio = 3.0}) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } catch (_) { return null; }
}

// ─────────────────────────────────────────────
// 输入表单
// ─────────────────────────────────────────────

class TicketForm extends StatefulWidget {
  final TicketData initial;
  final ValueChanged<TicketData> onChanged;

  const TicketForm({super.key, required this.initial, required this.onChanged});

  @override
  State<TicketForm> createState() => _TicketFormState();
}

class _TicketFormState extends State<TicketForm> {
  late TicketData _data;
  late Map<String, TextEditingController> _ctrl;

  @override
  void initState() {
    super.initState();
    _data = widget.initial;
    _ctrl = {
      'redId': TextEditingController(text: _data.redId),
      'id': TextEditingController(text: _data.id),
      'startStation': TextEditingController(text: _data.startStation),
      'endStation': TextEditingController(text: _data.endStation),
      'checkGate': TextEditingController(text: _data.checkGate),
      'ticketOffice': TextEditingController(text: _data.ticketOffice),
      'trainNumber': TextEditingController(text: _data.trainNumber),
      'price': TextEditingController(text: _data.price.toStringAsFixed(1)),
      'time': TextEditingController(text: _data.time),
      'seatCarriage': TextEditingController(text: _data.seatCarriage),
      'seatNumber': TextEditingController(text: _data.seatNumber),
      'passengerName': TextEditingController(text: _data.passengerName),
      'passengerId': TextEditingController(text: _data.passengerId),
      'seatType': TextEditingController(text: _data.seatType),
      'berth': TextEditingController(text: _data.berth),
      'qrCodeId': TextEditingController(text: _data.qrCodeId),
    };
  }

  @override
  void dispose() { for (final c in _ctrl.values) c.dispose(); super.dispose(); }

  void _notify() => widget.onChanged(_data);

  void _update(String key, String v) {
    setState(() {
      switch (key) {
        case 'redId': _data = _data.copyWith(redId: v); break;
        case 'id': _data = _data.copyWith(id: v); break;
        case 'startStation': _data = _data.copyWith(startStation: v); break;
        case 'endStation': _data = _data.copyWith(endStation: v); break;
        case 'checkGate': _data = _data.copyWith(checkGate: v); break;
        case 'ticketOffice': _data = _data.copyWith(ticketOffice: v); break;
        case 'trainNumber': _data = _data.copyWith(trainNumber: v); break;
        case 'price': _data = _data.copyWith(price: double.tryParse(v) ?? _data.price); break;
        case 'time': _data = _data.copyWith(time: v); break;
        case 'seatCarriage': _data = _data.copyWith(seatCarriage: v); break;
        case 'seatNumber': _data = _data.copyWith(seatNumber: v); break;
        case 'passengerName': _data = _data.copyWith(passengerName: v); break;
        case 'passengerId': _data = _data.copyWith(passengerId: v); break;
        case 'seatType': _data = _data.copyWith(seatType: v); break;
        case 'berth': _data = _data.copyWith(berth: v); break;
        case 'qrCodeId': _data = _data.copyWith(qrCodeId: v); break;
      }
      _notify();
    });
  }

  Widget _field(String key, String label, {TextInputType? kb, int? max, int flex = 1}) => Flexible(
    flex: flex,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: TextField(
        controller: _ctrl[key],
        keyboardType: kb,
        maxLength: max,
        decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder(),
          isDense: true, counterText: '',
        ),
        onChanged: (v) => _update(key, v),
      ),
    ),
  );

  Widget _check(String label, bool value, ValueChanged<bool?> cb) => Flexible(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Checkbox(value: value, onChanged: cb),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _data.date,
      firstDate: DateTime(2010), lastDate: DateTime(2030),
    );
    if (picked != null) setState(() { _data = _data.copyWith(date: picked); _notify(); });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('票面信息', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [_field('redId', '上票号', max: 11), _field('id', '下票号', max: 21, flex: 2)]),
          Row(children: [_field('startStation', '出发地', max: 5), _field('endStation', '目的地', max: 5), _field('checkGate', '检票口', max: 12)]),
          Row(children: [
            _field('trainNumber', '车次', max: 6),
            _field('price', '价格', kb: const TextInputType.numberWithOptions(decimal: true)),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '日期', border: OutlineInputBorder(), isDense: true),
                    child: Text('${_data.formattedYear}-${_data.formattedMonth}-${_data.formattedDay}'),
                  ),
                ),
              ),
            ),
            _field('time', '时间', max: 5),
          ]),
          Row(children: [
            _field('seatCarriage', '车厢号', max: 2, kb: TextInputType.number),
            _field('seatNumber', '座位号', max: 3),
            _field('seatType', '席别', max: 5),
            _field('berth', '铺位', max: 3),
          ]),
          Row(children: [_field('passengerName', '姓名', max: 12), _field('passengerId', '身份证号', max: 18, flex: 2)]),
          Row(children: [_field('ticketOffice', '售票点', max: 10), _field('qrCodeId', '二维码内容', max: 200, flex: 3)]),
          const SizedBox(height: 4),
          Row(children: [
            _check('学生票', _data.isStudent, (v) => setState(() {
              _data = _data.copyWith(isStudent: v, isDiscount: v == true ? true : _data.isDiscount, isChild: v == true ? false : _data.isChild);
              _notify();
            })),
            _check('儿童票', _data.isChild, (v) => setState(() {
              _data = _data.copyWith(isChild: v, isStudent: v == true ? false : _data.isStudent);
              _notify();
            })),
            _check('优惠票', _data.isDiscount, (v) => setState(() { _data = _data.copyWith(isDiscount: v); _notify(); })),
            _check('退票费', _data.isRefund, (v) => setState(() { _data = _data.copyWith(isRefund: v); _notify(); })),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 主页
// ─────────────────────────────────────────────

class TicketPage extends StatefulWidget {
  const TicketPage({super.key});

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> with SingleTickerProviderStateMixin {
  late TabController _tab;
  TicketData _data = TicketData();
  final GlobalKey _redKey = GlobalKey();
  final GlobalKey _blueKey = GlobalKey();
  bool _saving = false;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _save({bool both = false}) async {
    setState(() => _saving = true);
    try {
      final status = await Permission.photos.request();
      if (!status.isGranted) { _snack('需要相册权限才能保存图片', Colors.red); return; }
      if (both) {
        int saved = 0;
        for (final e in [(_blueKey, '蓝票'), (_redKey, '红票')]) {
          final bytes = await captureTicketImage(e.$1, pixelRatio: 3.0);
          if (bytes != null) {
            final r = await ImageGallerySaver.saveImage(bytes, quality: 100,
                name: 'ticket_${e.$2}_${DateTime.now().millisecondsSinceEpoch}');
            if (r['isSuccess'] == true) saved++;
          }
        }
        _snack(saved == 2 ? '蓝票和红票已保存到相册' : '部分保存失败', saved == 2 ? Colors.green : Colors.orange);
      } else {
        final isRed = _tab.index == 1;
        final key = isRed ? _redKey : _blueKey;
        final label = isRed ? '红票' : '蓝票';
        final bytes = await captureTicketImage(key, pixelRatio: 3.0);
        if (bytes == null) { _snack('图片生成失败', Colors.red); return; }
        final r = await ImageGallerySaver.saveImage(bytes, quality: 100,
            name: 'ticket_${label}_${DateTime.now().millisecondsSinceEpoch}');
        _snack(r['isSuccess'] == true ? '$label 已保存到相册' : '保存失败，请检查权限',
            r['isSuccess'] == true ? Colors.green : Colors.red);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 220,
              child: TabBarView(
                controller: _tab,
                children: [
                  Center(child: TicketWidget(ticketInfo: _data, type: TicketType.blue, repaintKey: _blueKey)),
                  Center(child: TicketWidget(ticketInfo: _data, type: TicketType.red, repaintKey: _redKey)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save(),
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_alt),
                  label: const Text('保存当前票'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _saving ? null : () => _save(both: true),
                  child: const Text('保存全部'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TicketForm(initial: _data, onChanged: (d) => setState(() => _data = d)),
          ]),
        ),
      ),
    );
  }
}
