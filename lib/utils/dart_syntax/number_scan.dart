import 'char_classes.dart';

bool isNumberStart(String source, int index, int end) {
  final char = source[index];

  if (isDigit(char)) {
    return true;
  }

  // Support numbers such as `.5`.
  if (char == '.' && index + 1 < end && isDigit(source[index + 1])) {
    return true;
  }

  return false;
}

int readNumberEnd(String source, int start, int end) {
  var i = start;

  // Integer / decimal part.
  while (i < end && isDigit(source[i])) {
    i++;
  }

  if (i < end && source[i] == '.' && i + 1 < end && isDigit(source[i + 1])) {
    i++;

    while (i < end && isDigit(source[i])) {
      i++;
    }
  } else if (start < end && source[start] == '.' && i == start) {
    i++;

    while (i < end && isDigit(source[i])) {
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

    while (exponentIndex < end && isDigit(source[exponentIndex])) {
      exponentIndex++;
    }

    if (exponentIndex > digitStart) {
      i = exponentIndex;
    }
  }

  return i;
}
