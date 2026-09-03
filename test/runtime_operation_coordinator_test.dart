import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/app/runtime_operation_coordinator.dart';

void main() {
  test('diagnostics wait for matching groups snapshot', () {
    final coordinator = RuntimeOperationCoordinator();
    coordinator.beginSelection('vless-2');
    coordinator.updateNetwork(generation: 4, usable: true);
    coordinator.updateRuntimeState(running: true, nativeRuntimeGeneration: 7);
    coordinator.finishRuntimeTransition(running: true);

    expect(coordinator.diagnosticsReady, isFalse);
    expect(
      coordinator.acceptGroupsSnapshot(
        nativeRuntimeGeneration: 7,
        selectedTag: 'vless-1',
      ),
      isTrue,
    );
    expect(coordinator.diagnosticsReady, isFalse);

    coordinator.acceptGroupsSnapshot(
      nativeRuntimeGeneration: 7,
      selectedTag: 'vless-2',
    );
    expect(coordinator.diagnosticsReady, isTrue);
  });

  test('old runtime groups and diagnostic keys become stale', () {
    final coordinator = RuntimeOperationCoordinator();
    coordinator.beginSelection('vless-1');
    coordinator.updateNetwork(generation: 1, usable: true);
    coordinator.updateRuntimeState(running: true, nativeRuntimeGeneration: 3);
    coordinator.finishRuntimeTransition(running: true);
    coordinator.acceptGroupsSnapshot(
      nativeRuntimeGeneration: 3,
      selectedTag: 'vless-1',
    );
    final oldKey = coordinator.currentKey;

    coordinator.beginRuntimeTransition();
    coordinator.updateRuntimeState(running: true, nativeRuntimeGeneration: 4);
    coordinator.finishRuntimeTransition(running: true);

    expect(coordinator.isCurrent(oldKey), isFalse);
    expect(
      coordinator.acceptGroupsSnapshot(
        nativeRuntimeGeneration: 3,
        selectedTag: 'vless-1',
      ),
      isFalse,
    );
    expect(coordinator.diagnosticsReady, isFalse);
  });

  test('network loss invalidates diagnostics until usable again', () {
    final coordinator = RuntimeOperationCoordinator();
    coordinator.beginSelection('vless-1');
    coordinator.updateRuntimeState(running: true, nativeRuntimeGeneration: 1);
    coordinator.finishRuntimeTransition(running: true);
    coordinator.updateNetwork(generation: 10, usable: true);
    coordinator.acceptGroupsSnapshot(
      nativeRuntimeGeneration: 1,
      selectedTag: 'vless-1',
    );
    final key = coordinator.currentKey;
    expect(coordinator.diagnosticsReady, isTrue);

    coordinator.updateNetwork(generation: 11, usable: false);
    expect(coordinator.diagnosticsReady, isFalse);
    expect(coordinator.isCurrent(key), isFalse);
  });

  test('proxy selection does not invalidate an active URLTest', () {
    final coordinator = RuntimeOperationCoordinator();
    coordinator.updateRuntimeState(running: true, nativeRuntimeGeneration: 1);
    coordinator.finishRuntimeTransition(running: true);
    coordinator.updateNetwork(generation: 10, usable: true);
    final urlTestGeneration = coordinator.urlTestGeneration;

    coordinator.beginSelection('vless-2');

    expect(coordinator.urlTestReady, isTrue);
    expect(coordinator.urlTestGeneration, urlTestGeneration);
  });

  test('runtime and network changes invalidate an active URLTest', () {
    final coordinator = RuntimeOperationCoordinator();
    coordinator.updateRuntimeState(running: true, nativeRuntimeGeneration: 1);
    coordinator.finishRuntimeTransition(running: true);
    coordinator.updateNetwork(generation: 10, usable: true);
    final initialGeneration = coordinator.urlTestGeneration;

    coordinator.updateNetwork(generation: 11, usable: true);
    expect(coordinator.urlTestGeneration, greaterThan(initialGeneration));
    final networkGeneration = coordinator.urlTestGeneration;

    coordinator.beginRuntimeTransition();
    expect(coordinator.urlTestReady, isFalse);
    expect(coordinator.urlTestGeneration, greaterThan(networkGeneration));
  });
}
