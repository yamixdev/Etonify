import 'desktop_preferences.dart';

/// Exact executable identity. No file is opened or executed by this policy.
class WindowsProcessRules {
  static List<Map<String, Object?>> build(DesktopModePreferences prefs) {
    final paths = prefs.processPaths.map(canonicalize).toSet().toList();
    return [
      if (paths.isNotEmpty)
        {
          'process_path_regex': paths
              .map((path) => '(?i)^${RegExp.escape(path)}\$')
              .toList(),
          'outbound':
              prefs.processRoutingMode == ProcessRoutingMode.onlySelected
              ? 'select'
              : 'direct',
        },
      if (prefs.processRoutingMode == ProcessRoutingMode.onlySelected)
        {'outbound': 'direct'},
    ];
  }

  static String canonicalize(String path) {
    final value = path.replaceAll('/', r'\');
    if (value.isEmpty ||
        value.trim() != value ||
        RegExp(r'[\x00-\x1f<>"|?*]').hasMatch(value) ||
        value.startsWith(r'\\.\') ||
        value.startsWith(r'\\?\')) {
      throw FormatException('Invalid Windows executable path', path);
    }
    String root;
    List<String> parts;
    if (RegExp(r'^[a-zA-Z]:\\').hasMatch(value)) {
      root = value.substring(0, 3).toLowerCase();
      parts = value.substring(3).split(r'\');
    } else if (value.startsWith(r'\\')) {
      final all = value.substring(2).split(r'\');
      if (all.length < 3 ||
          !_validComponent(all[0]) ||
          !_validComponent(all[1])) {
        throw FormatException('Invalid UNC executable path', path);
      }
      root = '\\\\${all[0].toLowerCase()}\\${all[1].toLowerCase()}\\';
      parts = all.sublist(2);
    } else {
      throw FormatException('Executable path must be Windows absolute', path);
    }
    final normalized = <String>[];
    for (final part in parts) {
      if (part == '.') continue;
      if (part == '..') {
        if (normalized.isEmpty) {
          throw FormatException('Path escapes Windows root', path);
        }
        normalized.removeLast();
        continue;
      }
      if (!_validComponent(part)) {
        throw FormatException('Invalid Windows path component', path);
      }
      normalized.add(part.toLowerCase());
    }
    if (normalized.isEmpty || !normalized.last.endsWith('.exe')) {
      throw FormatException('Process path must identify an executable', path);
    }
    return root + normalized.join(r'\');
  }

  static bool _validComponent(String value) =>
      value.isNotEmpty &&
      value != '.' &&
      value != '..' &&
      !value.contains(':') &&
      !value.endsWith(' ') &&
      !value.endsWith('.') &&
      !RegExp(
        r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
        caseSensitive: false,
      ).hasMatch(value);
}
