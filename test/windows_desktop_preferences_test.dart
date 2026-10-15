import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/platform/windows/desktop_preferences.dart';

void main() {
  test('Windows defaults do not turn on privileged modes', () {
    expect(DesktopModePreferences.defaults.tunEnabled, isFalse);
    expect(DesktopModePreferences.defaults.systemProxyEnabled, isFalse);
    expect(DesktopModePreferences.defaults.launchAtLogin, isFalse);
    expect(DesktopModePreferences.defaults.launchMinimized, isTrue);
    expect(DesktopModePreferences.defaults.connectOnLaunch, isFalse);
    expect(
      DesktopModePreferences.defaults.processRoutingMode,
      ProcessRoutingMode.allExceptSelected,
    );
    expect(DesktopModePreferences.defaults.processPaths, isEmpty);
  });

  test('all mode flags, paths and unknown keys survive typed round trip', () {
    final value = DesktopModePreferences.fromMap({
      'tunEnabled': true,
      'systemProxyEnabled': true,
      'launchAtLogin': true,
      'launchMinimized': false,
      'connectOnLaunch': true,
      'processRoutingMode': 'onlySelected',
      'processPaths': ['C:\\Apps\\a.exe'],
      'futureMode': {'enabled': true},
    });
    final restored = DesktopModePreferences.fromMap(value.toMap());
    expect(restored.toMap(), {
      'tunEnabled': true,
      'systemProxyEnabled': true,
      'launchAtLogin': true,
      'launchMinimized': false,
      'connectOnLaunch': true,
      'processRoutingMode': 'onlySelected',
      'processPaths': ['C:\\Apps\\a.exe'],
      'futureMode': {'enabled': true},
    });
    expect(restored.toMap(), value.toMap());
    expect(restored.processRoutingMode, ProcessRoutingMode.onlySelected);
    expect(restored.copyWith(tunEnabled: false).toMap()['tunEnabled'], false);
    expect(restored.toMap()['futureMode'], {'enabled': true});
  });

  test('invalid stored typed values fall back without overriding defaults', () {
    final value = DesktopModePreferences.fromMap({
      'tunEnabled': 'true',
      'launchMinimized': 0,
      'processRoutingMode': 'future',
      'processPaths': [1, 'a.exe'],
    });
    expect(value.tunEnabled, false);
    expect(value.launchMinimized, true);
    expect(value.processRoutingMode, ProcessRoutingMode.allExceptSelected);
    expect(value.processPaths, ['a.exe']);
    expect(value.toMap()['tunEnabled'], false);
  });

  test('presentation stays separate from modes and retains unknown keys', () {
    expect(
      DesktopPresentationPreferences.defaults.proxyListStyle,
      ProxyListStyle.compact,
    );
    final value = DesktopPresentationPreferences.fromMap({
      'proxyListStyle': 'comfortable',
      'future': 42,
    });
    expect(value.proxyListStyle, ProxyListStyle.comfortable);
    expect(value.copyWith(proxyListStyle: ProxyListStyle.compact).toMap(), {
      'future': 42,
      'proxyListStyle': 'compact',
    });
    expect(
      DesktopModePreferences.defaults.toMap(),
      isNot(contains('proxyListStyle')),
    );
  });
}
