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
  group("from a parameter", () {
    late NodeSassString string;
    setUp(() {
      string = parseValue<NodeSassString>("abc");
    });

    test("is instanceof String", () {
      expect(string, isJSInstanceOf(sass.types.String));
    });

    test("provides access to its value", () {
      expect(string.getValue(), equals("abc"));
      expect(parseValue<NodeSassString>('"abc"').getValue(), equals("abc"));
    });

    test("the value can be set without affecting the underlying string", () {
      expect(
          renderSync(RenderOptions(
              data: r"a {$string: foo; b: foo($string); c: $string}",
              functions: jsify({
                r"foo($string)":
                    allowInterop(expectAsync1((NodeSassString string) {
                  string.setValue("bar");
                  expect(string.getValue(), equals("bar"));
                  return string;
                }))
              }))),
          equalsIgnoringWhitespace("a { b: bar; c: foo; }"));
    });

    test("a quoted string becomes unquoted when its value is set", () {
      expect(
          renderSync(RenderOptions(
              data: r"a {b: foo('foo')}",
              functions: jsify({
                r"foo($string)":
                    allowInterop(expectAsync1((NodeSassString string) {
                  string.setValue("bar");
                  expect(string.getValue(), equals("bar"));
                  return string;
                }))
              }))),
          equalsIgnoringWhitespace('a { b: bar; }'));
    });

    test("has a useful .constructor.name", () {
      expect(string.constructor.name, equals("sass.types.String"));
    });
  });

  group("from a constructor", () {
    test("is a string with the given value", () {
      var string = callConstructor(sass.types.String, ["foo"]);
      expect(string, isJSInstanceOf(sass.types.String));
      expect(string.getValue(), equals("foo"));
    });

    test("is unquoted", () {
      expect(
          renderSync(RenderOptions(
              data: r"a {b: foo()}",
              functions: jsify({
                "foo()": allowInterop(expectAsync0(() {
                  var string = callConstructor(sass.types.String, ["foo"]);
                  return string;
                }))
              }))),
          equalsIgnoringWhitespace("a { b: foo; }"));
    });

    test("has a useful .constructor.name", () {
      expect(callConstructor(sass.types.String, ["foo"]).constructor.name,
          equals("sass.types.String"));
    });
  });
}
