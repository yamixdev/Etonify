import 'package:meow_client/models/subscription.dart';

String normalizeOutboundCountryCode(String? countryCode) {
  final normalized = countryCode?.trim().toUpperCase() ?? '';
  return RegExp(r'^[A-Z]{2}$').hasMatch(normalized) ? normalized : '';
}

/// Returns the country that should be shown beside an outbound.
///
/// [OutboundInfo.country] comes from the subscription or proxy name, while
/// [OutboundInfo.exitCountry] is observed through the proxy itself. Once an
/// exit location is known it must take precedence, otherwise a node named for
/// one country can keep showing that flag even when its public IP is elsewhere.
String outboundDisplayCountryCode(
  Outbound outbound, {
  required bool markAllServersRussia,
}) {
  if (markAllServersRussia) {
    return 'RU';
  }
  final exitCountry = normalizeOutboundCountryCode(outbound.info.exitCountry);
  return exitCountry.isNotEmpty
      ? exitCountry
      : normalizeOutboundCountryCode(outbound.info.country);
}

/// Whether the cached location is a complete observation of the proxy exit.
///
/// Older versions could store the observed country in [OutboundInfo.country].
/// Requiring the dedicated exit field makes those records run through the
/// current lookup once and migrate without treating a name-derived country as
/// verified.
bool hasResolvedOutboundExitLocation(
  Outbound outbound, {
  required bool markAllServersRussia,
}) {
  if (markAllServersRussia) {
    return true;
  }
  final externalIp = outbound.info.externalIp?.trim() ?? '';
  return externalIp.isNotEmpty &&
      normalizeOutboundCountryCode(outbound.info.exitCountry).isNotEmpty;
}
