import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/runner_provider.dart';
import '../utils/constants.dart';
import '../utils/themes.dart';

/// Phase 12's Variable Inspector. Opens as a bottom sheet from the
/// editor's overflow menu after a successful run.
///
/// What it actually does (confirmed capability):
///   - Lists top-level variables from the post-run environment via
///     `D4rt.getEnvironmentState().variables`
///   - Evaluates any user-typed expression via `D4rt.eval()`
///
/// What it honestly DOESN'T do (stated plainly, not hidden):
///   - Inspect local variables inside a function (call frames are gone
///     when execute() returns; only the global scope is accessible)
///   - Step-through debugging (no breakpoint API in tom_d4rt)
///   - Live watch / auto-refresh mid-execution
class VariableInspectorPanel extends StatefulWidget {
  const VariableInspectorPanel({super.key});

  @override
  State<VariableInspectorPanel> createState() => _VariableInspectorPanelState();
}

class _VariableInspectorPanelState extends State<VariableInspectorPanel> {
  final _expressionController = TextEditingController();
  final _expressionFocusNode = FocusNode();
  final List<_EvalEntry> _history = [];

  @override
  void dispose() {
    _expressionController.dispose();
    _expressionFocusNode.dispose();
    super.dispose();
  }

  void _eval(RunnerProvider runner) {
    final expr = _expressionController.text.trim();
    if (expr.isEmpty) return;
    final result = runner.evalService.eval(expr);
    setState(() {
      _history.insert(0, _EvalEntry(expression: expr, result: result));
      _expressionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final runner = context.watch<RunnerProvider>();
    final evalService = runner.evalService;
    final scheme = Theme.of(context).colorScheme;

    final varNames = evalService.getEnvironmentVariableNames();

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        // Wrap in Material so ListTile can paint its ink splashes and
        // background on a real Material ancestor rather than the
        // DecoratedBox, which hides them (the Flutter assertion explains
        // exactly this: "ListTile paints on the nearest Material ancestor").
        return Material(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: AppConstants.spaceSm),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppConstants.spaceMd, 0, AppConstants.spaceMd, AppConstants.spaceSm),
                child: Row(
                  children: [
                    const Icon(Icons.manage_search_rounded, size: 18),
                    const SizedBox(width: AppConstants.spaceSm),
                    Text('Variable Inspector',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 0.5, color: scheme.outlineVariant),
              // The rest of the content goes inside an Expanded so the
              // Column gets a bounded height and never overflows —
              // DraggableScrollableSheet gives us a finite height, but
              // a Column inside it still needs at least one Expanded
              // child to fill rather than size-to-content past the edge.
              Expanded(
                child: _buildBody(
                  context: context,
                  scrollController: scrollController,
                  runner: runner,
                  evalService: evalService,
                  varNames: varNames,
                  scheme: scheme,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required ScrollController scrollController,
    required RunnerProvider runner,
    required dynamic evalService,
    required List<String> varNames,
    required ColorScheme scheme,
  }) {
    if (!evalService.hasSession && !evalService.isSettingUp) {
      return SingleChildScrollView(
        controller: scrollController,
        child: _NoSessionBanner(),
      );
    }
    if (evalService.isSettingUp) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppConstants.spaceMd),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: AppConstants.spaceSm),
              Text('Setting up inspector…', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      );
    }

    // Build the scrollable list of: variables (if any), eval input,
    // history. Everything in one ListView so it scrolls as one unit
    // and the DraggableScrollableSheet controller drives the scroll.
    return ListView(
      controller: scrollController,
      children: [
        if (varNames.isNotEmpty) ...[
          _SectionLabel('Top-level variables'),
          ...varNames.map((name) => _VariableRow(
            name: name,
            evalService: runner.evalService,
            onTap: () {
              _expressionController.text = name;
              _expressionFocusNode.requestFocus();
            },
          )),
          Divider(height: 0.5, color: scheme.outlineVariant),
        ],
        _SectionLabel('Evaluate expression'),
        _EvalInputRow(
          controller: _expressionController,
          focusNode: _expressionFocusNode,
          onSubmit: () => _eval(runner),
        ),
        if (_history.isNotEmpty) ...[
          Divider(height: 0.5, color: scheme.outlineVariant),
          _SectionLabel('History'),
          ..._history.map((e) => _HistoryRow(entry: e)),
        ],
      ],
    );
  }
}

class _NoSessionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: AppConstants.spaceSm),
          const Text(
            'Run your code first.\n'
                'The inspector becomes available after a successful run (exit code 0).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Text(
            'Note: only top-level variables are accessible — '
                'local variables inside functions are not inspectable after '
                'the run finishes.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppConstants.spaceMd, AppConstants.spaceSm, AppConstants.spaceMd, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _VariableRow extends StatefulWidget {
  final String name;
  final dynamic evalService;
  final VoidCallback onTap;

  const _VariableRow({
    required this.name,
    required this.evalService,
    required this.onTap,
  });

  @override
  State<_VariableRow> createState() => _VariableRowState();
}

class _VariableRowState extends State<_VariableRow> {
  String? _value;

  void _load() {
    final result = widget.evalService.eval(widget.name) as String;
    setState(() => _value = result);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.code_rounded, size: 16),
      title: Text(
        widget.name,
        style: const TextStyle(fontFamily: editorFontFamily, fontSize: 13),
      ),
      subtitle: _value == null
          ? null
          : Text(
        _value!,
        style: TextStyle(
          fontFamily: editorFontFamily,
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: widget.onTap,
    );
  }
}

class _EvalInputRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  const _EvalInputRow({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceMd, vertical: 4),
      child: Row(
        children: [
          Text('> ', style: TextStyle(
              fontFamily: editorFontFamily,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold)),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(fontFamily: editorFontFamily, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'expression or variable name',
                border: InputBorder.none,
                isDense: true,
                isCollapsed: true,
              ),
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          TextButton(onPressed: onSubmit, child: const Text('Eval')),
        ],
      ),
    );
  }
}

class _EvalEntry {
  final String expression;
  final String result;
  const _EvalEntry({required this.expression, required this.result});
}

class _HistoryRow extends StatelessWidget {
  final _EvalEntry entry;
  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isError = entry.result.startsWith('Error:');
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceMd, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '> ${entry.expression}',
            style: TextStyle(
              fontFamily: editorFontFamily,
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            entry.result,
            style: TextStyle(
              fontFamily: editorFontFamily,
              fontSize: 12.5,
              color: isError
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}