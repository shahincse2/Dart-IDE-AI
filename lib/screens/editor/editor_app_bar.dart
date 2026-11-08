import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../widgets/editor_app_bar_title.dart';
import 'editor_actions.dart';
import 'editor_menu.dart';

/// The editor screen's app bar: the file name, Find, Save, Run/Stop and the
/// ⋮ menu.
class EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String fileName;
  final String? filePath;
  final bool isDirty;
  final bool useSidebar;
  final bool isRunning;
  final bool wordWrap;
  final EditorActions actions;

  const EditorAppBar({
    super.key,
    required this.fileName,
    this.filePath,
    required this.isDirty,
    required this.useSidebar,
    required this.isRunning,
    required this.wordWrap,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppBar(
      automaticallyImplyLeading: !useSidebar,
      // Wide layouts (Windows, tablets, landscape) have no drawer button and
      // no system back key, so they get an explicit way out.
      leading:
          useSidebar && Navigator.canPop(context) ? const BackButton() : null,
      title: EditorAppBarTitle(
        fileName: fileName,
        filePath: filePath,
        isDirty: isDirty,
      ),
      actions: [
        IconButton(
          tooltip: 'Find & Replace',
          icon: const Icon(Icons.search_rounded),
          onPressed: actions.find,
        ),
        IconButton(
          tooltip: isDirty ? 'Save (unsaved changes)' : 'Save',
          icon: Icon(
            Icons.save_outlined,
            color: isDirty
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.38),
          ),
          onPressed: isDirty ? actions.save : null,
        ),
        IconButton(
          tooltip: isRunning ? 'Stop' : 'Run',
          icon: Icon(isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
          color: isRunning ? colors.error : null,
          onPressed: actions.run,
        ),
        EditorMenu(
          actions: actions,
          useSidebar: useSidebar,
          wordWrap: wordWrap,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(AppConstants.appBarHeight);
}
