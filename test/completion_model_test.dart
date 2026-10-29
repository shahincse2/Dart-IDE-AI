import 'package:dartlab/utils/themes.dart';
import 'package:dartlab/widgets/code_editor_controller.dart';
import 'package:dartlab/widgets/completion_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

CodeEditorController editorWith(String text, {int? cursor}) {
  final controller = CodeEditorController(scheme: EditorColorScheme.dark);
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length),
  );
  return controller;
}

KeyEvent tab(
        KeyEvent Function({
          required PhysicalKeyboardKey physicalKey,
          required LogicalKeyboardKey logicalKey,
          required Duration timeStamp,
        }) make) =>
    make(
      physicalKey: PhysicalKeyboardKey.tab,
      logicalKey: LogicalKeyboardKey.tab,
      timeStamp: Duration.zero,
    );

KeyEvent tabDown() =>
    tab(({required physicalKey, required logicalKey, required timeStamp}) =>
        KeyDownEvent(
            physicalKey: physicalKey,
            logicalKey: logicalKey,
            timeStamp: timeStamp));
KeyEvent tabUp() =>
    tab(({required physicalKey, required logicalKey, required timeStamp}) =>
        KeyUpEvent(
            physicalKey: physicalKey,
            logicalKey: logicalKey,
            timeStamp: timeStamp));
KeyEvent tabRepeat() =>
    tab(({required physicalKey, required logicalKey, required timeStamp}) =>
        KeyRepeatEvent(
            physicalKey: physicalKey,
            logicalKey: logicalKey,
            timeStamp: timeStamp));

KeyEvent keyDown(LogicalKeyboardKey logical, PhysicalKeyboardKey physical) =>
    KeyDownEvent(
        physicalKey: physical, logicalKey: logical, timeStamp: Duration.zero);
KeyEvent down() =>
    keyDown(LogicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowDown);
KeyEvent up() =>
    keyDown(LogicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowUp);
KeyEvent escape() =>
    keyDown(LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('suggestions', () {
    test('follow the word at the cursor', () {
      final model = CompletionModel(editorWith('pri'));

      expect(model.suggestions.map((e) => e.label), contains('print'));
      expect(model.hasSuggestions, isTrue);
    });

    test('are empty when the cursor is not in a word', () {
      final model = CompletionModel(editorWith('print(x); '));

      expect(model.hasSuggestions, isFalse);
    });

    test('update as the text changes, and tell the listeners', () {
      final controller = editorWith('x');
      final model = CompletionModel(controller);
      var heard = 0;
      model.addListener(() => heard++);

      controller.value = const TextEditingValue(
        text: 'pri',
        selection: TextSelection.collapsed(offset: 3),
      );

      expect(model.suggestions.map((e) => e.label), contains('print'));
      expect(heard, greaterThan(0));
    });

    test('are empty while a range of text is selected', () {
      final controller = editorWith('pri');
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 3);

      expect(CompletionModel(controller).hasSuggestions, isFalse);
    });
  });

  group('accepting a suggestion', () {
    test('print: the cursor lands between the quotes', () {
      final controller = editorWith('pri');
      final model = CompletionModel(controller);

      model.accept(model.suggestions.firstWhere((e) => e.label == 'print'));

      expect(controller.text, "print('');");
      expect(controller.selection.baseOffset, 7);
    });

    test('a block snippet is lined up with its line, cursor in the condition',
        () {
      final controller = editorWith('  i');
      final model = CompletionModel(controller);

      model.accept(model.suggestions.first); // if

      expect(controller.text, '  if () {\n    \n  }');
      expect(controller.selection.baseOffset, 6);
    });

    test('indentation follows the setting', () {
      final controller = editorWith('i');
      final model = CompletionModel(controller)..indentSize = 4;

      model.accept(model.suggestions.first); // if

      expect(controller.text, 'if () {\n    \n}');
    });

    test('only the word being typed is replaced', () {
      final controller = editorWith('var a = 1;\npri', cursor: 14);
      final model = CompletionModel(controller);

      model.accept(model.suggestions.firstWhere((e) => e.label == 'print'));

      expect(controller.text, "var a = 1;\nprint('');");
    });

    test('a plain word leaves the cursor after it', () {
      final controller = editorWith('vo');
      final model = CompletionModel(controller);

      model.accept(model.suggestions.firstWhere((e) => e.label == 'void'));

      expect(controller.text, 'void ');
      expect(controller.selection.baseOffset, 5);
    });
  });

  group('the Tab key', () {
    test('accepts the first suggestion', () {
      final controller = editorWith('pri');
      final model = CompletionModel(controller);

      final result = model.handleKey(tabDown());

      expect(result, KeyEventResult.handled);
      expect(controller.text, "print('');");
      expect(controller.selection.baseOffset, 7);
    });

    test('then moves through the stops of a snippet, one per press', () {
      final controller = editorWith('  i');
      final model = CompletionModel(controller);
      model.handleKey(tabDown()); // accept "if"
      model.handleKey(tabUp());
      expect(controller.selection.baseOffset, 6); // in the condition

      final second = model.handleKey(tabDown());

      expect(second, KeyEventResult.handled);
      expect(controller.selection.baseOffset, 14); // in the block
      model.handleKey(tabUp());
      expect(model.handleKey(tabDown()), KeyEventResult.ignored); // none left
    });

    test('the stops move along while the condition is typed', () {
      final controller = editorWith('  i');
      final model = CompletionModel(controller);
      model.handleKey(tabDown()); // accept "if", cursor at 6
      model.handleKey(tabUp());

      controller.value = const TextEditingValue(
        text: '  if (ok) {\n    \n  }',
        selection: TextSelection.collapsed(offset: 8),
      );
      model.handleKey(tabDown());

      expect(controller.selection.baseOffset, 16); // 14 + the 2 typed letters
    });

    test('does nothing special without suggestions or a snippet', () {
      final model = CompletionModel(editorWith('print(x); '));

      expect(model.handleKey(tabDown()), KeyEventResult.ignored);
    });

    test('does not jump once the cursor has left the snippet', () {
      final controller = editorWith('x\n  i');
      final model = CompletionModel(controller);
      model.handleKey(tabDown()); // accept "if"
      model.handleKey(tabUp());

      controller.selection = const TextSelection.collapsed(offset: 0);

      expect(model.handleKey(tabDown()), KeyEventResult.ignored);
    });

    test('a held key does not accept twice', () {
      final controller = editorWith('pri');
      final model = CompletionModel(controller);
      model.handleKey(tabDown());
      final textAfterFirst = controller.text;

      final repeat = model.handleKey(tabRepeat());

      expect(repeat, KeyEventResult.handled);
      expect(controller.text, textAfterFirst);
    });

    test('other keys are left alone', () {
      final model = CompletionModel(editorWith('pri'));

      final result = model.handleKey(const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyA,
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      ));

      expect(result, KeyEventResult.ignored);
    });
  });

  group('choosing among the suggestions', () {
    test('starts at the first', () {
      final model = CompletionModel(editorWith('i'));

      expect(model.selectedIndex, 0);
      expect(model.suggestions.length, greaterThan(2));
    });

    test('Down chooses the next one, and Tab inserts that one', () {
      final controller = editorWith('i');
      final model = CompletionModel(controller);
      final second = model.suggestions[1];

      expect(model.handleKey(down()), KeyEventResult.handled);
      expect(model.selectedIndex, 1);
      model.handleKey(tabDown());

      expect(controller.text, second.insertText.replaceAll('§', ''));
    });

    test('Down after the last goes back to the first', () {
      final model = CompletionModel(editorWith('i'));

      for (var i = 0; i < model.suggestions.length; i++) {
        model.handleKey(down());
      }

      expect(model.selectedIndex, 0);
    });

    test('Up from the first goes to the last', () {
      final model = CompletionModel(editorWith('i'));

      model.handleKey(up());

      expect(model.selectedIndex, model.suggestions.length - 1);
    });

    test('a new set of suggestions starts at the first again', () {
      final controller = editorWith('i');
      final model = CompletionModel(controller);
      model.handleKey(down());

      controller.value = const TextEditingValue(
        text: 'im',
        selection: TextSelection.collapsed(offset: 2),
      );

      expect(model.selectedIndex, 0);
    });

    test('the arrow keys are left alone when nothing is suggested', () {
      final model = CompletionModel(editorWith('print(x); '));

      expect(model.handleKey(down()), KeyEventResult.ignored);
      expect(model.handleKey(up()), KeyEventResult.ignored);
    });
  });

  group('Esc', () {
    test('hides the suggestions until the next edit', () {
      final controller = editorWith('pri');
      final model = CompletionModel(controller);

      expect(model.handleKey(escape()), KeyEventResult.handled);
      expect(model.hasSuggestions, isFalse);

      controller.value = const TextEditingValue(
        text: 'prin',
        selection: TextSelection.collapsed(offset: 4),
      );
      expect(model.hasSuggestions, isTrue);
    });

    test('moving the cursor does not bring them back', () {
      final controller = editorWith('pri');
      final model = CompletionModel(controller);
      model.handleKey(escape());

      controller.selection = const TextSelection.collapsed(offset: 2);
      controller.selection = const TextSelection.collapsed(offset: 3);

      expect(model.hasSuggestions, isFalse);
    });

    test('is left alone when nothing is suggested', () {
      final model = CompletionModel(editorWith('print(x); '));

      expect(model.handleKey(escape()), KeyEventResult.ignored);
    });
  });
}
