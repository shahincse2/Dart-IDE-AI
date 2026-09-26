import 'dart:collection';

import 'package:flutter/material.dart';

import '../utils/bracket_matcher.dart';
import '../utils/dart_syntax_highlighter.dart';
import '../utils/themes.dart';

/// A [TextEditingController] that syntax-highlights Dart code, shows
/// matching-bracket highlights, auto-indents on Enter, auto-closes
/// paired characters as you type, and (Phase 7) highlights Find &
/// Replace matches — all without an external editor package (see the
/// Phase 2 architecture note: a custom controller gives full control
/// that off-the-shelf editor widgets don't expose).
class CodeEditorController extends TextEditingController {
  EditorColorScheme _scheme;
  int _indentSize;

  List<SyntaxToken> _cachedTokens = const [];
  String _cachedTokenText = '';

  List<int> _searchMatchStarts = const [];
  int _searchMatchLength = 0;
  int _activeSearchMatch = -1;

  int? _errorLine;

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

  /// Sets which character ranges Find & Replace's search box currently
  /// matches, all the same length ([queryLength]), so they render with
  /// a highlight background. Pass an empty list to clear.
  void setSearchHighlights(List<int> matchStarts, [int queryLength = 0]) {
    _searchMatchStarts = matchStarts;
    _searchMatchLength = queryLength;
    if (matchStarts.isEmpty) _activeSearchMatch = -1;
    notifyListeners();
  }

  /// Marks which of [setSearchHighlights]'s matches (by index) is the
  /// "current" one Find & Replace is on — rendered with a stronger
  /// highlight than the others.
  void setActiveSearchMatch(int index) {
    _activeSearchMatch = index;
    notifyListeners();
  }

  /// 1-indexed line a runtime/syntax error was reported on (Section
  /// 35), or null for no marker. This is a best-effort heuristic — see
  /// `utils/runner_error_parser.dart`'s doc comment for why it isn't a
  /// guaranteed API — so callers should treat a missing line as
  /// "couldn't tell", not "no error".
  int? get errorLine => _errorLine;

  void setErrorLine(int? line) {
    if (_errorLine == line) return;
    _errorLine = line;
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    final oldValue = value;
    final afterIndent = _applyAutoIndent(oldValue, newValue);
    // Auto-indent only ever changes something on a '\n' insert; for
    // any other kind of edit it returns newValue untouched (same
    // reference), so `identical` reliably tells us whether to also
    // try auto-pairing. The two never both apply to the same edit.
    final afterPair =
        identical(afterIndent, newValue) ? _applyAutoPair(oldValue, newValue) : afterIndent;
    if (_errorLine != null && afterPair.text != oldValue.text) {
      _errorLine = null;
    }
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
    if (trimmed.endsWith('{') || trimmed.endsWith('[') || trimmed.endsWith('(')) {
      indent = indent + (' ' * _indentSize);
    }
    if (indent.isEmpty) return newValue;

    final updatedText =
        newText.substring(0, insertPos + 1) + indent + newText.substring(insertPos + 1);
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
  static const Set<String> _autoPairSkipOverChars = {')', '}', ']', '>', "'", '"'};

  /// Handles real keyboard-level paired-character insertion (Section
  /// 15). Three cases, checked in order:
  ///   1. An opener typed while text is selected wraps the selection.
  ///   2. A closer typed immediately before an identical character
  ///      just moves the cursor past it, rather than duplicating it.
  ///   3. Any other opener insert adds its matching closer right
  ///      after, with the cursor left in between.
  /// Anything else passes through untouched.
  TextEditingValue _applyAutoPair(TextEditingValue oldValue, TextEditingValue newValue) {
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
            selection: TextSelection.collapsed(offset: oldSel.start + 1 + selectedText.length),
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
    if (withComposing && value.isComposingRangeValid && !value.composing.isCollapsed) {
      return TextSpan(style: style, text: text);
    }

    final source = text;
    final toks = tokens;
    final bracketMatch = value.selection.isCollapsed
        ? findMatchingBracket(source, toks, value.selection.baseOffset)
        : null;

    // Every span in the output must respect THREE independent sets of
    // boundaries: token edges (syntax color), the matched-bracket pair
    // (single characters), and search-match ranges (Phase 7, arbitrary
    // length, not aligned to token edges at all). Rather than iterate
    // tokens and hope search matches happen to land on token
    // boundaries — they usually won't — collect every boundary from
    // all three sources into one sorted breakpoint list, then build
    // one span per gap between consecutive breakpoints with whatever
    // combination of styling applies to that gap.
    final breakpoints = SplayTreeSet<int>()..addAll([0, source.length]);
    for (final t in toks) {
      breakpoints.add(t.start);
      breakpoints.add(t.end);
    }
    if (bracketMatch != null) {
      breakpoints.add(bracketMatch.openIndex);
      breakpoints.add(bracketMatch.openIndex + 1);
      breakpoints.add(bracketMatch.closeIndex);
      breakpoints.add(bracketMatch.closeIndex + 1);
    }
    for (final matchStart in _searchMatchStarts) {
      breakpoints.add(matchStart);
      breakpoints.add(matchStart + _searchMatchLength);
    }
    final sorted = breakpoints.where((b) => b >= 0 && b <= source.length).toList();

    final children = <TextSpan>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final start = sorted[i];
      final end = sorted[i + 1];
      if (start >= end) continue;

      final tokenType = _tokenTypeCovering(toks, start, end);
      final isBracketMatch = bracketMatch != null &&
          end - start == 1 &&
          (start == bracketMatch.openIndex || start == bracketMatch.closeIndex);

      var searchMatchIndex = -1;
      for (var m = 0; m < _searchMatchStarts.length; m++) {
        final matchStart = _searchMatchStarts[m];
        if (start >= matchStart && end <= matchStart + _searchMatchLength) {
          searchMatchIndex = m;
          break;
        }
      }
      final isSearchMatch = searchMatchIndex != -1;
      final isActiveSearchMatch = isSearchMatch && searchMatchIndex == _activeSearchMatch;

      Color? backgroundColor;
      if (isActiveSearchMatch) {
        backgroundColor = _scheme.operatorColor.withValues(alpha: 0.55);
      } else if (isSearchMatch) {
        backgroundColor = _scheme.selection.withValues(alpha: 0.35);
      } else if (isBracketMatch) {
        backgroundColor = _scheme.selection.withValues(alpha: 0.55);
      }

      children.add(TextSpan(
        text: source.substring(start, end),
        style: style?.copyWith(
          color: tokenType != null ? _colorFor(tokenType) : _scheme.text,
          backgroundColor: backgroundColor,
          fontWeight: isBracketMatch ? FontWeight.w700 : null,
        ),
      ));
    }

    return TextSpan(style: style, children: children);
  }

  /// Finds whichever token (if any) fully covers [start, end) — used
  /// to color a breakpoint-delimited span. Gaps between tokens (plain
  /// whitespace/punctuation not otherwise classified) return null,
  /// which callers render in the default text color.
  TokenType? _tokenTypeCovering(List<SyntaxToken> toks, int start, int end) {
    for (final t in toks) {
      if (t.start <= start && t.end >= end) return t.type;
      if (t.start >= end) break; // tokens are in source order; no need to scan further
    }
    return null;
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
