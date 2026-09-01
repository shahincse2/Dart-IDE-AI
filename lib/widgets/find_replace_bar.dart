import 'package:flutter/material.dart';

import '../utils/constants.dart';
import 'code_editor_controller.dart';

/// Find & Replace (Section 7's advanced-editor requirement), shown as
/// a bar above the editor rather than a dialog — keeps the code
/// visible while searching, which matters more on a small screen than
/// on desktop.
class FindReplaceBar extends StatefulWidget {
  final CodeEditorController controller;
  final VoidCallback onClose;

  const FindReplaceBar({super.key, required this.controller, required this.onClose});

  @override
  State<FindReplaceBar> createState() => _FindReplaceBarState();
}

class _FindReplaceBarState extends State<FindReplaceBar> {
  final _searchController = TextEditingController();
  final _replaceController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _showReplace = false;

  List<int> _matchStarts = [];
  int _currentMatch = -1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_updateMatches);
    // `autofocus` only takes effect when nothing else in the scope
    // already has focus — the editor's TextField does, since the user
    // was just typing in it when they tapped the search icon. Explicitly
    // requesting focus after the frame renders actually moves it here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    // Clear highlights on the controller so they don't linger after
    // the bar closes.
    widget.controller.setSearchHighlights(const []);
    _searchController.dispose();
    _replaceController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _updateMatches() {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _matchStarts = [];
        _currentMatch = -1;
      });
      widget.controller.setSearchHighlights(const []);
      return;
    }

    final text = widget.controller.text;
    final starts = <int>[];
    var index = 0;
    while (true) {
      final found = text.indexOf(query, index);
      if (found == -1) break;
      starts.add(found);
      index = found + query.length;
    }

    setState(() {
      _matchStarts = starts;
      _currentMatch = starts.isEmpty ? -1 : 0;
    });
    widget.controller.setSearchHighlights(starts, query.length);
    if (starts.isNotEmpty) _goToMatch(0);
  }

  void _goToMatch(int index) {
    if (_matchStarts.isEmpty) return;
    final wrapped = index % _matchStarts.length;
    setState(() => _currentMatch = wrapped);
    widget.controller.setActiveSearchMatch(wrapped);

    final start = _matchStarts[wrapped];
    final length = _searchController.text.length;
    widget.controller.selection = TextSelection(baseOffset: start, extentOffset: start + length);
  }

  void _next() => _goToMatch(_currentMatch + 1);
  void _prev() => _goToMatch(_currentMatch - 1 + _matchStarts.length);

  void _replaceCurrent() {
    if (_currentMatch == -1) return;
    final start = _matchStarts[_currentMatch];
    final query = _searchController.text;
    final replacement = _replaceController.text;
    final text = widget.controller.text;

    final newText = text.replaceRange(start, start + query.length, replacement);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    _updateMatches();
  }

  void _replaceAll() {
    final query = _searchController.text;
    if (query.isEmpty) return;
    final newText = widget.controller.text.replaceAll(query, _replaceController.text);
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _updateMatches();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.controller.scheme;
    final hasMatches = _matchStarts.isNotEmpty;

    return Container(
      color: scheme.gutterBackground,
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceSm, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: TextStyle(fontSize: 13, color: scheme.text),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Find',
                    hintStyle: TextStyle(color: scheme.gutterText),
                  ),
                ),
              ),
              Text(
                _searchController.text.isEmpty
                    ? ''
                    : (hasMatches ? '${_currentMatch + 1}/${_matchStarts.length}' : '0/0'),
                style: TextStyle(fontSize: 12, color: scheme.gutterText),
              ),
              IconButton(
                tooltip: 'Previous match',
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                onPressed: hasMatches ? _prev : null,
              ),
              IconButton(
                tooltip: 'Next match',
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                onPressed: hasMatches ? _next : null,
              ),
              IconButton(
                tooltip: _showReplace ? 'Hide replace' : 'Show replace',
                icon: Icon(
                  _showReplace ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 20,
                ),
                onPressed: () => setState(() => _showReplace = !_showReplace),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: widget.onClose,
              ),
            ],
          ),
          if (_showReplace)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replaceController,
                    style: TextStyle(fontSize: 13, color: scheme.text),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Replace',
                      hintStyle: TextStyle(color: scheme.gutterText),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: hasMatches ? _replaceCurrent : null,
                  child: const Text('Replace'),
                ),
                TextButton(
                  onPressed: hasMatches ? _replaceAll : null,
                  child: const Text('All'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
