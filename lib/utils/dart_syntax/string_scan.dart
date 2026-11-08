import 'interpolation_scan.dart';
import 'token_types.dart';

/// Scans `source[start, end)` as code and appends its tokens. The string
/// scanner calls this for the expression inside `${...}`.
typedef ExpressionScanner = void Function(
  String source,
  int start,
  int end,
  List<SyntaxToken> tokens,
);

/// Scans a string literal.
///
/// Handles:
///   - normal single-quoted strings
///   - normal double-quoted strings
///   - raw strings (`r'...'`, `r"..."`)
///   - `$identifier` interpolation
///   - `${expression}` interpolation (the expression is handed to
///     [scanExpression])
///
/// Returns the first offset after the string.
int scanString(
  String source,
  int start,
  int end,
  List<SyntaxToken> tokens,
  ExpressionScanner scanExpression,
) {
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
      final interpolation = readInterpolation(source, i, end);

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

      if (interpolationKind == InterpolationKind.simpleVariable) {
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
          scanExpression(source, expressionStart, expressionEnd, tokens);
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
