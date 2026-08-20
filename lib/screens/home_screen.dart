import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'editor_screen.dart';

/// Landing screen — will list saved projects once ProjectProvider and
/// local storage exist (Phase 5). Until then this is an honest empty
/// state rather than a mocked project list, per the "never fake
/// functionality" rule: there is genuinely nothing to show yet.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isTablet = AppConstants.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 480 : 360),
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spaceLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.code_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppConstants.spaceMd),
                  Text(
                    'Start your first project',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spaceSm),
                  Text(
                    'Write and run Dart code right on your phone — '
                    'no computer needed.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spaceLg),
                  SizedBox(
                    height: AppConstants.minTouchTarget,
                    child: FilledButton.icon(
                      onPressed: () => _openScratchFile(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New project'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Phase 1 stand-in: opens the editor with an unsaved scratch file.
  /// Real project creation (naming, on-disk folder, file tree) arrives
  /// with FileProvider/ProjectProvider in Phase 5.
  void _openScratchFile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditorScreen()),
    );
  }
}
