// Copyright 2026 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

import 'package:sass/src/util/span.dart';

/// Returns a span that covers the given [text].
FileSpan span(String text) => SourceFile.fromString(text).span(0);

void main() {
  group("trimLeft", () {
    test(
      "doesn't trim non-whitespace",
      () => expect(span("foo").trimLeft().text, equals("foo")),
    );

    test(
      "doesn't trim right-hand whitespace",
      () => expect(span("foo ").trimLeft().text, equals("foo ")),
    );

    test(
      "trims whitespace",
      () => expect(span(" \t\n\r\ffoo").trimLeft().text, equals("foo")),
    );

    test("trims the entire span", () {
      var result = span("   ").trimLeft();
      expect(result.text, isEmpty);
      expect(result.end.offset, equals(3));
    });

    test(
      "trims silent comments",
      () => expect(
        span(
          "// foo\n"
          "bar",
        ).trimLeft().text,
        equals("bar"),
      ),
    );

    test(
      "trims loud comments",
      () => expect(span("/* foo */bar").trimLeft().text, equals("bar")),
    );

    test(
      "ignores a commented-out silent comment",
      () => expect(span("/* // */bar").trimLeft().text, equals("bar")),
    );

    test(
      "ignores a commented-out loud comment opener",
      () => expect(
        span(
          '// /*\n'
          '"*/"',
        ).trimLeft().text,
        equals('"*/"'),
      ),
    );

    test(
      "respects a loud comment closer that looks like it's in a string",
      () => expect(span('/* "*/" bar"').trimLeft().text, equals('" bar"')),
    );

    test(
      "ignores a silent comment opener that's in a string",
      () => expect(span('"//"').trimLeft().text, equals('"//"')),
    );
  });

  group("trimRight", () {
    test(
      "doesn't trim non-whitespace",
      () => expect(span("foo").trimRight().text, equals("foo")),
    );

    test(
      "doesn't trim left-hand whitespace",
      () => expect(span(" foo").trimRight().text, equals(" foo")),
    );

    test(
      "trims whitespace",
      () => expect(span("foo \t\n\r\f").trimRight().text, equals("foo")),
    );

    test("trims the entire span", () {
      var result = span("   ").trimRight();
      expect(result.text, isEmpty);
      expect(result.start.offset, equals(0));
    });

    test(
      "trims silent comments",
      () => expect(
        span(
          "foo\n"
          "// bar",
        ).trimRight().text,
        equals("foo"),
      ),
    );

    test(
      "trims loud comments",
      () => expect(span("foo/* bar */").trimRight().text, equals("foo")),
    );

    group("ignores a commented-out loud comment closer", () {
      test(
        "with a string opener",
        () => expect(span('"/*"// */').trimRight().text, equals('"/*"')),
      );

      test(
        "with a commented-out opener",
        () => expect(
          span(
            '// /*\n'
            'foo\n'
            '// */ bar',
          ).trimRight().text,
          equals(
            '// /*\n'
            'foo',
          ),
        ),
      );
    });

    group("ignores a silent comment opener that's commented out", () {
      test(
        "on the same line",
        () => expect(
          span('/* // */ foo').trimRight().text,
          equals("/* // */ foo"),
        ),
      );

      test(
        "on an earlier line",
        () => expect(
          span(
            '/*\n'
            'foo\n'
            '// */ bar',
          ).trimRight().text,
          equals(
            '/*\n'
            'foo\n'
            '// */ bar',
          ),
        ),
      );
    });

    test(
      "respects a loud comment opener that looks like it's in a string",
      () => expect(span('"foo"/*" */').trimRight().text, equals('"foo"')),
    );

    test(
      "ignores a silent comment opener that's in a string",
      () => expect(span('"//" foo').trimRight().text, equals('"//" foo')),
    );
  });
}
