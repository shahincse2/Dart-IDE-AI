/// The end of the line that starts at [start] (the offset of its '\n').
int findLineEnd(String source, int start, int end) {
  var i = start;

  while (i < end && source[i] != '\n') {
    i++;
  }

  return i;
}

/// The offset just after the `*/` that closes the block comment at [start].
int findBlockCommentEnd(String source, int start, int end) {
  var i = start + 2;

  while (i + 1 < end) {
    if (source[i] == '*' && source[i + 1] == '/') {
      return i + 2;
    }

    i++;
  }

  return end;
}
