import 'dart:async';

import 'package:flutter/foundation.dart' show Listenable;

import 'open_files_store.dart';

/// Remembers, per project, which files are open and which one is active.
///
/// It only watches: after [changes] has been quiet for [delay] it looks at
/// the current project and tabs and, if that is new, saves it. It does not
/// know about FileProvider, so it needs no change there and is easy to test.
///
/// The short wait matters: opening another project closes the old project's
/// tabs one by one, and those half-closed states must not be saved.
class OpenFilesTracker {
  OpenFilesTracker({
    required Listenable changes,
    required Object? Function() projectId,
    required List<String> Function() openTabs,
    required String? Function() activeFile,
    OpenFilesStore? store,
    Duration delay = const Duration(milliseconds: 500),
  })  : _changes = changes,
        _projectId = projectId,
        _openTabs = openTabs,
        _activeFile = activeFile,
        _store = store ?? OpenFilesStore(),
        _delay = delay {
    _changes.addListener(_onChanged);
  }

  final Listenable _changes;
  final Object? Function() _projectId;
  final List<String> Function() _openTabs;
  final String? Function() _activeFile;
  final OpenFilesStore _store;
  final Duration _delay;

  Timer? _timer;
  String? _lastSaved;
  Future<void> _pending = Future<void>.value();

  /// Completes when every save requested so far has been written.
  Future<void> get settled => _pending;

  void _onChanged() {
    _timer?.cancel();
    _timer = Timer(_delay, _capture);
  }

  /// Saves the current state right now (for example just before the user
  /// opens another project) and completes when it has been written.
  Future<void> flush() {
    _timer?.cancel();
    _capture();
    return _pending;
  }

  void _capture() {
    _timer = null;
    final project = _projectId();
    final tabs = _openTabs();
    if (project == null || tabs.isEmpty) return;

    final files = OpenFiles(tabs: List<String>.of(tabs), active: _activeFile());
    final key = '$project|${files.encode()}';
    if (key == _lastSaved) return;
    _lastSaved = key;
    _pending = _pending.then((_) => _store.write(project, files));
  }

  void dispose() {
    _timer?.cancel();
    _changes.removeListener(_onChanged);
  }
}
