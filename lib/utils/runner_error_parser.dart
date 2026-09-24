/// Tries to pull a 1-indexed line number out of a runtime/syntax error
/// message from the interpreter, for Section 35's "editor-এ error
/// line highlight করার architecture থাকতে হবে".
///
/// This is a best-effort heuristic, not a guaranteed capability —
/// and real-device testing has now confirmed its actual ceiling:
/// for a runtime exception (tried with `RangeError`), NEITHER the
/// exception's message NOR its stack trace contains a usable line
/// number. The stack trace turned out to be entirely `tom_d4rt`'s own
/// AST-visitor call stack (`interpreter_visitor.dart`, analyzer's
/// `ast.dart`, ...) — real frames from the *host* interpreter walking
/// the syntax tree, not synthetic positions in the *interpreted*
/// source. So this function will simply never find a match for that
/// whole class of errors, and that's expected, not a bug to chase.
///
/// It's kept (rather than removed) because syntax/parse errors are a
/// different case: the analyzer that `tom_d4rt` parses with typically
/// does report a position as part of its diagnostic text before
/// execution even starts, so "line N" / ":N:N" patterns have a real
/// chance of appearing there. This just can't promise it for every
/// error — a null return means "couldn't tell", not "no error".
int? parseErrorLine(String message) {
  final lineWord = RegExp(r'[Ll]ine[: ]+(\d+)').firstMatch(message);
  if (lineWord != null) return int.tryParse(lineWord.group(1)!);

  final lineColumn = RegExp(r':(\d+):\d+').firstMatch(message);
  if (lineColumn != null) return int.tryParse(lineColumn.group(1)!);

  return null;
}
