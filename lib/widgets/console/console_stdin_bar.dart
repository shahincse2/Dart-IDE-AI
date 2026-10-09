import 'package:flutter/material.dart';

import '../../providers/runner_provider.dart';
import '../../utils/constants.dart';
import '../../utils/themes.dart';

/// The stdin input bar — appears only when interpreted code calls
/// readLineSync() and the program is blocked waiting for input.
class ConsoleStdinBar extends StatefulWidget {
  final RunnerProvider runner;
  final EditorColorScheme scheme;

  const ConsoleStdinBar({
    super.key,
    required this.runner,
    required this.scheme,
  });

  @override
  State<ConsoleStdinBar> createState() => _ConsoleStdinBarState();
}

class _ConsoleStdinBarState extends State<ConsoleStdinBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus so the user can type immediately without tapping.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    _controller.clear();
    widget.runner.submitStdinInput(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spaceMd,
        AppConstants.spaceSm,
        AppConstants.spaceSm,
        AppConstants.spaceSm,
      ),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: widget.scheme.gutterText.withValues(alpha: 0.2),
                width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.keyboard_return_rounded,
              size: 16, color: widget.scheme.type),
          const SizedBox(width: AppConstants.spaceSm),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(
                  fontFamily: editorFontFamily,
                  fontSize: 13,
                  color: widget.scheme.text),
              decoration: InputDecoration(
                hintText: 'Type input and press Send…',
                hintStyle: TextStyle(color: widget.scheme.gutterText),
                border: InputBorder.none,
                isDense: true,
                isCollapsed: true,
              ),
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _send(),
            ),
          ),
          TextButton(
            onPressed: _send,
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
