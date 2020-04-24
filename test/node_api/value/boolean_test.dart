// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('node')
@Tags(['node'])

import 'dart:js_util';

import 'package:test/test.dart';

import '../api.dart';
import 'utils.dart';

void main() {
  group("from a parameter", () {
    test("true is true", () {
      var value = parseValue<NodeSassBoolean>("true");
      expect(value, isJSInstanceOf(sass.types.Boolean));
      expect(value.getValue(), isTrue);
    });

    test("false is false", () {
      var value = parseValue<NodeSassBoolean>("false");
      expect(value, isJSInstanceOf(sass.types.Boolean));
      expect(value.getValue(), isFalse);
    });

    test("has a useful .constructor.name", () {
      expect(parseValue<NodeSassBoolean>("true").constructor.name,
          equals("SassBoolean"));
    });
  });

  group("from a constant", () {
    test("true is true", () {
      var value = sass.types.Boolean.TRUE;
      expect(value, isJSInstanceOf(sass.types.Boolean));
      expect(value.getValue(), isTrue);
    });

    test("false is false", () {
      var value = sass.types.Boolean.FALSE;
      expect(value, isJSInstanceOf(sass.types.Boolean));
      expect(value.getValue(), isFalse);
    });

    test("has a useful .constructor.name", () {
      expect(sass.types.Boolean.FALSE.constructor.name, equals("SassBoolean"));
    });
  });

  test("the constructor throws", () {
    expect(
        () => callConstructor(sass.types.Boolean, [true]), throwsA(anything));
  });

  group("the convenience accessor", () {
    test("sass.TRUE exists", () {
      expect(sass.TRUE, equals(sass.types.Boolean.TRUE));
    });

    test("sass.FALSE exists", () {
      expect(sass.FALSE, equals(sass.types.Boolean.FALSE));
    });
  });
}
