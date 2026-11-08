import 'char_classes.dart';
import 'comment_scan.dart';
import 'identifier_scan.dart';
import 'string_basics.dart';

enum InterpolationKind { simpleVariable, bracedExpression }

class InterpolationInfo {
  final int start;
  final int end;
  final InterpolationKind kind;

  const InterpolationInfo(this.start, this.end, this.kind);
}

/// Reads `$name` or `${expression}`.
///
/// Returns null when `$` isn't followed by a valid interpolation.
InterpolationInfo? readInterpolation(String source, int dollar, int end) {
  if (dollar + 1 >= end) {
    return null;
  }

  final next = source[dollar + 1];

  // Simple interpolation:
  //
  // $name
  if (isIdentifierStart(next)) {
    final variableEnd = readIdentifierEnd(source, dollar + 1, end);

    return InterpolationInfo(
      dollar,
      variableEnd,
      InterpolationKind.simpleVariable,
    );
  }

  // Braced interpolation:
  //
  // ${expression}
  if (next == '{') {
    final closingBrace = findInterpolationClosingBrace(
      source,
      dollar + 2,
      end,
    );

    if (closingBrace == -1) {
      return null;
    }

    return InterpolationInfo(
      dollar,
      closingBrace + 1,
      InterpolationKind.bracedExpression,
    );
  }

  return null;
}

/// Finds the `}` belonging to `${...}`.
///
/// The scanner understands nested braces, strings, and comments well enough
/// for normal Dart interpolation expressions.
int findInterpolationClosingBrace(String source, int start, int end) {
  var depth = 1;
  var i = start;

  while (i < end) {
    final char = source[i];

    // Line comment inside interpolation.
    if (char == '/' && i + 1 < end && source[i + 1] == '/') {
      i = findLineEnd(source, i, end);
      continue;
    }

    // Block comment inside interpolation.
    if (char == '/' && i + 1 < end && source[i + 1] == '*') {
      i = findBlockCommentEnd(source, i, end);
      continue;
    }

    // String inside interpolation.
    if (isStringStart(source, i, end)) {
      i = skipString(source, i, end);
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
