import 'dart_syntax_highlighter.dart';
import 'string_escapes.dart';

/// The syntax tokens and the string escapes of a text, found again only when
/// the text changes (not on every cursor move or rebuild).
class SyntaxCache {
  List<SyntaxToken> _tokens = const [];
  String _tokenText = '';

  EscapeRanges _escapes = EscapeRanges.empty;
  String _escapeText = '';

  List<SyntaxToken> tokensFor(String text) {
    if (text != _tokenText) {
      _tokens = tokenizeDart(text);
      _tokenText = text;
    }
    return _tokens;
  }

  /// Escape sequences (\n, \t, \u00e9 ...) inside string literals.
  EscapeRanges escapesFor(String text) {
    if (text != _escapeText) {
      final stringRanges = <int>[];
      for (final t in tokensFor(text)) {
        if (t.type == TokenType.string) {
          stringRanges
            ..add(t.start)
            ..add(t.end);
        }
      }
      _escapes = findStringEscapes(text, stringRanges);
      _escapeText = text;
    }
    return _escapes;
  }
}
