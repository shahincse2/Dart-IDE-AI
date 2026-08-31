import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/file_provider.dart';
import '../utils/constants.dart';

/// The real multi-file tab strip (Section 19), replacing Phase 5's
/// single-filename bar. Purely driven by [FileProvider] — it never
/// needs a CodeEditorController reference, since closing a dirty tab
/// only needs whatever content FileProvider already has pending from
/// the last keystroke.
class FileTabBar extends StatelessWidget {
  const FileTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    final fileProvider = context.watch<FileProvider>();
    final tabs = fileProvider.openTabs;
    if (tabs.isEmpty) return const SizedBox.shrink();

    return Container(
      height: AppConstants.tabBarHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, i) {
          final path = tabs[i];
          return _TabChip(
            key: ValueKey(path),
            name: path.split('/').last,
            isActive: path == fileProvider.activeTab,
            isDirty: fileProvider.isDirty(path),
            onTap: () => fileProvider.setActiveTab(path),
            onClose: () => _closeTab(context, path),
          );
        },
      ),
    );
  }

  Future<void> _closeTab(BuildContext context, String path) async {
    final fileProvider = context.read<FileProvider>();

    if (fileProvider.isDirty(path)) {
      final choice = await _confirmCloseUnsaved(context, path.split('/').last);
      if (choice == null || choice == 'cancel') return;
      if (!context.mounted) return;
      if (choice == 'save') {
        await fileProvider.flushPendingSave(path);
        if (!context.mounted) return;
      }
      // choice == 'discard' falls straight through to closing below.
    }

    await fileProvider.closeTab(path, flush: false);
  }
}

class _TabChip extends StatelessWidget {
  final String name;
  final bool isActive;
  final bool isDirty;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabChip({
    super.key,
    required this.name,
    required this.isActive,
    required this.isDirty,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isActive ? scheme.surfaceContainerHighest : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceSm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
              if (isDirty) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                ),
              ],
              const SizedBox(width: AppConstants.spaceXs),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 14, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Returns 'save', 'discard', or 'cancel' (or null if dismissed the
/// same as cancel).
Future<String?> _confirmCloseUnsaved(BuildContext context, String fileName) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Unsaved changes'),
      content: Text('"$fileName" has unsaved changes.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, 'cancel'),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Theme.of(dialogContext).colorScheme.error),
          onPressed: () => Navigator.pop(dialogContext, 'discard'),
          child: const Text('Discard'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, 'save'),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
