import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

String formatTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;

  final parts = <String>[];

  if (h > 0) parts.add('${h}h');
  if (m > 0) parts.add('${m}m');

  parts.add('${s}s');

  return parts.join(' ');
}

// user preference?
String formatDate(DateTime date) {
  return DateFormat('dd MMM yyyy').format(date);
}

/// True where a hardware keyboard is the primary input, so advertising a key
/// is useful. On web this resolves to the host OS, which is what we want.
bool get showKeyboardHints => switch (defaultTargetPlatform) {
  TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => true,
  _ => false,
};

/// Appends the key to a tooltip on desktop only; mobile keeps the plain label.
String shortcutHint(String label, String key) =>
    showKeyboardHints ? '$label ($key)' : label;
