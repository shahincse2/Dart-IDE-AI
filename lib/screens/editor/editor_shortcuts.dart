import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Section 43's Bluetooth/physical-keyboard shortcuts: Ctrl+S save,
/// Ctrl+Enter run/stop, Ctrl+F find, Ctrl+H find & replace, Ctrl+G go to line,
/// Ctrl+Alt+L format.
///
/// Ctrl+Z / Ctrl+Shift+Z are deliberately NOT bound here — Flutter's TextField
/// already handles both natively once given an `undoController` (Phase 7), so
/// adding our own binding would be redundant at best and could double-fire at
/// worst.
Map<ShortcutActivator, VoidCallback> editorShortcuts({
  required VoidCallback onSave,
  required VoidCallback onRunOrStop,
  required void Function({required bool expandReplace}) onOpenFind,
  required VoidCallback onGoToLine,
  required VoidCallback onFormat,
}) {
  return {
    const SingleActivator(LogicalKeyboardKey.keyS, control: true): onSave,
    const SingleActivator(LogicalKeyboardKey.enter, control: true): onRunOrStop,
    const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
        onOpenFind(expandReplace: false),
    const SingleActivator(LogicalKeyboardKey.keyH, control: true): () =>
        onOpenFind(expandReplace: true),
    const SingleActivator(LogicalKeyboardKey.keyG, control: true): onGoToLine,
    const SingleActivator(LogicalKeyboardKey.keyL, control: true, alt: true):
        onFormat,
  };
}
