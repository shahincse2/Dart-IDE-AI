import 'package:flutter/material.dart';

/// Section 34's "optional command-line arguments" before Run. A single
/// space-separated text field, matching the section's own example
/// (`hello 123`) — real support, since `execute()` accepts
/// `positionalArgs` directly (verified before Phase 3's runner was built).
///
/// Returns the parsed argument list, or null if the dialog was
/// cancelled (as opposed to confirmed with an empty field, which
/// returns an empty list — clearing previously-set arguments).
Future<List<String>?> showArgumentsDialog(BuildContext context, String initialValue) async {
  final controller = TextEditingController(text: initialValue);

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Arguments'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'hello 123',
          helperText: 'Space-separated — becomes main(List<String> args)',
          helperMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: const Text('Done'),
        ),
      ],
    ),
  );

  if (result == null) return null;
  return result.trim().isEmpty ? const [] : result.trim().split(RegExp(r'\s+'));
}
