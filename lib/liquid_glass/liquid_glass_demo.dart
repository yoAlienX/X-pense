// liquid_glass_demo.dart
//
// Full demo showing how to integrate LiquidGlassNavBar into your app.
// Drop liquid_glass_navbar.dart alongside this file and run.

import 'package:flutter/material.dart';
import 'liquid_glass_navbar.dart';

void main() => runApp(const LiquidGlassDemoApp());

class LiquidGlassDemoApp extends StatelessWidget {
  const LiquidGlassDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liquid Glass Nav',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B6CF6), // purple accent
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B6CF6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _DemoShell(),
    );
  }
}

// ── Demo shell ─────────────────────────────────────────────────────────────

class _DemoShell extends StatefulWidget {
  const _DemoShell();

  @override
  State<_DemoShell> createState() => _DemoShellState();
}

class _DemoShellState extends State<_DemoShell> {
  int _index = 0;

  static const _pages = [
    _ColorGridPage(label: 'Home',     color: Color(0xFF7B6CF6)),
    _ColorGridPage(label: 'Search',   color: Color(0xFF2AABEE)),
    _ColorGridPage(label: 'Settings', color: Color(0xFF34C759)),
  ];

  @override
  Widget build(BuildContext context) {
    return LiquidGlassScaffold(
      navBar: LiquidGlassNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        // ── Optional: customise the theme ───────────────────────────────
        theme: const LiquidGlassTheme(
          blurSigma:         24,
          tintOpacity:       0.15,
          specularity:       0.60,
          height:            70,
          horizontalPadding: 18,
          bottomPadding:     14,
          borderRadius:      42,
          actionButtonRadius: 28,
          animationDuration: Duration(milliseconds: 360),
          animationCurve:    Curves.easeInOutCubicEmphasized,
        ),
        items: const [
          LiquidGlassNavItem(
            icon:       Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label:      'Home',
          ),
          LiquidGlassNavItem(
            icon:       Icons.search_outlined,
            activeIcon: Icons.search_rounded,
            label:      'Search',
          ),
          LiquidGlassNavItem(
            icon:       Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label:      'Settings',
          ),
        ],
        actionButton: LiquidGlassActionButton(
          icon:  Icons.add_rounded,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Action button tapped'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_index],
      ),
    );
  }
}

// ── Colourful grid page (demo background so you can see the blur clearly) ──

class _ColorGridPage extends StatelessWidget {
  const _ColorGridPage({required this.label, required this.color});

  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar background so blur captures page content
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(label),
            backgroundColor: color.withAlpha(200),
            foregroundColor: Colors.white,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:   4,
                mainAxisSpacing:  8,
                crossAxisSpacing: 8,
              ),
              itemCount: 32,
              itemBuilder: (_, i) {
                final hue = (i * 22.0) % 360;
                return Container(
                  decoration: BoxDecoration(
                    color:        HSVColor.fromAHSV(1, hue, 0.7, 0.85).toColor(),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize:   18,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
