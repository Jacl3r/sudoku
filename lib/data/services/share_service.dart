import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Opens the system share sheet on Android. Everywhere else, or if the
/// share sheet is not available, the text is copied instead.
///
/// Returns true if the share sheet was opened.
Future<bool> shareText(String text) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      const channel = MethodChannel('sudoku/share');
      final ok = await channel.invokeMethod<bool>('shareText', {'text': text});
      if (ok ?? false) return true;
    } on PlatformException {
      // Fall through to clipboard.
    } on MissingPluginException {
      // Fall through to clipboard.
    }
  }
  await Clipboard.setData(ClipboardData(text: text));
  return false;
}
