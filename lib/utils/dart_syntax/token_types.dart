enum TokenType {
  keyword,
  string,
  comment,
  number,
  annotation,
  type,
  function,
  variable,
  operatorSymbol,
  punctuation,
}

class SyntaxToken {
  final int start;
  final int end;
  final TokenType type;

  const SyntaxToken(this.start, this.end, this.type);
}
