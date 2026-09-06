import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/runtime_event_controller.dart';
import 'package:meow_client/logging/app_log_store.dart';

void main() {
  test(
    'early group snapshots coalesce and replay once for the same runtime',
    () {
      final pending = PendingRuntimeGroups();
      for (var i = 0; i < 50; i++) {
        pending.remember(RuntimeGroupsEvent(groups: [i], runtimeGeneration: 7));
      }
      pending.remember(
        const RuntimeGroupsEvent(groups: ['old'], runtimeGeneration: 6),
      );
      expect(pending.take(7)?.groups, [49]);
      expect(pending.take(7), isNull);
      pending.remember(
        const RuntimeGroupsEvent(groups: [1], runtimeGeneration: 7),
      );
      expect(pending.take(8), isNull);
      pending.remember(
        const RuntimeGroupsEvent(groups: [1], runtimeGeneration: 8),
      );
      pending.clear();
      expect(pending.take(8), isNull);
      pending.remember(
        const RuntimeGroupsEvent(groups: [1], runtimeGeneration: 0),
      );
      expect(pending.take(0), isNull);
    },
  );

  tearDown(AppLogStore.clear);

  test('dispatch routes typed runtime events to callbacks', () {
    RuntimeStateEvent? state;
    Map<String, dynamic>? status;
    Map<String, dynamic>? network;
    RuntimeGroupsEvent? groups;

    final controller = RuntimeEventController(
      events: const Stream.empty(),
      onState: (event) => state = event,
      onStatus: (event) => status = event,
      onNetwork: (event) => network = event,
      onGroups: (event) => groups = event,
      shouldRecordLog: (_) => true,
    );

    controller.dispatch({'type': 'state', 'running': true});
    controller.dispatch({'type': 'status', 'uplink': 11});
    controller.dispatch({'type': 'network', 'reason': 'default_interface'});
    controller.dispatch({
      'type': 'groups',
      'groups': [
        {'tag': 'select'},
      ],
    });

    expect(state?.running, isTrue);
    expect(state?.hasError, isFalse);
    expect(status?['uplink'], 11);
    expect(network?['reason'], 'default_interface');
    expect(groups?.groups, [
      {'tag': 'select'},
    ]);
    expect(groups?.runtimeGeneration, 0);
  });

  test('nativeLog normalizes warn and records through AppLogStore', () {
    final controller = RuntimeEventController(
      events: const Stream.empty(),
      onState: (_) {},
      onStatus: (_) {},
      onNetwork: (_) {},
      onGroups: (_) {},
      shouldRecordLog: (_) => true,
    );

    controller.dispatch({
      'type': 'nativeLog',
      'level': 'warn',
      'message': 'default interface unavailable',
    });

    final entry = AppLogStore.entries.value.single;
    expect(entry.title, 'sing-box');
    expect(entry.level, 'warning');
    expect(entry.message, 'default interface unavailable');
  });

  test('logs batch filters debug entries and keeps inferred error level', () {
    final controller = RuntimeEventController(
      events: const Stream.empty(),
      onState: (_) {},
      onStatus: (_) {},
      onNetwork: (_) {},
      onGroups: (_) {},
      shouldRecordLog: (level) => level != 'debug',
      now: () => DateTime.fromMillisecondsSinceEpoch(42),
    );

    controller.dispatch({
      'type': 'logs',
      'logs': [
        {'level': 0, 'message': 'debug details'},
        {'level': 4, 'message': 'connection failed'},
      ],
    });

    final entries = AppLogStore.entries.value;
    expect(entries.length, 1);
    expect(entries.single.level, 'error');
    expect(entries.single.title, 'sing-box');
    expect(entries.single.message, 'connection failed');
    expect(entries.single.timestamp, DateTime.fromMillisecondsSinceEpoch(42));
  });

  test('nativeLog reports hard interface dial failures as runtime issues', () {
    final issues = <String>[];
    final controller = RuntimeEventController(
      events: const Stream.empty(),
      onState: (_) {},
      onStatus: (_) {},
      onNetwork: (_) {},
      onGroups: (_) {},
      shouldRecordLog: (_) => false,
      onRuntimeLogIssue: (reason, message) {
        issues.add('$reason|$message');
      },
    );

    controller.dispatch({
      'type': 'nativeLog',
      'level': 'error',
      'message':
          'connection: open connection using outbound/vless[vless-1]: '
          'dial ccmni1 (14): dial tcp 203.0.113.1:443: network is unreachable',
    });

    expect(issues, hasLength(1));
    expect(issues.single, contains('core_interface_dial_failure'));
  });

  test('nativeLog ignores remote timeout on a valid interface', () {
    final issues = <String>[];
    final controller = RuntimeEventController(
      events: const Stream.empty(),
      onState: (_) {},
      onStatus: (_) {},
      onNetwork: (_) {},
      onGroups: (_) {},
      shouldRecordLog: (_) => false,
      onRuntimeLogIssue: (reason, message) {
        issues.add('$reason|$message');
      },
    );

    controller.dispatch({
      'type': 'nativeLog',
      'level': 'error',
      'message':
          'connection: open connection using outbound/vless[vless-1]: '
          'dial wlan0 (36): dial tcp 203.0.113.1:443: i/o timeout',
    });

    expect(issues, isEmpty);
  });

  test('logs batch reports no-interface runtime issues', () {
    final issues = <String>[];
    final controller = RuntimeEventController(
      events: const Stream.empty(),
      onState: (_) {},
      onStatus: (_) {},
      onNetwork: (_) {},
      onGroups: (_) {},
      shouldRecordLog: (_) => true,
      onRuntimeLogIssue: (reason, message) {
        issues.add(reason);
      },
    );

    controller.dispatch({
      'type': 'logs',
      'logs': [
        {
          'level': 4,
          'message': 'manual URLTest skipped: no usable network interface',
        },
        {'level': 4, 'message': 'regular proxy timeout'},
      ],
    });

    expect(issues, ['core_no_usable_interface']);
  });

  test('start subscribes to stream and dispose cancels subscription', () async {
    final stream = StreamController<Map<String, dynamic>>();
    addTearDown(stream.close);
    final states = <RuntimeStateEvent>[];
    final controller = RuntimeEventController(
      events: stream.stream,
      onState: states.add,
      onStatus: (_) {},
      onNetwork: (_) {},
      onGroups: (_) {},
      shouldRecordLog: (_) => true,
    );

    controller.start();
    stream.add({'type': 'state', 'running': true});
    await Future<void>.delayed(Duration.zero);

    expect(states.single.running, isTrue);

    await controller.dispose();
    stream.add({'type': 'state', 'running': false});
    await Future<void>.delayed(Duration.zero);

    expect(states.length, 1);
  });
}
