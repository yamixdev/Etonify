import 'release_image_loader.dart';

/// Recognizes only image tags, never interprets the rest of remote HTML.
/// Code fences, indented code and inline code stay untouched.
String normalizeReleaseNotesImages(String body) {
  final output = StringBuffer();
  final prose = StringBuffer();
  String? fence;
  var fenceLength = 0;
  void flush() {
    output.write(_normalizeImageTags(prose.toString()));
    prose.clear();
  }

  for (final line in body.split('\n')) {
    final match = RegExp(r'^ {0,3}(`{3,}|~{3,})').firstMatch(line);
    if (fence != null) {
      output.writeln(line);
      if (match != null &&
          match[1]!.startsWith(fence) &&
          match[1]!.length >= fenceLength &&
          line.substring(match.end).trim().isEmpty) {
        fence = null;
      }
    } else if (match != null) {
      flush();
      fence = match[1]![0];
      fenceLength = match[1]!.length;
      output.writeln(line);
    } else if (line.startsWith('    ') || line.startsWith('\t')) {
      flush();
      output.writeln(line);
    } else {
      prose.writeln(line);
    }
  }
  flush();
  return output.toString().trimRight();
}

final _imageOrCode = RegExp(
  r'''(`+)[\s\S]*?\1|<img\b(?:[^>"']|"[^"]*"|'[^']*')*>''',
  caseSensitive: false,
);
final _attribute = RegExp(
  r'''(?:^|\s)([a-zA-Z_:][\w:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>"'=<>`]+))''',
  caseSensitive: false,
);

String _normalizeImageTags(String body) => body.replaceAllMapped(_imageOrCode, (
  match,
) {
  final tag = match[0]!;
  if (tag.startsWith('`') || tag.length > 4096) return tag;
  final attributes = <String, String>{};
  for (final attribute in _attribute.allMatches(tag.substring(4))) {
    if (!const {'src', 'alt'}.contains(attribute[1]!.toLowerCase())) {
      continue;
    }
    attributes[attribute[1]!
        .toLowerCase()] = (attribute[2] ?? attribute[3] ?? attribute[4] ?? '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
  final alt = (attributes['alt'] ?? 'image')
      .replaceAll(RegExp(r'[\r\n\[\]\\]'), ' ')
      .trim();
  final uri = Uri.tryParse(attributes['src'] ?? '');
  if (uri == null || !isTrustedReleaseImageUri(uri)) return '\n\n[$alt]\n\n';
  final url = uri.toString().replaceAll('(', '%28').replaceAll(')', '%29');
  return '\n\n![$alt]($url)\n\n';
});
