import 'package:dartlab/utils/dart_syntax/comment_scan.dart';
import 'package:dartlab/utils/dart_syntax/identifier_scan.dart';
import 'package:dartlab/utils/dart_syntax/interpolation_scan.dart';
import 'package:dartlab/utils/dart_syntax/number_scan.dart';
import 'package:dartlab/utils/dart_syntax/string_basics.dart';
import 'package:dartlab/utils/dart_syntax_highlighter.dart';
import 'package:flutter_test/flutter_test.dart';

/// "type:text" for every token, to read a result at a glance.
List<String> tokens(String source) => [
      for (final t in tokenizeDart(source))
        '${t.type.name}:${source.substring(t.start, t.end)}',
    ];

void main() {
  group('tokenizeDart', () {
    test('an empty text has no tokens', () {
      expect(tokenizeDart(''), isEmpty);
    });

    test('a declaration', () {
      expect(tokens('int x = 5;'), [
        'type:int',
        'variable:x',
        'operatorSymbol:=',
        'number:5',
        'punctuation:;',
      ]);
    });

    test('keywords, and a name followed by a bracket is a function', () {
      expect(tokens('if (a) return;'), [
        'keyword:if',
        'punctuation:(',
        'variable:a',
        'punctuation:)',
        'keyword:return',
        'punctuation:;',
      ]);
      expect(tokens('print(x)'), [
        'function:print',
        'punctuation:(',
        'variable:x',
        'punctuation:)',
      ]);
    });

    test('a capitalised name is a type', () {
      expect(tokens('Foo bar'), ['type:Foo', 'variable:bar']);
    });

    test('an annotation', () {
      expect(tokens('@override'), ['annotation:@override']);
    });

    test('numbers: decimals, a leading dot, exponents', () {
      expect(tokens('3.14 .5 1e10 2E-3 7'), [
        'number:3.14',
        'number:.5',
        'number:1e10',
        'number:2E-3',
        'number:7',
      ]);
    });

    test('comments', () {
      expect(tokens('// hi\nx'), ['comment:// hi', 'variable:x']);
      expect(tokens('/* a\nb */ x'), ['comment:/* a\nb */', 'variable:x']);
      expect(tokens('/* never closed'), ['comment:/* never closed']);
    });

    test('operators: the longest one wins', () {
      expect(tokens('a ??= b;'), [
        'variable:a',
        'operatorSymbol:??=',
        'variable:b',
        'punctuation:;',
      ]);
      expect(tokens('x?.y'), ['variable:x', 'operatorSymbol:?.', 'variable:y']);
      expect(tokens('[...a]'), [
        'punctuation:[',
        'operatorSymbol:...',
        'variable:a',
        'punctuation:]',
      ]);
      expect(tokens('a => b'), ['variable:a', 'operatorSymbol:=>', 'variable:b']);
    });

    test('plain and escaped strings', () {
      expect(tokens("'hi'"), ["string:'hi'"]);
      expect(tokens(r'"a\"b"'), [r'string:"a\"b"']);
    });

    test('a raw string has no interpolation', () {
      expect(tokens(r"r'a$b'"), [r"string:r'a$b'"]);
    });

    test('a simple interpolation', () {
      expect(tokens(r"'a $b c'"), [
        "string:'a ",
        r'variable:$b',
        "string: c'",
      ]);
    });

    test('a braced interpolation is tokenized as code', () {
      expect(tokens(r"'${x + 1}'"), [
        "string:'",
        r'string:${',
        'variable:x',
        'operatorSymbol:+',
        'number:1',
        'punctuation:}',
        "string:'",
      ]);
    });

    test('quotes inside an interpolation do not end the string', () {
      final source = r"'${a['k']}'";

      expect(tokens(source).first, "string:'");
      expect(tokens(source).last, "string:'");
      expect(tokens(source), contains("string:'k'"));
    });

    test('a dollar that starts nothing stays inside the string', () {
      expect(tokens(r"'$'"), [r"string:'$'"]);
    });

    test('a string that never closes colours the rest', () {
      expect(tokens("'abc"), ["string:'abc"]);
    });

    test('unknown characters are left uncoloured', () {
      expect(tokens('a # b'), ['variable:a', 'variable:b']);
    });
  });

  group('number scanning', () {
    test('a number starts with a digit, or with a dot and a digit', () {
      expect(isNumberStart('5', 0, 1), isTrue);
      expect(isNumberStart('.5', 0, 2), isTrue);
      expect(isNumberStart('.a', 0, 2), isFalse);
      expect(isNumberStart('a', 0, 1), isFalse);
    });

    test('where a number ends', () {
      expect(readNumberEnd('12.5x', 0, 5), 4);
      expect(readNumberEnd('1e', 0, 2), 1); // no digits after the e
      expect(readNumberEnd('1.', 0, 2), 1); // the dot is not part of it
      expect(readNumberEnd('1e+5', 0, 4), 4);
    });
  });

  group('comment scanning', () {
    test('the end of a line comment is the line break', () {
      expect(findLineEnd('ab\ncd', 0, 5), 2);
      expect(findLineEnd('ab', 0, 2), 2);
    });

    test('the end of a block comment is after the closing mark', () {
      expect(findBlockCommentEnd('/* x */y', 0, 8), 7);
      expect(findBlockCommentEnd('/* x', 0, 4), 4);
    });
  });

  group('identifier scanning', () {
    test('classifies words', () {
      expect(classifyIdentifier('foo', 'foo(', 3, 4), TokenType.function);
      expect(classifyIdentifier('foo', 'foo (', 3, 5), TokenType.function);
      expect(classifyIdentifier('foo', 'foo', 3, 3), TokenType.variable);
      expect(classifyIdentifier('Foo', 'Foo', 3, 3), TokenType.type);
      expect(classifyIdentifier('int', 'int', 3, 3), TokenType.type);
      expect(classifyIdentifier('if', 'if', 2, 2), TokenType.keyword);
    });
  });

  group('string helpers', () {
    test('where a string starts', () {
      expect(isStringStart("'a'", 0, 3), isTrue);
      expect(isStringStart('"a"', 0, 3), isTrue);
      expect(isStringStart("r'a'", 0, 4), isTrue);
      expect(isStringStart('rx', 0, 2), isFalse);
    });

    test('skipString jumps over the whole string', () {
      expect(skipString(r"'a\'b' rest", 0, 11), 6);
      expect(skipString(r"r'a\' rest", 0, 10), 5); // raw: the backslash is plain
      expect(skipString("'never", 0, 6), 6);
    });

    test('the } that closes a braced interpolation', () {
      expect(findInterpolationClosingBrace(r'${a{b}c}d', 2, 9), 7);
      expect(findInterpolationClosingBrace(r"${f('}')}", 2, 9), 8);
      expect(findInterpolationClosingBrace(r'${open', 2, 6), -1);
    });
  });
}
