import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/backup/etonify_backup_service.dart';
import 'package:meow_client/data/local/app_settings_store.dart';

void main() {
  test(
    'foreign platform namespace survives import and export without applying VPN fields',
    () async {
      final store = MemoryAppSettingsStore();
      final current = await store.loadState();
      final imported = store.mergeSafeImportMap(current, {
        'android': {
          'vpn_inbound_enabled': '0',
          'future': ['kept'],
        },
        'windows': {
          'modes': {'tunEnabled': false},
        },
        'storage.key': 'must-not-export',
      });
      expect(imported.vpnInboundEnabled, current.vpnInboundEnabled);
      final content = const EtonifyBackupService().buildSettingsExport(
        store: store,
        state: imported,
        clientVersion: '0.3.9',
      );
      final parsed = const EtonifyBackupService().parseSettingsExport(
        bytes: utf8.encode(content),
        currentClientVersion: '0.3.9',
      );
      expect(parsed.settings['android'], {
        'vpn_inbound_enabled': '0',
        'future': ['kept'],
      });
      expect(content, isNot(contains('must-not-export')));
    },
  );
}
