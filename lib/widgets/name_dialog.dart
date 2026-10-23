import 'package:flutter/material.dart';

/// Asks for a name (new project / file / folder, rename).
///
/// Returns the trimmed text, or null when cancelled. Enter on a keyboard
/// does the same as the confirm button.
Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String? hint,
  String confirmLabel = 'OK',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      title: title,
      initialValue: initialValue,
      hint: hint,
      confirmLabel: confirmLabel,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initialValue,
    required this.hint,
    required this.confirmLabel,
  });

  final String title;
  final String initialValue;
  final String? hint;
  final String confirmLabel;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        // Always a decoration: with none at all the field has no underline.
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
