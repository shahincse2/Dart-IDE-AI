import 'package:flutter/material.dart';

import '../services/code_formatter.dart';
import '../services/dart_style_formatter.dart';
import 'code_editor_controller.dart';
import 'overlay_message.dart';

/// Formats the whole text of [controller], keeps the cursor where it was in
/// the code, and tells the user how it went. A syntax error leaves the text
/// alone and says where it is.
///
/// Undo (Ctrl+Z) brings the old text back: it is one change to the text.
Future<void> formatWithMessage(
  BuildContext context,
  CodeEditorController controller, {
  CodeFormatter? formatter,
}) async {
  // Taken before the await, so no BuildContext is needed afterwards.
  final overlay = Overlay.of(context, rootOverlay: true);
  final source = controller.text;
  final selection = controller.selection;
  final cursor =
      selection.isValid ? selection.baseOffset.clamp(0, source.length).toInt() : 0;

  final result = await (formatter ?? DartStyleFormatter())
      .format(source, cursorOffset: cursor);

  final error = result.error;
  if (error != null) {
    showOverlayMessage(
      overlay,
      'Could not format: $error',
      duration: const Duration(seconds: 6),
    );
    return;
  }
  // Typing during the (short) wait must not be overwritten by old text.
  if (controller.text != source) {
    showOverlayMessage(overlay, 'The text changed while formatting. Try again.');
    return;
  }
  final formatted = result.text;
  if (formatted == null) {
    showOverlayMessage(overlay, 'Already formatted');
    return;
  }
  controller.value = TextEditingValue(
    text: formatted,
    selection: TextSelection.collapsed(
      offset: (result.cursor ?? 0).clamp(0, formatted.length).toInt(),
    ),
  );
  showOverlayMessage(overlay, 'Formatted');
}
