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
    late NodeSassNumber number;
    setUp(() {
      number = parseValue<NodeSassNumber>("1px");
    });

    test("is instanceof Number", () {
      expect(number, isJSInstanceOf(sass.types.Number));
    });

    test("provides access to its value and unit", () {
      expect(number.getValue(), equals(1));
      expect(number.getUnit(), equals("px"));
    });

    test("a unitless number returns the empty string", () {
      expect(parseValue<NodeSassNumber>("1").getUnit(), isEmpty);
    });

    test("a complex unit number returns its full units", () {
      expect(parseValue<NodeSassNumber>("1px*1ms/1rad/1dpi").getUnit(),
          equals("px*ms/rad*dpi"));
    });

    test("a denominator-only unit starts with /", () {
      expect(parseValue<NodeSassNumber>("1/1px").getUnit(), equals("/px"));
    });

    test("the value can be set without affecting the underlying number", () {
      expect(
          renderSync(RenderOptions(
              data: r"a {$number: 1px; b: foo($number); c: $number}",
              functions: jsify({
                r"foo($number)":
                    allowInterop(expectAsync1((NodeSassNumber number) {
                  number.setValue(42);
                  expect(number.getValue(), equals(42));
                  return number;
                }))
              }))),
          equalsIgnoringWhitespace("a { b: 42px; c: 1px; }"));
    });

    test("the unit can be set without affecting the underlying number", () {
      expect(
          renderSync(RenderOptions(
              data: r"a {$number: 1px; b: foo($number); c: $number}",
              functions: jsify({
                r"foo($number)":
                    allowInterop(expectAsync1((NodeSassNumber number) {
                  number.setUnit("em");
                  expect(number.getUnit(), equals("em"));
                  return number;
                }))
              }))),
          equalsIgnoringWhitespace("a { b: 1em; c: 1px; }"));
    });

    test("the unit can be set to a complex unit", () {
      expect(
          renderSync(RenderOptions(
              data: r"a {b: foo(1)*1ms*1dpi/1rad}",
              functions: jsify({
                r"foo($number)":
                    allowInterop(expectAsync1((NodeSassNumber number) {
                  number.setUnit("px*rad/ms*dpi");
                  expect(number.getUnit(), equals("px*rad/ms*dpi"));
                  return number;
                }))
              }))),
          equalsIgnoringWhitespace("a { b: 1px; }"));
    });

    test("the unit can be set to denominator-only", () {
      expect(
          renderSync(RenderOptions(
              data: r"a {b: foo(1)*1em}",
              functions: jsify({
                r"foo($number)":
                    allowInterop(expectAsync1((NodeSassNumber number) {
                  number.setUnit("/em");
                  expect(number.getUnit(), equals("/em"));
                  return number;
                }))
              }))),
          equalsIgnoringWhitespace("a { b: 1; }"));
    });

    test("the unit can be set to a complex unit", () {
      expect(
          renderSync(RenderOptions(
              data: r"a {b: foo(1)*1ms*1dpi/1rad}",
              functions: jsify({
                r"foo($number)":
                    allowInterop(expectAsync1((NodeSassNumber number) {
                  number.setUnit("px*rad/ms*dpi");
                  expect(number.getUnit(), equals("px*rad/ms*dpi"));
                  return number;
                }))
              }))),
          equalsIgnoringWhitespace("a { b: 1px; }"));
    });

    test("the unit can be unset", () {
      expect(
          renderSync(RenderOptions(
              data: r"a {b: unitless(foo(1px))}",
              functions: jsify({
                r"foo($number)":
                    allowInterop(expectAsync1((NodeSassNumber number) {
                  number.setUnit("");
                  expect(number.getUnit(), isEmpty);
                  return number;
                }))
              }))),
          equalsIgnoringWhitespace("a { b: true; }"));
    });

    test("rejects invalid unit formats", () {
      expect(() => number.setUnit("*"), throwsA(anything));
      expect(() => number.setUnit("/"), throwsA(anything));
      expect(() => number.setUnit("px*"), throwsA(anything));
      expect(() => number.setUnit("px/"), throwsA(anything));
      expect(() => number.setUnit("*px"), throwsA(anything));
      expect(() => number.setUnit("px/deg/ms"), throwsA(anything));
    });

    test("has a useful .constructor.name", () {
      expect(number.constructor.name, equals("sass.types.Number"));
    });
  });

  group("from a constructor", () {
    test("is a number with the given value and units", () {
      var number = callConstructor(sass.types.Number, [123, "px"]);
      expect(number, isJSInstanceOf(sass.types.Number));
      expect(number.getValue(), equals(123));
      expect(number.getUnit(), equals("px"));
    });

    test("defaults to no unit", () {
      var number = callConstructor(sass.types.Number, [123]);
      expect(number.getUnit(), isEmpty);
    });

    test("allows complex units", () {
      expect(
          renderSync(RenderOptions(
              data: r"a {b: foo()*1ms*1dpi/1rad}",
              functions: jsify({
                "foo()": allowInterop(expectAsync0(() {
                  var number =
                      callConstructor(sass.types.Number, [1, "px*rad/ms*dpi"]);
                  expect(number.getUnit(), equals("px*rad/ms*dpi"));
                  return number;
                }))
              }))),
          equalsIgnoringWhitespace("a { b: 1px; }"));
    });

    test("has a useful .constructor.name", () {
      expect(callConstructor(sass.types.Number, [123]).constructor.name,
          equals("sass.types.Number"));
    });
  });
}
