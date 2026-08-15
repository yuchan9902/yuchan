import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/stats.dart';

/// 세로 막대 차트. 값이 0인 칸도 자리를 남겨 시간 흐름이 끊기지 않게 그린다.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    super.key,
    required this.points,
    this.height = 160,
    this.color,
    this.labelEvery,
    this.valueFormatter,
    this.highlightMax = true,
  });

  final List<ChartPoint> points;
  final double height;
  final Color? color;

  /// 라벨을 몇 칸마다 그릴지. null이면 칸 수에 맞춰 자동으로 정한다.
  final int? labelEvery;
  final String Function(double)? valueFormatter;
  final bool highlightMax;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (points.isEmpty) {
      return _ChartEmpty(height: height);
    }
    final step = labelEvery ?? max(1, (points.length / 7).ceil());
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _BarChartPainter(
          points: points,
          barColor: color ?? c.accent,
          mutedColor: (color ?? c.accent).withValues(alpha: 0.28),
          gridColor: c.border,
          labelColor: c.textFaint,
          labelEvery: step,
          highlightMax: highlightMax,
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.points,
    required this.barColor,
    required this.mutedColor,
    required this.gridColor,
    required this.labelColor,
    required this.labelEvery,
    required this.highlightMax,
  });

  final List<ChartPoint> points;
  final Color barColor;
  final Color mutedColor;
  final Color gridColor;
  final Color labelColor;
  final int labelEvery;
  final bool highlightMax;

  static const double _labelHeight = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - _labelHeight;
    if (plotHeight <= 0) return;

    final maxValue = points.fold(0.0, (m, p) => p.value > m ? p.value : m);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    // 기준선 3개.
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = plotHeight * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final slot = size.width / points.length;
    final barWidth = min(slot * 0.62, 22.0);
    final radius = Radius.circular(barWidth / 2.6);

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final cx = slot * i + slot / 2;

      if (p.value > 0) {
        final barHeight = max(3.0, plotHeight * (p.value / safeMax));
        final isMax = highlightMax && p.value == maxValue;
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barWidth / 2, plotHeight - barHeight, barWidth, barHeight),
          topLeft: radius,
          topRight: radius,
        );
        final paint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isMax
                ? [barColor, barColor.withValues(alpha: 0.55)]
                : [mutedColor, mutedColor.withValues(alpha: 0.35)],
          ).createShader(rect.outerRect);
        canvas.drawRRect(rect, paint);
      } else {
        // 쉰 날은 얇은 점선 자국만 남긴다.
        final dot = Paint()..color = gridColor;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - barWidth / 2, plotHeight - 3, barWidth, 3),
            const Radius.circular(2),
          ),
          dot,
        );
      }

      // 마지막 라벨은 항상 그리고, 그 바로 앞의 주기 라벨은 겹치므로 건너뛴다.
      final last = points.length - 1;
      if (i == last || (i % labelEvery == 0 && last - i >= labelEvery * 0.6)) {
        _paintLabel(canvas, p.label, cx, plotHeight + 4, size.width);
      }
    }
  }

  void _paintLabel(Canvas canvas, String text, double cx, double top, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx =
        (cx - tp.width / 2).clamp(0.0, max(0.0, maxWidth - tp.width)).toDouble();
    tp.paint(canvas, Offset(dx, top));
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.points != points || old.barColor != barColor;
}

/// 추이용 라인 차트. 점이 하나뿐이면 가로선으로 표시한다.
class MiniLineChart extends StatelessWidget {
  const MiniLineChart({
    super.key,
    required this.points,
    this.height = 180,
    this.color,
    this.valueFormatter,
  });

  final List<ChartPoint> points;
  final double height;
  final Color? color;
  final String Function(double)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (points.isEmpty) return _ChartEmpty(height: height);
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _LineChartPainter(
          points: points,
          lineColor: color ?? c.accent,
          gridColor: c.border,
          labelColor: c.textFaint,
          surfaceColor: c.surface,
          formatter: valueFormatter ?? (v) => v.toStringAsFixed(0),
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.surfaceColor,
    required this.formatter,
  });

  final List<ChartPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final Color surfaceColor;
  final String Function(double) formatter;

  static const double _labelHeight = 18;
  static const double _padTop = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - _labelHeight - _padTop;
    if (plotHeight <= 0) return;

    var minV = points.first.value;
    var maxV = points.first.value;
    for (final p in points) {
      minV = min(minV, p.value);
      maxV = max(maxV, p.value);
    }
    // 값이 모두 같으면 0으로 나누지 않도록 위아래로 여유를 준다.
    if (maxV - minV < 1e-6) {
      maxV += 1;
      minV -= 1;
    } else {
      final pad = (maxV - minV) * 0.15;
      maxV += pad;
      minV -= pad;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = _padTop + plotHeight * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    double xAt(int i) => points.length == 1
        ? size.width / 2
        : size.width * i / (points.length - 1);
    double yAt(double v) => _padTop + plotHeight * (1 - (v - minV) / (maxV - minV));

    final path = Path();
    final fill = Path();
    for (var i = 0; i < points.length; i++) {
      final x = xAt(i);
      final y = yAt(points[i].value);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, _padTop + plotHeight);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(xAt(points.length - 1), _padTop + plotHeight);
    fill.close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withValues(alpha: 0.28), lineColor.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, _padTop, size.width, plotHeight)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 마지막 점만 강조하고, 나머지는 작은 점으로.
    for (var i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      final center = Offset(xAt(i), yAt(points[i].value));
      canvas.drawCircle(center, isLast ? 5.5 : 3, Paint()..color = surfaceColor);
      canvas.drawCircle(
        center,
        isLast ? 5.5 : 3,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = isLast ? 3 : 2,
      );
    }

    // 마지막 값 라벨.
    final last = points.last;
    final tp = TextPainter(
      text: TextSpan(
        text: formatter(last.value),
        style: TextStyle(color: lineColor, fontSize: 11, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final lx = (xAt(points.length - 1) - tp.width / 2)
        .clamp(0.0, max(0.0, size.width - tp.width))
        .toDouble();
    final ly = max(0.0, yAt(last.value) - 20);
    tp.paint(canvas, Offset(lx, ly));

    // 처음/마지막 x 라벨.
    _paintLabel(canvas, points.first.label, 0, size.height - _labelHeight + 2);
    if (points.length > 1) {
      final endTp = _textPainter(points.last.label);
      endTp.paint(
        canvas,
        Offset(size.width - endTp.width, size.height - _labelHeight + 2),
      );
    }
  }

  TextPainter _textPainter(String text) => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  void _paintLabel(Canvas canvas, String text, double x, double y) =>
      _textPainter(text).paint(canvas, Offset(x, y));

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.points != points || old.lineColor != lineColor;
}

/// 부위별 분포 도넛. 가운데에는 임의의 위젯을 넣을 수 있다.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.size = 168,
    this.center,
  });

  final List<GroupSlice> slices;
  final double size;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(
              slices: slices,
              trackColor: c.surfaceAlt,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.trackColor});

  final List<GroupSlice> slices;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.16;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    canvas.drawArc(
      rect,
      0,
      2 * pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );

    if (slices.isEmpty) return;

    // 조각 사이에 작은 간격을 둬서 경계가 보이게 한다.
    const gap = 0.035;
    var start = -pi / 2;
    for (final s in slices) {
      final sweep = 2 * pi * s.ratio;
      if (sweep <= gap) {
        start += sweep;
        continue;
      }
      canvas.drawArc(
        rect,
        start + gap / 2,
        sweep - gap,
        false,
        Paint()
          ..color = s.group.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices;
}

/// 목표 달성률 링.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 92,
    this.stroke = 9,
    this.color,
  });

  final double progress;
  final Widget child;
  final double size;
  final double stroke;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                progress: value,
                color: color ?? c.accent,
                trackColor: c.surfaceAlt,
                stroke: stroke,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    canvas.drawArc(
      rect,
      0,
      2 * pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -pi / 2,
          endAngle: 3 * pi / 2,
          colors: [color.withValues(alpha: 0.55), color],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          '표시할 기록이 없어요',
          style: TextStyle(color: c.textFaint, fontSize: 13),
        ),
      ),
    );
  }
}
