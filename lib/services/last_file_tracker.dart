import 'dart:async';

import 'package:flutter/material.dart';

import 'last_file_store.dart';

/// Remembers which file each project was last working in.
///
/// It only watches: whenever [changes] fires, it looks at the current
/// project and active file and, if that pair is new, saves it. It does not
/// know about FileProvider, so it needs no change there and is easy to test.
class LastFileTracker {
  LastFileTracker({
    required Listenable changes,
    required Object? Function() projectId,
    required String? Function() activeFile,
    LastFileStore? store,
  })  : _changes = changes,
        _projectId = projectId,
        _activeFile = activeFile,
        _store = store ?? LastFileStore() {
    _changes.addListener(_onChanged);
  }

  final Listenable _changes;
  final Object? Function() _projectId;
  final String? Function() _activeFile;
  final LastFileStore _store;

  String? _lastSeen;
  Future<void> _pending = Future<void>.value();

  /// Completes when every save requested so far has been written.
  Future<void> get settled => _pending;

  void _onChanged() {
    final project = _projectId();
    final file = _activeFile();
    if (project == null || file == null) return;

    final key = '$project|$file';
    if (key == _lastSeen) return;
    _lastSeen = key;
    _pending = _pending.then((_) => _store.write(project, file));
  }

  void dispose() => _changes.removeListener(_onChanged);
}
