import 'package:flutter_test/flutter_test.dart';
import 'package:x_pense/services/csv_service.dart';

void main() {
  group('CsvService autoCategorize', () {
    late CsvService csvService;

    setUp(() {
      csvService = CsvService();
    });

    test('categorizes Food & Dining correctly', () {
      expect(csvService.autoCategorize('zomato delivery'), 'Food & Dining');
      expect(csvService.autoCategorize('SWIGGY'), 'Food & Dining');
      expect(csvService.autoCategorize('fancy restaurant'), 'Food & Dining');
      expect(csvService.autoCategorize('food'), 'Food & Dining');
    });

    test('categorizes Transportation correctly', () {
      expect(csvService.autoCategorize('kerala st'), 'Transportation');
      expect(csvService.autoCategorize('bus ticket'), 'Transportation');
      expect(csvService.autoCategorize('PETROL PUMP'), 'Transportation');
      expect(csvService.autoCategorize('Uber Ride'), 'Transportation');
      expect(csvService.autoCategorize('ola cabs'), 'Transportation');
    });

    test('categorizes Shopping correctly', () {
      expect(csvService.autoCategorize('amazon online'), 'Shopping');
      expect(csvService.autoCategorize('FLIPKART order'), 'Shopping');
      expect(csvService.autoCategorize('coffee shop'), 'Shopping');
    });

    test('categorizes Bills & Utilities correctly', () {
      expect(csvService.autoCategorize('jio recharge'), 'Bills & Utilities');
      expect(csvService.autoCategorize('Electricity Bill'), 'Bills & Utilities');
      expect(csvService.autoCategorize('water supply'), 'Bills & Utilities');
      expect(csvService.autoCategorize('sms charges'), 'Bills & Utilities');
    });

    test('categorizes Entertainment correctly', () {
      expect(csvService.autoCategorize('movie tickets'), 'Entertainment');
      expect(csvService.autoCategorize('video game'), 'Entertainment');
    });

    test('categorizes Health correctly', () {
      expect(csvService.autoCategorize('city hospital'), 'Health');
      expect(csvService.autoCategorize('medical store'), 'Health');
      expect(csvService.autoCategorize('Pharmacy'), 'Health');
      expect(csvService.autoCategorize('bismi med'), 'Health');
    });

    test('categorizes Education correctly', () {
      expect(csvService.autoCategorize('state university'), 'Education');
      expect(csvService.autoCategorize('college fees'), 'Education');
      expect(csvService.autoCategorize('high school'), 'Education');
      expect(csvService.autoCategorize('udemy course'), 'Education');
    });

    test('categorizes ATM Withdrawal correctly', () {
      expect(csvService.autoCategorize('atm cash'), 'ATM Withdrawal');
    });

    test('categorizes Transfer/UPI correctly', () {
      expect(csvService.autoCategorize('bank transfer'), 'Transfer/UPI');
      expect(csvService.autoCategorize('upi cr'), 'Transfer/UPI');
      expect(csvService.autoCategorize('upi dr'), 'Transfer/UPI');
    });

    test('categorizes Salary/Income correctly', () {
      expect(csvService.autoCategorize('monthly salary'), 'Salary/Income');
      expect(csvService.autoCategorize('bank interest'), 'Salary/Income');
    });

    test('categorizes unknown descriptions as Uncategorized', () {
      expect(csvService.autoCategorize('unknown item'), 'Uncategorized');
      expect(csvService.autoCategorize('random words'), 'Uncategorized');
      expect(csvService.autoCategorize(''), 'Uncategorized'); // Empty string
      expect(csvService.autoCategorize('12345'), 'Uncategorized');
    });

    test('handles mixed case and extra spaces', () {
      expect(csvService.autoCategorize('  ZOMATO  '), 'Food & Dining');
      expect(csvService.autoCategorize('UBeR'), 'Transportation');
      expect(csvService.autoCategorize('EleCtRiCitY'), 'Bills & Utilities');
    });
  });
}
