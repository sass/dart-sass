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
  });

  test("the constructor throws", () {
    expect(
        () => callConstructor(sass.types.Boolean, [true]), throwsA(anything));
  });
}
