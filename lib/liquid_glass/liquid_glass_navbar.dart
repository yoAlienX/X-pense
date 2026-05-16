// liquid_glass_navbar.dart
//
// A cross-platform Liquid Glass Navigation Bar for Flutter.
// Replicates the iOS 26 "Liquid Glass" aesthetic on Android using:
//   • BackdropFilter + ImageFilter for real-time blur/refraction
//   • CustomPainter with radial gradients for the specular sheen
//   • AnimatedPositioned pill indicator that slides between tabs
//   • Per-tab ripple aura painted via canvas
//   • No third-party dependencies — pure Flutter
//
// ─────────────────────────────────────────────────────────────────────────────
// USAGE
// ─────────────────────────────────────────────────────────────────────────────
//
//   LiquidGlassNavBar(
//     currentIndex: _index,
//     onTap: (i) => setState(() => _index = i),
//     items: const [
//       LiquidGlassNavItem(icon: Icons.home_rounded,     label: 'Home'),
//       LiquidGlassNavItem(icon: Icons.search_rounded,    label: 'Search'),
//       LiquidGlassNavItem(icon: Icons.settings_rounded,  label: 'Settings'),
//     ],
//     actionButton: LiquidGlassActionButton(
//       icon: Icons.add_rounded,
//       onTap: () { /* … */ },
//     ),
//   )
//
// ─────────────────────────────────────────────────────────────────────────────

library liquid_glass_navbar;

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Public data models
// ══════════════════════════════════════════════════════════════════════════════

/// A single navigation tab.
class LiquidGlassNavItem {
  const LiquidGlassNavItem({
    required this.icon,
    required this.label,
    this.activeIcon,
  });

  final IconData icon;
  final IconData? activeIcon;
  final String label;
}

/// Optional FAB-style action button that floats to the right of the tab bar.
class LiquidGlassActionButton {
  const LiquidGlassActionButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
}

// ══════════════════════════════════════════════════════════════════════════════
// Theme / style config
// ══════════════════════════════════════════════════════════════════════════════

class LiquidGlassTheme {
  const LiquidGlassTheme({
    this.blurSigma = 22.0,
    this.tintOpacity = 0.18,
    this.specularity = 0.55,
    this.pillColor,
    this.activeColor,
    this.inactiveColor,
    this.borderRadius = 40.0,
    this.actionButtonRadius = 28.0,
    this.height = 72.0,
    this.horizontalPadding = 16.0,
    this.bottomPadding = 12.0,
    this.animationDuration = const Duration(milliseconds: 380),
    this.animationCurve = Curves.easeInOutCubicEmphasized,
  });

  /// Blur sigma for the backdrop glass effect.
  final double blurSigma;

  /// How opaque the frosted tint is (0–1).
  final double tintOpacity;

  /// Brightness of the specular highlight on the pill (0–1).
  final double specularity;

  /// Colour of the active-tab pill. Defaults to white/black tinted by theme.
  final Color? pillColor;

  /// Active icon + label colour. Defaults to [ColorScheme.primary].
  final Color? activeColor;

  /// Inactive icon + label colour.
  final Color? inactiveColor;

  final double borderRadius;
  final double actionButtonRadius;
  final double height;
  final double horizontalPadding;
  final double bottomPadding;
  final Duration animationDuration;
  final Curve animationCurve;
}

// ══════════════════════════════════════════════════════════════════════════════
// Main widget
// ══════════════════════════════════════════════════════════════════════════════

class LiquidGlassNavBar extends StatefulWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.actionButton,
    this.showActionButton = true,
    this.reserveActionSlot = false,
    this.theme = const LiquidGlassTheme(),
  }) : assert(
         items.length >= 2 && items.length <= 5,
         'LiquidGlassNavBar requires between 2 and 5 items.',
       );

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<LiquidGlassNavItem> items;
  final LiquidGlassActionButton? actionButton;
  final bool showActionButton;
  final bool reserveActionSlot;
  final LiquidGlassTheme theme;

  @override
  State<LiquidGlassNavBar> createState() => _LiquidGlassNavBarState();
}

class _LiquidGlassNavBarState extends State<LiquidGlassNavBar>
    with TickerProviderStateMixin {
  late AnimationController _pillController;
  late AnimationController _tapController;
  late Animation<double> _pillAnim;
  late Animation<double> _tapAnim;

  int _prevIndex = 0;
  int _tapIndex = -1;
  bool _skipNextPillAnimation = false;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex;

    _pillController = AnimationController(
      vsync: this,
      duration: widget.theme.animationDuration,
    );
    _pillAnim = CurvedAnimation(
      parent: _pillController,
      curve: widget.theme.animationCurve,
    );

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _tapAnim = CurvedAnimation(
      parent: _tapController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(LiquidGlassNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      // Skip animation restart if we just completed a drag-release
      // (the pill already animated to position via release animation)
      if (_skipNextPillAnimation) {
        _skipNextPillAnimation = false;
        _prevIndex = widget.currentIndex;
      } else {
        _prevIndex = old.currentIndex;
        _pillController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _pillController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _onTabRowDragReleaseComplete() {
    _skipNextPillAnimation = true;
  }

  void _onTap(int index) {
    setState(() => _tapIndex = index);
    _tapController.forward(from: 0);
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final cfg = widget.theme;

    final activeColor = cfg.activeColor ?? (isDark ? Colors.white : cs.primary);
    final inactiveColor =
        cfg.inactiveColor ?? (isDark ? Colors.white54 : Colors.black45);
    final tintColor = isDark
        ? Colors.white.withAlpha((cfg.tintOpacity * 255).round())
        : Colors.white.withAlpha(
            (cfg.tintOpacity * 2.2 * 255).round().clamp(0, 255),
          );
    final pillColor =
        cfg.pillColor ??
        (isDark ? Colors.white.withAlpha(38) : Colors.white.withAlpha(200));

    final hasAction = widget.actionButton != null;
    final fullActionGap = hasAction ? 10.0 : 0.0;
    final fullActionDiameter = hasAction ? cfg.actionButtonRadius * 2 : 0.0;
    final targetActionFactor = hasAction
        ? ((widget.reserveActionSlot || widget.showActionButton) ? 1.0 : 0.0)
        : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: targetActionFactor, end: targetActionFactor),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutSine,
      builder: (context, actionFactorRaw, _) {
        final actionFactor = actionFactorRaw.clamp(0.0, 1.0).toDouble();
        final actionGap = fullActionGap * actionFactor;
        final actionDiameter = fullActionDiameter * actionFactor;
        final horizontalInsets = cfg.horizontalPadding * 2;
        final availableWidth =
            (mq.size.width - horizontalInsets - actionGap - actionDiameter)
                .clamp(0.0, double.infinity)
                .toDouble();
        final preferredWidth = widget.items.length * 96.0;
        final navWidth = availableWidth <= 220.0
            ? availableWidth
            : preferredWidth.clamp(220.0, availableWidth).toDouble();

        return Padding(
          padding: EdgeInsets.only(
            left: cfg.horizontalPadding,
            right: cfg.horizontalPadding,
            bottom: cfg.bottomPadding + mq.padding.bottom,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: navWidth,
                child: _GlassPill(
                  height: cfg.height,
                  borderRadius: cfg.borderRadius,
                  blurSigma: cfg.blurSigma,
                  tintColor: tintColor,
                  specularity: cfg.specularity,
                  isDark: isDark,
                  child: _TabRow(
                    items: widget.items,
                    currentIndex: widget.currentIndex,
                    prevIndex: _prevIndex,
                    pillAnim: _pillAnim,
                    tapAnim: _tapAnim,
                    tapIndex: _tapIndex,
                    pillColor: pillColor,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                    specularity: cfg.specularity,
                    animDuration: cfg.animationDuration,
                    isDark: isDark,
                    onTap: _onTap,
                    onDragReleaseComplete: _onTabRowDragReleaseComplete,
                  ),
                ),
              ),
              if (hasAction) ...[
                SizedBox(width: actionGap),
                SizedBox(
                  width: actionDiameter,
                  height: fullActionDiameter,
                  child: actionFactor <= 0.001
                      ? const SizedBox.shrink()
                      : _ActionButton(
                          button: widget.actionButton!,
                          visible: widget.showActionButton,
                          visibilityDuration: const Duration(milliseconds: 800),
                          size: fullActionDiameter,
                          blurSigma: cfg.blurSigma,
                          tintColor: tintColor,
                          specularity: cfg.specularity,
                          isDark: isDark,
                          activeColor: activeColor,
                        ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Glass pill container (backdrop blur + tint + specular border)
// ══════════════════════════════════════════════════════════════════════════════

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.height,
    required this.borderRadius,
    required this.blurSigma,
    required this.tintColor,
    required this.specularity,
    required this.isDark,
    required this.child,
  });

  final double height;
  final double borderRadius;
  final double blurSigma;
  final Color tintColor;
  final double specularity;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rr = BorderRadius.circular(borderRadius);
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: rr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Real-time backdrop blur
            BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: const SizedBox.expand(),
            ),

            // 2. Frosted tint
            Container(color: tintColor),

            // Light mode extra frost layer
            if (!isDark)
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Colors.white54, Colors.transparent],
                    radius: 1.5,
                  ),
                ),
              ),

            // 3. Specular / iridescent edge highlight painted over everything
            CustomPaint(
              painter: _GlassEdgePainter(
                borderRadius: borderRadius,
                specularity: specularity,
                isDark: isDark,
              ),
            ),

            // Inner glow ring
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.white60,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.white12 : Colors.white30,
                    blurStyle: BlurStyle.normal,
                    blurRadius: 3.0,
                    spreadRadius: -1.0,
                  ),
                ],
              ),
            ),

            // 4. Content
            child,
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Specular edge painter — draws the iridescent rim + inner sheen
// ══════════════════════════════════════════════════════════════════════════════

class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({
    required this.borderRadius,
    required this.specularity,
    required this.isDark,
  });

  final double borderRadius;
  final double specularity;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );

    // ── Outer specular ring ──────────────────────────────────────────────
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = SweepGradient(
        center: Alignment.topCenter,
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          Colors.white.withAlpha((specularity * 200).round()),
          Colors.white.withAlpha((specularity * 60).round()),
          Colors.white.withAlpha((specularity * 180).round()),
          Colors.white.withAlpha((specularity * 30).round()),
          Colors.white.withAlpha((specularity * 200).round()),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rr, ringPaint);

    // ── Top inner sheen (simulates refracted light from above) ───────────
    final sheenRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.55);
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withAlpha((specularity * 90).round()),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(sheenRect);
    final sheenPath = Path()..addRRect(rr);
    canvas.save();
    canvas.clipPath(sheenPath);
    canvas.drawRect(sheenRect, sheenPaint);
    canvas.restore();

    // ── Bottom inner reflection (slight warm tint) ───────────────────────
    final reflectionRect = Rect.fromLTWH(
      0,
      size.height * 0.7,
      size.width,
      size.height * 0.3,
    );
    final reflectionPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          (isDark ? Colors.white : const Color(0xFFDDF4FF)).withAlpha(28),
          Colors.transparent,
        ],
      ).createShader(reflectionRect);
    canvas.save();
    canvas.clipPath(sheenPath);
    canvas.drawRect(reflectionRect, reflectionPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassEdgePainter old) =>
      old.specularity != specularity || old.isDark != isDark;
}

// ══════════════════════════════════════════════════════════════════════════════
// Tab row  — sliding pill indicator + per-tab auras
// ══════════════════════════════════════════════════════════════════════════════

class _TabRow extends StatefulWidget {
  const _TabRow({
    required this.items,
    required this.currentIndex,
    required this.prevIndex,
    required this.pillAnim,
    required this.tapAnim,
    required this.tapIndex,
    required this.pillColor,
    required this.activeColor,
    required this.inactiveColor,
    required this.specularity,
    required this.animDuration,
    required this.isDark,
    required this.onTap,
    this.onDragReleaseComplete,
  });

  final List<LiquidGlassNavItem> items;
  final int currentIndex;
  final int prevIndex;
  final Animation<double> pillAnim;
  final Animation<double> tapAnim;
  final int tapIndex;
  final Color pillColor;
  final Color activeColor;
  final Color inactiveColor;
  final double specularity;
  final Duration animDuration;
  final bool isDark;
  final ValueChanged<int> onTap;
  final VoidCallback? onDragReleaseComplete;

  @override
  State<_TabRow> createState() => _TabRowState();
}

class _TabRowState extends State<_TabRow> with TickerProviderStateMixin {
  static const Duration _kDragHoldDuration = Duration(milliseconds: 300);

  late final AnimationController _holdController;
  late final Animation<double> _holdAnim;
  AnimationController? _releaseController;
  Animation<double> _releaseAnim = kAlwaysDismissedAnimation;

  bool _isDragging = false;
  bool _isReleasing = false;
  double _dragX = 0;
  int _dragIndex = -1;
  int? _pendingIndex;
  double _releaseFromLeft = 0;
  double _releaseToLeft = 0;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _holdAnim = CurvedAnimation(
      parent: _holdController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    _releaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
    );
    _releaseAnim = CurvedAnimation(
      parent: _releaseController!,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant _TabRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pendingIndex != null && widget.currentIndex == _pendingIndex) {
      // We just completed a drag-release. Signal parent to skip pill animation.
      widget.onDragReleaseComplete?.call();
      _pendingIndex = null;
    }
  }

  @override
  void dispose() {
    _releaseController?.dispose();
    _holdController.dispose();
    super.dispose();
  }

  int _nearestIndexFromDx(double dx, double tabWidth) {
    final raw = ((dx / tabWidth) - 0.5).round();
    return raw.clamp(0, widget.items.length - 1);
  }

  int _hoverIndexWithHysteresis(double dx, double tabWidth) {
    if (_dragIndex < 0) {
      return _nearestIndexFromDx(dx, tabWidth);
    }

    final normalized = dx / tabWidth;
    final currentCenter = _dragIndex + 0.5;
    if ((normalized - currentCenter).abs() < 0.22) {
      return _dragIndex;
    }
    return _nearestIndexFromDx(dx, tabWidth);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / widget.items.length;

        return AnimatedBuilder(
          animation: Listenable.merge([
            widget.pillAnim,
            widget.tapAnim,
            _holdAnim,
            _releaseAnim,
          ]),
          builder: (context, _) {
            final t = widget.pillAnim.value;
            final animatedLeft = ui.lerpDouble(
              widget.prevIndex * tabWidth,
              widget.currentIndex * tabWidth,
              t,
            )!;
            final dragLeft = (_dragX - (tabWidth / 2)).clamp(
              0.0,
              constraints.maxWidth - tabWidth,
            );
            final pendingLeft = _pendingIndex != null
                ? _pendingIndex! * tabWidth
                : animatedLeft;

            final pillLeft = _isDragging
                ? dragLeft
                : _isReleasing
                ? ui.lerpDouble(
                    _releaseFromLeft,
                    _releaseToLeft,
                    _releaseAnim.value,
                  )!
                : pendingLeft;

            final activeIndex = _isDragging && _dragIndex >= 0
                ? _dragIndex
                : (_pendingIndex ?? widget.currentIndex);

            return RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      LongPressGestureRecognizer
                    >(
                      () => LongPressGestureRecognizer(
                        duration: _kDragHoldDuration,
                      ),
                      (instance) {
                        instance
                          ..onLongPressStart = (details) {
                            _releaseController?.stop();
                            final dx = details.localPosition.dx.clamp(
                              0.0,
                              constraints.maxWidth,
                            );
                            setState(() {
                              _isDragging = true;
                              _isReleasing = false;
                              _pendingIndex = null;
                              _dragX = dx;
                              _dragIndex = _nearestIndexFromDx(dx, tabWidth);
                            });
                            _holdController.forward();
                          }
                          ..onLongPressMoveUpdate = (details) {
                            if (!_isDragging) return;
                            final dx = details.localPosition.dx.clamp(
                              0.0,
                              constraints.maxWidth,
                            );
                            setState(() {
                              _dragX = dx;
                              _dragIndex = _hoverIndexWithHysteresis(
                                dx,
                                tabWidth,
                              );
                            });
                          }
                          ..onLongPressEnd = (details) {
                            if (!_isDragging) {
                              _holdController.reverse();
                              return;
                            }

                            // Commit to the last tracked drag target even if released
                            // slightly above the bar, then snap to that tab's center.
                            final maxLeft = constraints.maxWidth - tabWidth;
                            final projectedDragX =
                                (_dragX +
                                        (details.velocity.pixelsPerSecond.dx *
                                            0.06))
                                    .clamp(0.0, constraints.maxWidth);
                            final targetIndex = _nearestIndexFromDx(
                              projectedDragX,
                              tabWidth,
                            );
                            _releaseFromLeft = (_dragX - (tabWidth / 2)).clamp(
                              0.0,
                              maxLeft,
                            );
                            _releaseToLeft = targetIndex * tabWidth;

                            setState(() {
                              _isDragging = false;
                              _isReleasing = true;
                              _dragIndex = targetIndex;
                              _pendingIndex = targetIndex;
                            });

                            // Trigger navigation immediately; release animation is visual only.
                            widget.onTap(targetIndex);

                            // The pill bounce drop effect (blob effect) logic
                            // Add a little snap drop by reversing the hold scale quickly
                            _holdController.reverse(from: 1.0);

                            _releaseController?.forward(from: 0).whenComplete(
                              () {
                                if (!mounted) return;
                                setState(() {
                                  _isReleasing = false;
                                  _dragIndex = -1;
                                });
                              },
                            );
                          };
                      },
                    ),
              },
              child: Stack(
                children: [
                  // ── Sliding/dragging pill ──────────────────────────────────
                  Positioned(
                    left: pillLeft + 4,
                    right: constraints.maxWidth - pillLeft - tabWidth + 4,
                    top: 6,
                    bottom: 6,
                    child: Transform.scale(
                      scale: 1 + (0.18 * _holdAnim.value),
                      child: _PillBackground(
                        color: widget.pillColor,
                        specularity: widget.specularity,
                        isDark: widget.isDark,
                        progress: t,
                      ),
                    ),
                  ),

                  // ── Tap aura glow ─────────────────────────────────────────
                  if (widget.tapIndex >= 0)
                    Positioned(
                      left: widget.tapIndex * tabWidth,
                      width: tabWidth,
                      top: 0,
                      bottom: 0,
                      child: _TapAura(
                        progress: widget.tapAnim.value,
                        color: widget.activeColor,
                        isCurrent: widget.tapIndex == widget.currentIndex,
                      ),
                    ),

                  // ── Tab items ──────────────────────────────────────────────
                  Row(
                    children: List.generate(widget.items.length, (i) {
                      final isActive = i == activeIndex;
                      return Expanded(
                        child: _TabItem(
                          item: widget.items[i],
                          isActive: isActive,
                          activeColor: widget.activeColor,
                          inactiveColor: widget.inactiveColor,
                          animDuration: widget.animDuration,
                          onTap: () {
                            if (_isDragging ||
                                _isReleasing ||
                                _pendingIndex != null) {
                              setState(() {
                                _isDragging = false;
                                _isReleasing = false;
                                _dragIndex = -1;
                                _pendingIndex = null;
                              });
                              _releaseController?.stop();
                              _holdController.reverse();
                            }
                            widget.onTap(i);
                          },
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Pill background with specular sheen
// ══════════════════════════════════════════════════════════════════════════════

class _PillBackground extends StatelessWidget {
  const _PillBackground({
    required this.color,
    required this.specularity,
    required this.isDark,
    required this.progress,
  });

  final Color color;
  final double specularity;
  final bool isDark;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base pill
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: color,
            ),
          ),

          // Inner glow ring
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.white60,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.white12 : Colors.white30,
                  blurStyle: BlurStyle.normal,
                  blurRadius: 3.0,
                  spreadRadius: -1.0,
                ),
              ],
            ),
          ),

          // Inner specular sheen on top half
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 18,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withAlpha((specularity * 110).round()),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Iridescent left edge (simulates surface tension)
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withAlpha((specularity * 160).round()),
                    Colors.white.withAlpha((specularity * 40).round()),
                    Colors.white.withAlpha((specularity * 90).round()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tap aura — expanding coloured halo on press
// ══════════════════════════════════════════════════════════════════════════════

class _TapAura extends StatelessWidget {
  const _TapAura({
    required this.progress,
    required this.color,
    required this.isCurrent,
  });

  final double progress;
  final Color color;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    return CustomPaint(
      painter: _AuraPainter(
        progress: progress,
        color: color.withAlpha((opacity * 60).round()),
      ),
    );
  }
}

class _AuraPainter extends CustomPainter {
  const _AuraPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide * 0.9;
    final r = maxR * Curves.easeOut.transform(progress);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  @override
  bool shouldRepaint(_AuraPainter old) =>
      old.progress != progress || old.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// Single tab item
// ══════════════════════════════════════════════════════════════════════════════

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.item,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.animDuration,
    required this.onTap,
  });

  final LiquidGlassNavItem item;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final Duration animDuration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with scale bounce
              AnimatedScale(
                scale: isActive ? 1.12 : 1.0,
                duration: animDuration,
                curve: Curves.easeOutBack,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    key: ValueKey(isActive),
                    isActive ? (item.activeIcon ?? item.icon) : item.icon,
                    color: isActive ? activeColor : inactiveColor,
                    size: 23,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // Label with fade + slight vertical slide
              AnimatedDefaultTextStyle(
                duration: animDuration,
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? activeColor : inactiveColor,
                  letterSpacing: isActive ? 0.1 : 0.0,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Action button  (the "+" pill that floats to the right)
// ══════════════════════════════════════════════════════════════════════════════

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.button,
    required this.visible,
    required this.visibilityDuration,
    required this.size,
    required this.blurSigma,
    required this.tintColor,
    required this.specularity,
    required this.isDark,
    required this.activeColor,
  });

  final LiquidGlassActionButton button;
  final bool visible;
  final Duration visibilityDuration;
  final double size;
  final double blurSigma;
  final Color tintColor;
  final double specularity;
  final bool isDark;
  final Color activeColor;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnim = Tween(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() {
    _ctrl.forward().then((_) => _ctrl.reverse());
    widget.button.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final sz = widget.size;
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        duration: widget.visibilityDuration,
        curve: Curves.easeInOutCubicEmphasized,
        opacity: widget.visible ? 1.0 : 0.0,
        child: AnimatedScale(
          duration: widget.visibilityDuration,
          curve: Curves.easeInOutCubicEmphasized,
          scale: widget.visible ? 1.0 : 0.72,
          child: GestureDetector(
            onTap: _onTap,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: SizedBox(
                width: sz,
                height: sz,
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Blur
                      BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: widget.blurSigma,
                          sigmaY: widget.blurSigma,
                        ),
                        child: const SizedBox.expand(),
                      ),
                      // Tint
                      Container(color: widget.tintColor),
                      // Specular edge
                      CustomPaint(
                        painter: _CircleSpecularPainter(
                          specularity: widget.specularity,
                          isDark: widget.isDark,
                        ),
                      ),
                      // Icon
                      Center(
                        child: Icon(
                          widget.button.icon,
                          color: widget.isDark ? Colors.white : Colors.black87,
                          size: sz * 0.42,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Circle specular painter (for action button)
// ══════════════════════════════════════════════════════════════════════════════

class _CircleSpecularPainter extends CustomPainter {
  const _CircleSpecularPainter({
    required this.specularity,
    required this.isDark,
  });

  final double specularity;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    // Ring
    canvas.drawCircle(
      center,
      radius - 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = SweepGradient(
          colors: [
            Colors.white.withAlpha((specularity * 200).round()),
            Colors.white.withAlpha((specularity * 40).round()),
            Colors.white.withAlpha((specularity * 180).round()),
            Colors.white.withAlpha((specularity * 20).round()),
            Colors.white.withAlpha((specularity * 200).round()),
          ],
        ).createShader(Offset.zero & size),
    );

    // Top sheen
    final sheenRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.5);
    final sheenPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.5),
        radius: 0.7,
        colors: [
          Colors.white.withAlpha((specularity * 100).round()),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.save();
    canvas.clipPath(Path()..addOval(Offset.zero & size));
    canvas.drawRect(sheenRect, sheenPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CircleSpecularPainter old) =>
      old.specularity != specularity || old.isDark != isDark;
}

// ══════════════════════════════════════════════════════════════════════════════
// Convenience: scaffold-aware positioned wrapper
// Wrap your Scaffold's body content with this to float the nav bar
// naturally over the content (like iOS does).
// ══════════════════════════════════════════════════════════════════════════════

/// Positions the [LiquidGlassNavBar] as a floating overlay at the bottom
/// of the screen, on top of [body], just like iOS 26.
///
/// ```dart
/// LiquidGlassScaffold(
///   body: MyPageContent(),
///   navBar: LiquidGlassNavBar(
///     currentIndex: _index,
///     onTap: (i) => setState(() => _index = i),
///     items: [ … ],
///   ),
/// )
/// ```
class LiquidGlassScaffold extends StatelessWidget {
  const LiquidGlassScaffold({
    super.key,
    required this.body,
    required this.navBar,
    this.extendBodyBehindNavBar = true,
  });

  final Widget body;
  final LiquidGlassNavBar navBar;

  /// If true (default), body scrolls behind the nav bar (iOS-style).
  final bool extendBodyBehindNavBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: extendBodyBehindNavBar,
      body: body,
      bottomNavigationBar: navBar,
    );
  }
}
