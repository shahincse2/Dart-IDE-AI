import 'console_sink.dart';
import 'partial_line_buffer.dart';

/// A [ConsoleSink] that turns written text into complete lines and passes
/// each one to a callback. What the callbacks do (send over a port, add to
/// a stream, collect in a list) is up to the caller.
class LineConsoleSink implements ConsoleSink {
  LineConsoleSink({
    required void Function(String line) onOutLine,
    required void Function(String line) onErrLine,
  })  : _out = PartialLineBuffer(onOutLine),
        _err = PartialLineBuffer(onErrLine);

  final PartialLineBuffer _out;
  final PartialLineBuffer _err;

  @override
  void writeOut(String text) => _out.write(text);

  @override
  void writeErr(String text) => _err.write(text);

  @override
  void flush() {
    _out.flush();
    _err.flush();
  }
}
