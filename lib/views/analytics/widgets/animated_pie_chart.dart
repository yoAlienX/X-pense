import 'dart:math' as math;

import 'package:flutter/material.dart';

const double _defaultPieChartSize = 220.0;
const double _defaultPieChartStrokeWidth = 44.0;

class PieChartSegment {
  final String label;
  final double value;
  final Color color;
  final bool isSelected;

  const PieChartSegment({
    required this.label,
    required this.value,
    required this.color,
    this.isSelected = true,
  });
}

class AnimatedPieChart extends StatefulWidget {
  final List<PieChartSegment> segments;
  final Widget Function(BuildContext context, double total)? centerBuilder;
  final double size;
  final double strokeWidth;
  final Color backgroundColor;

  const AnimatedPieChart({
    super.key,
    required this.segments,
    this.centerBuilder,
    this.size = _defaultPieChartSize,
    this.strokeWidth = _defaultPieChartStrokeWidth,
    this.backgroundColor = const Color(0xFF17202A),
  });

  @override
  State<AnimatedPieChart> createState() => _AnimatedPieChartState();
}

class _AnimatedPieChartState extends State<AnimatedPieChart>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final AnimationController _pressController;

  int? _pressedIndex;
  int? _animatingPressIndex;
  late List<double> _startValues;
  late List<double> _targetValues;

  double get _outerRadius => widget.size / 2;
  double get _innerRadius => _outerRadius - widget.strokeWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _startValues = widget.segments.map((segment) => segment.value).toList();
    _targetValues = widget.segments
        .map((segment) => segment.isSelected ? segment.value : 0.0)
        .toList();

    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant AnimatedPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    final List<double> newTargets = widget.segments
        .map((segment) => segment.isSelected ? segment.value : 0.0)
        .toList();

    bool valuesChanged = false;
    if (newTargets.length != _targetValues.length) {
      valuesChanged = true;
    } else {
      for (int i = 0; i < newTargets.length; i++) {
        if (newTargets[i] != _targetValues[i]) {
          valuesChanged = true;
          break;
        }
      }
    }

    if (valuesChanged) {
      final int previousLength = math.min(
        _startValues.length,
        _targetValues.length,
      );
      final List<double> inFlightValues = List.generate(previousLength, (
        index,
      ) {
        return _startValues[index] +
            (_targetValues[index] - _startValues[index]) * _animation.value;
      });

      _startValues = List.generate(newTargets.length, (index) {
        if (index < inFlightValues.length) {
          return inFlightValues[index];
        }
        return widget.segments[index].value;
      });
      _targetValues = newTargets;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pressController.dispose();
    super.dispose();
  }

  int? _getSliceIndexAt(Offset position, List<double> values) {
    final center = Offset(_outerRadius, _outerRadius);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final r = math.sqrt(dx * dx + dy * dy);

    if (r < _innerRadius || r > _outerRadius) return null;

    double touchAngle = math.atan2(dy, dx);
    double touchAngleShifted = touchAngle + math.pi / 2;
    if (touchAngleShifted < 0) {
      touchAngleShifted += math.pi * 2;
    }

    final double total = values.fold(0.0, (sum, value) => sum + value);
    if (total <= 0.1) return null;

    double currentShifted = 0.0;
    for (int i = 0; i < values.length; i++) {
      if (values[i] < 0.1) continue;

      final double sweepAngle = (values[i] / total) * math.pi * 2;
      if (touchAngleShifted >= currentShifted &&
          touchAngleShifted <= currentShifted + sweepAngle) {
        return i;
      }
      currentShifted += sweepAngle;
    }

    return null;
  }

  void _onPanDown(DragDownDetails details, List<double> currentValues) {
    final int? index = _getSliceIndexAt(details.localPosition, currentValues);
    if (index == null) return;

    setState(() {
      _pressedIndex = index;
      _animatingPressIndex = index;
    });
    _pressController.forward();
  }

  void _onPanEndOrCancel() {
    if (_pressedIndex == null) return;

    setState(() {
      _pressedIndex = null;
    });
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_animation, _pressController]),
      builder: (context, child) {
        final List<double> currentValues = List.generate(
          _targetValues.length,
          (index) =>
              _startValues[index] +
              (_targetValues[index] - _startValues[index]) * _animation.value,
        );
        final double currentTotal = currentValues.fold(
          0.0,
          (sum, value) => sum + value,
        );

        return GestureDetector(
          onPanDown: (details) => _onPanDown(details, currentValues),
          onPanEnd: (_) => _onPanEndOrCancel(),
          onPanCancel: _onPanEndOrCancel,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: PieChartPainter(
                  segments: widget.segments,
                  currentValues: currentValues,
                  pressedIndex: _pressedIndex ?? _animatingPressIndex,
                  pressedScale: _pressController.value,
                  strokeWidth: widget.strokeWidth,
                ),
              ),
              if (widget.centerBuilder != null)
                widget.centerBuilder!(context, currentTotal),
            ],
          ),
        );
      },
    );
  }
}

class PieChartPainter extends CustomPainter {
  final List<PieChartSegment> segments;
  final List<double> currentValues;
  final int? pressedIndex;
  final double pressedScale;
  final double strokeWidth;

  PieChartPainter({
    required this.segments,
    required this.currentValues,
    required this.strokeWidth,
    this.pressedIndex,
    this.pressedScale = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double total = currentValues.fold(0.0, (sum, value) => sum + value);
    if (total <= 0.1) return;

    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    double startAngle = -math.pi / 2;
    const double gapAngle = 0.05;
    final int visibleCount = currentValues.where((value) => value > 0.1).length;

    for (int i = 0; i < segments.length; i++) {
      final double value = currentValues[i];
      if (value < 0.1) continue;

      final double sweepAngle = (value / total) * math.pi * 2;
      double actualSweep = sweepAngle;
      double actualStart = startAngle;

      if (visibleCount > 1) {
        final double currentGap = math.min(gapAngle, sweepAngle * 0.5);
        actualStart += currentGap / 2;
        actualSweep -= currentGap;
      }

      double pushOut = 0.0;
      if (i == pressedIndex) {
        pushOut = 8.0 * pressedScale;
      }

      final Rect currentRect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: radius + pushOut,
      );

      final paint = Paint()
        ..color = segments[i].color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + pushOut
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(currentRect, actualStart, actualSweep, false, paint);

      if (actualSweep > 0.25) {
        final int percentage = (value / total * 100).round();
        if (percentage > 0) {
          final double midAngle = actualStart + actualSweep / 2;
          final double textRadius = radius + pushOut;
          final double dx = size.width / 2 + math.cos(midAngle) * textRadius;
          final double dy = size.height / 2 + math.sin(midAngle) * textRadius;

          final textPainter = TextPainter(
            text: TextSpan(
              text: '$percentage%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(dx - textPainter.width / 2, dy - textPainter.height / 2),
          );
        }
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.currentValues != currentValues ||
        oldDelegate.pressedIndex != pressedIndex ||
        oldDelegate.pressedScale != pressedScale ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
