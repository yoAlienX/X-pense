import 'package:flutter_test/flutter_test.dart';
import 'package:x_pense/utils/formatters.dart';

void main() {
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
