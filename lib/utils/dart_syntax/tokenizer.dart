import 'char_classes.dart';
import 'comment_scan.dart';
import 'identifier_scan.dart';
import 'number_scan.dart';
import 'string_basics.dart';
import 'string_scan.dart';
import 'token_types.dart';
import 'vocabulary.dart';

/// Tokenizes Dart source into lightweight syntax tokens.
///
/// String interpolation is not treated as one giant string token.
///
/// Example:
///
///   'Valid number: $number'
///
/// becomes approximately:
///
///   string     -> 'Valid number: '
///   variable   -> $number
///   string     -> '
///
/// And:
///
///   'User: ${user.name}'
///
/// allows `user`, `.`, and `name` to be highlighted independently.
List<SyntaxToken> tokenizeDart(String source) {
  if (source.isEmpty) return const [];

  final tokens = <SyntaxToken>[];
  _scanSource(source, 0, source.length, tokens);

  return tokens;
}

/// Scans a source range and appends non-overlapping tokens.
///
/// [start] and [end] are absolute offsets into [source].
void _scanSource(String source, int start, int end, List<SyntaxToken> tokens) {
  var i = start;

  while (i < end) {
    final char = source[i];

    // Whitespace is intentionally ignored.
    if (isWhitespace(char)) {
      i++;
      continue;
    }

    // Line comment.
    if (char == '/' && i + 1 < end && source[i + 1] == '/') {
      final commentEnd = findLineEnd(source, i, end);

      tokens.add(SyntaxToken(i, commentEnd, TokenType.comment));

      i = commentEnd;
      continue;
    }

    // Block comment.
    if (char == '/' && i + 1 < end && source[i + 1] == '*') {
      final commentEnd = findBlockCommentEnd(source, i, end);

      tokens.add(SyntaxToken(i, commentEnd, TokenType.comment));

      i = commentEnd;
      continue;
    }

    // String or raw string.
    if (isStringStart(source, i, end)) {
      i = scanString(source, i, end, tokens, _scanSource);
      continue;
    }

    // Annotation.
    if (char == '@' && i + 1 < end && isIdentifierStart(source[i + 1])) {
      final annotationEnd = readIdentifierEnd(source, i + 1, end);

      tokens.add(SyntaxToken(i, annotationEnd, TokenType.annotation));

      i = annotationEnd;
      continue;
    }

    // Number.
    if (isNumberStart(source, i, end)) {
      final numberEnd = readNumberEnd(source, i, end);

      tokens.add(SyntaxToken(i, numberEnd, TokenType.number));

      i = numberEnd;
      continue;
    }

    // Identifier / keyword / type / function / variable.
    if (isIdentifierStart(char)) {
      final identifierEnd = readIdentifierEnd(source, i, end);

      final text = source.substring(i, identifierEnd);

      final type = classifyIdentifier(text, source, identifierEnd, end);

      tokens.add(SyntaxToken(i, identifierEnd, type));

      i = identifierEnd;
      continue;
    }

    // Multi-character operators.
    final operator = _readMultiCharacterOperator(source, i, end);

    if (operator != null) {
      final operatorEnd = i + operator.length;

      tokens.add(SyntaxToken(i, operatorEnd, TokenType.operatorSymbol));

      i = operatorEnd;
      continue;
    }

    // Single-character punctuation.
    if (singleCharacterPunctuation.contains(char)) {
      tokens.add(SyntaxToken(i, i + 1, TokenType.punctuation));

      i++;
      continue;
    }

    // Single-character operator.
    if (singleCharacterOperators.contains(char)) {
      tokens.add(SyntaxToken(i, i + 1, TokenType.operatorSymbol));

      i++;
      continue;
    }

    // Unknown character.
    //
    // We don't discard it from the source; we simply leave it uncolored.
    i++;
  }
}

String? _readMultiCharacterOperator(String source, int start, int end) {
  for (final operator in multiCharacterOperators) {
    final operatorEnd = start + operator.length;

    if (operatorEnd <= end &&
        source.substring(start, operatorEnd) == operator) {
      return operator;
    }
  }

  return null;
}
