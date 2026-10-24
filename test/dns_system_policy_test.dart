import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/app_settings_controller.dart';
import 'package:meow_client/data/local/app_settings_store.dart';

void main() {
  test('proxy resolver cannot silently use the physical network resolver', () {
    final controller = AppSettingsController();
    final original = controller.dnsProxyResolver;
    expect(controller.setDnsProxyPreset('device').changed, isFalse);
    expect(controller.setDnsProxyResolver('device://network').changed, isFalse);
    expect(controller.dnsProxyResolver, original);
  });

  test('system DNS and proxying direct DNS are mutually exclusive', () {
    final controller = AppSettingsController();
    controller.setDnsDirectPreset('device');
    expect(controller.dnsDirectResolver, 'device://network');
    expect(controller.setDnsDirectThroughProxy(true).changed, isFalse);
    expect(controller.dnsDirectThroughProxy, isFalse);
    controller.setDnsDirectResolver(defaultSecureDnsDirectResolver);
    controller.setDnsDirectThroughProxy(true);
    expect(controller.setDnsDirectPreset('device').changed, isFalse);
    expect(
      controller.setDnsDirectResolver('device://network').changed,
      isFalse,
    );
    expect(controller.dnsDirectResolver, defaultSecureDnsDirectResolver);
  });
}
