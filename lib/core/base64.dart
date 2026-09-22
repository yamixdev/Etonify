/// Rewrites URL-safe base64 into the standard alphabet with explicit padding.
///
/// `base64Decode` rejects both `-`/`_` and an unpadded length, while
/// subscription payloads arrive in all four combinations.
String toStandardBase64(String input) {
  final padding = switch (input.length % 4) {
    2 => '==',
    3 => '=',
    _ => '',
  };
  return '${input.replaceAll('-', '+').replaceAll('_', '/')}$padding';
}
