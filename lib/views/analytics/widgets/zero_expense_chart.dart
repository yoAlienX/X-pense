import 'dart:math' as math;
import 'package:flutter/scheduler.dart';

import 'package:flutter/material.dart';

class ZeroExpenseChart extends StatefulWidget {
  const ZeroExpenseChart({super.key, this.size = 230});

  final double size;

  @override
  State<ZeroExpenseChart> createState() => _ZeroExpenseChartState();
}

class _ZeroExpenseChartState extends State<ZeroExpenseChart>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  static const Color _greenA = Color(0xFF16D66B);
  static const Color _greenB = Color(0xFF62F5A2);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() => _elapsed = elapsed);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Transform.translate(
          offset: const Offset(0, -11),
          child: const Text(
            '₹',
            style: TextStyle(
              fontSize: 31.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.1,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          '0',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            color: Colors.white,
          ),
        ),
      ],
    );
    final timeSec = _elapsed.inMicroseconds / 1000000.0;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _ZeroExpensePainter(timeSec: timeSec),
        child: Center(
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_greenA, _greenB],
              ).createShader(bounds);
            },
            child: text,
          ),
        ),
      ),
    );
  }
}

class _ZeroExpensePainter extends CustomPainter {
  _ZeroExpensePainter({required this.timeSec});

  final double timeSec;

  static const Color _greenA = Color(0xFF16D66B);
  static const Color _greenB = Color(0xFF62F5A2);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = size.shortestSide * 0.32;

    final ringRect = Rect.fromCircle(center: center, radius: ringRadius);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..shader = SweepGradient(
        startAngle: timeSec * 0.35,
        endAngle: (timeSec * 0.35) + (math.pi * 2),
        colors: [_greenA, _greenB, _greenA],
      ).createShader(ringRect);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = _greenB.withAlpha(40);

    canvas.drawCircle(center, ringRadius, glowPaint);
    canvas.drawCircle(center, ringRadius, ringPaint);

    _paintSparkles(canvas, center, ringRadius, timeSec);
  }

  void _paintSparkles(
    Canvas canvas,
    Offset center,
    double ringRadius,
    double t,
  ) {
    const streamCount = 18;
    const sparklesPerStream = 3;

    for (int stream = 0; stream < streamCount; stream++) {
      final baseRate = 0.42 + ((stream * 37) % 11) * 0.035;
      final life = 1.6 + (stream % 4) * 0.34;
      final phase = stream * 0.173;
      final streamTime = t + phase;
      final emissionIndex = (streamTime * baseRate).floor();

      for (int j = 0; j < sparklesPerStream; j++) {
        final id = emissionIndex - j;
        if (id < 0) continue;

        final spawnTime = id / baseRate;
        final age = streamTime - spawnTime;
        if (age < 0 || age > life) continue;

        final ageNorm = (age / life).clamp(0.0, 1.0);
        final travel = Curves.easeOutCubic.transform(ageNorm);

        final seed = ((stream + 1) * 73856093) ^ (id * 19349663);
        final rand01 = ((seed & 0x7fffffff) / 0x7fffffff).clamp(0.0, 1.0);
        final rand02 = ((((seed >> 8) & 0x7fffffff) / 0x7fffffff)).clamp(
          0.0,
          1.0,
        );

        final baseAngle = (2 * math.pi * stream / streamCount) + (rand01 * 0.7);
        final drift = (t * (0.06 + rand02 * 0.05)) + (rand02 * 0.8);
        final angle = baseAngle + drift;

        final maxDistance = 54 + (rand01 * 26);
        final distance = ringRadius + 8 + (travel * maxDistance);

        final point = Offset(
          center.dx + math.cos(angle) * distance,
          center.dy + math.sin(angle) * distance,
        );

        final alpha = ((1.0 - ageNorm) * (1.0 - ageNorm) * 255)
            .clamp(16, 190)
            .toInt();
        final color = Color.lerp(_greenA, _greenB, rand02)!.withAlpha(alpha);

        final sparkleRadius = 1.0 + rand01 * 1.2;
        final glowRadius = sparkleRadius + 1.7;

        final glow = Paint()..color = color.withAlpha((alpha * 0.36).toInt());
        final dot = Paint()..color = color;

        canvas.drawCircle(point, glowRadius, glow);
        canvas.drawCircle(point, sparkleRadius, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ZeroExpensePainter oldDelegate) {
    return oldDelegate.timeSec != timeSec;
  }
}
