const Map<String, String> _importedKeyAliases = {
  'noGRPCHeader': 'no_grpc_header',
  'noSSEHeader': 'no_sse_header',
  'uplinkHTTPMethod': 'uplink_http_method',
};

/// Converts camelCase/PascalCase keys used by Xray into sing-box snake_case.
///
/// Acronyms need a word-boundary aware conversion: a character-by-character
/// implementation turns `noSSEHeader` into the invalid `no_s_s_e_header`.
String normalizeImportedKey(String value) {
  final key = value.trim();
  final alias = _importedKeyAliases[key];
  if (alias != null) return alias;
  return key
      .replaceAllMapped(
        RegExp(r'([A-Z]+)([A-Z][a-z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .toLowerCase();
}
