import 'package:flutter/services.dart';

/// If this change was exactly one Enter keystroke (a single '\n' inserted at
/// the cursor), carries the previous line's indentation forward and adds one
/// more level if that line opened a block (Section 12). Anything else —
/// typing, pasting, deleting, programmatic edits from the toolbar — passes
/// through untouched (the very same [newValue] object).
TextEditingValue applyAutoIndent(
  TextEditingValue oldValue,
  TextEditingValue newValue, {
  required int indentSize,
}) {
  final oldText = oldValue.text;
  final newText = newValue.text;
  final newSel = newValue.selection;

  final isSingleNewlineInsert = newText.length == oldText.length + 1 &&
      newSel.isCollapsed &&
      newSel.baseOffset > 0 &&
      newSel.baseOffset <= newText.length &&
      newText[newSel.baseOffset - 1] == '\n';

  if (!isSingleNewlineInsert) return newValue;

  final insertPos = newSel.baseOffset - 1;
  final beforeNewline = newText.substring(0, insertPos);
  final lineStart = beforeNewline.lastIndexOf('\n') + 1;
  final currentLine = beforeNewline.substring(lineStart);
  final leading = RegExp(r'^[ \t]*').stringMatch(currentLine) ?? '';
  final trimmed = currentLine.trimRight();

  var indent = leading;
  if (trimmed.endsWith('{') || trimmed.endsWith('[') || trimmed.endsWith('(')) {
    indent = indent + (' ' * indentSize);
  }
  if (indent.isEmpty) return newValue;

  final updatedText = newText.substring(0, insertPos + 1) +
      indent +
      newText.substring(insertPos + 1);
  return TextEditingValue(
    text: updatedText,
    selection: TextSelection.collapsed(offset: insertPos + 1 + indent.length),
  );
}
