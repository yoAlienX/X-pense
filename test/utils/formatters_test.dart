import 'package:flutter_test/flutter_test.dart';
import 'package:x_pense/utils/formatters.dart';

void main() {
  group('Formatters', () {
    group('relativeTime', () {
      test('returns "Just now" for dates less than a minute ago', () {
        final now = DateTime.now();
        expect(Formatters.relativeTime(now), 'Just now');
        expect(Formatters.relativeTime(now.subtract(const Duration(seconds: 30))), 'Just now');
      });

      test('returns minutes ago for dates < 1 hour', () {
        final now = DateTime.now();
        expect(Formatters.relativeTime(now.subtract(const Duration(minutes: 1))), '1 min ago');
        expect(Formatters.relativeTime(now.subtract(const Duration(minutes: 59))), '59 min ago');
      });

      test('returns hours ago for dates < 1 day', () {
        final now = DateTime.now();
        expect(Formatters.relativeTime(now.subtract(const Duration(hours: 1))), '1 hour ago');
        expect(Formatters.relativeTime(now.subtract(const Duration(hours: 2))), '2 hours ago');
        expect(Formatters.relativeTime(now.subtract(const Duration(hours: 23))), '23 hours ago');
      });

      test('returns "Yesterday" for dates exactly 1 day ago', () {
        final now = DateTime.now();
        expect(Formatters.relativeTime(now.subtract(const Duration(days: 1))), 'Yesterday');
      });

      test('returns days ago for dates < 7 days', () {
        final now = DateTime.now();
        expect(Formatters.relativeTime(now.subtract(const Duration(days: 2))), '2 days ago');
        expect(Formatters.relativeTime(now.subtract(const Duration(days: 6))), '6 days ago');
      });

      test('returns weeks ago for dates < 30 days', () {
        final now = DateTime.now();
        expect(Formatters.relativeTime(now.subtract(const Duration(days: 7))), '1 week ago');
        expect(Formatters.relativeTime(now.subtract(const Duration(days: 14))), '2 weeks ago');
        expect(Formatters.relativeTime(now.subtract(const Duration(days: 29))), '4 weeks ago');
      });

      test('returns months ago for dates < 365 days', () {
        final now = DateTime.now();
        expect(Formatters.relativeTime(now.subtract(const Duration(days: 30))), '1 month ago');
        expect(Formatters.relativeTime(now.subtract(const Duration(days: 60))), '2 months ago');
        expect(Formatters.relativeTime(now.subtract(const Duration(days: 364))), '12 months ago');
      });

      test('returns years ago for dates >= 365 days', () {
        final now = DateTime.now();
        expect(Formatters.relativeTime(now.subtract(const Duration(days: 365))), '1 year ago');
        expect(Formatters.relativeTime(now.subtract(const Duration(days: 730))), '2 years ago');
      });
    });
  });

  group('Formatters - Currency', () {
    test('formats standard positive values correctly', () {
      expect(Formatters.currency(500), '₹500.00');
      expect(Formatters.currency(1500), '₹1,500.00');
      expect(Formatters.currency(150000), '₹1,50,000.00');
      expect(Formatters.currency(15000000), '₹1,50,00,000.00');
    });

    test('strips negative sign from negative values due to abs()', () {
      expect(Formatters.currency(-500), '₹500.00');
      expect(Formatters.currency(-150000), '₹1,50,000.00');
    });

    test('formats decimals correctly', () {
      expect(Formatters.currency(500.5), '₹500.50');
      expect(Formatters.currency(500.55), '₹500.55');
      // Rounds half even for double depending on intl package configuration,
      // but toStringAsFixed/NumberFormat with #,##,##0.00 will show 2 decimal places.
      expect(Formatters.currency(500.555), '₹500.56'); // assuming standard rounding
    });

    test('hides symbol when showSymbol is false', () {
      expect(Formatters.currency(500, showSymbol: false), '500.00');
      expect(Formatters.currency(-1500, showSymbol: false), '1,500.00');
      expect(Formatters.currency(150000, showSymbol: false), '1,50,000.00');
    });
  });

  group('Formatters - Currency Compact', () {
    test('formats values below 1000 falling back to regular currency format', () {
      expect(Formatters.currencyCompact(0), '₹0.00');
      expect(Formatters.currencyCompact(500), '₹500.00');
      expect(Formatters.currencyCompact(999), '₹999.00');
      expect(Formatters.currencyCompact(999.99), '₹999.99');
    });

    test('formats values in Thousands (>= 1,000 and < 1,00,000)', () {
      expect(Formatters.currencyCompact(1000), '₹1.00 K');
      expect(Formatters.currencyCompact(1500), '₹1.50 K');
      expect(Formatters.currencyCompact(99999), '₹100.00 K'); // 99.999 is rounded to 100.00
      expect(Formatters.currencyCompact(10500), '₹10.50 K');
    });

    test('formats values in Lakhs (>= 1,00,000 and < 1,00,00,000)', () {
      expect(Formatters.currencyCompact(100000), '₹1.00 L');
      expect(Formatters.currencyCompact(150000), '₹1.50 L');
      expect(Formatters.currencyCompact(2500000), '₹25.00 L');
      expect(Formatters.currencyCompact(9999999), '₹100.00 L'); // 99.99999 is rounded to 100.00 L
    });

    test('formats values in Crores (>= 1,00,00,000)', () {
      expect(Formatters.currencyCompact(10000000), '₹1.00 Cr');
      expect(Formatters.currencyCompact(15000000), '₹1.50 Cr');
      expect(Formatters.currencyCompact(123456789), '₹12.35 Cr');
    });

    test('formats negative values correctly at all scales', () {
      expect(Formatters.currencyCompact(-500), '-₹500.00');
      expect(Formatters.currencyCompact(-1500), '-₹1.50 K');
      expect(Formatters.currencyCompact(-150000), '-₹1.50 L');
      expect(Formatters.currencyCompact(-15000000), '-₹1.50 Cr');
    });

    test('handles exact boundary conditions', () {
      expect(Formatters.currencyCompact(1000), '₹1.00 K');
      expect(Formatters.currencyCompact(100000), '₹1.00 L');
      expect(Formatters.currencyCompact(10000000), '₹1.00 Cr');
    });
  });
}
