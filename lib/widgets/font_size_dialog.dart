import 'package:flutter/material.dart';

import '../providers/settings_provider.dart';
import '../utils/constants.dart';

/// Section 41's font-size setting, exposed here as a quick stepper
/// rather than waiting for the full Settings screen (Phase 10) — it's
/// used often enough on a small screen to deserve a fast path.
Future<void> showFontSizeDialog(BuildContext context, SettingsProvider settings) {
  return showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        void adjust(double delta) {
          final next = (settings.editorFontSize + delta)
              .clamp(AppConstants.minFontSize, AppConstants.maxFontSize);
          settings.setEditorFontSize(next);
          setDialogState(() {});
        }

        return AlertDialog(
          title: const Text('Font size'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Smaller',
                icon: const Icon(Icons.remove_rounded),
                onPressed: settings.editorFontSize > AppConstants.minFontSize
                    ? () => adjust(-1)
                    : null,
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${settings.editorFontSize.round()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Larger',
                icon: const Icon(Icons.add_rounded),
                onPressed: settings.editorFontSize < AppConstants.maxFontSize
                    ? () => adjust(1)
                    : null,
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        );
      },
    ),
  );
}
