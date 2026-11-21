import 'dart:async';

import 'cursor_store.dart';

/// Remembers where the cursor was in each file of the project being edited,
/// so a file reopens at the place the user left it, even after the app was
/// closed.
///
/// [record] is called on every cursor move, so writing waits until things have
/// been quiet for [delay]; [flush] writes at once (when the app goes to the
/// background).
class CursorMemory {
  CursorMemory({
    CursorStore? store,
    Duration delay = const Duration(milliseconds: 800),
  })  : _store = store ?? CursorStore(),
        _delay = delay;

  final CursorStore _store;
  final Duration _delay;

  Object? _projectId;
  Map<String, int> _cursors = {};
  bool _unsaved = false;
  Timer? _timer;
  Future<void> _loading = Future<void>.value();
  Future<void> _pending = Future<void>.value();

  /// Makes [projectId] the project being edited: what is remembered for it
  /// is read (the previous project's cursors are saved first). Safe to call
  /// again and again with the same project.
  Future<void> useProject(Object? projectId) async {
    if (projectId == _projectId) return _loading;
    await flush();
    _projectId = projectId;
    _cursors = {};
    if (projectId == null) return;
    _loading = _store.read(projectId).then((stored) {
      if (_projectId == projectId) _cursors = stored;
    });
    await _loading;
  }

  /// The project being edited has another id now (it was renamed); what is
  /// remembered for it stays.
  void renameProject(Object oldId, Object newId) {
    if (_projectId == oldId) _projectId = newId;
  }

  /// The project was deleted: nothing more is remembered or written for it.
  void forgetProject(Object id) {
    if (_projectId != id) return;
    _timer?.cancel();
    _timer = null;
    _projectId = null;
    _cursors = {};
    _unsaved = false;
  }

  /// The remembered cursor offset in [path], or null.
  int? cursorOf(String path) => _cursors[path];

  void record(String path, int cursor) {
    if (_projectId == null || cursor < 0 || _cursors[path] == cursor) return;
    _cursors[path] = cursor;
    _unsaved = true;
    _timer?.cancel();
    _timer = Timer(_delay, () => unawaited(flush()));
  }

  /// Writes what is waiting; completes when every write so far is done.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final project = _projectId;
    if (project != null && _unsaved) {
      _unsaved = false;
      final copy = Map<String, int>.of(_cursors);
      _pending = _pending.then((_) => _store.write(project, copy));
    }
    return _pending;
  }

  void dispose() => _timer?.cancel();
}
