import 'package:flutter/material.dart';

import '../services/ui_runner_service.dart';
import '../utils/constants.dart';

/// Section 37's "UI Run": renders the given Dart source as a real,
/// live Flutter widget tree, full-screen.
///
/// This is a snapshot, not a live-reload preview — it interprets
/// [source] as it was at the moment "Preview UI" was tapped. Editing
/// the file afterwards doesn't update an already-open preview; go back
/// and tap "Preview UI" again. Wiring live-reload-on-edit is possible
/// but adds real complexity (re-interpreting on every keystroke would
/// need debouncing, and any state the interpreted widget holds would
/// need a policy for whether it resets on each reload) — left for a
/// later phase if it turns out to matter in practice.
class UiPreviewScreen extends StatefulWidget {
  final String source;

  const UiPreviewScreen({super.key, required this.source});

  @override
  State<UiPreviewScreen> createState() => _UiPreviewScreenState();
}

class _UiPreviewScreenState extends State<UiPreviewScreen> {
  final _service = UiRunnerService();
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
    _service.warmup();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    try {
      // Keying on _reloadToken forces a genuinely fresh interpretation
      // (and fresh widget state) when the user taps Reload, rather
      // than Flutter reusing the previous build's element tree.
      content = KeyedSubtree(
        key: ValueKey(_reloadToken),
        child: _service.buildWidget(widget.source, context),
      );
    } catch (error) {
      content = _UiPreviewError(error: error);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('UI Preview'),
        leading: IconButton(
          tooltip: 'Close preview',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() => _reloadToken++),
          ),
        ],
      ),
      body: content,
    );
  }
}

class _UiPreviewError extends StatelessWidget {
  final Object error;

  const _UiPreviewError({required this.error});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.error),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: Text(
                  "Couldn't render this as a UI script",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          const Text(
            'UI Preview expects a top-level '
            'Widget build(BuildContext context) function, built from '
            'real Flutter Material widgets.',
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spaceMd),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              error.toString(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
