/// A lightweight, heuristic Dart tokenizer for syntax highlighting.
///
/// This is NOT a full language parser — it's a regex/scanner-based lexer
/// good enough for coloring code as you type on a phone.
///
/// Known simplifications:
///   - Triple-quoted multiline strings aren't given special handling.
///   - Type detection is heuristic (capitalized identifier, or a small
///     built-in-types list), not symbol-table-based.
///   - String interpolation is tokenized so interpolated variables and
///     expressions can receive their own syntax colors.
///   - This is still not a full Dart parser, so complex interpolation
///     expressions may have minor highlighting differences from a full IDE.
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
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

const Set<String> _builtinTypes = {
  'int',
  'double',
  'String',
  'bool',
  'num',
  'Object',
  'List',
  'Map',
  'Set',
  'Iterable',
  'Future',
  'Stream',
  'Duration',
  'DateTime',
  'Symbol',
  'Never',
  'Function',
  'Record',
};

const List<String> _multiCharacterOperators = [
  '>>>',
  '>>=',
  '<<=',
  '=>',
  '?.',
  '??=',
  '??',
  '...',
  '==',
  '!=',
  '>=',
  '<=',
  '&&',
  '||',
  '++',
  '--',
  '+=',
  '-=',
  '*=',
  '/=',
  '%=',
  '&=',
  '|=',
  '^=',
  '<<',
  '>>',
];

const Set<String> _singleCharacterOperators = {
  '+',
  '-',
  '*',
  '/',
  '%',
  '=',
  '<',
  '>',
  '!',
  '&',
  '|',
  '^',
  '~',
  '?',
};

const Set<String> _singleCharacterPunctuation = {
  '{',
  '}',
  '(',
  ')',
  '[',
  ']',
  ';',
  ',',
  '.',
  ':',
};

/// Tokenizes Dart source into lightweight syntax tokens.
///
/// Unlike the previous implementation, string interpolation is no longer
/// treated as one giant string token.
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
    if (_isWhitespace(char)) {
      i++;
      continue;
    }

    // Line comment.
    if (char == '/' && i + 1 < end && source[i + 1] == '/') {
      final commentEnd = _findLineEnd(source, i, end);

      tokens.add(SyntaxToken(i, commentEnd, TokenType.comment));

      i = commentEnd;
      continue;
    }

    // Block comment.
    if (char == '/' && i + 1 < end && source[i + 1] == '*') {
      final commentEnd = _findBlockCommentEnd(source, i, end);

      tokens.add(SyntaxToken(i, commentEnd, TokenType.comment));

      i = commentEnd;
      continue;
    }

    // String or raw string.
    if (_isStringStart(source, i, end)) {
      i = _scanString(source, i, end, tokens);
      continue;
    }

    // Annotation.
    if (char == '@' && i + 1 < end && _isIdentifierStart(source[i + 1])) {
      final annotationEnd = _readIdentifierEnd(source, i + 1, end);

      tokens.add(SyntaxToken(i, annotationEnd, TokenType.annotation));

      i = annotationEnd;
      continue;
    }

    // Number.
    if (_isNumberStart(source, i, end)) {
      final numberEnd = _readNumberEnd(source, i, end);

      tokens.add(SyntaxToken(i, numberEnd, TokenType.number));

      i = numberEnd;
      continue;
    }

    // Identifier / keyword / type / function / variable.
    if (_isIdentifierStart(char)) {
      final identifierEnd = _readIdentifierEnd(source, i, end);

      final text = source.substring(i, identifierEnd);

      final type = _classifyIdentifier(text, source, identifierEnd, end);

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
    if (_singleCharacterPunctuation.contains(char)) {
      tokens.add(SyntaxToken(i, i + 1, TokenType.punctuation));

      i++;
      continue;
    }

    // Single-character operator.
    if (_singleCharacterOperators.contains(char)) {
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

/// Scans a string literal.
///
/// Handles:
///   - normal single-quoted strings
///   - normal double-quoted strings
///   - raw strings (`r'...'`, `r"..."`)
///   - `$identifier` interpolation
///   - `${expression}` interpolation
///
/// Returns the first offset after the string.
int _scanString(String source, int start, int end, List<SyntaxToken> tokens) {
  var i = start;

  var raw = false;

  if (source[i] == 'r') {
    raw = true;
    i++;
  }

  if (i >= end) {
    return start + 1;
  }

  final quote = source[i];

  // This method is called only when quote is known to be valid.
  i++;

  var stringSegmentStart = start;

  // Include the raw prefix and opening quote in the first string token.
  var contentStart = i;

  while (i < end) {
    final char = source[i];

    // Escaped character in a normal string.
    if (!raw && char == '\\' && i + 1 < end) {
      i += 2;
      continue;
    }

    // Closing quote.
    if (char == quote) {
      if (stringSegmentStart < i + 1) {
        tokens.add(SyntaxToken(stringSegmentStart, i + 1, TokenType.string));
      }

      return i + 1;
    }

    // Raw strings do not interpolate.
    if (raw) {
      i++;
      continue;
    }

    // String interpolation.
    if (char == r'$') {
      final interpolation = _readInterpolation(source, i, end);

      if (interpolation == null) {
        i++;
        continue;
      }

      final interpolationStart = interpolation.start;
      final interpolationEnd = interpolation.end;
      final interpolationKind = interpolation.kind;

      // Emit the string portion before interpolation.
      if (stringSegmentStart < interpolationStart) {
        tokens.add(
          SyntaxToken(stringSegmentStart, interpolationStart, TokenType.string),
        );
      }

      if (interpolationKind == _InterpolationKind.simpleVariable) {
        // `$number`
        tokens.add(
          SyntaxToken(interpolationStart, interpolationEnd, TokenType.variable),
        );
      } else {
        // `${user.name}`
        //
        // `${` is kept as string syntax.
        final expressionStart = interpolationStart + 2;
        final expressionEnd = interpolationEnd - 1;

        if (expressionStart > interpolationStart) {
          tokens.add(
            SyntaxToken(interpolationStart, expressionStart, TokenType.string),
          );
        }

        // Tokenize the expression using the same lexer.
        if (expressionStart < expressionEnd) {
          _scanSource(source, expressionStart, expressionEnd, tokens);
        }

        // `}` is punctuation.
        if (expressionEnd < interpolationEnd) {
          tokens.add(
            SyntaxToken(expressionEnd, interpolationEnd, TokenType.punctuation),
          );
        }
      }

      i = interpolationEnd;
      stringSegmentStart = i;
      contentStart = i;
      continue;
    }

    i++;
  }

  // Unterminated string.
  //
  // Color the remaining source as string rather than losing highlighting.
  if (stringSegmentStart < end) {
    tokens.add(SyntaxToken(stringSegmentStart, end, TokenType.string));
  } else if (contentStart < end) {
    tokens.add(SyntaxToken(start, end, TokenType.string));
  }

  return end;
}

/// Reads `$name` or `${expression}`.
///
/// Returns null when `$` isn't followed by a valid interpolation.
_InterpolationInfo? _readInterpolation(String source, int dollar, int end) {
  if (dollar + 1 >= end) {
    return null;
  }

  final next = source[dollar + 1];

  // Simple interpolation:
  //
  // $name
  if (_isIdentifierStart(next)) {
    final variableEnd = _readIdentifierEnd(source, dollar + 1, end);

    return _InterpolationInfo(
      dollar,
      variableEnd,
      _InterpolationKind.simpleVariable,
    );
  }

  // Braced interpolation:
  //
  // ${expression}
  if (next == '{') {
    final closingBrace = _findInterpolationClosingBrace(
      source,
      dollar + 2,
      end,
    );

    if (closingBrace == -1) {
      return null;
    }

    return _InterpolationInfo(
      dollar,
      closingBrace + 1,
      _InterpolationKind.bracedExpression,
    );
  }

  return null;
}

/// Finds the `}` belonging to `${...}`.
///
/// The scanner understands nested braces, strings, and comments well enough
/// for normal Dart interpolation expressions.
int _findInterpolationClosingBrace(String source, int start, int end) {
  var depth = 1;
  var i = start;

  while (i < end) {
    final char = source[i];

    // Line comment inside interpolation.
    if (char == '/' && i + 1 < end && source[i + 1] == '/') {
      i = _findLineEnd(source, i, end);
      continue;
    }

    // Block comment inside interpolation.
    if (char == '/' && i + 1 < end && source[i + 1] == '*') {
      i = _findBlockCommentEnd(source, i, end);
      continue;
    }

    // String inside interpolation.
    if (_isStringStart(source, i, end)) {
      i = _skipString(source, i, end);
      continue;
    }

    if (char == '{') {
      depth++;
      i++;
      continue;
    }

    if (char == '}') {
      depth--;

      if (depth == 0) {
        return i;
      }

      i++;
      continue;
    }

    i++;
  }

  return -1;
}

/// Skips a string while searching for the end of an interpolation.
///
/// This does not generate tokens.
int _skipString(String source, int start, int end) {
  var i = start;
  var raw = false;

  if (source[i] == 'r') {
    raw = true;
    i++;
  }

  if (i >= end) {
    return end;
  }

  final quote = source[i];
  i++;

  while (i < end) {
    final char = source[i];

    if (!raw && char == '\\' && i + 1 < end) {
      i += 2;
      continue;
    }

    if (char == quote) {
      return i + 1;
    }

    i++;
  }

  return end;
}

bool _isStringStart(String source, int index, int end) {
  final char = source[index];

  if (char == '"' || char == "'") {
    return true;
  }

  if (char == 'r' &&
      index + 1 < end &&
      (source[index + 1] == '"' || source[index + 1] == "'")) {
    return true;
  }

  return false;
}

bool _isNumberStart(String source, int index, int end) {
  final char = source[index];

  if (_isDigit(char)) {
    return true;
  }

  // Support numbers such as `.5`.
  if (char == '.' && index + 1 < end && _isDigit(source[index + 1])) {
    return true;
  }

  return false;
}

int _readNumberEnd(String source, int start, int end) {
  var i = start;

  // Integer / decimal part.
  while (i < end && _isDigit(source[i])) {
    i++;
  }

  if (i < end && source[i] == '.' && i + 1 < end && _isDigit(source[i + 1])) {
    i++;

    while (i < end && _isDigit(source[i])) {
      i++;
    }
  } else if (start < end && source[start] == '.' && i == start) {
    i++;

    while (i < end && _isDigit(source[i])) {
      i++;
    }
  }

  // Exponent.
  if (i < end && (source[i] == 'e' || source[i] == 'E')) {
    var exponentIndex = i + 1;

    if (exponentIndex < end &&
        (source[exponentIndex] == '+' || source[exponentIndex] == '-')) {
      exponentIndex++;
    }

    final digitStart = exponentIndex;

    while (exponentIndex < end && _isDigit(source[exponentIndex])) {
      exponentIndex++;
    }

    if (exponentIndex > digitStart) {
      i = exponentIndex;
    }
  }

  return i;
}

TokenType _classifyIdentifier(
  String text,
  String source,
  int end,
  int sourceEnd,
) {
  if (_dartKeywords.contains(text)) {
    return TokenType.keyword;
  }

  if (_builtinTypes.contains(text)) {
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

int _readIdentifierEnd(String source, int start, int end) {
  var i = start;

  while (i < end && _isIdentifierPart(source[i])) {
    i++;
  }

  return i;
}

String? _readMultiCharacterOperator(String source, int start, int end) {
  for (final operator in _multiCharacterOperators) {
    final operatorEnd = start + operator.length;

    if (operatorEnd <= end &&
        source.substring(start, operatorEnd) == operator) {
      return operator;
    }
  }

  return null;
}

int _findLineEnd(String source, int start, int end) {
  var i = start;

  while (i < end && source[i] != '\n') {
    i++;
  }

  return i;
}

int _findBlockCommentEnd(String source, int start, int end) {
  var i = start + 2;

  while (i + 1 < end) {
    if (source[i] == '*' && source[i + 1] == '/') {
      return i + 2;
    }

    i++;
  }

  return end;
}

bool _isWhitespace(String char) {
  return char == ' ' || char == '\t' || char == '\n' || char == '\r';
}

bool _isDigit(String char) {
  final code = char.codeUnitAt(0);
  return code >= 48 && code <= 57;
}

bool _isIdentifierStart(String char) {
  final code = char.codeUnitAt(0);

  return (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122) ||
      char == '_' ||
      char == r'$';
}

bool _isIdentifierPart(String char) {
  return _isIdentifierStart(char) || _isDigit(char);
}

enum _InterpolationKind { simpleVariable, bracedExpression }

class _InterpolationInfo {
  final int start;
  final int end;
  final _InterpolationKind kind;

  const _InterpolationInfo(this.start, this.end, this.kind);
}

//================================================================================================================
// /// A lightweight, heuristic Dart tokenizer for syntax highlighting.
// ///
// /// This is NOT a full language parser — it's a regex-based lexer good
// /// enough for coloring code as you type on a phone. Known simplifications
// /// (documented rather than hidden, per the "never fake" rule):
// ///   - String interpolation (`'Hello, $name'`) is colored entirely as a
// ///     string; the interpolated expression isn't separately tokenized.
// ///   - Triple-quoted multiline strings aren't given special handling —
// ///     each line is tokenized independently, so multi-line string
// ///     literals may highlight imperfectly across line boundaries.
// ///   - Type detection is heuristic (capitalized identifier, or a small
// ///     built-in-types list), not symbol-table-based.
// library;
//
// enum TokenType {
//   keyword,
//   string,
//   comment,
//   number,
//   annotation,
//   type,
//   function,
//   variable,
//   operatorSymbol,
//   punctuation,
// }
//
// class SyntaxToken {
//   final int start;
//   final int end;
//   final TokenType type;
//   const SyntaxToken(this.start, this.end, this.type);
// }
//
// const Set<String> _dartKeywords = {
//   'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case',
//   'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred',
//   'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
//   'external', 'factory', 'false', 'final', 'finally', 'for', 'get', 'hide',
//   'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
//   'mixin', 'new', 'null', 'on', 'operator', 'part', 'required', 'rethrow',
//   'return', 'sealed', 'set', 'show', 'static', 'super', 'switch', 'sync',
//   'this', 'throw', 'true', 'try', 'typedef', 'var', 'void', 'when', 'while',
//   'with', 'yield',
// };
//
// const Set<String> _builtinTypes = {
//   'int', 'double', 'String', 'bool', 'num', 'Object', 'List', 'Map', 'Set',
//   'Iterable', 'Future', 'Stream', 'Duration', 'DateTime', 'Symbol', 'Never',
//   'Function', 'Record',
// };
//
// const Set<String> _punctuation = {'{', '}', '(', ')', '[', ']', ';', ',', '.', ':'};
//
// /// Pieces are kept separate (rather than one giant string) so each can
// /// use whichever raw-string quote delimiter avoids escaping headaches.
// final RegExp _tokenPattern = RegExp(
//   <String>[
//     r'//[^\n]*|/\*[\s\S]*?\*/',
//     r'r?"(?:[^"\\\n]|\\.)*"',
//     r"r?'(?:[^'\\\n]|\\.)*'",
//     r'\b\d+\.?\d*(?:[eE][+-]?\d+)?\b',
//     r'@[A-Za-z_]\w*',
//     r'[A-Za-z_$][A-Za-z0-9_$]*',
//     r'=>|\?\.|\?\?=|\?\?|\.\.\.|==|!=|>=|<=|&&|\|\||\+\+|--|\+=|-=|\*=|/=|[+\-*/%=<>!&|^~?:.,;(){}\[\]]',
//   ].join('|'),
// );
//
// List<SyntaxToken> tokenizeDart(String source) {
//   if (source.isEmpty) return const [];
//   final tokens = <SyntaxToken>[];
//   for (final m in _tokenPattern.allMatches(source)) {
//     final text = m.group(0)!;
//     tokens.add(SyntaxToken(m.start, m.end, _classify(text, source, m.end)));
//   }
//   return tokens;
// }
//
// TokenType _classify(String text, String source, int end) {
//   final first = text[0];
//
//   if (text.startsWith('//') || text.startsWith('/*')) return TokenType.comment;
//
//   if (first == '"' || first == "'" || (text.length > 1 && first == 'r')) {
//     return TokenType.string;
//   }
//   if (RegExp(r'^\d').hasMatch(text)) return TokenType.number;
//   if (first == '@') return TokenType.annotation;
//
//   if (RegExp(r'^[A-Za-z_$]').hasMatch(first)) {
//     if (_dartKeywords.contains(text)) return TokenType.keyword;
//     if (_builtinTypes.contains(text)) return TokenType.type;
//     if (RegExp(r'^[A-Z]').hasMatch(text)) return TokenType.type;
//     if (_isFollowedByOpenParen(source, end)) return TokenType.function;
//     return TokenType.variable;
//   }
//
//   if (_punctuation.contains(text)) return TokenType.punctuation;
//   return TokenType.operatorSymbol;
// }
//
// bool _isFollowedByOpenParen(String source, int end) {
//   var i = end;
//   while (i < source.length && (source[i] == ' ' || source[i] == '\t')) {
//     i++;
//   }
//   return i < source.length && source[i] == '(';
// }
