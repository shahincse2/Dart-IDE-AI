/// A lightweight, heuristic Dart tokenizer for syntax highlighting.
///
/// This is NOT a full language parser — it's a regex-based lexer good
/// enough for coloring code as you type on a phone. Known simplifications
/// (documented rather than hidden, per the "never fake" rule):
///   - String interpolation (`'Hello, $name'`) is colored entirely as a
///     string; the interpolated expression isn't separately tokenized.
///   - Triple-quoted multiline strings aren't given special handling —
///     each line is tokenized independently, so multi-line string
///     literals may highlight imperfectly across line boundaries.
///   - Type detection is heuristic (capitalized identifier, or a small
///     built-in-types list), not symbol-table-based.
library;

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

const Set<String> _dartKeywords = {
  'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case',
  'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred',
  'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
  'external', 'factory', 'false', 'final', 'finally', 'for', 'get', 'hide',
  'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
  'mixin', 'new', 'null', 'on', 'operator', 'part', 'required', 'rethrow',
  'return', 'sealed', 'set', 'show', 'static', 'super', 'switch', 'sync',
  'this', 'throw', 'true', 'try', 'typedef', 'var', 'void', 'when', 'while',
  'with', 'yield',
};

const Set<String> _builtinTypes = {
  'int', 'double', 'String', 'bool', 'num', 'Object', 'List', 'Map', 'Set',
  'Iterable', 'Future', 'Stream', 'Duration', 'DateTime', 'Symbol', 'Never',
  'Function', 'Record',
};

const Set<String> _punctuation = {'{', '}', '(', ')', '[', ']', ';', ',', '.', ':'};

/// Pieces are kept separate (rather than one giant string) so each can
/// use whichever raw-string quote delimiter avoids escaping headaches.
final RegExp _tokenPattern = RegExp(
  <String>[
    r'//[^\n]*|/\*[\s\S]*?\*/',
    r'r?"(?:[^"\\\n]|\\.)*"',
    r"r?'(?:[^'\\\n]|\\.)*'",
    r'\b\d+\.?\d*(?:[eE][+-]?\d+)?\b',
    r'@[A-Za-z_]\w*',
    r'[A-Za-z_$][A-Za-z0-9_$]*',
    r'=>|\?\.|\?\?=|\?\?|\.\.\.|==|!=|>=|<=|&&|\|\||\+\+|--|\+=|-=|\*=|/=|[+\-*/%=<>!&|^~?:.,;(){}\[\]]',
  ].join('|'),
);

List<SyntaxToken> tokenizeDart(String source) {
  if (source.isEmpty) return const [];
  final tokens = <SyntaxToken>[];
  for (final m in _tokenPattern.allMatches(source)) {
    final text = m.group(0)!;
    tokens.add(SyntaxToken(m.start, m.end, _classify(text, source, m.end)));
  }
  return tokens;
}

TokenType _classify(String text, String source, int end) {
  final first = text[0];

  if (text.startsWith('//') || text.startsWith('/*')) return TokenType.comment;

  if (first == '"' || first == "'" || (text.length > 1 && first == 'r')) {
    return TokenType.string;
  }
  if (RegExp(r'^\d').hasMatch(text)) return TokenType.number;
  if (first == '@') return TokenType.annotation;

  if (RegExp(r'^[A-Za-z_$]').hasMatch(first)) {
    if (_dartKeywords.contains(text)) return TokenType.keyword;
    if (_builtinTypes.contains(text)) return TokenType.type;
    if (RegExp(r'^[A-Z]').hasMatch(text)) return TokenType.type;
    if (_isFollowedByOpenParen(source, end)) return TokenType.function;
    return TokenType.variable;
  }

  if (_punctuation.contains(text)) return TokenType.punctuation;
  return TokenType.operatorSymbol;
}

bool _isFollowedByOpenParen(String source, int end) {
  var i = end;
  while (i < source.length && (source[i] == ' ' || source[i] == '\t')) {
    i++;
  }
  return i < source.length && source[i] == '(';
}
