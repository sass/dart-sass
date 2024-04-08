// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:test/test.dart';

import 'package:sass/sass.dart';
import 'package:sass/src/logger.dart';

void main() {
  // Deprecated in all version of Dart Sass
  test("callString is violated by passing a string to call", () {
    _expectDeprecation("a { b: call(random)}", Deprecation.callString);
  });

  // Deprecated in 1.3.2
  test("elseIf is violated by using @elseif instead of @else if", () {
    _expectDeprecation("@if false {} @elseif false {}", Deprecation.elseif);
  });

  // Deprecated in 1.7.2
  test("mozDocument is violated by most @-moz-document rules", () {
    _expectDeprecation(
        "@-moz-document url-prefix(foo) {}", Deprecation.mozDocument);
  });

  // Deprecated in 1.17.2
  test("newGlobal is violated by declaring a new variable with !global", () {
    _expectDeprecation(r"a {$foo: bar !global;}", Deprecation.newGlobal);
  });

  // Deprecated in 1.23.0
  group("colorModuleCompat is violated by", () {
    var color = "@use 'sass:color'; a { b: color";

    test("passing a number to color.invert", () {
      _expectDeprecation("$color.invert(0)}", Deprecation.colorModuleCompat);
    });

    test("passing a number to color.grayscale", () {
      _expectDeprecation("$color.grayscale(0)}", Deprecation.colorModuleCompat);
    });

    test("passing a number to color.opacity", () {
      _expectDeprecation("$color.opacity(0)}", Deprecation.colorModuleCompat);
    });

    test("using color.alpha for a microsoft filter", () {
      _expectDeprecation(
          "$color.alpha(foo=bar)}", Deprecation.colorModuleCompat);
    });
  });

  // Deprecated in 1.33.0
  test("slashDiv is violated by using / for division", () {
    _expectDeprecation(r"a {b: (4/2)}", Deprecation.slashDiv);
  });

  // Deprecated in 1.54.0
  group("bogusCombinators is violated by", () {
    test("adjacent combinators", () {
      _expectDeprecation("a > > a {b: c}", Deprecation.bogusCombinators);
    });

    test("leading combinators", () {
      _expectDeprecation("a > {b: c}", Deprecation.bogusCombinators);
    });

    test("trailing combinators", () {
      _expectDeprecation("> a {b: c}", Deprecation.bogusCombinators);
    });
  });

  // Deprecated in 1.55.0
  group("strictUnary is violated by", () {
    test("an ambiguous + operator", () {
      _expectDeprecation(r"a {b: 1 +2}", Deprecation.strictUnary);
    });

    test("an ambiguous - operator", () {
      _expectDeprecation(r"a {$x: 2; b: 1 -$x}", Deprecation.strictUnary);
    });
  });

  // Deprecated in various Sass versions <=1.56.0
  group("functionUnits is violated by", () {
    test("a hue with a non-angle unit", () {
      _expectDeprecation("a {b: hsl(10px, 0%, 0%)}", Deprecation.functionUnits);
    });

    test("a saturation/lightness with a non-percent unit", () {
      _expectDeprecation(
          "a {b: hsl(10deg, 0px, 0%)}", Deprecation.functionUnits);
    });

    test("a saturation/lightness with no unit", () {
      _expectDeprecation("a {b: hsl(10deg, 0%, 0)}", Deprecation.functionUnits);
    });

    test("an alpha value with a percent unit", () {
      _expectDeprecation(
          r"@use 'sass:color'; a {b: color.change(red, $alpha: 1%)}",
          Deprecation.functionUnits);
    });

    test("an alpha value with a non-percent unit", () {
      _expectDeprecation(
          r"@use 'sass:color'; a {b: color.change(red, $alpha: 1px)}",
          Deprecation.functionUnits);
    });

    test("calling math.random with units", () {
      _expectDeprecation("@use 'sass:math'; a {b: math.random(100px)}",
          Deprecation.functionUnits);
    });

    test("calling list.nth with units", () {
      _expectDeprecation("@use 'sass:list'; a {b: list.nth(1 2, 1px)}",
          Deprecation.functionUnits);
    });

    test("calling list.set-nth with units", () {
      _expectDeprecation("@use 'sass:list'; a {b: list.set-nth(1 2, 1px, 3)}",
          Deprecation.functionUnits);
    });
  });

  // Deprecated in 1.75.0
  group(
      "importerWithoutUrl is violated by passing an importer without a base URL to",
      () {
    test("compileString", () {
      var logger = _DeprecationTrackingLogger();
      compileString("", importer: FilesystemImporter('.'), logger: logger);
      expect(logger.deprecations, equals({Deprecation.importerWithoutUrl}));
    });

    test("compileStringAsync", () async {
      var logger = _DeprecationTrackingLogger();
      await compileStringAsync("",
          importer: FilesystemImporter('.'), logger: logger);
      expect(logger.deprecations, equals({Deprecation.importerWithoutUrl}));
    });

    test("compileStringToResult", () {
      var logger = _DeprecationTrackingLogger();
      compileStringToResult("",
          importer: FilesystemImporter('.'), logger: logger);
      expect(logger.deprecations, equals({Deprecation.importerWithoutUrl}));
    });

    test("compileStringToResultAsync", () async {
      var logger = _DeprecationTrackingLogger();
      await compileStringToResultAsync("",
          importer: FilesystemImporter('.'), logger: logger);
      expect(logger.deprecations, equals({Deprecation.importerWithoutUrl}));
    });
  });
}

/// A logger that tracks which deprecations were emitted by a Sass compilation.
class _DeprecationTrackingLogger extends LoggerWithDeprecationType {
  /// The deprecations encountered by this logger during the compilation.
  final deprecations = <Deprecation>{};

  /// The internal logger to which to delegate non-deprecation messages.
  final _inner = Logger.stderr();

  @override
  void internalWarn(String message,
      {FileSpan? span, Trace? trace, Deprecation? deprecation}) {
    if (deprecation != null) {
      deprecations.add(deprecation);
    } else {
      _inner.warn(message, span: span, trace: trace);
    }
  }

  @override
  void debug(String message, SourceSpan span) => _inner.debug(message, span);
}

/// Verifies that [source] emits [deprecation] when compiled.
void _expectDeprecation(String source, Deprecation deprecation) {
  var logger = _DeprecationTrackingLogger();
  compileStringToResult(source, logger: logger);
  expect(logger.deprecations, equals({deprecation}));
}
