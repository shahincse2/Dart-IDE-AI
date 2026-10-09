/// Where console output written by an interpreted program ends up.
///
/// The interpreter bindings and `print` only know this interface, so the
/// same code works whether output travels over an isolate port, straight
/// into a stream, or into a test buffer.
abstract class ConsoleSink {
  /// Text for stdout. May be a partial line (`stdout.write('Name: ')`).
  void writeOut(String text);

  /// Text for stderr. May be a partial line.
  void writeErr(String text);

  /// Emits any text still waiting for its newline (e.g. a prompt).
  void flush();
}
