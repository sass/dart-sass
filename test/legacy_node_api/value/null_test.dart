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
    late NodeSassNull value;
    setUp(() {
      value = parseValue<NodeSassNull>("null");
    });

    test("is instanceof Null", () {
      expect(value, isJSInstanceOf(sass.types.Null));
    });

    test("equals NULL", () {
      expect(value, equals(sass.types.Null.NULL));
    });
  });

  test("the constructor throws", () {
    expect(() => callConstructor(sass.types.Null, []), throwsA(anything));
  });

  test("the convenience accessor sass.NULL exists", () {
    expect(sass.NULL, equals(sass.types.Null.NULL));
  });
}
