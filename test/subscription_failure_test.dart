import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:meow_client/data/subscription/happ_crypto_link.dart';
import 'package:meow_client/data/subscription/subscription_failure.dart';
import 'package:meow_client/features/subscriptions/subscription_error_message.dart';
import 'package:meow_client/l10n/generated/app_localizations_en.dart';
import 'package:meow_client/l10n/generated/app_localizations_ru.dart';

void main() {
  group('classifySubscriptionFailure', () {
    test('keeps the HTTP status for a provider response', () {
      final failure = classifySubscriptionFailure(
        SubscriptionHttpStatusException(502),
      );

      expect(failure.kind, SubscriptionFailureKind.httpStatus);
      expect(failure.httpStatus, 502);
    });

    test('distinguishes common network failures', () {
      expect(
        classifySubscriptionFailure(
          const SocketException('Failed host lookup: provider.example'),
        ).kind,
        SubscriptionFailureKind.dns,
      );
      expect(
        classifySubscriptionFailure(
          const SocketException('Connection refused'),
        ).kind,
        SubscriptionFailureKind.connection,
      );
      expect(
        classifySubscriptionFailure(
          const HandshakeException('CERTIFICATE_VERIFY_FAILED'),
        ).kind,
        SubscriptionFailureKind.tls,
      );
      expect(
        classifySubscriptionFailure(
          TimeoutException('subscription import timed out'),
        ).kind,
        SubscriptionFailureKind.timeout,
      );
    });

    test('distinguishes content and Happ failures', () {
      expect(
        classifySubscriptionFailure(
          const SubscriptionContentException(
            SubscriptionContentFailureKind.emptyResponse,
          ),
        ).kind,
        SubscriptionFailureKind.emptyResponse,
      );
      expect(
        classifySubscriptionFailure(StateError('No usable proxies found')).kind,
        SubscriptionFailureKind.noUsableProxies,
      );
      expect(
        classifySubscriptionFailure(
          const SubscriptionContentException(
            SubscriptionContentFailureKind.wireGuardUnsupported,
          ),
        ).kind,
        SubscriptionFailureKind.wireGuardUnsupported,
      );
      expect(
        classifySubscriptionFailure(
          const UnsupportedHappCryptoLinkException('unsupported'),
        ).kind,
        SubscriptionFailureKind.happUnsupported,
      );
      expect(
        classifySubscriptionFailure(
          const HappCryptoLinkException('decrypt failed'),
        ).kind,
        SubscriptionFailureKind.happInvalid,
      );
    });

    test('recognizes legacy exception messages without exposing them', () {
      expect(
        classifySubscriptionFailure(
          const HttpException('Subscription server returned 403'),
        ).httpStatus,
        403,
      );
      expect(
        classifySubscriptionFailure(
          const HttpException(
            'Sensitive subscription credentials require HTTPS',
          ),
        ).kind,
        SubscriptionFailureKind.credentialsRequireHttps,
      );
    });
  });

  group('subscriptionErrorMessage', () {
    test('explains HTTP 502 in both supported languages', () {
      final error = SubscriptionHttpStatusException(502);

      expect(
        subscriptionErrorMessage(error, AppLocalizationsEn()),
        contains('HTTP 502'),
      );
      expect(
        subscriptionErrorMessage(error, AppLocalizationsRu()),
        allOf(contains('HTTP 502'), contains('провайдер')),
      );
    });

    test('saved placeholder warning includes the actual reason', () {
      final message = subscriptionSavedWarningMessage(
        const SubscriptionContentException(
          SubscriptionContentFailureKind.emptyResponse,
        ),
        AppLocalizationsRu(),
      );

      expect(message, contains('Подписка сохранена без серверов'));
      expect(message, contains('пустой ответ'));
    });

    test('WireGuard warning explains the version and skips generic advice', () {
      final message = subscriptionSavedWarningMessage(
        const SubscriptionContentException(
          SubscriptionContentFailureKind.wireGuardUnsupported,
        ),
        AppLocalizationsRu(),
      );

      expect(message, contains('WireGuard'));
      expect(message, contains('0.3.1'));
      expect(message, contains('пропущены'));
      expect(message, isNot(contains('HWID')));
    });

    test('unknown errors do not expose raw exception text', () {
      const secret = 'vless://uuid-secret@example.com';
      final message = subscriptionErrorMessage(
        Exception(secret),
        AppLocalizationsEn(),
      );

      expect(message, isNot(contains(secret)));
      expect(message, contains('Diagnostics'));
    });
  });
}
