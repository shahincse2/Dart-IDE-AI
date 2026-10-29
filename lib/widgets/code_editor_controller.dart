import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/auto_indent.dart';
import '../utils/auto_pair.dart';
import '../utils/bracket_matcher.dart';
import '../utils/dart_syntax_highlighter.dart';
import '../utils/hidden_text.dart';
import '../utils/highlight_spans.dart';
import '../utils/string_escapes.dart';
import '../utils/themes.dart';
import 'code_folding.dart';
import 'search_highlighting.dart';

/// A [TextEditingController] that syntax-highlights Dart code, shows
/// matching-bracket highlights, auto-indents on Enter, auto-closes paired
/// characters as you type, highlights Find & Replace matches, and supports
/// code folding — all without an external editor package.
///
/// The pieces live elsewhere: folding in [CodeFolding], search highlights in
/// [SearchHighlighting], auto-indent and auto-pair in `utils/auto_*`, the
/// coloured text in `utils/highlight_spans.dart`. This class ties them to the
/// text and the selection.
class CodeEditorController extends TextEditingController
    with CodeFolding, SearchHighlighting {
  EditorColorScheme _scheme;
  int _indentSize;

  List<SyntaxToken> _cachedTokens = const [];
  String _cachedTokenText = '';

  EscapeRanges _cachedEscapes = EscapeRanges.empty;
  String _cachedEscapeText = '';

  int? _errorLine;
  bool _isDisposed = false;

  CodeEditorController({
    required EditorColorScheme scheme,
    int indentSize = 2,
    super.text,
  })  : _scheme = scheme,
        _indentSize = indentSize;

  EditorColorScheme get scheme => _scheme;
  set scheme(EditorColorScheme value) {
    if (identical(_scheme, value)) return;
    _scheme = value;
    // EditorScreen sets this from build(). Telling the listeners right there
    // is illegal while the framework is building (one of them, the
    // auto-save hook, notifies FileProvider). So notify just after.
    scheduleMicrotask(() {
      if (!_isDisposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  set indentSize(int value) => _indentSize = value;

  /// Tokens for the current text, recomputed only when the text actually
  /// changes (not on every cursor move / rebuild).
  @override
  List<SyntaxToken> get tokens {
    if (text != _cachedTokenText) {
      _cachedTokens = tokenizeDart(text);
      _cachedTokenText = text;
    }
    return _cachedTokens;
  }

  /// Escape sequences (\n, \t, \u00e9 ...) inside string literals, found again
  /// only when the text changes.
  EscapeRanges get escapes {
    if (text != _cachedEscapeText) {
      final stringRanges = <int>[];
      for (final t in tokens) {
        if (t.type == TokenType.string) {
          stringRanges
            ..add(t.start)
            ..add(t.end);
        }
      }
      _cachedEscapes = findStringEscapes(text, stringRanges);
      _cachedEscapeText = text;
    }
    return _cachedEscapes;
  }

  /// 1-indexed line a runtime/syntax error was reported on (Section 35), or
  /// null for no marker. This is a best-effort heuristic — see
  /// `utils/runner_error_parser.dart` — so callers should treat a missing
  /// line as "couldn't tell", not "no error".
  int? get errorLine => _errorLine;

  void setErrorLine(int? line) {
    if (_errorLine == line) return;
    _errorLine = line;
    if (line != null) unfoldLine(line); // an error inside a fold must be seen
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    final oldValue = value;
    final afterIndent =
        applyAutoIndent(oldValue, newValue, indentSize: _indentSize);
    // Auto-indent only ever changes something on a '\n' insert; for any other
    // kind of edit it returns newValue untouched (same reference), so
    // `identical` reliably tells us whether to also try auto-pairing. The two
    // never both apply to the same edit.
    final afterPair = identical(afterIndent, newValue)
        ? applyAutoPair(oldValue, newValue)
        : afterIndent;
    if (afterPair.text != oldValue.text) {
      if (_errorLine != null) _errorLine = null;
      followEdit(afterPair.text); // [text] is still the old text here
    }
    super.value = afterPair;
    unfoldIfSelectionHidden();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final hidden = hiddenChars;
    if (withComposing &&
        value.isComposingRangeValid &&
        !value.composing.isCollapsed) {
      return buildComposingSpan(text: text, style: style, hidden: hidden);
    }

    final toks = tokens;
    final bracketMatch = value.selection.isCollapsed
        ? findMatchingBracket(text, toks, value.selection.baseOffset)
        : null;
    return buildHighlightedSpan(
      source: text,
      style: style,
      scheme: _scheme,
      tokens: toks,
      escapes: escapes,
      openBracket: bracketMatch?.openIndex,
      closeBracket: bracketMatch?.closeIndex,
      search: searchHighlights,
      hidden: hidden,
    );
  }
}
