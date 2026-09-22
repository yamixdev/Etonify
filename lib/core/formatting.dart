String formatBytes(double bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final precision = value >= 100
      ? 0
      : value >= 10
      ? 1
      : 2;
  return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
}

String formatSpeed(double bytesPerSecond) => '${formatBytes(bytesPerSecond)}/s';

/// Size of a routing rule-set file or its download, in `B`/`KB`/`MB`.
///
/// Unlike [formatBytes] this ladder stops at MB and fixes the precision, which
/// is what the rule-set panels need: they never reach GB and reflow if the
/// string changes width.
String formatRuleSetBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

/// `dd.MM.yyyy HH:mm` in the device's local time.
String formatLocalDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
