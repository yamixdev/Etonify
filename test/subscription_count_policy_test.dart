import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/subscriptions/subscriptions_page.dart';
import 'package:meow_client/models/subscription.dart';

void main() {
  test('fresh summaries do not require hydration even at zero', () {
    const subscription = Subscription(
      id: 'stale-count',
      name: 'Profile',
      url: 'https://example.com',
      cachedVisibleProxyCount: 0,
      hasRawPayload: true,
    );
    expect(subscriptionCountNeedsHydration(subscription), isFalse);
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
