import 'package:dartlab/utils/completion_engine.dart';
import 'package:dartlab/utils/snippet_template.dart';
import 'package:flutter_test/flutter_test.dart';

CompletionItem snippetNamed(String label) =>
    CompletionEngine.suggest(label, '').firstWhere((item) => item.label == label);

void main() {
  group('CompletionEngine.suggest', () {
    test('matches snippets by the start of the word', () {
      final labels = CompletionEngine.suggest('pri', '').map((e) => e.label);

      expect(labels, contains('print'));
    });

    test('adds names already used in the source', () {
      final labels = CompletionEngine.suggest(
        'cou',
        'int counter = 0;\nprint(counter);',
      ).map((e) => e.label);

      expect(labels, contains('counter'));
    });

    test('nothing is suggested for an empty word', () {
      expect(CompletionEngine.suggest('', 'int a = 0;'), isEmpty);
    });
  });

  group('where the cursor goes after a suggestion', () {
    int firstStop(String label, {String indent = ''}) =>
        expandSnippet(snippetNamed(label).insertText, baseIndent: indent).stops.first;

    test('print: between the quotes', () {
      final snippet = expandSnippet(snippetNamed('print').insertText);

      expect(snippet.text, "print('');");
      expect(snippet.stops.first, 7);
    });

    test('if, while, switch: inside the brackets of the condition', () {
      expect(expandSnippet(snippetNamed('if').insertText).text.substring(0, 4), 'if (');
      expect(firstStop('if'), 4);
      expect(firstStop('while'), 7);
      expect(firstStop('switch'), 8);
    });

    test('if has a second stop: inside the block', () {
      final snippet = expandSnippet(snippetNamed('if').insertText);

      expect(snippet.stops.length, 2);
      expect(snippet.text.substring(snippet.stops[1] - 2, snippet.stops[1]), '  ');
    });

    test('generic types: between the angle brackets', () {
      expect(expandSnippet(snippetNamed('List').insertText).text, 'List<>');
      expect(firstStop('List'), 5);
      expect(expandSnippet(snippetNamed('Map').insertText).stops, [4, 6]);
    });

    test('import: between the quotes', () {
      expect(firstStop('import'), 8);
    });

    test('class: at the name', () {
      expect(firstStop('class'), 6);
    });

    test('words that need nothing more have no stop (the cursor ends up after them)', () {
      expect(expandSnippet(snippetNamed('void').insertText).stops, isEmpty);
      expect(expandSnippet(snippetNamed('int').insertText).text, 'int ');
    });

    test('plainText shows what is typed, without markers', () {
      expect(snippetNamed('print').plainText, "print('');");
    });
  });

  group('the list of suggestions', () {
    test('no word appears twice', () {
      final labels = <String>[];
      for (final letter in 'abcdefghijklmnopqrstuvwxyz'.split('')) {
        labels.addAll(
          CompletionEngine.suggest(letter, '', maxResults: 100).map((e) => e.label),
        );
      }

      expect(labels.length, labels.toSet().length);
    });

    test('stdout.write inserts the whole call, cursor inside the brackets', () {
      final item = snippetNamed('stdout.write');
      final snippet = expandSnippet(item.insertText);

      expect(snippet.text, 'stdout.write();');
      expect(snippet.stops.first, 13);
    });

    test('for "std" the useful calls come before the bare names', () {
      final labels = CompletionEngine.suggest('std', '').map((e) => e.label).toList();

      expect(labels.first, 'stdout.write');
      expect(labels.indexOf('stdout.writeln'), lessThan(labels.indexOf('stdout')));
    });

    test('words that do not exist in Dart are gone', () {
      final labels = CompletionEngine.suggest('stdout', '').map((e) => e.label);

      expect(labels, isNot(contains('stdout.writeLine')));
      expect(labels, isNot(contains('stdout.writeLineSync')));
      expect(labels, isNot(contains('stdout.writeSync')));
    });
  });
}
