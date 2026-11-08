import 'package:flutter/material.dart';

import '../../utils/feature_flags.dart';
import 'editor_actions.dart';

/// The app bar's ⋮ menu. An item whose action is null is shown disabled.
class EditorMenu extends StatelessWidget {
  final EditorActions actions;
  final bool useSidebar;
  final bool wordWrap;

  const EditorMenu({
    super.key,
    required this.actions,
    required this.useSidebar,
    required this.wordWrap,
  });

  PopupMenuItem<VoidCallback> _item(
    IconData icon,
    String title,
    VoidCallback? action, {
    Widget? trailing,
  }) {
    return PopupMenuItem<VoidCallback>(
      enabled: action != null,
      value: action,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: trailing,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<VoidCallback>(
      tooltip: 'More',
      // Closing a menu hands focus back to the editor, and the keyboard
      // with it, even if the user had hidden it. Nothing in this menu
      // needs the keyboard, so let go of the focus when it opens.
      onOpened: () => FocusManager.instance.primaryFocus?.unfocus(),
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        _item(
          Icons.format_align_left_rounded,
          'Format code',
          actions.format,
          // Only a wide screen (with a keyboard) has the shortcut.
          trailing: useSidebar ? const Text('Ctrl+Alt+L') : null,
        ),
        _item(Icons.arrow_forward_rounded, 'Go to line', actions.goToLine),
        _item(Icons.unfold_less_rounded, 'Fold all', actions.foldAll),
        _item(Icons.unfold_more_rounded, 'Unfold all', actions.unfoldAll),
        _item(Icons.format_size_rounded, 'Font size', actions.fontSize),
        CheckedPopupMenuItem<VoidCallback>(
          value: actions.toggleWordWrap,
          checked: wordWrap,
          padding: EdgeInsets.zero,
          child: const Text('Word wrap'),
        ),
        const PopupMenuDivider(),
        _item(Icons.file_download_outlined, 'Export file', actions.export),
        _item(Icons.file_upload_outlined, 'Import file', actions.importFile),
        _item(Icons.share_outlined, 'Share code', actions.shareCode),
        _item(Icons.print_outlined, 'Print', actions.printCode),
        _item(Icons.picture_as_pdf_outlined, 'Share as PDF', actions.sharePdf),
        const PopupMenuDivider(),
        _item(Icons.visibility_outlined, 'Preview UI', actions.previewUi),
        _item(
            Icons.manage_search_rounded, 'Inspect variables', actions.inspect),
        // Switched off in v1.0 (see utils/feature_flags.dart).
        if (kGitEnabled)
          _item(
            Icons.cloud_upload_outlined,
            'Push to GitHub / GitLab',
            actions.git,
          ),
        const PopupMenuDivider(),
        _item(Icons.settings_outlined, 'Settings', actions.settings),
      ],
    );
  }
}
