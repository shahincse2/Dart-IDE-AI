bool isWhitespace(String char) {
  return char == ' ' || char == '\t' || char == '\n' || char == '\r';
}

bool isDigit(String char) {
  final code = char.codeUnitAt(0);
  return code >= 48 && code <= 57;
}

bool isIdentifierStart(String char) {
  final code = char.codeUnitAt(0);

  return (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      char == '_' ||
      char == r'$';
}

bool isIdentifierPart(String char) {
  return isIdentifierStart(char) || isDigit(char);
}
