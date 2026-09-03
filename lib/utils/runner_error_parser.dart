/// Tries to pull a 1-indexed line number out of a runtime/syntax error
/// message from the interpreter, for Section 35's "editor-এ error
/// line highlight করার architecture থাকতে হবে".
///
/// This is a best-effort heuristic, not a guaranteed capability.
/// Before building this, `tom_d4rt`'s public API was checked for a
/// structured exception type with a `.line`/`.column` field — none was
/// found in the core package (a related companion package,
/// `tom_d4rt_dcli`, has one on a *different* exception type, which
/// isn't proof the base interpreter's runtime errors carry the same
/// structure). Rather than claim a capability that isn't confirmed,
/// this just tries a couple of common "line N" / ":N:N" text patterns
/// that error messages often contain, and returns null — meaning "no
/// marker", not "no error" — when neither matches. If real-device
/// testing shows tom_d4rt's actual error format, this is the one place
/// that needs updating to match it exactly.
int? parseErrorLine(String message) {
  final lineWord = RegExp(r'[Ll]ine[: ]+(\d+)').firstMatch(message);
  if (lineWord != null) return int.tryParse(lineWord.group(1)!);

  final lineColumn = RegExp(r':(\d+):\d+').firstMatch(message);
  if (lineColumn != null) return int.tryParse(lineColumn.group(1)!);

  return null;
}
