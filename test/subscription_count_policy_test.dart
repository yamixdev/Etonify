import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/subscriptions/subscriptions_page.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  test('rechecks a zero count when a saved payload exists', () {
    const subscription = Subscription(
      id: 'stale-count',
      name: 'Profile',
      url: 'https://example.com',
      cachedVisibleProxyCount: 0,
      hasRawPayload: true,
    );
    expect(subscriptionCountNeedsHydration(subscription), isTrue);
    expect(
      subscriptionCountNeedsHydration(
        subscription.copyWith(hasRawPayload: false),
      ),
      isFalse,
    );
    expect(
      subscriptionCountNeedsHydration(
        subscription.copyWith(cachedVisibleProxyCount: 226),
      ),
      isFalse,
    );
  });
}
