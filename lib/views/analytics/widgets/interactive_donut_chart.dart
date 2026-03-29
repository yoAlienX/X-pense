import 'dart:math' as math;

import 'package:flutter/material.dart';

class DonutSegment {
  const DonutSegment({
    required this.label,
    required this.value,
    required this.color,
    this.enabled = true,
  });

  final String label;
  final double value;
  final Color color;
  final bool enabled;
}

class InteractiveDonutChart extends StatefulWidget {
  const InteractiveDonutChart({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSelected,
    required this.centerBuilder,
    this.size = 220,
    this.strokeWidth = 44,
  });

  final List<DonutSegment> segments;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget Function(BuildContext context, double total) centerBuilder;
  final double size;
  final double strokeWidth;

  @override
  State<InteractiveDonutChart> createState() => _InteractiveDonutChartState();
}

class _InteractiveDonutChartState extends State<InteractiveDonutChart>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final AnimationController _valueController;
  late final AnimationController _entryController;
  late final Animation<double> _valueAnimation;
  late final Animation<double> _entryAnimation;
  int? _pressedIndex;
  late List<double> _startValues;
  late List<double> _targetValues;
  List<int> _revealOrder = [];

  double get _outerRadius => widget.size / 2;
  double get _innerRadius => _outerRadius - widget.strokeWidth;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );

    _valueController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _valueAnimation = CurvedAnimation(
      parent: _valueController,
      curve: Curves.easeInOutCubic,
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );

    _startValues = List<double>.filled(
      widget.segments.length,
      0.0,
      growable: false,
    );
    _targetValues = widget.segments
        .map((segment) => segment.enabled ? segment.value : 0.0)
        .toList(growable: false);
    _valueController.value = 1.0;

    _revealOrder = _buildRevealOrder(widget.segments);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entryController.forward(from: 0.0);
    });
  }

  @override
  void didUpdateWidget(covariant InteractiveDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newTargets = widget.segments
        .map((segment) => segment.enabled ? segment.value : 0.0)
        .toList(growable: false);

    var changed = newTargets.length != _targetValues.length;
    if (!changed) {
      for (int i = 0; i < newTargets.length; i++) {
        if (newTargets[i] != _targetValues[i]) {
          changed = true;
          break;
        }
      }
    }

    final newOrder = _buildRevealOrder(widget.segments);
    if (_listNotEqual(newOrder, _revealOrder)) {
      _revealOrder = newOrder;
      _entryController.forward(from: 0.0);
      if (!changed) return;
    }

    if (!changed) {
      if (_entryController.status != AnimationStatus.forward &&
          _entryController.status != AnimationStatus.completed) {
        _entryController.forward(from: 0.0);
      }
      return;
    }

    final previousLength = math.min(_startValues.length, _targetValues.length);
    final inFlightValues = List<double>.generate(previousLength, (index) {
      return _startValues[index] +
          (_targetValues[index] - _startValues[index]) * _valueAnimation.value;
    }, growable: false);

    _startValues = List<double>.generate(newTargets.length, (index) {
      if (index < inFlightValues.length) {
        return inFlightValues[index];
      }
      return 0.0;
    }, growable: false);
    _targetValues = newTargets;

    _valueController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _pressController.dispose();
    _valueController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  List<int> _buildRevealOrder(List<DonutSegment> segments) {
    final indexed = segments.asMap().entries.toList();
    indexed.sort((a, b) => b.value.value.compareTo(a.value.value));
    return indexed.map((e) => e.key).toList();
  }

  bool _listNotEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }

  int? _sliceAtPosition(Offset position, List<double> values) {
    final center = Offset(_outerRadius, _outerRadius);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final radius = math.sqrt(dx * dx + dy * dy);

    if (radius < _innerRadius || radius > _outerRadius) {
      return null;
    }

    double touchAngle = math.atan2(dy, dx);
    double shifted = touchAngle + math.pi / 2;
    if (shifted < 0) shifted += math.pi * 2;

    final total = values.fold(0.0, (sum, value) => sum + value);
    if (total <= 0.0) return null;

    double start = 0.0;
    for (int i = 0; i < values.length; i++) {
      final value = values[i];
      if (value <= 0.0) continue;

      final sweep = (value / total) * math.pi * 2;
      if (shifted >= start && shifted <= start + sweep) {
        return i;
      }
      start += sweep;
    }

    return null;
  }

  void _onPanDown(DragDownDetails details, List<double> currentValues) {
    final index = _sliceAtPosition(details.localPosition, currentValues);
    if (index == null) return;

    setState(() => _pressedIndex = index);
    _pressController.forward(from: 0);
    widget.onSelected(index);
  }

  void _onPanEnd() {
    if (_pressedIndex == null) return;
    setState(() => _pressedIndex = null);
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _pressController,
        _valueAnimation,
        _entryAnimation,
      ]),
      builder: (context, _) {
        final baseValues = List<double>.generate(_targetValues.length, (index) {
          return _startValues[index] +
              (_targetValues[index] - _startValues[index]) *
                  _valueAnimation.value;
        }, growable: false);

        final entryProgress = _entryAnimation.value.clamp(0.0, 1.0);
        final currentValues = List<double>.generate(baseValues.length, (i) {
          if (baseValues[i] <= 0) return 0.0;

          final revealIdx = _revealOrder.indexOf(i);
          if (revealIdx < 0) return baseValues[i];

          final totalCategories = _revealOrder.length;
          final itemStart = (revealIdx / totalCategories);
          final itemEnd = ((revealIdx + 1) / totalCategories);

          if (entryProgress < itemStart) {
            return 0.0;
          } else if (entryProgress >= itemEnd) {
            return baseValues[i];
          } else {
            final itemProgress =
                (entryProgress - itemStart) / (itemEnd - itemStart);
            return baseValues[i] * itemProgress;
          }
        }, growable: false);

        final total = currentValues.fold<double>(
          0.0,
          (sum, value) => sum + value,
        );

        return GestureDetector(
          onPanDown: (details) => _onPanDown(details, currentValues),
          onPanEnd: (_) => _onPanEnd(),
          onPanCancel: _onPanEnd,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _DonutPainter(
                  segments: widget.segments,
                  currentValues: currentValues,
                  selectedIndex: widget.selectedIndex,
                  pressedIndex: _pressedIndex,
                  pressedScale: _pressController.value,
                  strokeWidth: widget.strokeWidth,
                ),
              ),
              widget.centerBuilder(context, total),
            ],
          ),
        );
      },
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.segments,
    required this.currentValues,
    required this.selectedIndex,
    required this.pressedIndex,
    required this.pressedScale,
    required this.strokeWidth,
  });

  final List<DonutSegment> segments;
  final List<double> currentValues;
  final int selectedIndex;
  final int? pressedIndex;
  final double pressedScale;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final total = currentValues.fold(0.0, (sum, value) => sum + value);
    if (total <= 0) return;

    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    var startAngle = -math.pi / 2;
    const gapAngle = 0.045;

    final visibleCount = currentValues.where((value) => value > 0).length;

    for (int i = 0; i < segments.length; i++) {
      final value = currentValues[i];
      if (value <= 0) continue;

      final sweep = (value / total) * math.pi * 2;
      var actualSweep = sweep;
      var actualStart = startAngle;

      if (visibleCount > 1) {
        final currentGap = math.min(gapAngle, sweep * 0.5);
        actualStart += currentGap / 2;
        actualSweep -= currentGap;
      }

      final isSelected = i == selectedIndex;
      var pushOut = isSelected ? 6.0 : 0.0;
      if (i == pressedIndex) {
        pushOut += 8.0 * pressedScale;
      }

      final rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: radius + pushOut,
      );

      final paint = Paint()
        ..color = segments[i].color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + pushOut
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, actualStart, actualSweep, false, paint);

      if (actualSweep > 0.22) {
        final percentage = (currentValues[i] / total * 100).round();
        if (percentage > 0) {
          final midAngle = actualStart + actualSweep / 2;
          final textRadius = radius + pushOut;
          final dx = size.width / 2 + math.cos(midAngle) * textRadius;
          final dy = size.height / 2 + math.sin(midAngle) * textRadius;

          final textPainter = TextPainter(
            text: TextSpan(
              text: '$percentage%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();

          textPainter.paint(
            canvas,
            Offset(dx - textPainter.width / 2, dy - textPainter.height / 2),
          );
        }
      }

      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.currentValues != currentValues ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.pressedIndex != pressedIndex ||
        oldDelegate.pressedScale != pressedScale ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
