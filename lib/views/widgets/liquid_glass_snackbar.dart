import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class LiquidGlassSnackBar extends SnackBar {
  LiquidGlassSnackBar({
    required BuildContext context,
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onDismissed,
  }) : super(
         content: _LiquidGlassSnackBarContent(
           message: message,
           type: type,
           context: context,
         ),
         backgroundColor: Colors.transparent,
         elevation: 0,
         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
         behavior: SnackBarBehavior.floating,
         margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
         duration: duration,
         onVisible: onDismissed,
       );
}

enum SnackBarType { success, error, warning, info }

class _LiquidGlassSnackBarContent extends StatefulWidget {
  final String message;
  final SnackBarType type;
  final BuildContext context;

  const _LiquidGlassSnackBarContent({
    required this.message,
    required this.type,
    required this.context,
  });

  @override
  State<_LiquidGlassSnackBarContent> createState() =>
      _LiquidGlassSnackBarContentState();
}

class _LiquidGlassSnackBarContentState
    extends State<_LiquidGlassSnackBarContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late bool _isDarkMode;
  late TextStyle _messageTextStyle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    _isDarkMode = theme.brightness == Brightness.dark;
    // Text color based on theme (inverted for readability)
    _messageTextStyle =
        theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: _isDarkMode ? Colors.black87 : Colors.white,
        ) ??
        TextStyle(
          fontWeight: FontWeight.w500,
          color: _isDarkMode ? Colors.black87 : Colors.white,
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getTypeColor() {
    switch (widget.type) {
      case SnackBarType.success:
        return AppConstants.incomeGreen;
      case SnackBarType.error:
        return AppConstants.expenseRed;
      case SnackBarType.warning:
        return _isDarkMode ? const Color(0xFFFCAC12) : Colors.orange.shade600;
      case SnackBarType.info:
        return _isDarkMode ? const Color(0xFF0077FF) : Colors.blue.shade400;
    }
  }

  IconData _getTypeIcon() {
    switch (widget.type) {
      case SnackBarType.success:
        return Icons.check_circle_outline;
      case SnackBarType.error:
        return Icons.error_outline;
      case SnackBarType.warning:
        return Icons.warning_outlined;
      case SnackBarType.info:
        return Icons.info_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor();
    final backgroundColor = _isDarkMode
        ? const Color(0xFFFAFAFA)
        : const Color(0xFF1F1F1F);

    return ScaleTransition(
      scale: _animation,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: typeColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_getTypeIcon(), size: 18, color: typeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.message,
                style: _messageTextStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
