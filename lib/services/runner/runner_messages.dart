import 'dart:isolate';

/// What the main isolate asks an isolate runner to execute.
class RunRequest {
  const RunRequest({
    required this.source,
    required this.args,
    required this.sendPort,
  });

  final String source;
  final List<String> args;
  final SendPort sendPort;
}

enum RunnerMessageType { stdoutBatch, stderr, limit, done }

/// What an isolate runner sends back.
class RunnerMessage {
  const RunnerMessage.stdoutBatch(List<String> this.lines)
      : type = RunnerMessageType.stdoutBatch,
        text = null,
        exitCode = null;

  const RunnerMessage.stderr(String this.text)
      : type = RunnerMessageType.stderr,
        lines = null,
        exitCode = null;

  const RunnerMessage.limit()
      : type = RunnerMessageType.limit,
        text = null,
        lines = null,
        exitCode = null;

  const RunnerMessage.done(int this.exitCode)
      : type = RunnerMessageType.done,
        text = null,
        lines = null;

  final RunnerMessageType type;
  final String? text;
  final List<String>? lines;
  final int? exitCode;
}
