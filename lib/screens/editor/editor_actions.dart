import 'package:flutter/widgets.dart';

/// Everything the editor's app bar and its ⋮ menu can do. A null callback is
/// an action that is not possible right now (no file open): its item is shown
/// disabled.
class EditorActions {
  const EditorActions({
    required this.run,
    required this.save,
    required this.find,
    required this.goToLine,
    required this.format,
    required this.foldAll,
    required this.unfoldAll,
    required this.export,
    required this.importFile,
    required this.shareCode,
    required this.printCode,
    required this.sharePdf,
    required this.previewUi,
    required this.inspect,
    required this.git,
    required this.settings,
    required this.toggleWordWrap,
    required this.fontSize,
  });

  final VoidCallback? run;
  final VoidCallback? save;
  final VoidCallback? find;
  final VoidCallback? goToLine;
  final VoidCallback? format;
  final VoidCallback? foldAll;
  final VoidCallback? unfoldAll;
  final VoidCallback? export;
  final VoidCallback importFile;
  final VoidCallback? shareCode;
  final VoidCallback? printCode;
  final VoidCallback? sharePdf;
  final VoidCallback? previewUi;
  final VoidCallback inspect;
  final VoidCallback? git;
  final VoidCallback settings;
  final VoidCallback toggleWordWrap;
  final VoidCallback fontSize;
}
