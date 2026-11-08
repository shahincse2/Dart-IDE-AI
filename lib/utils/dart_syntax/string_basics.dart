// Where a string starts, and how to jump over one.

bool isStringStart(String source, int index, int end) {
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

/// Skips a string while searching for the end of an interpolation.
///
/// This does not generate tokens.
int skipString(String source, int start, int end) {
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
