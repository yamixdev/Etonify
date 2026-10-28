import 'package:meow_client/data/subscription/happ_crypto_link.dart';
import 'package:meow_client/data/subscription/parsers/link_parser.dart';

bool isSupportedSubscriptionQrContent(String content) {
  final value = content.trim();
  if (HappCryptoLinkDecoder.isSupportedSubscriptionUrl(value)) return true;
  final proxy = LinkParser.tryParse(value);
  return proxy != null &&
      (proxy['server'] as String? ?? '').trim().isNotEmpty &&
      (proxy['server_port'] as int? ?? 0) > 0 &&
      (proxy['server_port'] as int? ?? 0) <= 65535;
}
