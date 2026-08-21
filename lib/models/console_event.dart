import 'package:flutter/foundation.dart';

enum ConsoleEventType { stdout, stderr, systemInfo, exitCode }

/// A single item in the execution output stream. This is the
/// app-facing model — [DartRunnerService] translates raw isolate
/// messages into these before they ever reach a Provider or widget.
@immutable
class ConsoleEvent {
  final ConsoleEventType type;
  final String? text;
  final int? exitCode;
  final DateTime timestamp;

  ConsoleEvent._(this.type, {this.text, this.exitCode}) : timestamp = DateTime.now();

  factory ConsoleEvent.stdout(String text) => ConsoleEvent._(ConsoleEventType.stdout, text: text);
  factory ConsoleEvent.stderr(String text) => ConsoleEvent._(ConsoleEventType.stderr, text: text);
  factory ConsoleEvent.systemInfo(String text) =>
      ConsoleEvent._(ConsoleEventType.systemInfo, text: text);
  factory ConsoleEvent.exitCode(int code) =>
      ConsoleEvent._(ConsoleEventType.exitCode, exitCode: code);
}
