import '../../models/console_event.dart';
import '../../providers/runner_provider.dart';
import '../../utils/runner_error_parser.dart';
import '../../widgets/code_editor_controller.dart';

/// Looks for a line number in any new stderr output and, if found, marks it on
/// whichever file was actually running (Section 35) — best-effort, see
/// runner_error_parser.dart for why this can't be guaranteed to always find one
/// (confirmed: it won't, for runtime exceptions — only a real chance for
/// syntax/parse errors).
class RunErrorMarker {
  RunErrorMarker({
    required RunnerProvider runner,
    required CodeEditorController? Function(String path) controllerFor,
  })  : _runner = runner,
        _controllerFor = controllerFor;

  final RunnerProvider _runner;
  final CodeEditorController? Function(String path) _controllerFor;

  String? _runPath;
  int _seenEvents = 0;

  /// A run of the file at [path] starts: only its output counts from now on.
  void beginRun(String? path) {
    _runPath = path;
    _seenEvents = 0;
  }

  /// Give this to the runner's `addListener`.
  void onRunnerChanged() {
    final events = _runner.events;
    if (events.length > _seenEvents) {
      final newEvents = events.sublist(_seenEvents);
      final runPath = _runPath;
      if (runPath != null) {
        for (final event in newEvents) {
          if (event.type == ConsoleEventType.stderr) {
            final line = parseErrorLine(event.text ?? '');
            if (line != null) {
              _controllerFor(runPath)?.setErrorLine(line);
              break;
            }
          }
        }
      }
    }
    _seenEvents = events.length;
  }
}
