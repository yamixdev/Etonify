import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/core/formatting.dart';

void main() {
  group('formatBytes', () {
    test('climbs the unit ladder and widens precision as values shrink', () {
      expect(formatBytes(0), equals('0.00 B'));
      expect(formatBytes(999), equals('999 B'));
      expect(formatBytes(1024), equals('1.00 KB'));
      expect(formatBytes(20480), equals('20.0 KB'));
      expect(formatBytes(5242880), equals('5.00 MB'));
      expect(formatBytes(3221225472), equals('3.00 GB'));
    });

    test('stops at the terabyte rung', () {
      expect(formatBytes(1099511627776), equals('1.00 TB'));
      expect(formatBytes(2199023255552), equals('2.00 TB'));
    });
  });

  test('formatSpeed appends the per-second unit', () {
    expect(formatSpeed(1024), equals('1.00 KB/s'));
  });

  group('formatRuleSetBytes', () {
    test('uses whole B and KB and one decimal MB', () {
      expect(formatRuleSetBytes(0), equals('0 B'));
      expect(formatRuleSetBytes(1023), equals('1023 B'));
      expect(formatRuleSetBytes(4096), equals('4 KB'));
      expect(formatRuleSetBytes(1048576), equals('1.0 MB'));
      expect(formatRuleSetBytes(5242880), equals('5.0 MB'));
    });

    test('caps at MB instead of rolling over to GB', () {
      expect(formatRuleSetBytes(1073741824), equals('1024.0 MB'));
    });
  });

  group('formatLocalDateTime', () {
    test('renders day.month.year hour:minute with zero padding', () {
      expect(
        formatLocalDateTime(DateTime(2026, 3, 5, 7, 8, 9)),
        equals('05.03.2026 07:08'),
      );
      expect(
        formatLocalDateTime(DateTime(2026, 12, 31, 23, 59)),
        equals('31.12.2026 23:59'),
      );
    });
  });
}
