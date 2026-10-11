import 'dart:isolate';

/// What the main isolate asks the runner isolate to execute.
class RunRequest {
  const RunRequest({
    required this.source,
    required this.args,
    required this.sendPort,
    required this.stdinDir,
  });

  final String source;
  final List<String> args;
  final SendPort sendPort;

  /// Folder of the stdin mailbox (see StdinMailbox).
  final String stdinDir;
}

enum RunnerMessageType { stdoutBatch, stderr, stdinRequest, limit, done }

/// What the runner isolate sends back.
class RunnerMessage {
  const RunnerMessage.stdoutBatch(List<String> this.lines)
      : type = RunnerMessageType.stdoutBatch,
        text = null,
        exitCode = null;

  const RunnerMessage.stderr(String this.text)
      : type = RunnerMessageType.stderr,
        lines = null,
        exitCode = null;

  /// The program is waiting for a line of input.
  const RunnerMessage.stdinRequest()
      : type = RunnerMessageType.stdinRequest,
        text = null,
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
