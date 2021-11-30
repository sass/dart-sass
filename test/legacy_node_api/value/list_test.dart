// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('node')
@Tags(['node'])

import 'dart:js_util';

import 'package:js/js.dart';
import 'package:test/test.dart';

import '../api.dart';
import '../utils.dart';
import 'utils.dart';

void main() {
  group("an argument list", () {
    late NodeSassList args;
    setUp(() {
      renderSync(RenderOptions(
          data: "a {b: foo(1, 'a', blue)}",
          functions: jsify({
            r"foo($args...)": allowInterop(expectAsync1((NodeSassList args_) {
              args = args_;
              return sass.types.Null.NULL;
            }))
          })));
    });

    test("is instanceof List", () {
      expect(args, isJSInstanceOf(sass.types.List));
    });

    test("provides access to the list attributes", () {
      expect(args.getLength(), equals(3));
      expect(args.getSeparator(), isTrue);
      expect(args.getValue(0), isJSInstanceOf(sass.types.Number));
      expect(args.getValue(1), isJSInstanceOf(sass.types.String));
      expect(args.getValue(2), isJSInstanceOf(sass.types.Color));
    });

    test("has a useful .constructor.name", () {
      expect(args.constructor.name, equals("sass.types.List"));
    });
  });

  group("a list", () {
    group("from a parameter", () {
      late NodeSassList list;
      setUp(() {
        list = parseValue<NodeSassList>("1, 'a', blue");
      });

      test("is instanceof List", () {
        expect(list, isJSInstanceOf(sass.types.List));
      });

      test("provides access to its length", () {
        expect(list.getLength(), equals(3));
      });

      test("provides access to its contents", () {
        expect(list.getValue(0), isJSInstanceOf(sass.types.Number));
        expect(list.getValue(1), isJSInstanceOf(sass.types.String));
        expect(list.getValue(2), isJSInstanceOf(sass.types.Color));
      });

      test("provides access to the separator type", () {
        expect(list.getSeparator(), isTrue);
        expect(parseValue<NodeSassList>("1 2 3").getSeparator(), isFalse);
      });

      test("throws on invalid indices", () {
        expect(() => list.getValue(-1), throwsA(anything));
        expect(() => list.getValue(4), throwsA(anything));
      });

      test("values can be set without affecting the underlying list", () {
        expect(
            renderSync(RenderOptions(
                data: r"a {$list: 1 2 3; b: foo($list); c: $list}",
                functions: jsify({
                  r"foo($list)": allowInterop(expectAsync1((NodeSassList list) {
                    list.setValue(1, sass.types.Null.NULL);
                    expect(list.getValue(1), equals(sass.types.Null.NULL));
                    return list;
                  }))
                }))),
            equalsIgnoringWhitespace("a { b: 1 3; c: 1 2 3; }"));
      });

      test("the separator can be set without affecting the underlying list",
          () {
        expect(
            renderSync(RenderOptions(
                data: r"a {$list: 1 2 3; b: foo($list); c: $list}",
                functions: jsify({
                  r"foo($list)": allowInterop(expectAsync1((NodeSassList list) {
                    list.setSeparator(true);
                    expect(list.getSeparator(), isTrue);
                    return list;
                  }))
                }))),
            equalsIgnoringWhitespace("a { b: 1, 2, 3; c: 1 2 3; }"));
      });

      test(
          "lists with undefined separators are reported as having space "
          "separators", () {
        expect(parseValue<NodeSassList>("()").getSeparator(), isFalse);
        expect(
            parseValue<NodeSassList>("join((), 1px)").getSeparator(), isFalse);
      });

      test("has a useful .constructor.name", () {
        expect(list.constructor.name, equals("sass.types.List"));
      });
    });

    group("from a constructor", () {
      test("is a list with the given length", () {
        var list = callConstructor(sass.types.List, [3]);
        expect(list, isJSInstanceOf(sass.types.List));
        expect(list.getLength(), equals(3));
      });

      test("is populated with nulls", () {
        var list = callConstructor(sass.types.List, [3]);
        expect(list.getValue(0), equals(sass.types.Null.NULL));
        expect(list.getValue(1), equals(sass.types.Null.NULL));
        expect(list.getValue(2), equals(sass.types.Null.NULL));
      });

      test("can have its values set", () {
        var list = callConstructor(sass.types.List, [3]);
        list.setValue(1, sass.types.Boolean.TRUE);
        expect(list.getValue(1), equals(sass.types.Boolean.TRUE));
      });

      test("defaults to comma-separated", () {
        var list = callConstructor(sass.types.List, [3]);
        expect(list.getSeparator(), isTrue);
      });

      test("can be space-separated", () {
        var list = callConstructor(sass.types.List, [3, false]);
        expect(list.getSeparator(), isFalse);
      });

      test("has a useful .constructor.name", () {
        expect(callConstructor(sass.types.List, [3]).constructor.name,
            equals("sass.types.List"));
      });
    });
  });
}
