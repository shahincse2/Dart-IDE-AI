import 'dart_syntax_highlighter.dart';

/// A matched bracket pair, by character offset in the source string.
class BracketMatch {
  final int openIndex;
  final int closeIndex;
  const BracketMatch(this.openIndex, this.closeIndex);
}

const Map<String, String> _openToClose = {'(': ')', '{': '}', '[': ']'};
const Map<String, String> _closeToOpen = {')': '(', '}': '{', ']': '['};

/// Finds the bracket matching whichever bracket sits at [caret] or just
/// before it (Section 11: "cursor বন্ধনীর কাছে গেলে matching bracket
/// visually indicate করবে").
///
/// Positions inside string or comment tokens are skipped when counting
/// nesting depth, so a stray bracket inside a string literal doesn't
/// throw off matching in the surrounding code — this uses the already
/// computed [tokens] list rather than a separate parse pass.
BracketMatch? findMatchingBracket(String source, List<SyntaxToken> tokens, int caret) {
  bool insideStringOrComment(int i) {
    for (final t in tokens) {
      if ((t.type == TokenType.string || t.type == TokenType.comment) &&
          i >= t.start &&
          i < t.end) {
        return true;
      }
    }
    return false;
  }

  BracketMatch? tryAt(int pos) {
    if (pos < 0 || pos >= source.length) return null;
    if (insideStringOrComment(pos)) return null;
    final ch = source[pos];

    final close = _openToClose[ch];
    if (close != null) {
      var depth = 0;
      for (var i = pos; i < source.length; i++) {
        if (insideStringOrComment(i)) continue;
        final c = source[i];
        if (c == ch) {
          depth++;
        } else if (c == close) {
          depth--;
          if (depth == 0) return BracketMatch(pos, i);
        }
      }
      return null;
    }

    final open = _closeToOpen[ch];
    if (open != null) {
      var depth = 0;
      for (var i = pos; i >= 0; i--) {
        if (insideStringOrComment(i)) continue;
        final c = source[i];
        if (c == ch) {
          depth++;
        } else if (c == open) {
          depth--;
          if (depth == 0) return BracketMatch(i, pos);
        }
      }
    }
    return null;
  }

  return tryAt(caret) ?? tryAt(caret - 1);
}
