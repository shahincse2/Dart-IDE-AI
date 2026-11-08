import 'char_classes.dart';
import 'token_types.dart';
import 'vocabulary.dart';

int readIdentifierEnd(String source, int start, int end) {
  var i = start;

  while (i < end && isIdentifierPart(source[i])) {
    i++;
  }

  return i;
}

/// What an identifier is drawn as: keyword, type, function (followed by `(`)
/// or plain variable.
TokenType classifyIdentifier(
  String text,
  String source,
  int end,
  int sourceEnd,
) {
  if (dartKeywords.contains(text)) {
    return TokenType.keyword;
  }

  if (builtinTypes.contains(text)) {
    return TokenType.type;
  }

  if (RegExp(r'^[A-Z]').hasMatch(text)) {
    return TokenType.type;
  }

  if (_isFollowedByOpenParen(source, end, sourceEnd)) {
    return TokenType.function;
  }

  return TokenType.variable;
}

bool _isFollowedByOpenParen(String source, int end, int sourceEnd) {
  var i = end;

  while (i < sourceEnd &&
      (source[i] == ' ' ||
          source[i] == '\t' ||
          source[i] == '\r' ||
          source[i] == '\n')) {
    i++;
  }

  return i < sourceEnd && source[i] == '(';
}
