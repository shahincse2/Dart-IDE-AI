import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/bracket_matcher.dart';
import '../utils/dart_syntax_highlighter.dart';
import '../utils/fold_regions.dart';
import '../utils/string_escapes.dart'; // ← এই লাইনটা যোগ করুন
import '../utils/themes.dart';

/// A [TextEditingController] that syntax-highlights Dart code, shows
/// matching-bracket highlights, auto-indents on Enter, auto-closes
/// paired characters as you type, highlights Find & Replace matches,
/// and (Phase 11) supports code folding — all without an external
/// editor package.
///
/// Code folding design: the controller's text is NEVER changed by a
/// fold. Folded lines stay in `text` (so save, run, undo, find, share
/// all keep working on the full source); they are merely *rendered*
/// invisible by [buildTextSpan]: the hidden range is drawn as same-length
/// tiny transparent zero-width characters with a single line break at its
/// end, so it collapses into ONE placeholder row (where the editor draws
/// the "..." marker) between the opening and the closing line.
/// Fold state is stored as the start line of
/// each folded region, and is remapped on every edit so folds follow
/// the code when lines are added/removed above them. An edit that
/// touches hidden text, or a cursor that lands inside hidden text
/// (arrow keys, Find, Go to line, error line), unfolds that region.
class CodeEditorController extends TextEditingController {
  EditorColorScheme _scheme;
  int _indentSize;

  List<SyntaxToken> _cachedTokens = const [];
  String _cachedTokenText = '';

  List<int> _searchMatchStarts = const [];
  int _searchMatchLength = 0;
  int _activeSearchMatch = -1;

  int? _errorLine;

  // ---- Code folding state ------------------------------------------------

  /// Font size of hidden text — tiny, so the hidden glyphs add
  /// practically no width to the line they are merged into.
  static const double _hiddenFontSize = 0.001;

  /// Start lines of regions the user has folded.
  final Set<int> _foldedStarts = {};

  String? _foldCacheText;
  List<FoldRegion> _regions = const [];
  List<int> _lineStarts = const [0];
  List<LineRange> _hiddenLines = const [];
  List<CharRange> _hiddenChars = const [];

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

  EscapeRanges _cachedEscapes = EscapeRanges.empty;
  String _cachedEscapeText = '';

  /// Escape sequences (\n, \t, \u00e9 ...) inside string literals, found
  /// again only when the text changes.
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
  /// `utils/runner_error_parser.dart` — so callers should treat a
  /// missing line as "couldn't tell", not "no error".
  int? get errorLine => _errorLine;

  void setErrorLine(int? line) {
    if (_errorLine == line) return;
    _errorLine = line;
    // An error inside a folded region must be visible.
    if (line != null && _foldedStarts.isNotEmpty) {
      _ensureFoldState();
      if (_unfoldFoldsHidingLine(line - 1)) _rebuildHidden();
    }
    notifyListeners();
  }

  // ---- Code folding: public API -------------------------------------------

  /// Every foldable region in the current text (sorted by start line).
  /// The returned list is cached: it is the same object until the text
  /// changes.
  List<FoldRegion> get foldRegions {
    _ensureFoldState();
    return _regions;
  }

  /// Start lines of the regions currently folded (sorted).
  List<int> get foldedStartLines {
    _ensureFoldState();
    return _foldedStarts.toList()..sort();
  }

  /// Merged, sorted, inclusive line ranges that are currently hidden.
  List<LineRange> get hiddenLineRanges {
    _ensureFoldState();
    return _hiddenLines;
  }

  /// Compact description of the hidden ranges; changes whenever the set
  /// of hidden lines changes. Handy as a cache key.
  String get hiddenSignature {
    _ensureFoldState();
    if (_hiddenLines.isEmpty) return '';
    return _hiddenLines.map((r) => '${r.first}-${r.last}').join(',');
  }

  bool get hasFolds {
    _ensureFoldState();
    return _hiddenLines.isNotEmpty;
  }

  bool isFolded(int startLine) {
    _ensureFoldState();
    return _foldedStarts.contains(startLine);
  }

  /// Folds the region starting at [startLine], or unfolds it if it is
  /// already folded. Does nothing if no region starts on that line.
  void toggleFold(int startLine) {
    _ensureFoldState();
    if (!_regions.any((r) => r.startLine == startLine)) return;
    if (_foldedStarts.remove(startLine)) {
      _rebuildHidden();
      notifyListeners();
    } else {
      _foldedStarts.add(startLine);
      _rebuildHidden();
      _moveSelectionOutOfHidden();
    }
  }

  void foldAll() {
    _ensureFoldState();
    if (_regions.isEmpty) return;
    _foldedStarts
      ..clear()
      ..addAll(_regions.map((r) => r.startLine));
    _rebuildHidden();
    _moveSelectionOutOfHidden();
  }

  void unfoldAll() {
    if (_foldedStarts.isEmpty) return;
    _foldedStarts.clear();
    _rebuildHidden();
    notifyListeners();
  }

  // ---- Code folding: internals --------------------------------------------

  List<int> _skipRangesOf(List<SyntaxToken> toks) {
    final out = <int>[];
    for (final t in toks) {
      if (t.type == TokenType.string || t.type == TokenType.comment) {
        out
          ..add(t.start)
          ..add(t.end);
      }
    }
    return out;
  }

  /// Recomputes regions / line starts when the text changed.
  void _ensureFoldState() {
    final t = text;
    if (_foldCacheText == t) return;
    _foldCacheText = t;
    _lineStarts = computeLineStarts(t);
    _regions = computeFoldRegions(t, _skipRangesOf(tokens));
    _rebuildHidden();
  }

  /// Rebuilds the hidden line/char ranges from [_foldedStarts], first
  /// dropping any folded start line that no longer has a region.
  void _rebuildHidden() {
    final byStart = <int, FoldRegion>{
      for (final r in _regions) r.startLine: r,
    };
    _foldedStarts.removeWhere((line) => !byStart.containsKey(line));

    final folded = _foldedStarts.map((l) => byStart[l]!).toList()
      ..sort((a, b) => a.startLine.compareTo(b.startLine));

    final merged = <LineRange>[];
    for (final r in folded) {
      final first = r.startLine + 1;
      final last = r.endLine - 1;
      if (merged.isNotEmpty && first <= merged.last.last + 1) {
        // Nested inside (or touching) an already-hidden range.
        if (last > merged.last.last) {
          merged[merged.length - 1] = LineRange(merged.last.first, last);
        }
      } else {
        merged.add(LineRange(first, last));
      }
    }
    _hiddenLines = merged;

    final t = text;
    _hiddenChars = [
      for (final r in merged)
        CharRange(
          _lineStarts[r.first],
          r.last + 1 < _lineStarts.length ? _lineStarts[r.last + 1] : t.length,
        ),
    ];
  }

  int _lineOfOffset(int offset) {
    var lo = 0;
    var hi = _lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Removes every folded region that hides [line]. Returns whether
  /// anything was removed (caller must then call [_rebuildHidden]).
  bool _unfoldFoldsHidingLine(int line) {
    final toRemove = <int>[];
    for (final r in _regions) {
      if (_foldedStarts.contains(r.startLine) &&
          line > r.startLine &&
          line < r.endLine) {
        toRemove.add(r.startLine);
      }
    }
    if (toRemove.isEmpty) return false;
    _foldedStarts.removeAll(toRemove);
    return true;
  }

  /// After a fold: if the cursor/selection ended up inside hidden text,
  /// move it to the end of the visible line just above the fold.
  void _moveSelectionOutOfHidden() {
    final sel = selection;
    if (!sel.isValid) {
      notifyListeners();
      return;
    }

    int fix(int offset) {
      for (final r in _hiddenChars) {
        if (offset >= r.start && offset < r.end) {
          return r.start - 1; // end of the start line, before its '\n'
        }
      }
      return offset;
    }

    final base = fix(sel.baseOffset);
    final extent = fix(sel.extentOffset);
    if (base != sel.baseOffset || extent != sel.extentOffset) {
      super.value = value.copyWith(
        selection: TextSelection(baseOffset: base, extentOffset: extent),
      );
    } else {
      notifyListeners();
    }
  }

  /// If the selection landed inside hidden text (arrow keys, Find, Go
  /// to line...), unfold whatever hides it.
  void _unfoldIfSelectionHidden() {
    if (_foldedStarts.isEmpty) return;
    _ensureFoldState();
    final sel = selection;
    if (!sel.isValid || _hiddenChars.isEmpty) return;

    var changed = false;
    for (final offset in {sel.baseOffset, sel.extentOffset}) {
      if (offset < 0) continue;
      if (_unfoldFoldsHidingLine(_lineOfOffset(offset))) changed = true;
    }
    if (changed) {
      _rebuildHidden();
      notifyListeners();
    }
  }

  int _newlinesIn(String s, int from, int to) {
    var n = 0;
    for (var i = from; i < to; i++) {
      if (s.codeUnitAt(i) == 10) n++;
    }
    return n;
  }

  /// Called just before the text changes from [oldText] to [newText]:
  /// shifts each folded start line by the number of lines the edit
  /// added/removed above it, and unfolds regions the edit touches.
  /// ([text] is still the old text while this runs.)
  void _remapFoldsForEdit(String oldText, String newText) {
    if (_foldedStarts.isEmpty) return;
    _ensureFoldState();

    // Smallest changed window: common prefix / suffix.
    final minLen = math.min(oldText.length, newText.length);
    var p = 0;
    while (p < minLen && oldText.codeUnitAt(p) == newText.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < minLen - p &&
        oldText.codeUnitAt(oldText.length - 1 - s) ==
            newText.codeUnitAt(newText.length - 1 - s)) {
      s++;
    }
    final oldEnd = oldText.length - s; // edit = [p, oldEnd) in old text
    final newEnd = newText.length - s;

    final editLine = _newlinesIn(oldText, 0, p);
    final removed = _newlinesIn(oldText, p, oldEnd);
    final added = _newlinesIn(newText, p, newEnd);
    final delta = added - removed;

    final survivors = <int>{};
    for (final r in _regions) {
      if (!_foldedStarts.contains(r.startLine)) continue;
      final f = r.startLine;

      // Edit touches this fold's hidden text -> unfold it.
      final hiddenStart = _lineStarts[f + 1];
      final hiddenEnd = _lineStarts[r.endLine];
      if (p < hiddenEnd && oldEnd > hiddenStart) continue;

      if (f < editLine) {
        survivors.add(f);
      } else if (f == editLine) {
        // Typing on the fold's own line keeps it folded; adding or
        // removing line breaks there changes what it covers.
        if (removed == 0 && added == 0) survivors.add(f);
      } else if (editLine + removed < f) {
        survivors.add(f + delta);
      }
      // else: the edit spans the start line -> unfold.
    }

    _foldedStarts
      ..clear()
      ..addAll(survivors);
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
    if (_errorLine != null && afterPair.text != oldValue.text) {
      _errorLine = null;
    }
    if (afterPair.text != oldValue.text) {
      _remapFoldsForEdit(oldValue.text, afterPair.text);
    }
    super.value = afterPair;
    _unfoldIfSelectionHidden();
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
    '"',
  };

  /// Handles real keyboard-level paired-character insertion (Section
  /// 15). Three cases, checked in order:
  ///   1. An opener typed while text is selected wraps the selection.
  ///   2. A closer typed immediately before an identical character
  ///      just moves the cursor past it, rather than duplicating it.
  ///   3. Any other opener insert adds its matching closer right
  ///      after, with the cursor left in between.
  /// Anything else passes through untouched.
  TextEditingValue _applyAutoPair(
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
              offset: oldSel.start + 1 + selectedText.length,
            ),
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

  /// What is DRAWN for (a piece of) a hidden range. Same length as the
  /// real text, so caret/selection offsets still line up: every '\n'
  /// becomes one zero-width space — except the final '\n' of the range
  /// ([endsRange]), which stays a real line break. So a folded block
  /// renders as exactly ONE row (the "..." placeholder row, drawn by the
  /// editor) between the opening line and the closing line.
  String _hiddenText(String s, {required bool endsRange}) {
    final z = s.replaceAll('\n', '\u200B');
    if (!endsRange || z.isEmpty || !s.endsWith('\n')) return z;
    return '${z.substring(0, z.length - 1)}\n';
  }

  /// Style for folded (hidden) text: tiny and transparent.
  TextStyle _hiddenStyle(TextStyle? base) {
    return (base ?? const TextStyle()).copyWith(
      fontSize: _hiddenFontSize,
      height: 1.0,
      letterSpacing: 0,
      wordSpacing: 0,
      fontWeight: FontWeight.normal,
      color: Colors.transparent,
      backgroundColor: Colors.transparent,
      decoration: TextDecoration.none,
    );
  }

  CharRange? _hiddenRangeCovering(List<CharRange> hidden, int start, int end) {
    for (final r in hidden) {
      if (r.start <= start && end <= r.end) return r;
    }
    return null;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    var hidden = const <CharRange>[];
    if (_foldedStarts.isNotEmpty) {
      _ensureFoldState();
      hidden = _hiddenChars;
    }

    // During active IME composition (accented characters, some
    // Asian-language input), defer to plain rendering so the
    // composing-region underline behaves correctly. Splitting spans
    // mid-composition is easy to get subtly wrong — falling back here
    // is the safer trade-off rather than faking correctness. Folded
    // text is still kept hidden.
    if (withComposing &&
        value.isComposingRangeValid &&
        !value.composing.isCollapsed) {
      if (hidden.isEmpty) return TextSpan(style: style, text: text);
      final plain = <TextSpan>[];
      var pos = 0;
      for (final r in hidden) {
        if (r.start > pos) {
          plain.add(TextSpan(text: text.substring(pos, r.start), style: style));
        }
        plain.add(
          TextSpan(
            text: _hiddenText(text.substring(r.start, r.end), endsRange: true),
            style: _hiddenStyle(style),
          ),
        );
        pos = r.end;
      }
      if (pos < text.length) {
        plain.add(TextSpan(text: text.substring(pos), style: style));
      }
      return TextSpan(style: style, children: plain);
    }

    final source = text;
    final toks = tokens;
    final esc = escapes;
    final bracketMatch = value.selection.isCollapsed
        ? findMatchingBracket(source, toks, value.selection.baseOffset)
        : null;

    // Every span in the output must respect independent sets of
    // boundaries: token edges (syntax color), the matched-bracket pair
    // (single characters), search-match ranges (arbitrary length), and
    // folded (hidden) ranges. Collect every boundary into one sorted
    // breakpoint list, then build one span per gap between consecutive
    // breakpoints with whatever combination of styling applies.
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
    for (final r in hidden) {
      breakpoints.add(r.start);
      breakpoints.add(r.end);
    }
    breakpoints.addAll(esc.boundaries);
    final sorted =
        breakpoints.where((b) => b >= 0 && b <= source.length).toList();

    final children = <TextSpan>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final start = sorted[i];
      final end = sorted[i + 1];
      if (start >= end) continue;

      final hiddenRange =
          hidden.isEmpty ? null : _hiddenRangeCovering(hidden, start, end);
      if (hiddenRange != null) {
        children.add(
          TextSpan(
            text: _hiddenText(
              source.substring(start, end),
              endsRange: end == hiddenRange.end,
            ),
            style: _hiddenStyle(style),
          ),
        );
        continue;
      }

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
      final isActiveSearchMatch =
          isSearchMatch && searchMatchIndex == _activeSearchMatch;

      Color? backgroundColor;
      if (isActiveSearchMatch) {
        backgroundColor = _scheme.operatorColor.withValues(alpha: 0.55);
      } else if (isSearchMatch) {
        backgroundColor = _scheme.selection.withValues(alpha: 0.35);
      } else if (isBracketMatch) {
        backgroundColor = _scheme.selection.withValues(alpha: 0.55);
      }

      children.add(
        TextSpan(
          text: source.substring(start, end),
          style: style?.copyWith(
            color: esc.covers(start, end)
                ? _scheme.operatorColor
                : (tokenType != null ? _colorFor(tokenType) : _scheme.text),
            backgroundColor: backgroundColor,
            fontWeight: isBracketMatch ? FontWeight.w700 : null,
          ),
        ),
      );
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
      if (t.start >= end) {
        break; // tokens are in source order; no need to scan further
      }
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
        return _scheme.annotation;

      case TokenType.type:
        return _scheme.type;

      case TokenType.function:
        return _scheme.function;

      case TokenType.variable:
        return _scheme.variable;

      case TokenType.operatorSymbol:
        return _scheme.operatorColor;

      case TokenType.punctuation:
        return _scheme.punctuation;
    }
  }
}
