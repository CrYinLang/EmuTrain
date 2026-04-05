import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';

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
  String time; // "HH:mm"
  String seatType;
  String berth;
  String seatCarriage;
  String seatNumber;
  String passengerName;
  String passengerId;
  String qrCodeId;
  bool isChild;
  bool isStudent;
  bool isNet;
  bool isDiscount;
  bool isRefund;

  TicketData({
    this.redId = '01X073561',
    this.id = '21077000060721X073561',
    this.startStation = '东方红',
    this.endStation = '卫星',
    this.checkGate = '1',
    this.ticketOffice = '武昌',
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
    this.isNet = true,
    this.isDiscount = true,
    this.isRefund = false,
  }) : date = date ?? DateTime(2025, 7, 23);

  TicketData copyWith({
    String? redId, String? id, String? startStation, String? endStation,
    String? checkGate, String? ticketOffice, String? trainNumber,
    double? price, DateTime? date, String? time, String? seatType,
    String? berth, String? seatCarriage, String? seatNumber,
    String? passengerName, String? passengerId, String? qrCodeId,
    bool? isChild, bool? isStudent, bool? isNet, bool? isDiscount, bool? isRefund,
  }) {
    return TicketData(
      redId: redId ?? this.redId,
      id: id ?? this.id,
      startStation: startStation ?? this.startStation,
      endStation: endStation ?? this.endStation,
      checkGate: checkGate ?? this.checkGate,
      ticketOffice: ticketOffice ?? this.ticketOffice,
      trainNumber: trainNumber ?? this.trainNumber,
      price: price ?? this.price,
      date: date ?? this.date,
      time: time ?? this.time,
      seatType: seatType ?? this.seatType,
      berth: berth ?? this.berth,
      seatCarriage: seatCarriage ?? this.seatCarriage,
      seatNumber: seatNumber ?? this.seatNumber,
      passengerName: passengerName ?? this.passengerName,
      passengerId: passengerId ?? this.passengerId,
      qrCodeId: qrCodeId ?? this.qrCodeId,
      isChild: isChild ?? this.isChild,
      isStudent: isStudent ?? this.isStudent,
      isNet: isNet ?? this.isNet,
      isDiscount: isDiscount ?? this.isDiscount,
      isRefund: isRefund ?? this.isRefund,
    );
  }
}

// ─────────────────────────────────────────────
// 工具函数
// ─────────────────────────────────────────────
String maskedId(String idCard) {
  if (idCard.length < 18) return idCard;
  return '${idCard.substring(0, 10)}****${idCard.substring(14)}';
}

/// 汉字转拼音（无声调，首字母大写），使用 lpinyin 包
String toPinyin(String chinese) {
  if (chinese.isEmpty) return chinese;
  final result = PinyinHelper.getPinyin(
    chinese,
    separator: '',
    format: PinyinFormat.WITHOUT_TONE,
  );
  if (result.isEmpty) return chinese;
  return result[0].toUpperCase() + result.substring(1);
}

double getStationSpacing(String text) {
  if (text.length >= 4) return -6;
  if (text.length == 3) return 10;
  return 65;
}

String padLeft2(dynamic val) => val.toString().padLeft(2, '0');
String padLeft3(dynamic val) => val.toString().padLeft(3, '0');


// ─────────────────────────────────────────────
// 票面 Painter 基类
// ─────────────────────────────────────────────
abstract class BaseTicketPainter extends CustomPainter {
  final TicketData ticket;
  final Random _rand = Random(42);

  BaseTicketPainter(this.ticket);

  // 绘制带随机透明度效果的文字（模拟油墨效果）
  void drawInkText(
    Canvas canvas,
    String text,
    double x,
    double y,
    TextStyle style, {
    double spacing = 0,
    Color color = Colors.black,
  }) {
    double curX = x;
    for (final char in text.characters) {
      final tp = TextPainter(
        text: TextSpan(text: char, style: style.copyWith(color: color)),
        textDirection: TextDirection.ltr,
      )..layout();
      final alpha = (_rand.nextDouble() * 0.7 + 0.3).clamp(0.0, 1.0);
      final paint = Paint()..colorFilter = ColorFilter.mode(
        color.withValues(alpha:alpha), BlendMode.modulate);
      tp.paint(canvas, Offset(curX, y));
      curX += tp.width + spacing;
    }
  }

  // 简单绘制文字
  void drawText(
    Canvas canvas,
    String text,
    double x,
    double y,
    TextStyle style, {
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    double drawX = x;
    if (align == TextAlign.center) drawX = x - tp.width / 2;
    tp.paint(canvas, Offset(drawX, y));
  }

  double measureText(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  // 绘制梯形（票边凸起装饰）
  void drawTrapezoid(Canvas canvas, Paint paint, double x, double y,
      double width, double height, double offset, bool isLeft) {
    final path = Path();
    if (isLeft) {
      path.moveTo(x, y - height / 2 + offset);
      path.lineTo(x + width, y - height / 2);
      path.lineTo(x + width, y + height / 2);
      path.lineTo(x, y + height / 2 - offset);
    } else {
      path.moveTo(x, y - height / 2 + offset);
      path.lineTo(x - width, y - height / 2);
      path.lineTo(x - width, y + height / 2);
      path.lineTo(x, y + height / 2 - offset);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  // 绘制圆角矩形
  void drawRoundRect(Canvas canvas, double x, double y, double w, double h,
      double radius, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(radius)),
      Paint()..color = color,
    );
  }

  // 绘制伪二维码
  void drawQRCode(Canvas canvas, double x, double y, double size) {
    final qrPaint = Paint()..color = const Color(0xB3000000);
    final cellSize = size / 21;
    final hash = ticket.qrCodeId.hashCode;
    final rand = Random(hash);

    void drawFinder(double fx, double fy) {
      canvas.drawRect(Rect.fromLTWH(fx, fy, cellSize * 7, cellSize * 7), qrPaint);
      canvas.drawRect(
        Rect.fromLTWH(fx + cellSize, fy + cellSize, cellSize * 5, cellSize * 5),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromLTWH(fx + cellSize * 2, fy + cellSize * 2, cellSize * 3, cellSize * 3),
        qrPaint,
      );
    }

    drawFinder(x, y);
    drawFinder(x + 14 * cellSize, y);
    drawFinder(x, y + 14 * cellSize);

    for (int row = 0; row < 21; row++) {
      for (int col = 0; col < 21; col++) {
        bool isFinderArea = (row < 8 && col < 8) ||
            (row < 8 && col > 12) ||
            (row > 12 && col < 8);
        if (isFinderArea) continue;
        if (rand.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(x + col * cellSize, y + row * cellSize, cellSize, cellSize),
            qrPaint,
          );
        }
      }
    }
  }

  // 绘制起止站 + 车次区域
  void drawStationArea(Canvas canvas, Size size, double topOffset) {
    final w = size.width;

    // 站名
    final stationStyle = TextStyle(
      fontSize: 45, fontWeight: FontWeight.bold, color: Colors.black,
    );
    final startSpacing = getStationSpacing(ticket.startStation);
    final endSpacing = getStationSpacing(ticket.endStation);

    double leftStart = ticket.startStation.length == 5 ? 70 : 110;
    double leftEnd = ticket.endStation.length == 5 ? w / 2 + 80 : w / 2 + 120;

    drawInkText(canvas, ticket.startStation, leftStart, topOffset + 40,
        stationStyle, spacing: startSpacing);
    drawInkText(canvas, ticket.endStation, leftEnd, topOffset + 40,
        stationStyle, spacing: endSpacing);

    // "站" 字
    final zhanStyle = TextStyle(fontSize: 30, color: Colors.black);
    drawText(canvas, '站', 270, topOffset + 33, zhanStyle);
    drawText(canvas, '站', w - 160, topOffset + 33, zhanStyle);

    // 拼音
    final pinyinStyle = TextStyle(fontSize: 28, color: Colors.black);
    final startPinyin = toPinyin(ticket.startStation);
    final endPinyin = toPinyin(ticket.endStation);
    final startPW = measureText(startPinyin, pinyinStyle);
    final endPW = measureText(endPinyin, pinyinStyle);
    drawText(canvas, startPinyin, 200 - startPW / 2, topOffset + 72, pinyinStyle);
    drawText(canvas, endPinyin, w / 2 + 220 - endPW / 2, topOffset + 72, pinyinStyle);

    // 车次
    final trainStyle = TextStyle(fontSize: 42, color: Colors.black);
    final trainW = measureText(ticket.trainNumber, trainStyle);
    drawInkText(canvas, ticket.trainNumber, w / 2 - trainW / 2, topOffset + 42, trainStyle, spacing: 2);

    // 箭头
    final arrowPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final arrowStartX = w / 2 - 63.0;
    final arrowStartY = topOffset + 55.0;
    canvas.drawLine(Offset(arrowStartX, arrowStartY),
        Offset(arrowStartX + 126, arrowStartY), arrowPaint);
    canvas.drawLine(Offset(arrowStartX + 111, arrowStartY - 5),
        Offset(arrowStartX + 126, arrowStartY), arrowPaint);
  }

  // 绘制日期时间 + 座位区域
  void drawDateSeatArea(Canvas canvas, Size size, double topOffset) {
    final w = size.width;
    final mainStyle = TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black);
    final smallStyle = TextStyle(fontSize: 21, color: Colors.black);
    const lo = 80.0;

    final year = ticket.date.year.toString();
    final month = padLeft2(ticket.date.month);
    final day = padLeft2(ticket.date.day);

    drawInkText(canvas, year, lo + 10, topOffset + 120, mainStyle, spacing: -2);
    drawInkText(canvas, month, lo + 118, topOffset + 120, mainStyle, spacing: -2);
    drawInkText(canvas, day, lo + 180, topOffset + 120, mainStyle, spacing: -2);
    drawInkText(canvas, ticket.time, lo + 248, topOffset + 120, mainStyle, spacing: -2);

    drawText(canvas, '年', lo + 90, topOffset + 113, smallStyle);
    drawText(canvas, '月', lo + 155, topOffset + 113, smallStyle);
    drawText(canvas, '日', lo + 218, topOffset + 113, smallStyle);
    drawText(canvas, '开', lo + 345, topOffset + 113, smallStyle);
    drawText(canvas, '车', lo + 515, topOffset + 113, smallStyle);

    // 车厢号
    final carriage = padLeft2(ticket.seatCarriage);
    drawInkText(canvas, carriage, w / 2 + 120, topOffset + 120, mainStyle, spacing: -2);

    // 座位号
    String seatNum = padLeft3(ticket.seatNumber);
    final noSeat = seatNum == '000';
    if (!noSeat) drawText(canvas, '号', lo + 594, topOffset + 113, smallStyle);

    if (noSeat) {
      drawText(canvas, '无座', w / 2 + 182, topOffset + 118,
          TextStyle(fontSize: 32, color: Colors.black));
    } else if (ticket.berth.isNotEmpty) {
      drawInkText(canvas, seatNum, w / 2 + 177, topOffset + 120, mainStyle, spacing: -3);
      drawText(canvas, '号${ticket.berth}', w / 2 + 240, topOffset + 118,
          TextStyle(fontSize: 34, color: Colors.black));
    } else {
      drawInkText(canvas, seatNum, w / 2 + 182, topOffset + 120, mainStyle, spacing: -3);
    }

    // 席别
    final seatStyle = TextStyle(fontSize: 28, color: Colors.black);
    final seatW = measureText(ticket.seatType, seatStyle);
    drawText(canvas, ticket.seatType, 650 - seatW / 2, topOffset + 158, seatStyle);
  }

  // 绘制票价 + 优惠标识
  void drawPriceArea(Canvas canvas, Size size, double topOffset) {
    final w = size.width;
    const lo = 80.0;
    final priceStr = ticket.price.toStringAsFixed(1);
    drawText(canvas, '¥', lo + 15, topOffset + 163,
        TextStyle(fontSize: 40, color: Colors.black));
    final priceStyle = TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black);
    drawInkText(canvas, priceStr, lo + 50, topOffset + 165, priceStyle, spacing: -2);
    final priceW = measureText(priceStr, priceStyle);
    drawText(canvas, '元', lo + 42 + priceW, topOffset + 160,
        TextStyle(fontSize: 21, color: Colors.black));

    // 圆圈标识
    final circlePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final circleStyle = TextStyle(fontSize: 32, color: Colors.black);
    double markX = w / 2 - 75;
    if (ticket.isStudent) {
      final sw = measureText('学', circleStyle);
      drawText(canvas, '学', markX - sw / 2, topOffset + 158, circleStyle);
      canvas.drawCircle(Offset(markX, topOffset + 148), 17, circlePaint);
      markX += 45;
    }
    if (ticket.isChild) {
      final sw = measureText('孩', circleStyle);
      drawText(canvas, '孩', markX - sw / 2, topOffset + 158, circleStyle);
      canvas.drawCircle(Offset(markX, topOffset + 148), 17, circlePaint);
      markX += 45;
    }
    if (ticket.isDiscount) {
      final sw = measureText('惠', circleStyle);
      drawText(canvas, '惠', markX - sw / 2, topOffset + 158, circleStyle);
      canvas.drawCircle(Offset(markX, topOffset + 148), 17, circlePaint);
    }
  }

  // 绘制身份证 + 姓名
  void drawPassengerArea(Canvas canvas, double y) {
    const lo = 80.0;
    final idStyle = TextStyle(fontSize: 36, color: Colors.black,
        fontFamily: 'monospace');
    final nameStyle = TextStyle(fontSize: 36, color: Colors.black);
    final maskedIdStr = maskedId(ticket.passengerId);
    drawInkText(canvas, maskedIdStr, lo, y, idStyle, spacing: -3);
    final idW = measureText(maskedIdStr, idStyle);
    drawText(canvas, ticket.passengerName, lo + idW - 40, y + 2, nameStyle);
  }

  // 绘制虚线框
  void drawDashRect(Canvas canvas, double x, double y, double w, double h,
      double dashLen, double gapLen) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path = Path()..addRect(Rect.fromLTWH(x, y, w, h));
    final dashPath = _createDashPath(path, dashLen, gapLen);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashPath(Path source, double dashLen, double gapLen) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLen : gapLen;
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  // 绘制票号 + 售票点
  void drawTicketId(Canvas canvas, Size size, double y) {
    const lo = 80.0;
    final style = TextStyle(fontSize: 28, color: Colors.black);
    drawText(canvas, ticket.id, lo, y, style);
    final idW = measureText(ticket.id, style);
    drawText(canvas, '${ticket.ticketOffice}售', lo + idW + 30, y,
        TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black));
  }
}

// ─────────────────────────────────────────────
// 蓝票（报销凭证）Painter
// ─────────────────────────────────────────────
class BlueReceiptPainter extends BaseTicketPainter {
  BlueReceiptPainter(super.ticket);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 白色背景
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);

    // 圆角矩形边框（淡蓝色）
    drawRoundRect(canvas, 20, 10, w - 40, h - 20, 20,
        const Color(0x33ADD8E6));

    // 梯形凸起
    final trapPaint = Paint()..color = const Color(0x33ADD8E6);
    drawTrapezoid(canvas, trapPaint, 10, h * 0.2, 10, 40, 5, true);
    drawTrapezoid(canvas, trapPaint, w - 10, h * 0.2, 10, 40, 5, false);
    drawTrapezoid(canvas, trapPaint, 10, h * 0.8, 10, 40, 5, true);
    drawTrapezoid(canvas, trapPaint, w - 10, h * 0.8, 10, 40, 5, false);

    // 斜线纹理
    final linePaint = Paint()
      ..color = const Color(0x7FADD8E6)
      ..strokeWidth = 1;
    for (double i = 20; i < w - 20; i += 5) {
      double endX = i + h * tan(pi / 6);
      canvas.drawLine(Offset(i, 10), Offset(endX, h - 10), linePaint);
    }

    // 下方蓝色区域
    final bluePaint = Paint()..color = const Color(0xFF94CAE0);
    final bluePath = Path()
      ..moveTo(30, h * 0.9)
      ..lineTo(w - 20, h * 0.9)
      ..lineTo(w - 20, h - 20)
      ..arcToPoint(Offset(w - 50, h - 10), radius: const Radius.circular(20))
      ..lineTo(50, h - 10)
      ..arcToPoint(Offset(20, h - 30), radius: const Radius.circular(20))
      ..lineTo(20, h * 0.9)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // CR水印重复
    for (double wy = h * 0.88; wy < h * 0.9; wy += 18) {
      for (double wx = 20; wx < w - 20; wx += 16) {
        drawText(canvas, 'CR', wx, wy,
            TextStyle(fontSize: 8, color: const Color(0xFF94CAE0)));
      }
    }

    // 左上角红色编号
    _drawRedId(canvas);

    double topOffset = ticket.checkGate.isNotEmpty ? 5 : -5;

    // 检票口
    if (ticket.checkGate.isNotEmpty) {
      final gateText = '检票:${ticket.checkGate}';
      final gateStyle = TextStyle(fontSize: 32, color: Colors.black);
      final gateW = measureText(gateText, gateStyle);
      drawText(canvas, gateText, w - gateW - 100, 38, gateStyle);
    }

    // 站名 + 车次
    drawStationArea(canvas, size, topOffset + 40);

    // 日期 + 座位
    drawDateSeatArea(canvas, size, topOffset + 40);

    // 票价
    drawPriceArea(canvas, size, topOffset + 40);

    // 仅供纪念
    drawText(canvas, '仅供纪念使用', 340, 320,  // 修改：从298改为320
        TextStyle(fontSize: 32, color: Colors.black));

    // 退票费
    if (ticket.isRefund) {
      drawText(canvas, '退票费', 80, 315, TextStyle(fontSize: 32, color: Colors.black));  // 修改：从293改为315
    }

    // 仅供报销
    drawText(canvas, '仅供报销使用', 80, 360,  // 修改：从335改为360
        TextStyle(fontSize: 32, color: Colors.black));

    // 乘客信息
    drawPassengerArea(canvas, 390);  // 修改：从381改为390

    // 虚线框
    drawDashRect(canvas, 108, 402, 490, 74, 13.3, 4.3);  // 修改：从393改为402
    final boxStyle = TextStyle(fontSize: 28, color: Colors.black);
    final t1 = '报销凭证 遗失不补';
    final t2 = '退票改签时须交回车站';
    final t1w = measureText(t1, boxStyle);
    final t2w = measureText(t2, boxStyle);
    drawText(canvas, t1, 108 + 490 / 2 - t1w / 2, 425, boxStyle);  // 修改：从416改为425
    drawText(canvas, t2, 108 + 490 / 2 - t2w / 2, 460, boxStyle);  // 修改：从451改为460

    // 二维码
    drawQRCode(canvas, 108 + 490 + 65, 345, 140);  // 修改：从328改为345

    // 票号
    drawText(canvas, '${ticket.id} JM', 80, h - 25,
        TextStyle(fontSize: 24, color: Colors.black));
  }

  void _drawRedId(Canvas canvas) {
    drawText(canvas, ticket.redId, 80, 28,
        TextStyle(fontSize: 42, color: const Color(0x7FFF0000)));
  }

  @override
  bool shouldRepaint(BlueReceiptPainter old) => true;
}

class BlueTicketPainter extends BaseTicketPainter {
  BlueTicketPainter(super.ticket);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);
    _drawBlueTicketBackground(canvas, size);

    // 左上角红色编号
    drawText(canvas, ticket.redId, 80, 28,
        TextStyle(fontSize: 42, color: const Color(0x7FFF0000)));

    double topOffset = ticket.checkGate.isNotEmpty ? 5 : -5;

    if (ticket.checkGate.isNotEmpty) {
      final gateText = '检票:${ticket.checkGate}';
      final gateStyle = TextStyle(fontSize: 32, color: Colors.black);
      final gateW = measureText(gateText, gateStyle);
      drawText(canvas, gateText, w - gateW - 100, 28, gateStyle);
    }

    // 站名 + 车次
    drawStationArea(canvas, size, topOffset + 40);

    // 日期 + 座位
    drawDateSeatArea(canvas, size, topOffset + 40);

    // 票价
    drawPriceArea(canvas, size, topOffset + 40);

    // 限乘当日当次车
    drawText(canvas, '限乘当日当次车', 80, 310,  // 修改：从288改为310
        TextStyle(fontSize: 32, color: Colors.black));

    // 仅供纪念
    drawText(canvas, '仅供纪念使用', 340, 340,  // 修改：从328改为340
        TextStyle(fontSize: 32, color: Colors.black));

    // 乘客信息
    drawPassengerArea(canvas, 390);  // 修改：从378改为390

    // 虚线框
    drawDashRect(canvas, 108, 402, 490, 74, 13.3, 4.4);  // 修改：从392改为402
    final boxStyle = TextStyle(fontSize: 28, color: Colors.black);
    final t1 = '买票请到12306 发货请到95306';
    final t2 = '中国铁路祝您旅途愉快';
    final t1w = measureText(t1, boxStyle);
    final t2w = measureText(t2, boxStyle);
    drawText(canvas, t1, 108 + 490 / 2 - t1w / 2, 425, boxStyle);  // 修改：从422改为425
    drawText(canvas, t2, 108 + 490 / 2 - t2w / 2, 460, boxStyle);  // 修改：从457改为460

    // 二维码
    drawQRCode(canvas, 108 + 490 + 68, 345, 140);  // 修改：从326改为345

    // 票号 + 售票点
    drawTicketId(canvas, size, h - 40);
  }

  void _drawBlueTicketBackground(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFE8F4FD),
        const Color(0xFFCDE8F7),
        const Color(0xFFB0D9F0),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(BlueTicketPainter old) => true;
}

class RedReceiptPainter extends BaseTicketPainter {
  RedReceiptPainter(super.ticket);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);
    _drawRedTicketBackground(canvas, size);

    // 左上角红色编号
    drawText(canvas, ticket.redId, 80, 50,
        TextStyle(fontSize: 44, color: const Color(0x7FFF0000),
            fontWeight: FontWeight.bold));

    // 检票口
    if (ticket.checkGate.isNotEmpty) {
      final gateText = '检票:${ticket.checkGate}';
      final gateStyle = TextStyle(fontSize: 34, color: Colors.black);
      final gateW = measureText(gateText, gateStyle);
      drawText(canvas, gateText, w - gateW - 100, 50, gateStyle);
    }

    const topOffset = 50.0;

    // 站名 + 车次（红票字体略大）
    _drawStationAreaRed(canvas, size, topOffset);

    // 日期 + 座位
    _drawDateSeatAreaRed(canvas, size, topOffset);

    // 票价
    _drawPriceAreaRed(canvas, size, topOffset);

    // 仅供纪念
    drawText(canvas, '仅供纪念使用', 340, 345,  // 修改：从323改为345
        TextStyle(fontSize: 34, color: Colors.black));

    // 仅供报销
    drawText(canvas, '仅供报销使用', 80, 385,  // 修改：从363改为385
        TextStyle(fontSize: 34, color: Colors.black));

    // 退票费
    if (ticket.isRefund) {
      drawText(canvas, '退票费', 80, 343, TextStyle(fontSize: 34, color: Colors.black));  // 修改：从321改为343
    }

    // 乘客信息
    drawPassengerArea(canvas, 425);  // 修改：从403改为425

    // 虚线框
    drawDashRect(canvas, 95, 445, 500, 80, 16, 4);  // 修改：从423改为445
    final boxStyle = TextStyle(fontSize: 28, color: Colors.black);
    final t1 = '报销凭证 遗失不补';
    final t2 = '退票改签时须交回车站';
    final t1w = measureText(t1, boxStyle);
    final t2w = measureText(t2, boxStyle);
    drawText(canvas, t1, 95 + 500 / 2 - t1w / 2, 475, boxStyle);  // 修改：从453改为475
    drawText(canvas, t2, 95 + 500 / 2 - t2w / 2, 513, boxStyle);  // 修改：从491改为513

    // 二维码
    drawQRCode(canvas, 95 + 500 + 65, 385, 180);  // 修改：从363改为385

    // 票号
    drawText(canvas, '${ticket.id} JM', 80, h - 75,
        TextStyle(fontSize: 30, color: Colors.black));
  }

  void _drawRedTicketBackground(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFFFF5F5),
        const Color(0xFFFFE0E0),
        const Color(0xFFFFCCCC),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // 顶部红色横条
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 10),
        Paint()..color = const Color(0xFFCC0000));
    // 底部红色横条
    canvas.drawRect(Rect.fromLTWH(0, size.height - 10, size.width, 10),
        Paint()..color = const Color(0xFFCC0000));
  }

  void _drawStationAreaRed(Canvas canvas, Size size, double topOffset) {
    final w = size.width;
    final stationStyle = TextStyle(
      fontSize: 50, fontWeight: FontWeight.bold, color: Colors.black,
    );
    final startSpacing = getStationSpacing(ticket.startStation);
    final endSpacing = getStationSpacing(ticket.endStation);

    double leftStart = ticket.startStation.length == 5 ? 50 : 95;
    double leftEnd = ticket.endStation.length == 5 ? w / 2 + 80 : w / 2 + 120;

    drawInkText(canvas, ticket.startStation, leftStart, topOffset + 40,
        stationStyle, spacing: startSpacing);
    drawInkText(canvas, ticket.endStation, leftEnd, topOffset + 40,
        stationStyle, spacing: endSpacing);

    drawText(canvas, '站', 275, topOffset + 33,
        TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.black));
    drawText(canvas, '站', w - 145, topOffset + 33,
        TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.black));

    final pinyinStyle = TextStyle(fontSize: 32, color: Colors.black);
    final startPinyin = toPinyin(ticket.startStation);
    final endPinyin = toPinyin(ticket.endStation);
    final startPW = measureText(startPinyin, pinyinStyle);
    final endPW = measureText(endPinyin, pinyinStyle);
    drawText(canvas, startPinyin, 200 - startPW / 2, topOffset + 78, pinyinStyle);
    drawText(canvas, endPinyin, w / 2 + 220 - endPW / 2, topOffset + 78, pinyinStyle);

    final trainStyle = TextStyle(fontSize: 44, color: Colors.black);
    final trainW = measureText(ticket.trainNumber, trainStyle);
    drawInkText(canvas, ticket.trainNumber, w / 2 - trainW / 2, topOffset + 42, trainStyle, spacing: 2);

    final arrowPaint = Paint()
      ..color = Colors.black..strokeWidth = 2..style = PaintingStyle.stroke;
    final ax = w / 2 - 63.0;
    final ay = topOffset + 55.0;
    canvas.drawLine(Offset(ax, ay), Offset(ax + 126, ay), arrowPaint);
    canvas.drawLine(Offset(ax + 111, ay - 5), Offset(ax + 126, ay), arrowPaint);
  }

  void _drawDateSeatAreaRed(Canvas canvas, Size size, double topOffset) {
    final w = size.width;
    final mainStyle = TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.black);
    final smallStyle = TextStyle(fontSize: 24, color: Colors.black);
    const lo = 75.0;

    final year = ticket.date.year.toString();
    final month = padLeft2(ticket.date.month);
    final day = padLeft2(ticket.date.day);

    drawInkText(canvas, year, lo - 2, topOffset + 127, mainStyle, spacing: -2);
    drawInkText(canvas, month, lo + 112, topOffset + 127, mainStyle, spacing: -2);
    drawInkText(canvas, day, lo + 181, topOffset + 127, mainStyle, spacing: -2);
    drawInkText(canvas, ticket.time, lo + 253, topOffset + 127, mainStyle, spacing: -2);

    drawText(canvas, '年', lo + 83, topOffset + 125, smallStyle);
    drawText(canvas, '月', lo + 156, topOffset + 125, smallStyle);
    drawText(canvas, '日', lo + 223, topOffset + 125, smallStyle);
    drawText(canvas, '开', lo + 357, topOffset + 125, smallStyle);
    drawText(canvas, '车', lo + 523, topOffset + 125, smallStyle);

    final carriage = padLeft2(ticket.seatCarriage);
    drawInkText(canvas, carriage, w / 2 + 107, topOffset + 127, mainStyle, spacing: -2);

    String seatNum = padLeft3(ticket.seatNumber);
    final noSeat = seatNum == '000';
    if (!noSeat) drawText(canvas, '号', lo + 613, topOffset + 125, smallStyle);

    if (noSeat) {
      drawText(canvas, '无座', w / 2 + 175, topOffset + 130,
          TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.black));
    } else if (ticket.berth.isNotEmpty) {
      drawInkText(canvas, seatNum, w / 2 + 177, topOffset + 127, mainStyle, spacing: -3);
      drawText(canvas, '号${ticket.berth}', w / 2 + 240, topOffset + 130,
          TextStyle(fontSize: 34, color: Colors.black));
    } else {
      drawInkText(canvas, seatNum, w / 2 + 175, topOffset + 127, mainStyle, spacing: -3);
    }

    final seatStyle = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black);
    final seatW = measureText(ticket.seatType, seatStyle);
    drawText(canvas, ticket.seatType, 650 - seatW / 2, topOffset + 175, seatStyle);
  }

  void _drawPriceAreaRed(Canvas canvas, Size size, double topOffset) {
    final w = size.width;
    const lo = 75.0;
    final priceStr = ticket.price.toStringAsFixed(1);
    drawText(canvas, '￥', lo + 7, topOffset + 178,
        TextStyle(fontSize: 28, color: Colors.black));
    final priceStyle = TextStyle(fontSize: 34, color: Colors.black);
    drawInkText(canvas, priceStr, lo + 38, topOffset + 177, priceStyle, spacing: -2);
    final priceW = measureText(priceStr, priceStyle);
    drawText(canvas, '元', lo + 35 + priceW, topOffset + 175,
        TextStyle(fontSize: 24, color: Colors.black));

    final markStyle = TextStyle(fontSize: 34, color: Colors.black);
    double markX = w / 2 - 50;
    if (ticket.isStudent) {
      drawText(canvas, '学', markX, topOffset + 175, markStyle);
      markX += 45;
    }
    if (ticket.isChild) {
      drawText(canvas, '孩', markX, topOffset + 175, markStyle);
      markX += 45;
    }
    if (ticket.isDiscount) {
      drawText(canvas, '折', markX, topOffset + 175, markStyle);
    }
  }

  @override
  bool shouldRepaint(RedReceiptPainter old) => true;
}

class RedTicketPainter extends RedReceiptPainter {
  RedTicketPainter(super.ticket);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);
    _drawRedTicketBackground(canvas, size);

    drawText(canvas, ticket.redId, 80, 50,
        TextStyle(fontSize: 44, color: const Color(0x7FFF0000),
            fontWeight: FontWeight.bold));

    if (ticket.checkGate.isNotEmpty) {
      final gateText = '检票:${ticket.checkGate}';
      final gateStyle = TextStyle(fontSize: 34, color: Colors.black);
      final gateW = measureText(gateText, gateStyle);
      drawText(canvas, gateText, w - gateW - 100, 50, gateStyle);
    }

    const topOffset = 50.0;
    _drawStationAreaRed(canvas, size, topOffset);
    _drawDateSeatAreaRed(canvas, size, topOffset);
    _drawPriceAreaRed(canvas, size, topOffset);

    // 限乘当日当次车
    drawText(canvas, '限乘当日当次车', 80, 345,  // 修改：从323改为345
        TextStyle(fontSize: 34, color: Colors.black));

    // 仅供纪念
    drawText(canvas, '仅供纪念使用', 340, 375,  // 修改：从353改为375
        TextStyle(fontSize: 34, color: Colors.black));

    // 乘客信息
    drawPassengerArea(canvas, 425);  // 修改：从403改为425

    // 虚线框
    drawDashRect(canvas, 95, 445, 500, 80, 16, 4);  // 修改：从423改为445
    final boxStyle = TextStyle(fontSize: 28, color: Colors.black);
    final t1 = '买票请到12306 发货请到95306';
    final t2 = '中国铁路祝您旅途愉快';
    final t1w = measureText(t1, boxStyle);
    final t2w = measureText(t2, boxStyle);
    drawText(canvas, t1, 95 + 500 / 2 - t1w / 2, 475, boxStyle);  // 修改：从453改为475
    drawText(canvas, t2, 95 + 500 / 2 - t2w / 2, 513, boxStyle);  // 修改：从491改为513

    // 二维码
    drawQRCode(canvas, 95 + 500 + 65, 385, 180);  // 修改：从363改为385

    // 票号 + 售票点
    drawTicketId(canvas, size, h - 70);
  }

  @override
  bool shouldRepaint(RedTicketPainter old) => true;
}

// ─────────────────────────────────────────────
// 票背面 Painter（通用）
// ─────────────────────────────────────────────
class TicketBackPainter extends BaseTicketPainter {
  final bool isRed;
  final bool isReceipt;
  TicketBackPainter(super.ticket, {this.isRed = false, this.isReceipt = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (isRed) {
      // 红票背面：灰白色背景
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
          Paint()..color = const Color(0xFFF2F2F2));

      final color = <int>[0, 0, 0];
      drawText(canvas, '乘车须知：', 40, 50,
          TextStyle(fontSize: 35, color: Colors.black));
      drawText(canvas, '☆正在开发中，敬请期待！', 40, 100,
          TextStyle(fontSize: 25, color: Colors.black));

      // 底部黑框
      canvas.drawRect(Rect.fromLTWH(0, h - 40, w, 40),
          Paint()..color = Colors.black);
    } else {
      // 蓝票背面：黑色背景
      drawRoundRect(canvas, 20, 10, w - 40, h - 20, 20,
          const Color(0xE6000000));

      final trapPaint = Paint()..color = const Color(0xE6000000);
      drawTrapezoid(canvas, trapPaint, 10, h * 0.2, 10, 40, 5, true);
      drawTrapezoid(canvas, trapPaint, w - 10, h * 0.2, 10, 40, 5, false);
      drawTrapezoid(canvas, trapPaint, 10, h * 0.8, 10, 40, 5, true);
      drawTrapezoid(canvas, trapPaint, w - 10, h * 0.8, 10, 40, 5, false);

      final grayColor = const Color(0xFFB4B4B4);

      if (isReceipt) {
        final titleStyle = TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: grayColor);
        final title = '报销凭证使用须知';
        final titleW = measureText(title, titleStyle);
        drawText(canvas, title, w / 2 - titleW / 2, 50, titleStyle);

        const notice = '购票后如需报销凭证的，应在开车前或乘车日期之日起180日以内（含当日），持购票时所使用的有效身份证件原件到车站售票窗口、自动售票机领取。退票后如需退票费报销凭证，应在办理之日起180天以内（含当日），持购票时所使用的有效身份证件原件到车站退票窗口领取。报销凭证开具后请妥善保管，丢失后将无法办理补办申领手续。已领取报销凭证的车票办理改签、退票或退款手续时，须交回报销凭证方可办理。报销凭证不能作为乘车凭证使用。';
        _drawWrappedText(canvas, notice, 40, 110, w - 80, 32, grayColor);
      } else {
        final titleStyle = TextStyle(fontSize: 35, color: grayColor);
        drawText(canvas, '乘车须知：', 100, 50, titleStyle);
        drawText(canvas, '☆正在开发中，敬请期待！', 40, 100,
            TextStyle(fontSize: 25, color: grayColor));
      }
    }
  }

  void _drawWrappedText(Canvas canvas, String text, double x, double y,
      double maxWidth, double lineHeight, Color color) {
    final style = TextStyle(fontSize: 22, color: color);
    final words = text.split('');
    String line = '';
    double curY = y;

    for (int i = 0; i < words.length; i++) {
      final testLine = line + words[i];
      final w = measureText(testLine, style);
      if (w > maxWidth && line.isNotEmpty) {
        drawText(canvas, line, x, curY, style);
        line = words[i];
        curY += lineHeight;
      } else {
        line = testLine;
      }
    }
    if (line.isNotEmpty) drawText(canvas, line, x, curY, style);
  }

  @override
  bool shouldRepaint(TicketBackPainter old) => true;
}

// ─────────────────────────────────────────────
// 票面 Widget
// ─────────────────────────────────────────────
class TicketCanvas extends StatelessWidget {
  final TicketData ticket;
  final String ticketType; // blueReceipt, blueTicket, redReceipt, redTicket
  final bool isBack;

  const TicketCanvas({
    super.key,
    required this.ticket,
    required this.ticketType,
    this.isBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isRed = ticketType.startsWith('red');
    final bool isReceipt = ticketType.endsWith('Receipt');

    return AspectRatio(
      aspectRatio: isRed ? 900 / 600 : 856 / 540,
      child: CustomPaint(
        painter: isBack
            ? TicketBackPainter(ticket, isRed: isRed, isReceipt: isReceipt)
            : _getFrontPainter(),
      ),
    );
  }

  CustomPainter _getFrontPainter() {
    switch (ticketType) {
      case 'blueReceipt': return BlueReceiptPainter(ticket);
      case 'blueTicket': return BlueTicketPainter(ticket);
      case 'redReceipt': return RedReceiptPainter(ticket);
      case 'redTicket': return RedTicketPainter(ticket);
      default: return BlueReceiptPainter(ticket);
    }
  }
}

// ─────────────────────────────────────────────
// 表单字段 Widget
// ─────────────────────────────────────────────
class _FieldItem extends StatelessWidget {
  final String label;
  final Widget child;
  final int colSpan;

  const _FieldItem({
    required this.label,
    required this.child,
    this.colSpan = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

InputDecoration _inputDeco() => InputDecoration(
  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(6),
    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
  ),
  isDense: true,
);

// ─────────────────────────────────────────────
// 主表单 Widget
// ─────────────────────────────────────────────
class TicketForm extends StatefulWidget {
  final TicketData data;
  final ValueChanged<TicketData> onChanged;

  const TicketForm({super.key, required this.data, required this.onChanged});

  @override
  State<TicketForm> createState() => _TicketFormState();
}

class _TicketFormState extends State<TicketForm> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final d = widget.data;
    _controllers['redId'] = TextEditingController(text: d.redId);
    _controllers['id'] = TextEditingController(text: d.id);
    _controllers['startStation'] = TextEditingController(text: d.startStation);
    _controllers['endStation'] = TextEditingController(text: d.endStation);
    _controllers['checkGate'] = TextEditingController(text: d.checkGate);
    _controllers['ticketOffice'] = TextEditingController(text: d.ticketOffice);
    _controllers['trainNumber'] = TextEditingController(text: d.trainNumber);
    _controllers['price'] = TextEditingController(text: d.price.toString());
    _controllers['seatCarriage'] = TextEditingController(text: d.seatCarriage);
    _controllers['seatNumber'] = TextEditingController(text: d.seatNumber);
    _controllers['passengerName'] = TextEditingController(text: d.passengerName);
    _controllers['passengerId'] = TextEditingController(text: d.passengerId);
    _controllers['seatType'] = TextEditingController(text: d.seatType);
    _controllers['berth'] = TextEditingController(text: d.berth);
    _controllers['qrCodeId'] = TextEditingController(text: d.qrCodeId);
    _controllers['time'] = TextEditingController(text: d.time);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  void _update(TicketData newData) => widget.onChanged(newData);

  Widget _textField(String key, String label,
      {int maxLength = 100, bool chineseOnly = false,
       bool engNumOnly = false, int colSpan = 1}) {
    return _FieldItem(
      label: label,
      colSpan: colSpan,
      child: TextField(
        controller: _controllers[key],
        maxLength: maxLength,
        decoration: _inputDeco().copyWith(counterText: ''),
        style: const TextStyle(fontSize: 13),
        onChanged: (v) {
          final d = widget.data;
          switch (key) {
            case 'redId': _update(d.copyWith(redId: v)); break;
            case 'id': _update(d.copyWith(id: v)); break;
            case 'startStation': _update(d.copyWith(startStation: v)); break;
            case 'endStation': _update(d.copyWith(endStation: v)); break;
            case 'checkGate': _update(d.copyWith(checkGate: v)); break;
            case 'ticketOffice': _update(d.copyWith(ticketOffice: v)); break;
            case 'trainNumber': _update(d.copyWith(trainNumber: v)); break;
            case 'seatCarriage': _update(d.copyWith(seatCarriage: v)); break;
            case 'seatNumber': _update(d.copyWith(seatNumber: v)); break;
            case 'passengerName': _update(d.copyWith(passengerName: v)); break;
            case 'passengerId': _update(d.copyWith(passengerId: v)); break;
            case 'seatType': _update(d.copyWith(seatType: v)); break;
            case 'berth': _update(d.copyWith(berth: v)); break;
            case 'qrCodeId': _update(d.copyWith(qrCodeId: v)); break;
            case 'time': _update(d.copyWith(time: v)); break;
          }
        },
      ),
    );
  }

  Widget _numberField(String key, String label) {
    return _FieldItem(
      label: label,
      child: TextField(
        controller: _controllers[key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _inputDeco().copyWith(counterText: ''),
        style: const TextStyle(fontSize: 13),
        onChanged: (v) {
          final parsed = double.tryParse(v);
          if (parsed != null) _update(widget.data.copyWith(price: parsed));
        },
      ),
    );
  }

  Widget _checkboxField(String label, bool value, ValueChanged<bool?> onChanged) {
    return _FieldItem(
      label: '',
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6366F1),
          ),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    return Column(
      children: [
        // 票号行
        Row(children: [
          Expanded(flex: 2, child: _textField('redId', '上票号', maxLength: 11, engNumOnly: true)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _textField('id', '下票号', maxLength: 21, engNumOnly: true)),
        ]),
        const SizedBox(height: 12),

        // 将包含4个字段的Row改为Wrap
        Wrap(
          spacing: 12,  // 水平间距
          runSpacing: 12,  // 垂直间距
          children: [
            Expanded(child: _textField('startStation', '出发地', maxLength: 5, chineseOnly: true)),
            Expanded(child: _textField('endStation', '目的地', maxLength: 5, chineseOnly: true)),
            Expanded(child: _textField('checkGate', '检票口', maxLength: 12)),
            Expanded(child: _textField('ticketOffice', '售票点', maxLength: 6, chineseOnly: true)),
          ],
        ),
        const SizedBox(height: 12),

        // 将包含5个字段的Row改为Wrap
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Expanded(child: _textField('trainNumber', '车次', maxLength: 6, engNumOnly: true)),
            Expanded(child: _numberField('price', '价格')),
            Expanded(
              child: _FieldItem(
                label: '日期',
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: d.date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2099),
                    );
                    if (picked != null) _update(d.copyWith(date: picked));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${d.date.year}-${padLeft2(d.date.month)}-${padLeft2(d.date.day)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: _textField('time', '时间', maxLength: 5)),
          ],
        ),
        const SizedBox(height: 12),

        // 将包含4个字段的Row改为Wrap
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Expanded(child: _textField('seatCarriage', '车厢号', maxLength: 2)),
            Expanded(child: _textField('seatNumber', '座位号', maxLength: 3, engNumOnly: true)),
            Expanded(child: _textField('seatType', '席别', maxLength: 5, chineseOnly: true)),
            Expanded(child: _textField('berth', '铺位', maxLength: 3, chineseOnly: true)),
          ],
        ),
        const SizedBox(height: 12),

        Row(children: [
          Expanded(child: _textField('passengerName', '姓名', maxLength: 12, chineseOnly: true)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _textField('passengerId', '身份证号', maxLength: 18)),
        ]),
        const SizedBox(height: 12),

        _textField('qrCodeId', '二维码内容', maxLength: 144),
        const SizedBox(height: 12),

        // 复选框行改为Wrap
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            Expanded(child: _checkboxField('儿童票', d.isChild, (v) {
              if (v == true) _update(d.copyWith(isChild: true, isStudent: false));
              else _update(d.copyWith(isChild: false));
            })),
            Expanded(child: _checkboxField('学生票', d.isStudent, (v) {
              if (v == true) _update(d.copyWith(isStudent: true, isChild: false, isDiscount: true));
              else _update(d.copyWith(isStudent: false));
            })),
            Expanded(child: _checkboxField('优惠票', d.isDiscount, (v) {
              if (!d.isStudent) _update(d.copyWith(isDiscount: v ?? false));
            })),
            Expanded(child: _checkboxField('网络售票', d.isNet, (v) {
              _update(d.copyWith(isNet: v ?? false));
            })),
            Expanded(child: _checkboxField('退票费', d.isRefund, (v) {
              _update(d.copyWith(isRefund: v ?? false));
            })),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 主 App
// ─────────────────────────────────────────────

class TicketGeneratorPage extends StatefulWidget {
  const TicketGeneratorPage({super.key});

  @override
  State<TicketGeneratorPage> createState() => _TicketGeneratorPageState();
}

class _TicketGeneratorPageState extends State<TicketGeneratorPage> {
  TicketData _ticketData = TicketData();
  String _activeTab = 'blueReceipt';

  // Screenshot controllers — 正面和背面各一个
  final ScreenshotController _frontController = ScreenshotController();
  final ScreenshotController _backController = ScreenshotController();
  bool _isSaving = false;

  static const List<Map<String, String>> _tabs = [
    {'key': 'blueReceipt', 'label': '蓝票（报销凭证）'},
    {'key': 'blueTicket', 'label': '蓝票（实名车票）'},
    {'key': 'redReceipt', 'label': '红票（报销凭证）'},
    {'key': 'redTicket', 'label': '红票（实名车票）'},
  ];

  /// 保存正面或背面到相册
  Future<void> _saveToGallery(bool isFront) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 1. 检查并请求权限
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('需要相册权限才能保存图片'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // 2. 截图（pixelRatio 提高清晰度）
      final controller = isFront ? _frontController : _backController;
      final bytes = await controller.capture(pixelRatio: 3.0);
      if (bytes == null) throw Exception('截图失败');

      // 3. 保存到相册
      await Gal.putImageBytes(bytes, album: '火车票');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isFront ? "正面" : "背面"}已保存到相册'),
            backgroundColor: const Color(0xFF6366F1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败：$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha:0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  _buildHeader(),
                  const SizedBox(height: 20),

                  // 表单
                  TicketForm(
                    data: _ticketData,
                    onChanged: (d) => setState(() => _ticketData = d),
                  ),
                  const SizedBox(height: 20),

                  // Tabs
                  _buildTabs(),
                  const SizedBox(height: 16),

                  // 票面预览
                  _buildTicketPreview(),

                  const SizedBox(height: 20),
                  // 页脚
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.train, color: Color(0xFF6366F1), size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('火车票生成器',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Train Ticket Generator',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: const Color(0xFFE5E7EB)),
      ],
    );
  }

  Widget _buildTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _tabs.map((tab) {
          final isActive = _activeTab == tab['key'];
          return GestureDetector(
            onTap: () => setState(() => _activeTab = tab['key']!),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF6366F1) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tab['label']!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTicketPreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTicketCard('正面', false)),
              const SizedBox(width: 16),
              Expanded(child: _buildTicketCard('背面', true)),
            ],
          );
        } else {
          return Column(
            children: [
              _buildTicketCard('正面', false),
              const SizedBox(height: 16),
              _buildTicketCard('背面', true),
            ],
          );
        }
      },
    );
  }

  Widget _buildTicketCard(String title, bool isBack) {
    final controller = isBack ? _backController : _frontController;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行 + 保存按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
            TextButton.icon(
              onPressed: _isSaving ? null : () => _saveToGallery(!isBack),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)))
                  : const Icon(Icons.download, size: 16),
              label: Text(_isSaving ? '保存中...' : '保存到相册',
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Screenshot 包裹票面
        Screenshot(
          controller: controller,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TicketCanvas(
                ticket: _ticketData,
                ticketType: _activeTab,
                isBack: isBack,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(height: 1, color: const Color(0xFFE5E7EB)),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 14, color: Color(0xFF9CA3AF)),
            SizedBox(width: 4),
            Text(
              '本项目仅供学习研究用途，禁止用于非法用途',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ],
    );
  }
}
