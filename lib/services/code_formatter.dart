/// What a formatter says about a piece of source.
class FormatResult {
  /// The source, formatted; [cursor] is where the cursor belongs in [text].
  const FormatResult.formatted(String this.text, int this.cursor)
      : error = null;

  /// The source was already formatted: nothing to change.
  const FormatResult.unchanged()
      : text = null,
        cursor = null,
        error = null;

  /// The source could not be formatted ([error] says why, for the user).
  const FormatResult.failed(String this.error)
      : text = null,
        cursor = null;

  final String? text;
  final int? cursor;
  final String? error;
}

/// Formats source code. The editor only knows this; which package does the
/// work (and that it exists at all) is not its business.
abstract class CodeFormatter {
  /// Formats [source]. [cursorOffset] is where the cursor is now, so the
  /// result can say where it should be afterwards.
  Future<FormatResult> format(String source, {int cursorOffset = 0});
}
