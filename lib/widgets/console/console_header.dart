import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../providers/console_provider.dart';
import '../../providers/runner_provider.dart';
import '../../utils/constants.dart';
import '../../utils/themes.dart';

class ConsoleHeader extends StatelessWidget {
  final ConsoleProvider console;
  final RunnerProvider runner;
  final EditorColorScheme scheme;

  const ConsoleHeader({
    super.key,
    required this.console,
    required this.runner,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    Widget action(String tip, IconData icon, VoidCallback onTap) => IconButton(
          tooltip: tip,
          icon: Icon(icon, size: 18, color: scheme.gutterText),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: onTap,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spaceMd,
        0,
        AppConstants.spaceSm,
        AppConstants.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Console',
                    style: TextStyle(
                        color: scheme.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  const SizedBox(width: AppConstants.spaceSm),
                  if (runner.isRunning)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.selection.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Running',
                          style: TextStyle(color: scheme.text, fontSize: 11)),
                    ),
                  if (runner.waitingForStdin)
                    Container(
                      margin: const EdgeInsets.only(left: AppConstants.spaceSm),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.type.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Waiting for input',
                          style: TextStyle(color: scheme.type, fontSize: 11)),
                    ),
                ],
              ),
            ),
          ),
          action('Copy output', Icons.copy_outlined, () async {
            await console.copyToClipboard();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')));
            }
          }),
          action('Save as .txt', Icons.download_outlined, () async {
            final path = await console.saveToFile();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Output saved'),
                  action: SnackBarAction(
                    label: 'Open folder',
                    onPressed: () => OpenFilex.open(path),
                  ),
                ),
              );
            }
          }),
          action('Clear', Icons.delete_outline, console.clear),
          action('Close', Icons.close, console.close),
        ],
      ),
    );
  }
}
