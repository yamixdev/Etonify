import 'package:flutter/services.dart';

/// Keeps a one-line [TextField] from accepting a newline on any platform.
///
/// Shared because `deny(...)` compiles its [RegExp] and allocates a formatter
/// on every call, and five text fields needed byte-identical copies of it.
final FilteringTextInputFormatter noNewlineInputFormatter =
    FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'));
