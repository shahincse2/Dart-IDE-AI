import 'dart:io';

/// A one-line-at-a-time mailbox on disk, shared by two isolates.
///
/// The program's isolate must BLOCK until the user has typed a line (that
/// is what a synchronous `stdin.readLineSync()` means), but isolates cannot
/// share memory or wait on each other's ports. A file can do it: the UI
/// isolate [deliver]s a line, the program isolate [waitForLine]s for it.
///
/// Files are numbered, so nothing has to be deleted between lines, and a
/// line only appears once it is complete (written aside, then renamed).
class StdinMailbox {
  StdinMailbox(this.directory);

  final String directory;
  int _sent = 0;
  int _received = 0;

  String _path(int number, String extension) =>
      '$directory${Platform.pathSeparator}line_$number.$extension';

  /// UI side: hands one line to the program.
  void deliver(String line) {
    final aside = File(_path(_sent, 'tmp'));
    aside.writeAsStringSync(line, flush: true);
    aside.renameSync(_path(_sent, 'txt'));
    _sent++;
  }

  /// Program side: blocks this isolate until the next line arrives.
  String waitForLine() {
    final file = File(_path(_received, 'txt'));
    while (!file.existsSync()) {
      sleep(const Duration(milliseconds: 10));
    }
    final line = file.readAsStringSync();
    _received++;
    return line;
  }
}
