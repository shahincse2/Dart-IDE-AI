import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/file_provider.dart';
import '../services/open_files_tracker.dart';
import '../services/session/cursor_memory.dart';
import '../services/session/last_project_store.dart';
import '../services/session/open_project_flow.dart';

/// Keeps the user's work across closing the app. It sits around the first
/// screen (the project list) and does three things:
///
///  * at the start, opens the project that was open last (with its tabs and
///    cursors) straight into the editor; back goes to the project list;
///  * remembers which project is open, as it changes;
///  * when the app goes to the background, writes everything that is waiting
///    (unsaved typing, open tabs, cursor positions), because the system may
///    close the app there without telling it.
class SessionKeeper extends StatefulWidget {
  const SessionKeeper({
    super.key,
    required this.child,
    required this.editorBuilder,
  });

  /// The first screen: shown when there is nothing to reopen.
  final Widget child;

  /// The editor screen, pushed on top of [child] when a project is reopened.
  final WidgetBuilder editorBuilder;

  @override
  State<SessionKeeper> createState() => _SessionKeeperState();
}

class _SessionKeeperState extends State<SessionKeeper>
    with WidgetsBindingObserver {
  late final FileProvider _files;
  bool _ready = false;
  String? _rememberedProject;

  @override
  void initState() {
    super.initState();
    _files = context.read<FileProvider>();
    _files.addListener(_rememberProject);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _files.removeListener(_rememberProject);
    super.dispose();
  }

  void _rememberProject() {
    final id = _files.currentProject?.id;
    if (id == null || id == _rememberedProject) return;
    _rememberedProject = id;
    unawaited(LastProjectStore().write(id));
  }

  /// Opens the project that was open last, if there is one.
  Future<void> _restore() async {
    try {
      final id = await LastProjectStore().read();
      if (id != null && mounted) {
        await _files.loadProjects();
        final project = _files.projects.where((p) => p.id == id).firstOrNull;
        if (project != null && mounted) {
          await openProjectWithMemory(context, project);
          if (mounted) {
            unawaited(Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: widget.editorBuilder)));
          }
        }
      }
    } on Exception {
      // Not being able to reopen is never worth a crash: the project list
      // is shown instead.
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_files.flushAllPendingSaves());
      unawaited(context.read<OpenFilesTracker>().flush());
      unawaited(context.read<CursorMemory>().flush());
    }
  }

  @override
  Widget build(BuildContext context) {
    // While it is not known yet whether to reopen a project, show nothing: the
    // project list would flash by before the editor covers it.
    return _ready ? widget.child : const Scaffold();
  }
}
