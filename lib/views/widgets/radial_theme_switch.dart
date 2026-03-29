import 'package:flutter/material.dart';
import '../../viewmodels/theme_viewmodel.dart';
import 'theme_switcher.dart';

class RadialThemeSwitch extends StatelessWidget {
  final ThemeViewModel themeViewModel;

  const RadialThemeSwitch({Key? key, required this.themeViewModel})
    : super(key: key);

  void _onTogglePressed(Offset position, BuildContext context) async {
    // Match the exact pattern from app bar menu that WORKS
    // Small delay for smooth transition
    await Future.delayed(const Duration(milliseconds: 50));
    if (!context.mounted) return;

    // Trigger animation from toggle position
    await ThemeSwitcherWrapper.toggleThemeWithAnimation(context, position);

    // Persist the change to storage
    if (context.mounted) {
      await themeViewModel.toggleTheme();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read from ThemeSwitcherController (same source as MaterialApp)
    final controller = ThemeSwitcherWrapper.controllerOf(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isDarkMode = controller.isDark;
        final textColor =
            Theme.of(context).textTheme.bodyMedium?.color ??
            (isDarkMode ? Colors.white : Colors.black87);

        return GestureDetector(
          onTapDown: (details) {
            _onTogglePressed(details.globalPosition, context);
          },
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Dark Mode', style: TextStyle(color: textColor)),
            subtitle: Text(
              'Use dark theme',
              style: TextStyle(color: textColor.withAlpha(180)),
            ),
            value: isDarkMode,
            onChanged: (_) {
              // Tap handled by GestureDetector above
            },
          ),
        );
      },
    );
  }
}
