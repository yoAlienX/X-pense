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
}
