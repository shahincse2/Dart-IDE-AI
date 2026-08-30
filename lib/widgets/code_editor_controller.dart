import 'package:flutter/material.dart';

import '../utils/bracket_matcher.dart';
import '../utils/dart_syntax_highlighter.dart';
import '../utils/themes.dart';

/// A [TextEditingController] that syntax-highlights Dart code, shows
/// matching-bracket highlights, auto-indents on Enter, and auto-closes
/// paired characters as you type — all without an external editor
/// package (see the Phase 2 architecture note: a custom controller
/// gives full control over paired-character insertion and precise
/// line-number sync that off-the-shelf editor widgets don't expose).
class CodeEditorController extends TextEditingController {
  EditorColorScheme _scheme;
  int _indentSize;

  List<SyntaxToken> _cachedTokens = const [];
  String _cachedTokenText = '';

  CodeEditorController({
    required EditorColorScheme scheme,
    int indentSize = 2,
    String? text,
  })  : _scheme = scheme,
        _indentSize = indentSize,
        super(text: text);

  EditorColorScheme get scheme => _scheme;
  set scheme(EditorColorScheme value) {
    if (identical(_scheme, value)) return;
    _scheme = value;
    notifyListeners();
  }

  set indentSize(int value) => _indentSize = value;

  /// Tokens for the current text, recomputed only when the text
  /// actually changes (not on every cursor move / rebuild).
  List<SyntaxToken> get tokens {
    if (text != _cachedTokenText) {
      _cachedTokens = tokenizeDart(text);
      _cachedTokenText = text;
    }
    return _cachedTokens;
  }

  @override
  set value(TextEditingValue newValue) {
    final oldValue = value;
    final afterIndent = _applyAutoIndent(oldValue, newValue);
    // Auto-indent only ever changes something on a '\n' insert; for
    // any other kind of edit it returns newValue untouched (same
    // reference), so `identical` reliably tells us whether to also
    // try auto-pairing. The two never both apply to the same edit.
    final afterPair = identical(afterIndent, newValue)
        ? _applyAutoPair(oldValue, newValue)
        : afterIndent;
    super.value = afterPair;
  }

  /// If this change was exactly one Enter keystroke (a single '\n'
  /// inserted at the cursor), carries the previous line's indentation
  /// forward and adds one more level if that line opened a block
  /// (Section 12). Anything else — typing, pasting, deleting,
  /// programmatic edits from the toolbar — passes through untouched.
  TextEditingValue _applyAutoIndent(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
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
    if (trimmed.endsWith('{') ||
        trimmed.endsWith('[') ||
        trimmed.endsWith('(')) {
      indent = indent + (' ' * _indentSize);
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

  static const Map<String, String> _autoPairOpenToClose = {
    '(': ')',
    '{': '}',
    '[': ']',
    '<': '>',
    "'": "'",
    '"': '"',
  };

  /// Characters where, if the very next character in the text already
  /// matches what was just typed, we step the cursor over it instead
  /// of inserting a duplicate — the standard "typing over a closer you
  /// (or an auto-pair) already placed" behavior. Quotes are in both
  /// this set and [_autoPairOpenToClose] since the same character
  /// opens and closes a string.
  static const Set<String> _autoPairSkipOverChars = {
    ')',
    '}',
    ']',
    '>',
    "'",
    '"'
  };

  /// Handles real keyboard-level paired-character insertion (Section
  /// 15) — the coding toolbar already did this for its own taps, but
  /// typing `(` directly on the keyboard wasn't auto-closing. Three
  /// cases, checked in order:
  ///   1. An opener typed while text is selected wraps the selection.
  ///   2. A closer typed immediately before an identical character
  ///      just moves the cursor past it, rather than duplicating it.
  ///   3. Any other opener insert adds its matching closer right
  ///      after, with the cursor left in between.
  /// Anything else (typing a non-pair character, deleting, pasting,
  /// programmatic edits from the toolbar) passes through untouched.
  TextEditingValue _applyAutoPair(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final oldText = oldValue.text;
    final newText = newValue.text;
    final oldSel = oldValue.selection;
    final newSel = newValue.selection;

    // Case 1: wrap an active selection.
    if (oldSel.isValid && !oldSel.isCollapsed && newSel.isCollapsed) {
      final removedLen = oldSel.end - oldSel.start;
      final expectedLen = oldText.length - removedLen + 1;
      if (newText.length == expectedLen &&
          newSel.baseOffset == oldSel.start + 1) {
        final typedChar = newText[oldSel.start];
        final closeChar = _autoPairOpenToClose[typedChar];
        if (closeChar != null) {
          final selectedText = oldText.substring(oldSel.start, oldSel.end);
          final before = oldText.substring(0, oldSel.start);
          final after = oldText.substring(oldSel.end);
          return TextEditingValue(
            text: '$before$typedChar$selectedText$closeChar$after',
            selection: TextSelection.collapsed(
                offset: oldSel.start + 1 + selectedText.length),
          );
        }
      }
      return newValue;
    }

    // Cases 2 & 3 both require a plain single-character insertion at
    // the old cursor position with no prior selection.
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

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // During active IME composition (accented characters, some
    // Asian-language input), defer to plain rendering so the
    // composing-region underline behaves correctly. Splitting spans
    // mid-composition is easy to get subtly wrong — falling back here
    // is the safer trade-off rather than faking correctness.
    if (withComposing &&
        value.isComposingRangeValid &&
        !value.composing.isCollapsed) {
      return TextSpan(style: style, text: text);
    }

    final source = text;
    final toks = tokens;
    final match = value.selection.isCollapsed
        ? findMatchingBracket(source, toks, value.selection.baseOffset)
        : null;

    final children = <TextSpan>[];
    var cursor = 0;

    void addPlain(int start, int end) {
      if (end <= start) return;
      children.add(TextSpan(
        text: source.substring(start, end),
        style: style?.copyWith(color: _scheme.text),
      ));
    }

    for (final t in toks) {
      addPlain(cursor, t.start);
      final isBracketMatch = match != null &&
          t.end - t.start == 1 &&
          (t.start == match.openIndex || t.start == match.closeIndex);
      children.add(TextSpan(
        text: source.substring(t.start, t.end),
        style: style?.copyWith(
          color: _colorFor(t.type),
          backgroundColor:
              isBracketMatch ? _scheme.selection.withOpacity(0.55) : null,
          fontWeight: isBracketMatch ? FontWeight.w700 : null,
        ),
      ));
      cursor = t.end;
    }
    addPlain(cursor, source.length);

    return TextSpan(style: style, children: children);
  }

  Color _colorFor(TokenType type) {
    switch (type) {
      case TokenType.keyword:
        return _scheme.keyword;
      case TokenType.string:
        return _scheme.string;
      case TokenType.comment:
        return _scheme.comment;
      case TokenType.number:
        return _scheme.number;
      case TokenType.annotation:
      case TokenType.type:
        return _scheme.type;
      case TokenType.function:
        return _scheme.function;
      case TokenType.variable:
        return _scheme.variable;
      case TokenType.operatorSymbol:
        return _scheme.operatorColor;
      case TokenType.punctuation:
        return _scheme.text;
    }
  }
}
