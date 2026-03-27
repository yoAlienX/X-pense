import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TELEGRAM-STYLE CIRCULAR REVEAL THEME SWITCHER
// ─────────────────────────────────────────────────────────────────────────────
//
// This is a clean, modern theme switcher with circular reveal animation.
// The animation shows the old theme disappearing into a shrinking circle,
// revealing the new theme underneath.
//
// It works by:
// 1. Capturing a screenshot of the current theme
// 2. Toggling the theme
// 3. Capturing a screenshot of the new theme
// 4. Animating a circular mask between the two
//
// ─────────────────────────────────────────────────────────────────────────────

/// Controller for managing theme state and notifications.
class ThemeSwitcherController extends ChangeNotifier {
  ThemeSwitcherController({ThemeMode initialMode = ThemeMode.light})
    : _themeMode = initialMode;

  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  void toggle() {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// InheritedWidget to propagate the controller and overlay state.
class _ThemeSwitcherScope extends InheritedWidget {
  const _ThemeSwitcherScope({
    required this.controller,
    required this.overlayKey,
    required super.child,
  });

  final ThemeSwitcherController controller;
  final GlobalKey<_ThemeSwitcherOverlayState> overlayKey;

  static _ThemeSwitcherScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ThemeSwitcherScope>();

  static _ThemeSwitcherScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'No ThemeSwitcherWrapper found in the widget tree. '
      'Wrap your app with ThemeSwitcherWrapper.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(_ThemeSwitcherScope oldWidget) =>
      controller != oldWidget.controller;
}

// ─────────────────────────────────────────────────────────────────────────────

/// Main wrapper that provides theme switching capability.
/// Wrap your [MaterialApp] (or root widget) with this.
///
/// ```dart
/// ThemeSwitcherWrapper(
///   builder: (context, themeMode) => MaterialApp(
///     themeMode: themeMode,
///     theme: ThemeData.light(),
///     darkTheme: ThemeData.dark(),
///     home: const HomePage(),
///   ),
/// )
/// ```
class ThemeSwitcherWrapper extends StatefulWidget {
  const ThemeSwitcherWrapper({
    super.key,
    required this.builder,
    this.initialThemeMode = ThemeMode.light,
    this.animationDuration = const Duration(milliseconds: 450),
    this.animationCurve = Curves.easeInOut,
  });

  /// Receives the current [ThemeMode]; pass it straight to [MaterialApp].
  final Widget Function(BuildContext context, ThemeMode themeMode) builder;
  final ThemeMode initialThemeMode;
  final Duration animationDuration;
  final Curve animationCurve;

  @override
  State<ThemeSwitcherWrapper> createState() => _ThemeSwitcherWrapperState();

  /// Get the controller from any descendant context.
  static ThemeSwitcherController controllerOf(BuildContext context) =>
      _ThemeSwitcherScope.of(context).controller;

  /// Simple theme toggle with animation from the specified origin.
  /// Handles everything: captures old theme, toggles once, animates reveal.
  static Future<void> toggleThemeWithAnimation(
    BuildContext context,
    Offset origin,
  ) async {
    final scope = _ThemeSwitcherScope.maybeOf(context);
    if (scope == null) return;

    // Use Controller's CURRENT state (the single source of truth for MaterialApp)
    // NOT ViewModel state, which might be out of sync
    final isCurrentlyDark = scope.controller.isDark;
    final isDarkAfter = !isCurrentlyDark;

    // Start animation and toggle theme (only once!)
    await scope.overlayKey.currentState?.startAnimation(
      origin,
      isDarkAfter: isDarkAfter,
      toggleCallback: () => scope.controller.toggle(),
    );
  }
}

class _ThemeSwitcherWrapperState extends State<ThemeSwitcherWrapper> {
  late final ThemeSwitcherController _controller;
  final GlobalKey<_ThemeSwitcherOverlayState> _overlayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = ThemeSwitcherController(initialMode: widget.initialThemeMode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ThemeSwitcherScope(
      controller: _controller,
      overlayKey: _overlayKey,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return _ThemeSwitcherOverlay(
            key: _overlayKey,
            duration: widget.animationDuration,
            curve: widget.animationCurve,
            child: widget.builder(context, _controller.themeMode),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Overlay that handles the screenshot + circular clip animation.
class _ThemeSwitcherOverlay extends StatefulWidget {
  const _ThemeSwitcherOverlay({
    super.key,
    required this.child,
    required this.duration,
    required this.curve,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  _ThemeSwitcherOverlayState createState() => _ThemeSwitcherOverlayState();
}

class _ThemeSwitcherOverlayState extends State<_ThemeSwitcherOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late Animation<double> _radiusAnim;

  ui.Image? _snapshot;
  Offset _origin = Offset.zero;
  bool _animating = false;
  bool _expanding = false; // true = expand (light→dark), false = shrink (dark→light)

  // The RepaintBoundary key lets us screenshot the *old* theme.
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _radiusAnim = CurvedAnimation(parent: _animController, curve: widget.curve);
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _animating = false;
          _snapshot?.dispose();
          _snapshot = null;
          _animController.reset();
        });
      }
    });
  }

  @override
  void dispose() {
    _snapshot?.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ThemeSwitcherOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _animController.duration = widget.duration;
    }
  }

  /// Called to start animation and toggle theme.
  /// [isDarkAfter] - whether we're switching TO dark mode (expand) or FROM it (shrink)
  /// Captures old theme, toggles it, then animates the reveal.
  Future<void> startAnimation(
    Offset origin, {
    required bool isDarkAfter,
    required VoidCallback toggleCallback,
  }) async {
    if (_animating) return;

    // Capture current screen before theme change
    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(
      pixelRatio: ui.PlatformDispatcher.instance.views.first.devicePixelRatio,
    );

    setState(() {
      _snapshot = image;
      _origin = origin;
      _animating = true;
      _expanding = isDarkAfter; // Expand when going to dark, shrink when going to light
    });

    // Toggle the theme NOW (new theme renders underneath)
    toggleCallback.call();

    // Wait for new theme to render
    await Future.delayed(const Duration(milliseconds: 16));
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _boundaryKey,
      child: Stack(
        alignment: Alignment.topLeft,
        fit: StackFit.expand,
        children: [
          // ── New theme (renders underneath) ──────────────────────────────
          widget.child,

          // ── Old theme snapshot fading/clipping away ──────────────────────
          if (_animating && _snapshot != null)
            AnimatedBuilder(
              animation: _radiusAnim,
              builder: (context, _) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _CircularRevealPainter(
                    snapshot: _snapshot!,
                    origin: _origin,
                    progress: _radiusAnim.value,
                    expanding: _expanding,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Painter that renders the old-theme screenshot with directional clipping.
class _CircularRevealPainter extends CustomPainter {
  const _CircularRevealPainter({
    required this.snapshot,
    required this.origin,
    required this.progress,
    required this.expanding,
  });

  final ui.Image snapshot;
  final Offset origin;

  /// 0 → start of transition; 1 → end of transition.
  final double progress;

  /// true = light→dark reveal (dark expands from origin),
  /// false = dark→light reveal (old dark shrinks to origin)
  final bool expanding;

  @override
  void paint(Canvas canvas, Size size) {
    // Max radius = distance to the farthest corner
    final maxRadius = [
      (origin - Offset.zero).distance,
      (origin - Offset(size.width, 0)).distance,
      (origin - Offset(0, size.height)).distance,
      (origin - Offset(size.width, size.height)).distance,
    ].reduce((a, b) => a > b ? a : b);

    // Calculate radius based on direction
    // Expanding: grows from 0 → maxRadius (light→dark, circle expands from menu)
    // Shrinking: shrinks from maxRadius → 0 (dark→light, old theme shrinks away)
    final radius = expanding
        ? maxRadius * progress
        : maxRadius * (1.0 - progress);

    canvas.save();
    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: origin, radius: radius));

    // For light→dark, keep old snapshot OUTSIDE the growing circle so
    // the new dark theme appears to expand from the origin.
    // For dark→light, keep old snapshot INSIDE the shrinking circle.
    if (expanding) {
      final fullPath = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      final outsideCircle = Path.combine(
        PathOperation.difference,
        fullPath,
        circlePath,
      );
      canvas.clipPath(outsideCircle);
    } else {
      canvas.clipPath(circlePath);
    }

    // Draw the snapshot scaled to fill the widget
    final src = Rect.fromLTWH(
      0,
      0,
      snapshot.width.toDouble(),
      snapshot.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(snapshot, src, dst, Paint());

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CircularRevealPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      origin != oldDelegate.origin ||
      snapshot != oldDelegate.snapshot ||
      expanding != oldDelegate.expanding;
}

// ─────────────────────────────────────────────────────────────────────────────

/// Drop-in icon button that triggers the circular reveal animation.
/// Place it anywhere (AppBar actions, floating button, drawer header…).
///
/// ```dart
/// AppBar(
///   actions: [ThemeSwitcherIconButton(iconSize: 26)],
/// )
/// ```
class ThemeSwitcherIconButton extends StatelessWidget {
  const ThemeSwitcherIconButton({
    super.key,
    this.iconSize = 24.0,
    this.darkIcon = Icons.nights_stay_rounded,
    this.lightIcon = Icons.wb_sunny_rounded,
    this.tooltip,
    this.color,
  });

  final double iconSize;

  /// Icon shown when currently in light mode (tap → go dark).
  final IconData darkIcon;

  /// Icon shown when currently in dark mode (tap → go light).
  final IconData lightIcon;

  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scope = _ThemeSwitcherScope.of(context);
    final controller = scope.controller;
    final overlayKey = scope.overlayKey;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isDark = controller.isDark;
        return IconButton(
          tooltip:
              tooltip ??
              (isDark ? 'Switch to light theme' : 'Switch to dark theme'),
          icon: Icon(isDark ? lightIcon : darkIcon),
          iconSize: iconSize,
          color: color,
          onPressed: () async {
            // Get the global position of this icon's center
            final renderBox = context.findRenderObject() as RenderBox?;
            final overlayBox =
                overlayKey.currentContext?.findRenderObject() as RenderBox?;

            Offset iconCenter = Offset.zero;
            if (renderBox != null && overlayBox != null) {
              final localPos = renderBox.localToGlobal(
                renderBox.size.center(Offset.zero),
                ancestor: overlayBox,
              );
              iconCenter = localPos;
            }

            // Start animation and toggle theme
            // Note: isDark is read from controller inside startAnimation, always in sync
            await overlayKey.currentState?.startAnimation(
              iconCenter,
              isDarkAfter: !isDark,
              toggleCallback: () => controller.toggle(),
            );
          },
        );
      },
    );
  }
}
