import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/settings/settings_routing_page.dart';

void main() {
  group('split routing app search', () {
    test('matches app label, package parts, and small typos', () {
      const label = 'Telegram';
      const packageName = 'org.telegram.messenger';

      expect(
        installedAppSearchScoreForTest(
          label: label,
          packageName: packageName,
          query: 'telegram',
        ),
        greaterThanOrEqualTo(0),
      );
      expect(
        installedAppSearchScoreForTest(
          label: 'Telegram Beta',
          packageName: 'org.telegram.messenger-beta',
          query: 'messenger beta',
        ),
        greaterThanOrEqualTo(0),
      );
      expect(
        installedAppSearchScoreForTest(
          label: label,
          packageName: packageName,
          query: 'org messenger',
        ),
        greaterThanOrEqualTo(0),
      );
      expect(
        installedAppSearchScoreForTest(
          label: label,
          packageName: packageName,
          query: 'telegran',
        ),
        greaterThanOrEqualTo(0),
      );
    });
  });
}
