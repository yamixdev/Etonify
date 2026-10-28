import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/subscriptions/subscription_qr_content.dart';

void main() {
  test('QR import accepts provider links and standalone proxy URIs', () {
    expect(isSupportedSubscriptionQrContent('https://example.com/sub'), isTrue);
    expect(
      isSupportedSubscriptionQrContent(
        'vless://00000000-0000-0000-0000-000000000001@example.com:443?type=tcp&security=none#Proxy',
      ),
      isTrue,
    );
    expect(
      isSupportedSubscriptionQrContent(
        'trojan://password@example.com:443#Proxy',
      ),
      isTrue,
    );
    expect(isSupportedSubscriptionQrContent('not a proxy'), isFalse);
    expect(isSupportedSubscriptionQrContent('file:///etc/passwd'), isFalse);
    expect(isSupportedSubscriptionQrContent('vless://'), isFalse);
    expect(isSupportedSubscriptionQrContent(''), isFalse);
  });
}
