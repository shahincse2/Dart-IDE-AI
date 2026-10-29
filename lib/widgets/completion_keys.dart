import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;

import 'completion_model.dart';

/// The keyboard side of the completions: Tab inserts the chosen suggestion (or
/// moves to the next stop of a snippet), Down and Up choose among the
/// suggestions, Esc hides them. Any other key, and Shift+Tab, is left to the
/// system ("ignored").
class CompletionKeys {
  CompletionKeys(this._model);

  final CompletionModel _model;
  bool _tabHandled = false;

  KeyEventResult handle(KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab) return _tab(event);
    if (!_model.hasSuggestions || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _model.selectNext();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _model.selectPrevious();
    } else if (key == LogicalKeyboardKey.escape && event is KeyDownEvent) {
      _model.dismiss();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _tab(KeyEvent event) {
    if (event is KeyUpEvent) {
      _tabHandled = false;
      return KeyEventResult.ignored;
    }
    // A held key repeats: it must not accept or jump again.
    if (event is KeyRepeatEvent) {
      return _tabHandled ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;

    if (_model.hasSuggestions) {
      _model.accept(_model.suggestions[_model.selectedIndex]);
    } else if (!_model.jumpToNextStop()) {
      return KeyEventResult.ignored;
    }
    _tabHandled = true;
    return KeyEventResult.handled;
  }
}
