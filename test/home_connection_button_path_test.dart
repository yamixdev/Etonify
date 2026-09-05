import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/features/home/home_connection_button.dart';

void main() {
  const buttonSize = Size.square(148.0);

  group('ConnectionButton Path Caching', () {
    test('returns identical cached Path for canonical resting states', () {
      final idleShape1 = ConnectionButtonShape.forState(
        connected: false,
        connecting: false,
        resolvingProxy: false,
      );
      final idleShape2 = ConnectionButtonShape.forState(
        connected: false,
        connecting: false,
        resolvingProxy: false,
      );

      final path1 = connectionButtonCookiePathForTesting(buttonSize, idleShape1);
      final path2 = connectionButtonCookiePathForTesting(buttonSize, idleShape2);
      expect(identical(path1, path2), isTrue);

      final connectedShape1 = ConnectionButtonShape.forState(
        connected: true,
        connecting: false,
        resolvingProxy: false,
      );
      final connectedShape2 = ConnectionButtonShape.forState(
        connected: true,
        connecting: false,
        resolvingProxy: false,
      );

      final connectedPath1 = connectionButtonCookiePathForTesting(
        buttonSize,
        connectedShape1,
      );
      final connectedPath2 = connectionButtonCookiePathForTesting(
        buttonSize,
        connectedShape2,
      );
      expect(identical(connectedPath1, connectedPath2), isTrue);
      expect(identical(path1, connectedPath1), isFalse);

      final connectingShape = ConnectionButtonShape.forState(
        connected: false,
        connecting: true,
        resolvingProxy: false,
      );
      final connectingPath1 = connectionButtonCookiePathForTesting(
        buttonSize,
        connectingShape,
      );
      final connectingPath2 = connectionButtonCookiePathForTesting(
        buttonSize,
        connectingShape,
      );
      expect(identical(connectingPath1, connectingPath2), isTrue);

      final resolvingShape = ConnectionButtonShape.forState(
        connected: false,
        connecting: false,
        resolvingProxy: true,
      );
      final resolvingPath1 = connectionButtonCookiePathForTesting(
        buttonSize,
        resolvingShape,
      );
      final resolvingPath2 = connectionButtonCookiePathForTesting(
        buttonSize,
        resolvingShape,
      );
      expect(identical(resolvingPath1, resolvingPath2), isTrue);
    });

    test('interpolated intermediate states produce valid non-empty paths', () {
      final idle = ConnectionButtonShape.forState(
        connected: false,
        connecting: false,
        resolvingProxy: false,
      );
      final connected = ConnectionButtonShape.forState(
        connected: true,
        connecting: false,
        resolvingProxy: false,
      );

      for (var t = 0.1; t < 1.0; t += 0.2) {
        final lerped = ConnectionButtonShape.lerp(idle, connected, t);
        final path = connectionButtonCookiePathForTesting(buttonSize, lerped);
        final bounds = path.getBounds();
        expect(bounds.width, greaterThan(100.0));
        expect(bounds.height, greaterThan(100.0));
        expect(bounds.width, lessThanOrEqualTo(150.0));
        expect(bounds.height, lessThanOrEqualTo(150.0));
      }
    });

    test('rotated shape produces valid non-empty path', () {
      final shape = const ConnectionButtonShape(
        phase: 1.5,
        rotation: 0.785, // ~45 degrees
        emphasis: 0.5,
      );
      final path = connectionButtonCookiePathForTesting(buttonSize, shape);
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(100.0));
      expect(bounds.height, greaterThan(100.0));
    });

    test('non-standard size dynamically computes valid path', () {
      final customSize = const Size.square(200.0);
      final shape = ConnectionButtonShape.forState(
        connected: true,
        connecting: false,
        resolvingProxy: false,
      );
      final path = connectionButtonCookiePathForTesting(customSize, shape);
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(150.0));
      expect(bounds.height, greaterThan(150.0));
    });
  });
}
