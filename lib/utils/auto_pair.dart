import 'package:flutter/services.dart';

const Map<String, String> _autoPairOpenToClose = {
  '(': ')',
  '{': '}',
  '[': ']',
  '<': '>',
  "'": "'",
  '"': '"',
};

/// Characters where, if the very next character in the text already matches
/// what was just typed, we step the cursor over it instead of inserting a
/// duplicate — the standard "typing over a closer you (or an auto-pair)
/// already placed" behavior. Quotes are in both this set and
/// [_autoPairOpenToClose] since the same character opens and closes a string.
const Set<String> _autoPairSkipOverChars = {')', '}', ']', '>', "'", '"'};

/// Handles real keyboard-level paired-character insertion (Section 15).
/// Three cases, checked in order:
///   1. An opener typed while text is selected wraps the selection.
///   2. A closer typed immediately before an identical character just moves
///      the cursor past it, rather than duplicating it.
///   3. Any other opener insert adds its matching closer right after, with
///      the cursor left in between.
/// Anything else passes through untouched (the very same [newValue] object).
TextEditingValue applyAutoPair(
  TextEditingValue oldValue,
  TextEditingValue newValue,
) {
  final oldText = oldValue.text;
  final newText = newValue.text;
  final oldSel = oldValue.selection;
  final newSel = newValue.selection;

  // Case 1: wrap an active selection.
  if (oldSel.isValid && !oldSel.isCollapsed && newSel.isCollapsed) {
    final removedLen = oldSel.end - oldSel.start;
    final expectedLen = oldText.length - removedLen + 1;
    if (newText.length == expectedLen && newSel.baseOffset == oldSel.start + 1) {
      final typedChar = newText[oldSel.start];
      final closeChar = _autoPairOpenToClose[typedChar];
      if (closeChar != null) {
        final selectedText = oldText.substring(oldSel.start, oldSel.end);
        final before = oldText.substring(0, oldSel.start);
        final after = oldText.substring(oldSel.end);
        return TextEditingValue(
          text: '$before$typedChar$selectedText$closeChar$after',
          selection: TextSelection.collapsed(
            offset: oldSel.start + 1 + selectedText.length,
          ),
        );
      }
    }
    return newValue;
  }

  // Cases 2 & 3 both require a plain single-character insertion at the old
  // cursor position with no prior selection.
  final isSingleCharTyped = newText.length == oldText.length + 1 &&
      oldSel.isCollapsed &&
      newSel.isCollapsed &&
      newSel.baseOffset == oldSel.baseOffset + 1;
  if (!isSingleCharTyped) return newValue;

  final cursorBefore = oldSel.baseOffset;
  final typedChar = newText[cursorBefore];

  // Case 2: skip over an identical existing character.
  if (_autoPairSkipOverChars.contains(typedChar) &&
      cursorBefore < oldText.length &&
      oldText[cursorBefore] == typedChar) {
    return TextEditingValue(
      text: oldText,
      selection: TextSelection.collapsed(offset: cursorBefore + 1),
    );
  }

  // Case 3: auto-insert the matching closer.
  final closeChar = _autoPairOpenToClose[typedChar];
  if (closeChar != null) {
    final updated =
        '${newText.substring(0, cursorBefore + 1)}$closeChar${newText.substring(cursorBefore + 1)}';
    return TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: cursorBefore + 1),
    );
  }

  return newValue;
}
