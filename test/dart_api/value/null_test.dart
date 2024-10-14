// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
library;

import 'package:test/test.dart';

import 'package:sass/sass.dart';

import 'utils.dart';

void main() {
  late Value value;
  setUp(() => value = parseValue("null"));

  test("is falsy", () {
    expect(value.isTruthy, isFalse);
  });

  test("is sassNull", () {
    expect(value, equalsWithHash(sassNull));
  });

  test("isn't any type", () {
    expect(value.assertBoolean, throwsSassScriptException);
    expect(value.assertCalculation, throwsSassScriptException);
    expect(value.assertColor, throwsSassScriptException);
    expect(value.assertFunction, throwsSassScriptException);
    expect(value.assertMap, throwsSassScriptException);
    expect(value.tryMap(), isNull);
    expect(value.assertNumber, throwsSassScriptException);
    expect(value.assertString, throwsSassScriptException);
  });
}
