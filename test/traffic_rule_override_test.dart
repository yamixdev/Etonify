import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/routing/traffic_rule_override.dart';

void main() {
  TrafficRuleOverride? parse(TrafficRuleMatchType type, String value) =>
      TrafficRuleOverride.tryParse(
        matchType: type,
        value: value,
        action: TrafficRuleAction.vpn,
      );

  test('normalizes exact domains and suffixes', () {
    expect(
      parse(TrafficRuleMatchType.domain, ' Example.NET. ')?.value,
      'example.net',
    );
    expect(
      parse(TrafficRuleMatchType.domainSuffix, '*.Example.NET')?.value,
      'example.net',
    );
    expect(
      parse(TrafficRuleMatchType.domainSuffix, '.example.net')?.value,
      'example.net',
    );
    expect(parse(TrafficRuleMatchType.domain, '*.example.net'), isNull);
    expect(parse(TrafficRuleMatchType.domain, 'example..net'), isNull);
    expect(parse(TrafficRuleMatchType.domain, 'example.net:443'), isNull);
    expect(parse(TrafficRuleMatchType.domain, 'https://example.net'), isNull);
    expect(parse(TrafficRuleMatchType.domain, '192.0.2.1'), isNull);
  });

  test('normalizes literal addresses and masks CIDR host bits', () {
    expect(
      parse(TrafficRuleMatchType.ipCidr, '192.0.2.15')?.value,
      '192.0.2.15/32',
    );
    expect(
      parse(TrafficRuleMatchType.ipCidr, '192.0.2.15/24')?.value,
      '192.0.2.0/24',
    );
    expect(
      parse(TrafficRuleMatchType.ipCidr, '2001:db8:8000:ffff::1/33')?.value,
      '2001:db8:8000::/33',
    );
    expect(parse(TrafficRuleMatchType.ipCidr, '2600::1')?.value, '2600::1/128');
    expect(parse(TrafficRuleMatchType.ipCidr, '192.0.2.1/33'), isNull);
    expect(parse(TrafficRuleMatchType.ipCidr, '2001:db8::1/129'), isNull);
    expect(parse(TrafficRuleMatchType.ipCidr, 'fe80::1%2'), isNull);
    expect(parse(TrafficRuleMatchType.ipCidr, 'example.net'), isNull);
  });

  test('JSON round-trip validates match type, action and value', () {
    final rule = parse(TrafficRuleMatchType.domain, 'example.net')!;
    expect(TrafficRuleOverride.tryFromJson(rule.toJson()), rule);
    expect(TrafficRuleOverride.tryFromJson({'value': 'example.net'}), isNull);
    expect(
      TrafficRuleOverride.tryFromJson({...rule.toJson(), 'action': 'unknown'}),
      isNull,
    );
    expect(
      TrafficRuleOverride.tryFromJson({
        ...rule.toJson(),
        'value': 'a..example',
      }),
      isNull,
    );
  });
}
