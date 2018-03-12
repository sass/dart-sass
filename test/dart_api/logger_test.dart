// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'package:test/test.dart';
import 'package:source_span/source_span.dart';
import 'package:stack_trace/stack_trace.dart';

import 'package:sass/sass.dart';

main() {
  group("with @warn", () {
    test("passes the message and stack trace to the logger", () {
      var mustBeCalled = expectAsync0(() {});
      compileString('''
        @mixin foo {@warn heck}
        @include foo;
      ''', logger:
              new _TestLogger.withWarn((message, {span, trace, deprecation}) {
        expect(message, equals("heck"));
        expect(span, isNull);
        expect(trace.frames.first.member, equals('foo()'));
        expect(deprecation, isFalse);
        mustBeCalled();
      }));
    });

    test("stringifies the argument", () {
      var mustBeCalled = expectAsync0(() {});
      compileString('@warn #abc', logger:
          new _TestLogger.withWarn((message, {span, trace, deprecation}) {
        expect(message, equals("#abc"));
        mustBeCalled();
      }));
    });

    test("doesn't inspect the argument", () {
      var mustBeCalled = expectAsync0(() {});
      compileString('@warn null', logger:
          new _TestLogger.withWarn((message, {span, trace, deprecation}) {
        expect(message, isEmpty);
        mustBeCalled();
      }));
    });
  });

  group("with @debug", () {
    test("passes the message and span to the logger", () {
      compileString('@debug heck',
          logger: new _TestLogger.withDebug(expectAsync2((message, span) {
        expect(message, equals("heck"));
        expect(span.start.line, equals(0));
        expect(span.start.column, equals(0));
        expect(span.end.line, equals(0));
        expect(span.end.column, equals(11));
      })));
    });

    test("stringifies the argument", () {
      compileString('@debug #abc',
          logger: new _TestLogger.withDebug(expectAsync2((message, span) {
        expect(message, equals("#abc"));
      })));
    });

    test("inspects the argument", () {
      compileString('@debug null',
          logger: new _TestLogger.withDebug(expectAsync2((message, span) {
        expect(message, equals("null"));
      })));
    });
  });

  test("with a parser warning passes the message and span", () {
    var mustBeCalled = expectAsync0(() {});
    compileString('a {b: c && d}',
        logger: new _TestLogger.withWarn((message, {span, trace, deprecation}) {
      expect(message, contains('"&&" means two copies'));

      expect(span.start.line, equals(0));
      expect(span.start.column, equals(8));
      expect(span.end.line, equals(0));
      expect(span.end.column, equals(10));

      expect(trace, isNull);
      expect(deprecation, isFalse);
      mustBeCalled();
    }));
  });

  test("with a runner warning passes the message, span, and trace", () {
    var mustBeCalled = expectAsync0(() {});
    compileString('''
        @mixin foo {#{blue} {x: y}}
        @include foo;
      ''',
        logger: new _TestLogger.withWarn((message, {span, trace, deprecation}) {
      expect(message, contains("color value blue"));

      expect(span.start.line, equals(0));
      expect(span.start.column, equals(22));
      expect(span.end.line, equals(0));
      expect(span.end.column, equals(26));

      expect(trace.frames.first.member, equals('foo()'));
      expect(deprecation, isFalse);
      mustBeCalled();
    }));
  });
}

/// A [Logger] whose [warn] and [debug] methods are provided by callbacks.
class _TestLogger implements Logger {
  final void Function(String, {FileSpan span, Trace trace, bool deprecation})
      _warn;
  final void Function(String, SourceSpan) _debug;

  _TestLogger.withWarn(this._warn) : _debug = const Logger.stderr().debug;

  _TestLogger.withDebug(this._debug) : _warn = const Logger.stderr().warn;

  void warn(String message,
          {FileSpan span, Trace trace, bool deprecation: false}) =>
      _warn(message, span: span, trace: trace, deprecation: deprecation);
  void debug(String message, SourceSpan span) => _debug(message, span);
}
