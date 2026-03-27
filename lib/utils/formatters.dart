// utils/formatters.dart
import 'package:intl/intl.dart';

class Formatters {
  // Currency formatter for Indian Rupees
  static String currency(double amount, {bool showSymbol = true}) {
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    final formatted = formatter.format(amount.abs());
    return showSymbol ? '₹$formatted' : formatted;
  }

  // Compact currency format (K, L, Cr)
  static String currencyCompact(double amount) {
    final absAmount = amount.abs();
    String formatted;
    
    if (absAmount >= 10000000) {
      // Crores
      formatted = '₹${(absAmount / 10000000).toStringAsFixed(2)} Cr';
    } else if (absAmount >= 100000) {
      // Lakhs
      formatted = '₹${(absAmount / 100000).toStringAsFixed(2)} L';
    } else if (absAmount >= 1000) {
      // Thousands
      formatted = '₹${(absAmount / 1000).toStringAsFixed(2)} K';
    } else {
      formatted = currency(absAmount);
    }
    
    return amount < 0 ? '-$formatted' : formatted;
  }

  // Date formatters
  static String date(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String dateShort(DateTime date) {
    return DateFormat('dd/MM/yy').format(date);
  }

  static String dateLong(DateTime date) {
    return DateFormat('EEEE, MMMM dd, yyyy').format(date);
  }

  static String time(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  static String dateTime(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  static String monthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  static String month(DateTime date) {
    return DateFormat('MMM').format(date);
  }

  static String year(DateTime date) {
    return DateFormat('yyyy').format(date);
  }

  // Relative time
  static String relativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
  }

  // Number formatters
  static String number(int number) {
    final formatter = NumberFormat('#,##,##0', 'en_IN');
    return formatter.format(number);
  }

  static String percentage(double value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  // Masked balance (for privacy)
  static String maskedBalance() {
    return '******';
  }

  // Transaction reference formatting
  static String reference(String ref) {
    if (ref.length <= 10) return ref;
    return '${ref.substring(0, 4)}...${ref.substring(ref.length - 4)}';
  }
}
