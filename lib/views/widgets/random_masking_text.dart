import 'dart:math';

import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

class RandomMaskingText extends StatefulWidget {
  const RandomMaskingText({
    super.key,
    required this.text,
    required this.obscured,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
  });

  final String text;
  final bool obscured;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  State<RandomMaskingText> createState() => _RandomMaskingTextState();
}

class _RandomMaskingTextState extends State<RandomMaskingText> {
  static const String _maskChar = '*';

  List<double> _charThresholds = const <double>[];
  int _salt = 0;

  @override
  void initState() {
    super.initState();
    _regenerateThresholds();
  }

  @override
  void didUpdateWidget(covariant RandomMaskingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final textChanged = oldWidget.text != widget.text;
    final visibilityChanged = oldWidget.obscured != widget.obscured;

    if (textChanged || visibilityChanged) {
      _salt++;
      _regenerateThresholds();
    }
  }

  void _regenerateThresholds() {
    final source = widget.text;
    if (source.isEmpty) {
      _charThresholds = const <double>[];
      return;
    }

    final seed = DateTime.now().microsecondsSinceEpoch ^ source.hashCode ^ _salt;
    final random = Random(seed);

    _charThresholds = List<double>.generate(
      source.length,
      (_) => random.nextDouble(),
      growable: false,
    );
  }

  String _maskedChar(int index, double progress) {
    final sourceChar = widget.text[index];
    if (sourceChar.trim().isEmpty) {
      return sourceChar;
    }

    if (progress >= _charThresholds[index]) {
      return sourceChar;
    }

    return _maskChar;
  }

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      motion: Motion.curved(
        const Duration(milliseconds: 950),
        Curves.easeInOutCubic,
      ),
      value: widget.obscured ? 0.0 : 1.0,
      builder: (context, value, child) {
        final progress = value.clamp(0.0, 1.0);
        final output = StringBuffer();

        for (int i = 0; i < widget.text.length; i++) {
          output.write(_maskedChar(i, progress));
        }

        return Text(
          output.toString(),
          style: widget.style,
          textAlign: widget.textAlign,
          overflow: widget.overflow,
          maxLines: widget.maxLines,
        );
      },
    );
  }
}
