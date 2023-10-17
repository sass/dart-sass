// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'package:test/test.dart';

import 'package:sass/src/embedded/embedded_sass.pb.dart';
import 'package:sass/src/embedded/utils.dart';

import 'embedded_process.dart';
import 'utils.dart';

final _true = Value()..singleton = SingletonValue.TRUE;
final _false = Value()..singleton = SingletonValue.FALSE;
final _null = Value()..singleton = SingletonValue.NULL;

late EmbeddedProcess _process;

void main() {
  setUp(() async {
    _process = await EmbeddedProcess.start();
  });

  group("emits a compile failure for a custom function with a signature", () {
    test("that's empty", () async {
      _process.send(compileString("a {b: c}", functions: [r""]));
      await _expectFunctionError(
          _process, r'Invalid signature "": Expected identifier.');
      await _process.close();
    });

    test("that's just a name", () async {
      _process.send(compileString("a {b: c}", functions: [r"foo"]));
      await _expectFunctionError(
          _process, r'Invalid signature "foo": expected "(".');
      await _process.close();
    });

    test("without a closing paren", () async {
      _process.send(compileString("a {b: c}", functions: [r"foo($bar"]));
      await _expectFunctionError(
          _process, r'Invalid signature "foo($bar": expected ")".');
      await _process.close();
    });

    test("with text after the closing paren", () async {
      _process.send(compileString("a {b: c}", functions: [r"foo() "]));
      await _expectFunctionError(
          _process, r'Invalid signature "foo() ": expected no more input.');
      await _process.close();
    });

    test("with invalid arguments", () async {
      _process.send(compileString("a {b: c}", functions: [r"foo($)"]));
      await _expectFunctionError(
          _process, r'Invalid signature "foo($)": Expected identifier.');
      await _process.close();
    });
  });

  group("includes in FunctionCallRequest", () {
    test("the function name", () async {
      _process.send(compileString("a {b: foo()}", functions: ["foo()"]));
      var request = await getFunctionCallRequest(_process);
      expect(request.name, equals("foo"));
      await _process.kill();
    });

    group("arguments", () {
      test("that are empty", () async {
        _process.send(compileString("a {b: foo()}", functions: ["foo()"]));
        var request = await getFunctionCallRequest(_process);
        expect(request.arguments, isEmpty);
        await _process.kill();
      });

      test("by position", () async {
        _process.send(compileString("a {b: foo(true, null, false)}",
            functions: [r"foo($arg1, $arg2, $arg3)"]));
        var request = await getFunctionCallRequest(_process);
        expect(request.arguments, equals([_true, _null, _false]));
        await _process.kill();
      });

      test("by name", () async {
        _process.send(compileString(
            r"a {b: foo($arg3: true, $arg1: null, $arg2: false)}",
            functions: [r"foo($arg1, $arg2, $arg3)"]));
        var request = await getFunctionCallRequest(_process);
        expect(request.arguments, equals([_null, _false, _true]));
        await _process.kill();
      });

      test("by position and name", () async {
        _process.send(compileString(
            r"a {b: foo(true, $arg3: null, $arg2: false)}",
            functions: [r"foo($arg1, $arg2, $arg3)"]));
        var request = await getFunctionCallRequest(_process);
        expect(request.arguments, equals([_true, _false, _null]));
        await _process.kill();
      });

      test("from defaults", () async {
        _process.send(compileString(r"a {b: foo(1, $arg3: 2)}",
            functions: [r"foo($arg1: null, $arg2: true, $arg3: false)"]));
        var request = await getFunctionCallRequest(_process);
        expect(
            request.arguments,
            equals([
              Value()..number = (Value_Number()..value = 1.0),
              _true,
              Value()..number = (Value_Number()..value = 2.0)
            ]));
        await _process.kill();
      });

      group("from argument lists", () {
        test("with no named arguments", () async {
          _process.send(compileString("a {b: foo(true, false, null)}",
              functions: [r"foo($arg, $args...)"]));
          var request = await getFunctionCallRequest(_process);

          expect(
              request.arguments,
              equals([
                _true,
                Value()
                  ..argumentList = (Value_ArgumentList()
                    ..id = 1
                    ..separator = ListSeparator.COMMA
                    ..contents.addAll([_false, _null]))
              ]));
          await _process.kill();
        });

        test("with named arguments", () async {
          _process.send(compileString(r"a {b: foo(true, $arg: false)}",
              functions: [r"foo($args...)"]));
          var request = await getFunctionCallRequest(_process);

          expect(
              request.arguments,
              equals([
                Value()
                  ..argumentList = (Value_ArgumentList()
                    ..id = 1
                    ..separator = ListSeparator.COMMA
                    ..contents.addAll([_true])
                    ..keywords.addAll({"arg": _false}))
              ]));
          await _process.kill();
        });

        test("throws if named arguments are unused", () async {
          _process.send(compileString(r"a {b: foo($arg: false)}",
              functions: [r"foo($args...)"]));
          var request = await getFunctionCallRequest(_process);

          _process.send(InboundMessage()
            ..functionCallResponse = (InboundMessage_FunctionCallResponse()
              ..id = request.id
              ..success = _true));

          var failure = await getCompileFailure(_process);
          expect(failure.message, equals(r"No argument named $arg."));
          await _process.close();
        });

        test("doesn't throw if named arguments are used", () async {
          _process.send(compileString(r"a {b: foo($arg: false)}",
              functions: [r"foo($args...)"]));
          var request = await getFunctionCallRequest(_process);

          _process.send(InboundMessage()
            ..functionCallResponse = (InboundMessage_FunctionCallResponse()
              ..id = request.id
              ..accessedArgumentLists
                  .add(request.arguments.first.argumentList.id)
              ..success = _true));

          await expectSuccess(_process, equals("a {\n  b: true;\n}"));
          await _process.close();
        });
      });
    });
  });

  test("returns the result as a SassScript value", () async {
    _process.send(compileString("a {b: foo() + 2px}", functions: [r"foo()"]));
    var request = await getFunctionCallRequest(_process);

    _process.send(InboundMessage()
      ..functionCallResponse = (InboundMessage_FunctionCallResponse()
        ..id = request.id
        ..success = (Value()
          ..number = (Value_Number()
            ..value = 1
            ..numerators.add("px")))));

    await expectSuccess(_process, equals("a {\n  b: 3px;\n}"));
    await _process.close();
  });

  group("calls a first-class function", () {
    test("defined in the compiler and passed to and from the host", () async {
      _process.send(compileString(r"""
        @use "sass:math";
        @use "sass:meta";

        a {b: call(foo(meta.get-function("abs", $module: "math")), -1)}
      """, functions: [r"foo($arg)"]));

      var request = await getFunctionCallRequest(_process);
      var value = request.arguments.single;
      expect(value.hasCompilerFunction(), isTrue);
      _process.send(InboundMessage()
        ..functionCallResponse = (InboundMessage_FunctionCallResponse()
          ..id = request.id
          ..success = value));

      await expectSuccess(_process, equals("a {\n  b: 1;\n}"));
      await _process.close();
    });

    test("defined in the host", () async {
      _process.send(
          compileString("a {b: call(foo(), true)}", functions: [r"foo()"]));

      var hostFunctionId = 5678;
      var request = await getFunctionCallRequest(_process);
      _process.send(InboundMessage()
        ..functionCallResponse = (InboundMessage_FunctionCallResponse()
          ..id = request.id
          ..success = (Value()
            ..hostFunction = (Value_HostFunction()
              ..id = hostFunctionId
              ..signature = r"bar($arg)"))));

      request = await getFunctionCallRequest(_process);
      expect(request.functionId, equals(hostFunctionId));
      expect(request.arguments, equals([_true]));

      _process.send(InboundMessage()
        ..functionCallResponse = (InboundMessage_FunctionCallResponse()
          ..id = request.id
          ..success = _false));

      await expectSuccess(_process, equals("a {\n  b: false;\n}"));
      await _process.close();
    });

    test("defined in the host and passed to and from the host", () async {
      _process.send(compileString(r"""
            $function: get-host-function();
            $function: round-trip($function);
            a {b: call($function, true)}
          """, functions: [r"get-host-function()", r"round-trip($function)"]));

      var hostFunctionId = 5678;
      var request = await getFunctionCallRequest(_process);
      expect(request.name, equals("get-host-function"));
      _process.send(InboundMessage()
        ..functionCallResponse = (InboundMessage_FunctionCallResponse()
          ..id = request.id
          ..success = (Value()
            ..hostFunction = (Value_HostFunction()
              ..id = hostFunctionId
              ..signature = r"bar($arg)"))));

      request = await getFunctionCallRequest(_process);
      expect(request.name, equals("round-trip"));
      var value = request.arguments.single;
      expect(value.hasCompilerFunction(), isTrue);
      _process.send(InboundMessage()
        ..functionCallResponse = (InboundMessage_FunctionCallResponse()
          ..id = request.id
          ..success = value));

      request = await getFunctionCallRequest(_process);
      expect(request.functionId, equals(hostFunctionId));
      expect(request.arguments, equals([_true]));

      _process.send(InboundMessage()
        ..functionCallResponse = (InboundMessage_FunctionCallResponse()
          ..id = request.id
          ..success = _false));

      await expectSuccess(_process, equals("a {\n  b: false;\n}"));
      await _process.close();
    });
  });

  group("serializes to protocol buffers", () {
    group("a string that's", () {
      group("quoted", () {
        test("and empty", () async {
          var value = (await _protofy('""')).string;
          expect(value.text, isEmpty);
          expect(value.quoted, isTrue);
        });

        test("and non-empty", () async {
          var value = (await _protofy('"foo bar"')).string;
          expect(value.text, equals("foo bar"));
          expect(value.quoted, isTrue);
        });
      });

      group("unquoted", () {
        test("and empty", () async {
          var value = (await _protofy('unquote("")')).string;
          expect(value.text, isEmpty);
          expect(value.quoted, isFalse);
        });

        test("and non-empty", () async {
          var value = (await _protofy('"foo bar"')).string;
          expect(value.text, equals("foo bar"));
          expect(value.quoted, isTrue);
        });
      });
    });

    group("a number", () {
      group("that's unitless", () {
        test("and an integer", () async {
          var value = (await _protofy('1')).number;
          expect(value.value, equals(1.0));
          expect(value.numerators, isEmpty);
          expect(value.denominators, isEmpty);
        });

        test("and a float", () async {
          var value = (await _protofy('1.5')).number;
          expect(value.value, equals(1.5));
          expect(value.numerators, isEmpty);
          expect(value.denominators, isEmpty);
        });
      });

      test("with one numerator", () async {
        var value = (await _protofy('1em')).number;
        expect(value.value, equals(1.0));
        expect(value.numerators, ["em"]);
        expect(value.denominators, isEmpty);
      });

      test("with multiple numerators", () async {
        var value = (await _protofy('1em * 1px * 1foo')).number;
        expect(value.value, equals(1.0));
        expect(value.numerators, unorderedEquals(["em", "px", "foo"]));
        expect(value.denominators, isEmpty);
      });

      test("with one denominator", () async {
        var value = (await _protofy('math.div(1,1em)')).number;
        expect(value.value, equals(1.0));
        expect(value.numerators, isEmpty);
        expect(value.denominators, ["em"]);
      });

      test("with multiple denominators", () async {
        var value =
            (await _protofy('math.div(math.div(math.div(1, 1em), 1px), 1foo)'))
                .number;
        expect(value.value, equals(1.0));
        expect(value.numerators, isEmpty);
        expect(value.denominators, unorderedEquals(["em", "px", "foo"]));
      });

      test("with numerators and denominators", () async {
        var value =
            (await _protofy('1em * math.div(math.div(1px, 1s), 1foo)')).number;
        expect(value.value, equals(1.0));
        expect(value.numerators, unorderedEquals(["em", "px"]));
        expect(value.denominators, unorderedEquals(["s", "foo"]));
      });
    });

    group("a color that's", () {
      group("rgb", () {
        group("without alpha:", () {
          test("black", () async {
            expect(await _protofy('#000'), _rgb(0, 0, 0, 1.0));
          });

          test("white", () async {
            expect(await _protofy('#fff'), equals(_rgb(255, 255, 255, 1.0)));
          });

          test("in the middle", () async {
            expect(await _protofy('#abc'), equals(_rgb(0xaa, 0xbb, 0xcc, 1.0)));
          });
        });

        group("with alpha", () {
          test("0", () async {
            expect(await _protofy('rgb(10, 20, 30, 0)'),
                equals(_rgb(10, 20, 30, 0.0)));
          });

          test("1", () async {
            expect(await _protofy('rgb(10, 20, 30, 1)'),
                equals(_rgb(10, 20, 30, 1.0)));
          });

          test("between 0 and 1", () async {
            expect(await _protofy('rgb(10, 20, 30, 0.123)'),
                equals(_rgb(10, 20, 30, 0.123)));
          });
        });
      });

      group("hsl", () {
        group("without alpha:", () {
          group("hue", () {
            test("0", () async {
              expect(await _protofy('hsl(0, 50%, 50%)'), _hsl(0, 50, 50, 1.0));
            });

            test("360", () async {
              expect(
                  await _protofy('hsl(360, 50%, 50%)'), _hsl(0, 50, 50, 1.0));
            });

            test("below 0", () async {
              expect(await _protofy('hsl(-100, 50%, 50%)'),
                  _hsl(260, 50, 50, 1.0));
            });

            test("between 0 and 360", () async {
              expect(
                  await _protofy('hsl(100, 50%, 50%)'), _hsl(100, 50, 50, 1.0));
            });

            test("above 360", () async {
              expect(
                  await _protofy('hsl(560, 50%, 50%)'), _hsl(200, 50, 50, 1.0));
            });
          });

          group("saturation", () {
            test("0", () async {
              expect(await _protofy('hsl(0, 0%, 50%)'), _hsl(0, 0, 50, 1.0));
            });

            test("100", () async {
              expect(
                  await _protofy('hsl(0, 100%, 50%)'), _hsl(0, 100, 50, 1.0));
            });

            test("in the middle", () async {
              expect(await _protofy('hsl(0, 42%, 50%)'), _hsl(0, 42, 50, 1.0));
            });
          });

          group("lightness", () {
            test("0", () async {
              expect(await _protofy('hsl(0, 50%, 0%)'), _hsl(0, 50, 0, 1.0));
            });

            test("100", () async {
              expect(
                  await _protofy('hsl(0, 50%, 100%)'), _hsl(0, 50, 100, 1.0));
            });

            test("in the middle", () async {
              expect(await _protofy('hsl(0, 50%, 42%)'), _hsl(0, 50, 42, 1.0));
            });
          });
        });

        group("with alpha", () {
          test("0", () async {
            expect(await _protofy('hsl(10, 20%, 30%, 0)'),
                equals(_hsl(10, 20, 30, 0.0)));
          });

          test("1", () async {
            expect(await _protofy('hsl(10, 20%, 30%, 1)'),
                equals(_hsl(10, 20, 30, 1.0)));
          });

          test("between 0 and 1", () async {
            expect(await _protofy('hsl(10, 20%, 30%, 0.123)'),
                equals(_hsl(10, 20, 30, 0.123)));
          });
        });
      });
    });

    group("a list", () {
      group("with no elements", () {
        group("with brackets", () {
          test("with unknown separator", () async {
            var list = (await _protofy("[]")).list;
            expect(list.contents, isEmpty);
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(ListSeparator.UNDECIDED));
          });

          test("with a comma separator", () async {
            var list =
                (await _protofy(r"list.join([], [], $separator: comma)")).list;
            expect(list.contents, isEmpty);
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(ListSeparator.COMMA));
          });

          test("with a space separator", () async {
            var list =
                (await _protofy(r"list.join([], [], $separator: space)")).list;
            expect(list.contents, isEmpty);
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(ListSeparator.SPACE));
          });

          test("with a slash separator", () async {
            var list =
                (await _protofy(r"list.join([], [], $separator: slash)")).list;
            expect(list.contents, isEmpty);
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(ListSeparator.SLASH));
          });
        });

        group("without brackets", () {
          test("with unknown separator", () async {
            var list = (await _protofy("()")).list;
            expect(list.contents, isEmpty);
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(ListSeparator.UNDECIDED));
          });

          test("with a comma separator", () async {
            var list =
                (await _protofy(r"list.join((), (), $separator: comma)")).list;
            expect(list.contents, isEmpty);
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(ListSeparator.COMMA));
          });

          test("with a space separator", () async {
            var list =
                (await _protofy(r"list.join((), (), $separator: space)")).list;
            expect(list.contents, isEmpty);
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(ListSeparator.SPACE));
          });

          test("with a slash separator", () async {
            var list =
                (await _protofy(r"list.join((), (), $separator: slash)")).list;
            expect(list.contents, isEmpty);
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(ListSeparator.SLASH));
          });
        });
      });

      group("with one element", () {
        group("with brackets", () {
          test("with unknown separator", () async {
            var list = (await _protofy("[true]")).list;
            expect(list.contents, equals([_true]));
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(ListSeparator.UNDECIDED));
          });

          test("with a comma separator", () async {
            var list = (await _protofy(r"[true,]")).list;
            expect(list.contents, equals([_true]));
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(ListSeparator.COMMA));
          });

          test("with a space separator", () async {
            var list =
                (await _protofy(r"list.join([true], [], $separator: space)"))
                    .list;
            expect(list.contents, equals([_true]));
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(ListSeparator.SPACE));
          });

          test("with a slash separator", () async {
            var list =
                (await _protofy(r"list.join([true], [], $separator: slash)"))
                    .list;
            expect(list.contents, equals([_true]));
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(ListSeparator.SLASH));
          });
        });

        group("without brackets", () {
          test("with a comma separator", () async {
            var list = (await _protofy(r"(true,)")).list;
            expect(list.contents, equals([_true]));
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(ListSeparator.COMMA));
          });

          test("with a space separator", () async {
            var list =
                (await _protofy(r"list.join(true, (), $separator: space)"))
                    .list;
            expect(list.contents, equals([_true]));
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(ListSeparator.SPACE));
          });

          test("with a slash separator", () async {
            var list =
                (await _protofy(r"list.join(true, (), $separator: slash)"))
                    .list;
            expect(list.contents, equals([_true]));
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(ListSeparator.SLASH));
          });
        });
      });

      group("with multiple elements", () {
        group("with brackets", () {
          test("with a comma separator", () async {
            var list = (await _protofy(r"[true, null, false]")).list;
            expect(list.contents, equals([_true, _null, _false]));
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(ListSeparator.COMMA));
          });

          test("with a space separator", () async {
            var list = (await _protofy(r"[true null false]")).list;
            expect(list.contents, equals([_true, _null, _false]));
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(ListSeparator.SPACE));
          });
        });

        group("without brackets", () {
          test("with a comma separator", () async {
            var list = (await _protofy(r"true, null, false")).list;
            expect(list.contents, equals([_true, _null, _false]));
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(ListSeparator.COMMA));
          });

          test("with a space separator", () async {
            var list = (await _protofy(r"true null false")).list;
            expect(list.contents, equals([_true, _null, _false]));
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(ListSeparator.SPACE));
          });

          test("with a slash separator", () async {
            var list = (await _protofy(r"list.slash(true, null, false)")).list;
            expect(list.contents, equals([_true, _null, _false]));
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(ListSeparator.SLASH));
          });
        });
      });
    });

    group("an argument list", () {
      test("that's empty", () async {
        var list = (await _protofy(r"capture-args()")).argumentList;
        expect(list.contents, isEmpty);
        expect(list.keywords, isEmpty);
        expect(list.separator, equals(ListSeparator.COMMA));
      });

      test("with arguments", () async {
        var list =
            (await _protofy(r"capture-args(true, null, false)")).argumentList;
        expect(list.contents, [_true, _null, _false]);
        expect(list.keywords, isEmpty);
        expect(list.separator, equals(ListSeparator.COMMA));
      });

      test("with a space separator", () async {
        var list =
            (await _protofy(r"capture-args(true null false...)")).argumentList;
        expect(list.contents, [_true, _null, _false]);
        expect(list.keywords, isEmpty);
        expect(list.separator, equals(ListSeparator.SPACE));
      });

      test("with a slash separator", () async {
        var list =
            (await _protofy(r"capture-args(list.slash(true, null, false)...)"))
                .argumentList;
        expect(list.contents, [_true, _null, _false]);
        expect(list.keywords, isEmpty);
        expect(list.separator, equals(ListSeparator.SLASH));
      });

      test("with keywords", () async {
        var list = (await _protofy(r"capture-args($arg1: true, $arg2: false)"))
            .argumentList;
        expect(list.contents, isEmpty);
        expect(list.keywords, equals({"arg1": _true, "arg2": _false}));
        expect(list.separator, equals(ListSeparator.COMMA));
      });
    });

    group("a map", () {
      test("with no elements", () async {
        expect((await _protofy("map.remove((1: 2), 1)")).map.entries, isEmpty);
      });

      test("with one element", () async {
        expect(
            (await _protofy("(true: false)")).map.entries,
            equals([
              Value_Map_Entry()
                ..key = _true
                ..value = _false
            ]));
      });

      test("with multiple elements", () async {
        expect(
            (await _protofy("(true: false, 1: 2, a: b)")).map.entries,
            equals([
              Value_Map_Entry()
                ..key = _true
                ..value = _false,
              Value_Map_Entry()
                ..key = (Value()..number = (Value_Number()..value = 1.0))
                ..value = (Value()..number = (Value_Number()..value = 2.0)),
              Value_Map_Entry()
                ..key = (Value()
                  ..string = (Value_String()
                    ..text = "a"
                    ..quoted = false))
                ..value = (Value()
                  ..string = (Value_String()
                    ..text = "b"
                    ..quoted = false))
            ]));
      });
    });

    group("a calculation", () {
      test("with a string argument", () async {
        expect(
            (await _protofy("calc(var(--foo))")).calculation,
            equals(Value_Calculation()
              ..name = "calc"
              ..arguments.add(Value_Calculation_CalculationValue()
                ..string = "var(--foo)")));
      });

      test("with an interpolation argument", () async {
        expect(
            (await _protofy("calc(#{var(--foo)})")).calculation,
            equals(Value_Calculation()
              ..name = "calc"
              ..arguments.add(Value_Calculation_CalculationValue()
                ..string = "var(--foo)")));
      });

      test("with number arguments", () async {
        expect(
            (await _protofy("clamp(1%, 2px, 3em)")).calculation,
            equals(Value_Calculation()
              ..name = "clamp"
              ..arguments.add(Value_Calculation_CalculationValue()
                ..number = (Value_Number()
                  ..value = 1.0
                  ..numerators.add("%")))
              ..arguments.add(Value_Calculation_CalculationValue()
                ..number = (Value_Number()
                  ..value = 2.0
                  ..numerators.add("px")))
              ..arguments.add(Value_Calculation_CalculationValue()
                ..number = (Value_Number()
                  ..value = 3.0
                  ..numerators.add("em")))));
      });

      test("with a calculation argument", () async {
        expect(
            (await _protofy("min(max(1%, 2px), 3em)")).calculation,
            equals(Value_Calculation()
              ..name = "min"
              ..arguments.add(Value_Calculation_CalculationValue()
                ..calculation = (Value_Calculation()
                  ..name = "max"
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..number = (Value_Number()
                      ..value = 1.0
                      ..numerators.add("%")))
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..number = (Value_Number()
                      ..value = 2.0
                      ..numerators.add("px")))))
              ..arguments.add(Value_Calculation_CalculationValue()
                ..number = (Value_Number()
                  ..value = 3.0
                  ..numerators.add("em")))));
      });

      test("with an operation", () async {
        expect(
            (await _protofy("calc(1% + 2px)")).calculation,
            equals(Value_Calculation()
              ..name = "calc"
              ..arguments.add(Value_Calculation_CalculationValue()
                ..operation = (Value_Calculation_CalculationOperation()
                  ..operator = CalculationOperator.PLUS
                  ..left = (Value_Calculation_CalculationValue()
                    ..number = (Value_Number()
                      ..value = 1.0
                      ..numerators.add("%")))
                  ..right = (Value_Calculation_CalculationValue()
                    ..number = (Value_Number()
                      ..value = 2.0
                      ..numerators.add("px")))))));
      });
    });

    test("true", () async {
      expect((await _protofy("true")), equals(_true));
    });

    test("false", () async {
      expect((await _protofy("false")), equals(_false));
    });

    test("true", () async {
      expect((await _protofy("null")), equals(_null));
    });
  });

  group("deserializes from protocol buffer", () {
    group("a string that's", () {
      group("quoted", () {
        test("and empty", () async {
          expect(
              await _deprotofy(Value()
                ..string = (Value_String()
                  ..text = ""
                  ..quoted = true)),
              '""');
        });

        test("and non-empty", () async {
          expect(
              await _deprotofy(Value()
                ..string = (Value_String()
                  ..text = "foo bar"
                  ..quoted = true)),
              '"foo bar"');
        });
      });

      group("unquoted", () {
        test("and empty", () async {
          // We can't use [_deprotofy] here because a property with an empty
          // value won't render at all.
          await _assertRoundTrips(Value()
            ..string = (Value_String()
              ..text = ""
              ..quoted = false));
        });

        test("and non-empty", () async {
          expect(
              await _deprotofy(Value()
                ..string = (Value_String()
                  ..text = "foo bar"
                  ..quoted = false)),
              "foo bar");
        });
      });
    });

    group("a number", () {
      group("that's unitless", () {
        test("and an integer", () async {
          expect(
              await _deprotofy(Value()..number = (Value_Number()..value = 1.0)),
              "1");
        });

        test("and a float", () async {
          expect(
              await _deprotofy(Value()..number = (Value_Number()..value = 1.5)),
              "1.5");
        });
      });

      test("with one numerator", () async {
        expect(
            await _deprotofy(Value()
              ..number = (Value_Number()
                ..value = 1
                ..numerators.add("em"))),
            "1em");
      });

      test("with multiple numerators", () async {
        expect(
            await _deprotofy(
                Value()
                  ..number = (Value_Number()
                    ..value = 1
                    ..numerators.addAll(["em", "px", "foo"])),
                inspect: true),
            "1em*px*foo");
      });

      test("with one denominator", () async {
        expect(
            await _deprotofy(
                Value()
                  ..number = (Value_Number()
                    ..value = 1
                    ..denominators.add("em")),
                inspect: true),
            "1em^-1");
      });

      test("with multiple denominators", () async {
        expect(
            await _deprotofy(
                Value()
                  ..number = (Value_Number()
                    ..value = 1
                    ..denominators.addAll(["em", "px", "foo"])),
                inspect: true),
            "1(em*px*foo)^-1");
      });

      test("with numerators and denominators", () async {
        expect(
            await _deprotofy(
                Value()
                  ..number = (Value_Number()
                    ..value = 1
                    ..numerators.addAll(["em", "px"])
                    ..denominators.addAll(["s", "foo"])),
                inspect: true),
            "1em*px/s*foo");
      });
    });

    group("a color that's", () {
      group("rgb", () {
        group("without alpha:", () {
          test("black", () async {
            expect(await _deprotofy(_rgb(0, 0, 0, 1.0)), equals('black'));
          });

          test("white", () async {
            expect(await _deprotofy(_rgb(255, 255, 255, 1.0)), equals('white'));
          });

          test("in the middle", () async {
            expect(await _deprotofy(_rgb(0xaa, 0xbb, 0xcc, 1.0)),
                equals('#aabbcc'));
          });

          test("with red above 255", () async {
            expect(await _deprotofy(_rgb(256, 0, 0, 1.0)),
                equals('rgb(256, 0, 0)'));
          });

          test("with green above 255", () async {
            expect(await _deprotofy(_rgb(0, 256, 0, 1.0)),
                equals('rgb(0, 256, 0)'));
          });

          test("with blue above 255", () async {
            expect(await _deprotofy(_rgb(0, 0, 256, 1.0)),
                equals('rgb(0, 0, 256)'));
          });
        });

        group("with alpha", () {
          test("0", () async {
            expect(await _deprotofy(_rgb(10, 20, 30, 0.0)),
                equals('rgba(10, 20, 30, 0)'));
          });

          test("between 0 and 1", () async {
            expect(await _deprotofy(_rgb(10, 20, 30, 0.123)),
                equals('rgba(10, 20, 30, 0.123)'));
          });
        });
      });

      group("hsl", () {
        group("without alpha:", () {
          group("hue", () {
            test("0", () async {
              expect(
                  await _deprotofy(_hsl(0, 50, 50, 1.0)), "hsl(0, 50%, 50%)");
            });

            test("360", () async {
              expect(
                  await _deprotofy(_hsl(360, 50, 50, 1.0)), "hsl(0, 50%, 50%)");
            });

            test("below 0", () async {
              expect(await _deprotofy(_hsl(-100, 50, 50, 1.0)),
                  "hsl(260, 50%, 50%)");
            });

            test("between 0 and 360", () async {
              expect(await _deprotofy(_hsl(100, 50, 50, 1.0)),
                  "hsl(100, 50%, 50%)");
            });

            test("above 360", () async {
              expect(await _deprotofy(_hsl(560, 50, 50, 1.0)),
                  "hsl(200, 50%, 50%)");
            });
          });

          group("saturation", () {
            test("0", () async {
              expect(await _deprotofy(_hsl(0, 0, 50, 1.0)), "hsl(0, 0%, 50%)");
            });

            test("100", () async {
              expect(
                  await _deprotofy(_hsl(0, 100, 50, 1.0)), "hsl(0, 100%, 50%)");
            });

            test("in the middle", () async {
              expect(
                  await _deprotofy(_hsl(0, 42, 50, 1.0)), "hsl(0, 42%, 50%)");
            });
          });

          group("lightness", () {
            test("0", () async {
              expect(await _deprotofy(_hsl(0, 50, 0, 1.0)), "hsl(0, 50%, 0%)");
            });

            test("100", () async {
              expect(
                  await _deprotofy(_hsl(0, 50, 100, 1.0)), "hsl(0, 50%, 100%)");
            });

            test("in the middle", () async {
              expect(
                  await _deprotofy(_hsl(0, 50, 42, 1.0)), "hsl(0, 50%, 42%)");
            });
          });
        });

        group("with alpha", () {
          test("0", () async {
            expect(await _deprotofy(_hsl(10, 20, 30, 0.0)),
                "hsla(10, 20%, 30%, 0)");
          });

          test("between 0 and 1", () async {
            expect(await _deprotofy(_hsl(10, 20, 30, 0.123)),
                "hsla(10, 20%, 30%, 0.123)");
          });
        });
      });
    });

    group("a list", () {
      group("with no elements", () {
        group("with brackets", () {
          group("with unknown separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..hasBrackets = true
                    ..separator = ListSeparator.UNDECIDED),
                "[]");
          });

          group("with a comma separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..hasBrackets = true
                    ..separator = ListSeparator.COMMA),
                "[]");
          });

          group("with a space separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..hasBrackets = true
                    ..separator = ListSeparator.SPACE),
                "[]");
          });

          group("with a slash separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..hasBrackets = true
                    ..separator = ListSeparator.SLASH),
                "[]");
          });
        });

        group("without brackets", () {
          group("with unknown separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..hasBrackets = false
                    ..separator = ListSeparator.UNDECIDED),
                "()",
                inspect: true);
          });

          group("with a comma separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..hasBrackets = false
                    ..separator = ListSeparator.COMMA),
                "()",
                inspect: true);
          });

          group("with a space separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..hasBrackets = false
                    ..separator = ListSeparator.SPACE),
                "()",
                inspect: true);
          });

          group("with a slash separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..hasBrackets = false
                    ..separator = ListSeparator.SLASH),
                "()",
                inspect: true);
          });
        });
      });

      group("with one element", () {
        group("with brackets", () {
          group("with unknown separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..contents.add(_true)
                    ..hasBrackets = true
                    ..separator = ListSeparator.UNDECIDED),
                "[true]");
          });

          test("with a comma separator", () async {
            expect(
                await _deprotofy(
                    Value()
                      ..list = (Value_List()
                        ..contents.add(_true)
                        ..hasBrackets = true
                        ..separator = ListSeparator.COMMA),
                    inspect: true),
                "[true,]");
          });

          group("with a space separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..contents.add(_true)
                    ..hasBrackets = true
                    ..separator = ListSeparator.SPACE),
                "[true]");
          });

          group("with a slash separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..contents.add(_true)
                    ..hasBrackets = true
                    ..separator = ListSeparator.SLASH),
                "[true]");
          });
        });

        group("without brackets", () {
          group("with unknown separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..contents.add(_true)
                    ..hasBrackets = false
                    ..separator = ListSeparator.UNDECIDED),
                "true");
          });

          test("with a comma separator", () async {
            expect(
                await _deprotofy(
                    Value()
                      ..list = (Value_List()
                        ..contents.add(_true)
                        ..hasBrackets = false
                        ..separator = ListSeparator.COMMA),
                    inspect: true),
                "(true,)");
          });

          group("with a space separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..contents.add(_true)
                    ..hasBrackets = false
                    ..separator = ListSeparator.SPACE),
                "true");
          });

          group("with a slash separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..contents.add(_true)
                    ..hasBrackets = false
                    ..separator = ListSeparator.SLASH),
                "true");
          });
        });
      });

      group("with multiple elements", () {
        group("with brackets", () {
          test("with a comma separator", () async {
            expect(
                await _deprotofy(
                    Value()
                      ..list = (Value_List()
                        ..contents.addAll([_true, _null, _false])
                        ..hasBrackets = true
                        ..separator = ListSeparator.COMMA),
                    inspect: true),
                "[true, null, false]");
          });

          test("with a space separator", () async {
            expect(
                await _deprotofy(
                    Value()
                      ..list = (Value_List()
                        ..contents.addAll([_true, _null, _false])
                        ..hasBrackets = true
                        ..separator = ListSeparator.SPACE),
                    inspect: true),
                "[true null false]");
          });

          test("with a slash separator", () async {
            expect(
                await _deprotofy(
                    Value()
                      ..list = (Value_List()
                        ..contents.addAll([_true, _null, _false])
                        ..hasBrackets = true
                        ..separator = ListSeparator.SLASH),
                    inspect: true),
                "[true / null / false]");
          });
        });

        group("without brackets", () {
          test("with a comma separator", () async {
            expect(
                await _deprotofy(
                    Value()
                      ..list = (Value_List()
                        ..contents.addAll([_true, _null, _false])
                        ..hasBrackets = false
                        ..separator = ListSeparator.COMMA),
                    inspect: true),
                "true, null, false");
          });

          test("with a space separator", () async {
            expect(
                await _deprotofy(
                    Value()
                      ..list = (Value_List()
                        ..contents.addAll([_true, _null, _false])
                        ..hasBrackets = false
                        ..separator = ListSeparator.SPACE),
                    inspect: true),
                "true null false");
          });

          test("with a slash separator", () async {
            expect(
                await _deprotofy(
                    Value()
                      ..list = (Value_List()
                        ..contents.addAll([_true, _null, _false])
                        ..hasBrackets = false
                        ..separator = ListSeparator.SLASH),
                    inspect: true),
                "true / null / false");
          });
        });
      });
    });

    group("an argument list", () {
      test("with no elements", () async {
        expect(
            await _roundTrip(Value()
              ..argumentList =
                  (Value_ArgumentList()..separator = ListSeparator.UNDECIDED)),
            equals(Value()
              ..argumentList = (Value_ArgumentList()
                ..id = 1
                ..separator = ListSeparator.UNDECIDED)));
      });

      test("with comma separator", () async {
        expect(
            await _roundTrip(Value()
              ..argumentList = (Value_ArgumentList()
                ..contents.addAll([_true, _false, _null])
                ..separator = ListSeparator.COMMA)),
            equals(Value()
              ..argumentList = (Value_ArgumentList()
                ..id = 1
                ..contents.addAll([_true, _false, _null])
                ..separator = ListSeparator.COMMA)));
      });

      test("with space separator", () async {
        expect(
            await _roundTrip(Value()
              ..argumentList = (Value_ArgumentList()
                ..contents.addAll([_true, _false, _null])
                ..separator = ListSeparator.SPACE)),
            equals(Value()
              ..argumentList = (Value_ArgumentList()
                ..id = 1
                ..contents.addAll([_true, _false, _null])
                ..separator = ListSeparator.SPACE)));
      });

      test("with slash separator", () async {
        expect(
            await _roundTrip(Value()
              ..argumentList = (Value_ArgumentList()
                ..contents.addAll([_true, _false, _null])
                ..separator = ListSeparator.SLASH)),
            equals(Value()
              ..argumentList = (Value_ArgumentList()
                ..id = 1
                ..contents.addAll([_true, _false, _null])
                ..separator = ListSeparator.SLASH)));
      });

      test("with keywords", () async {
        expect(
            await _roundTrip(Value()
              ..argumentList = (Value_ArgumentList()
                ..keywords.addAll({"arg1": _true, "arg2": _false})
                ..separator = ListSeparator.COMMA)),
            equals(Value()
              ..argumentList = (Value_ArgumentList()
                ..id = 1
                ..keywords.addAll({"arg1": _true, "arg2": _false})
                ..separator = ListSeparator.COMMA)));
      });
    });

    group("a map", () {
      group("with no elements", () {
        _testSerializationAndRoundTrip(Value()..map = Value_Map(), "()",
            inspect: true);
      });

      test("with one element", () async {
        expect(
            await _deprotofy(
                Value()
                  ..map = (Value_Map()
                    ..entries.add(Value_Map_Entry()
                      ..key = _true
                      ..value = _false)),
                inspect: true),
            "(true: false)");
      });

      test("with multiple elements", () async {
        expect(
            await _deprotofy(
                Value()
                  ..map = (Value_Map()
                    ..entries.addAll([
                      Value_Map_Entry()
                        ..key = _true
                        ..value = _false,
                      Value_Map_Entry()
                        ..key =
                            (Value()..number = (Value_Number()..value = 1.0))
                        ..value =
                            (Value()..number = (Value_Number()..value = 2.0)),
                      Value_Map_Entry()
                        ..key = (Value()
                          ..string = (Value_String()
                            ..text = "a"
                            ..quoted = false))
                        ..value = (Value()
                          ..string = (Value_String()
                            ..text = "b"
                            ..quoted = false))
                    ])),
                inspect: true),
            "(true: false, 1: 2, a: b)");
      });
    });

    group("a calculation", () {
      test("with a string argument", () async {
        expect(
            await _deprotofy(Value()
              ..calculation = (Value_Calculation()
                ..name = "calc"
                ..arguments.add(Value_Calculation_CalculationValue()
                  ..string = "var(--foo)"))),
            "calc(var(--foo))");
      });

      test("with an interpolation argument", () async {
        expect(
            await _deprotofy(Value()
              ..calculation = (Value_Calculation()
                ..name = "calc"
                ..arguments.add(Value_Calculation_CalculationValue()
                  ..interpolation = "var(--foo)"))),
            "calc((var(--foo)))");
      });

      test("with number arguments", () async {
        expect(
            await _deprotofy(Value()
              ..calculation = (Value_Calculation()
                ..name = "clamp"
                ..arguments.add(Value_Calculation_CalculationValue()
                  ..number = (Value_Number()
                    ..value = 1.0
                    ..numerators.add("%")))
                ..arguments.add(Value_Calculation_CalculationValue()
                  ..number = (Value_Number()
                    ..value = 2.0
                    ..numerators.add("px")))
                ..arguments.add(Value_Calculation_CalculationValue()
                  ..number = (Value_Number()
                    ..value = 3.0
                    ..numerators.add("em"))))),
            "clamp(1%, 2px, 3em)");
      });

      test("with a calculation argument", () async {
        expect(
            await _deprotofy(Value()
              ..calculation = (Value_Calculation()
                ..name = "min"
                ..arguments.add(Value_Calculation_CalculationValue()
                  ..calculation = (Value_Calculation()
                    ..name = "max"
                    ..arguments.add(Value_Calculation_CalculationValue()
                      ..number = (Value_Number()
                        ..value = 1.0
                        ..numerators.add("%")))
                    ..arguments.add(Value_Calculation_CalculationValue()
                      ..number = (Value_Number()
                        ..value = 2.0
                        ..numerators.add("px")))))
                ..arguments.add(Value_Calculation_CalculationValue()
                  ..number = (Value_Number()
                    ..value = 3.0
                    ..numerators.add("em"))))),
            "min(max(1%, 2px), 3em)");
      });

      test("with an operation", () async {
        expect(
            await _deprotofy(Value()
              ..calculation = (Value_Calculation()
                ..name = "calc"
                ..arguments.add(Value_Calculation_CalculationValue()
                  ..operation = (Value_Calculation_CalculationOperation()
                    ..operator = CalculationOperator.PLUS
                    ..left = (Value_Calculation_CalculationValue()
                      ..number = (Value_Number()
                        ..value = 1.0
                        ..numerators.add("%")))
                    ..right = (Value_Calculation_CalculationValue()
                      ..number = (Value_Number()
                        ..value = 2.0
                        ..numerators.add("px"))))))),
            "calc(1% + 2px)");
      });

      group("simplifies", () {
        test("an operation", () async {
          expect(
              await _deprotofy(Value()
                ..calculation = (Value_Calculation()
                  ..name = "calc"
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..operation = (Value_Calculation_CalculationOperation()
                      ..operator = CalculationOperator.PLUS
                      ..left = (Value_Calculation_CalculationValue()
                        ..number = (Value_Number()..value = 1.0))
                      ..right = (Value_Calculation_CalculationValue()
                        ..number = (Value_Number()..value = 2.0)))))),
              "3");
        });

        test("a nested operation", () async {
          expect(
              await _deprotofy(Value()
                ..calculation = (Value_Calculation()
                  ..name = "calc"
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..operation = (Value_Calculation_CalculationOperation()
                      ..operator = CalculationOperator.PLUS
                      ..left = (Value_Calculation_CalculationValue()
                        ..number = (Value_Number()
                          ..value = 1.0
                          ..numerators.add("%")))
                      ..right = (Value_Calculation_CalculationValue()
                        ..operation = (Value_Calculation_CalculationOperation()
                          ..operator = CalculationOperator.PLUS
                          ..left = (Value_Calculation_CalculationValue()
                            ..number = (Value_Number()
                              ..value = 2.0
                              ..numerators.add("px")))
                          ..right = (Value_Calculation_CalculationValue()
                            ..number = (Value_Number()
                              ..value = 3.0
                              ..numerators.add("px"))))))))),
              "calc(1% + 5px)");
        });

        test("min", () async {
          expect(
              await _deprotofy(Value()
                ..calculation = (Value_Calculation()
                  ..name = "min"
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..number = (Value_Number()..value = 1.0))
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..number = (Value_Number()..value = 2.0))
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..number = (Value_Number()..value = 3.0)))),
              "1");
        });

        test("max", () async {
          expect(
              await _deprotofy(Value()
                ..calculation = (Value_Calculation()
                  ..name = "max"
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..number = (Value_Number()..value = 1.0))
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..number = (Value_Number()..value = 2.0))
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..number = (Value_Number()..value = 3.0)))),
              "3");
        });

        test("clamp", () async {
          expect(
              await _deprotofy(Value()
                ..calculation = (Value_Calculation()
                  ..name = "clamp"
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..number = (Value_Number()..value = 1.0))
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..number = (Value_Number()..value = 2.0))
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..number = (Value_Number()..value = 3.0)))),
              "2");
        });
      });
    });

    test("true", () async {
      expect(await _deprotofy(_true), equals("true"));
    });

    test("false", () async {
      expect(await _deprotofy(_false), equals("false"));
    });

    test("null", () async {
      expect(await _deprotofy(_null, inspect: true), equals("null"));
    });

    group("and rejects", () {
      group("a color", () {
        test("with RGB alpha below 0", () async {
          await _expectDeprotofyError(_rgb(0, 0, 0, -0.1),
              "Color.alpha must be between 0 and 1, was -0.1");
        });

        test("with RGB alpha above 1", () async {
          await _expectDeprotofyError(_rgb(0, 0, 0, 1.1),
              "Color.alpha must be between 0 and 1, was 1.1");
        });

        test("with HSL alpha below 0", () async {
          await _expectDeprotofyError(_hsl(0, 0, 0, -0.1),
              "Color.alpha must be between 0 and 1, was -0.1");
        });

        test("with HSL alpha above 1", () async {
          await _expectDeprotofyError(_hsl(0, 0, 0, 1.1),
              "Color.alpha must be between 0 and 1, was 1.1");
        });
      });

      test("a list with multiple elements and an unknown separator", () async {
        await _expectDeprotofyError(
            Value()
              ..list = (Value_List()
                ..contents.addAll([_true, _false])
                ..separator = ListSeparator.UNDECIDED),
            endsWith("can't have an undecided separator because it has 2 "
                "elements"));
      });

      test("an arglist with an unknown id", () async {
        await _expectDeprotofyError(
            Value()..argumentList = (Value_ArgumentList()..id = 1),
            equals(
                "Value.ArgumentList.id 1 doesn't match any known argument lists"));
      });

      group("a calculation", () {
        group("with too many arguments", () {
          test("for calc", () async {
            await _expectDeprotofyError(
                Value()
                  ..calculation = (Value_Calculation()
                    ..name = "calc"
                    ..arguments.add(Value_Calculation_CalculationValue()
                      ..number = (Value_Number()..value = 1.0))
                    ..arguments.add(Value_Calculation_CalculationValue()
                      ..number = (Value_Number()..value = 2.0))),
                equals("Value.Calculation.arguments must have exactly one "
                    "argument for calc()."));
          });

          test("for clamp", () async {
            await _expectDeprotofyError(
                Value()
                  ..calculation = (Value_Calculation()
                    ..name = "clamp"
                    ..arguments.add(Value_Calculation_CalculationValue()
                      ..number = (Value_Number()..value = 1.0))
                    ..arguments.add(Value_Calculation_CalculationValue()
                      ..number = (Value_Number()..value = 2.0))
                    ..arguments.add(Value_Calculation_CalculationValue()
                      ..number = (Value_Number()..value = 3.0))
                    ..arguments.add(Value_Calculation_CalculationValue()
                      ..number = (Value_Number()..value = 4.0))),
                equals("Value.Calculation.arguments must have 1 to 3 "
                    "arguments for clamp()."));
          });
        });

        group("with too few arguments", () {
          test("for calc", () async {
            await _expectDeprotofyError(
                Value()..calculation = (Value_Calculation()..name = "calc"),
                equals("Value.Calculation.arguments must have exactly one "
                    "argument for calc()."));
          });

          test("for clamp", () async {
            await _expectDeprotofyError(
                Value()..calculation = (Value_Calculation()..name = "clamp"),
                equals("Value.Calculation.arguments must have 1 to 3 "
                    "arguments for clamp()."));
          });

          test("for min", () async {
            await _expectDeprotofyError(
                Value()..calculation = (Value_Calculation()..name = "min"),
                equals("Value.Calculation.arguments must have at least 1 "
                    "argument for min()."));
          });

          test("for max", () async {
            await _expectDeprotofyError(
                Value()..calculation = (Value_Calculation()..name = "max"),
                equals("Value.Calculation.arguments must have at least 1 "
                    "argument for max()."));
          });
        });

        test("reports a compilation failure when simplification fails",
            () async {
          _process.send(compileString("a {b: foo()}", functions: [r"foo()"]));

          var request = await getFunctionCallRequest(_process);
          expect(request.arguments, isEmpty);
          _process.send(InboundMessage()
            ..functionCallResponse = (InboundMessage_FunctionCallResponse()
              ..id = request.id
              ..success = (Value()
                ..calculation = (Value_Calculation()
                  ..name = "min"
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..number = (Value_Number()
                      ..value = 1.0
                      ..numerators.add("px")))
                  ..arguments.add(Value_Calculation_CalculationValue()
                    ..number = (Value_Number()
                      ..value = 2.0
                      ..numerators.add("s")))))));

          var failure = await getCompileFailure(_process);
          expect(failure.message, equals("1px and 2s are incompatible."));
          expect(_process.close(), completes);
        });
      });

      group("reports a compilation error for a function with a signature", () {
        Future<void> expectSignatureError(
            String signature, Object message) async {
          _process.send(
              compileString("a {b: inspect(foo())}", functions: [r"foo()"]));

          var request = await getFunctionCallRequest(_process);
          expect(request.arguments, isEmpty);
          _process.send(InboundMessage()
            ..functionCallResponse = (InboundMessage_FunctionCallResponse()
              ..id = request.id
              ..success = (Value()
                ..hostFunction = (Value_HostFunction()
                  ..id = 1234
                  ..signature = signature))));

          var failure = await getCompileFailure(_process);
          expect(failure.message, message);
          expect(_process.close(), completes);
        }

        test("that's empty", () async {
          await expectSignatureError(
              "", r'Invalid signature "": Expected identifier.');
        });

        test("that's just a name", () async {
          await expectSignatureError(
              "foo", r'Invalid signature "foo": expected "(".');
        });

        test("without a closing paren", () async {
          await expectSignatureError(
              r"foo($bar", r'Invalid signature "foo($bar": expected ")".');
        });

        test("with text after the closing paren", () async {
          await expectSignatureError(r"foo() ",
              r'Invalid signature "foo() ": expected no more input.');
        });

        test("with invalid arguments", () async {
          await expectSignatureError(
              r"foo($)", r'Invalid signature "foo($)": Expected identifier.');
        });
      });
    });
  });
}

/// Evaluates [sassScript] in the compiler, passes it to a custom function, and
/// returns the protocol buffer result.
Future<Value> _protofy(String sassScript) async {
  _process.send(compileString("""
@use 'sass:list';
@use 'sass:map';
@use 'sass:math';
@use 'sass:meta';

@function capture-args(\$args...) {
  \$_: meta.keywords(\$args);
  @return \$args;
}

\$_: foo(($sassScript));
""", functions: [r"foo($arg)"]));
  var request = await getFunctionCallRequest(_process);
  expect(_process.kill(), completes);
  return request.arguments.single;
}

/// Defines two tests: one that asserts that [value] is serialized to the CSS
/// value [expected], and one that asserts that it survives a round trip in the
/// same protocol buffer format.
///
/// This is necessary for values that can be serialized but also have metadata
/// that's not visible in the serialized form.
void _testSerializationAndRoundTrip(Value value, String expected,
    {bool inspect = false}) {
  test("is serialized correctly",
      () async => expect(await _deprotofy(value, inspect: inspect), expected));

  test("preserves metadata", () => _assertRoundTrips(value));
}

/// Sends [value] to the compiler and returns its string serialization.
///
/// If [inspect] is true, this returns the value as serialized by the
/// `meta.inspect()` function.
Future<String> _deprotofy(Value value, {bool inspect = false}) async {
  _process.send(compileString(
      inspect ? "a {b: inspect(foo())}" : "a {b: foo()}",
      functions: [r"foo()"]));

  var request = await getFunctionCallRequest(_process);
  expect(request.arguments, isEmpty);
  _process.send(InboundMessage()
    ..functionCallResponse = (InboundMessage_FunctionCallResponse()
      ..id = request.id
      ..success = value));

  var success = await getCompileSuccess(_process);
  expect(_process.close(), completes);
  return RegExp(r"  b: (.*);").firstMatch(success.css)![1]!;
}

/// Asserts that [value] causes a parameter error with a message matching
/// [message] when deserializing it from a protocol buffer.
Future<void> _expectDeprotofyError(Value value, Object message) async {
  _process.send(compileString("a {b: foo()}", functions: [r"foo()"]));

  var request = await getFunctionCallRequest(_process);
  expect(request.arguments, isEmpty);
  _process.send(InboundMessage()
    ..functionCallResponse = (InboundMessage_FunctionCallResponse()
      ..id = request.id
      ..success = value));

  await expectParamsError(_process, errorId, message);
  await _process.kill();
}

/// Sends [value] to the compiler to convert to a native Sass value, then sends
/// it back out to the host as a protocol buffer and asserts the two buffers are
/// identical.
///
/// Generally [_deprotofy] should be used instead unless there are details about
/// the internal structure of the value that won't show up in its string
/// representation.
Future<void> _assertRoundTrips(Value value) async =>
    expect(await _roundTrip(value), equals(value));

/// Sends [value] to the compiler to convert to a native Sass value, then sends
/// it back out to the host as a protocol buffer and returns the result.
Future<Value> _roundTrip(Value value) async {
  _process.send(compileString("""
\$_: outbound(inbound());
""", functions: ["inbound()", r"outbound($arg)"]));

  var request = await getFunctionCallRequest(_process);
  expect(request.arguments, isEmpty);
  _process.send(InboundMessage()
    ..functionCallResponse = (InboundMessage_FunctionCallResponse()
      ..id = request.id
      ..success = value));

  request = await getFunctionCallRequest(_process);
  expect(_process.kill(), completes);
  return request.arguments.single;
}

/// Returns a [Value] that's an RGB color with the given fields.
Value _rgb(int red, int green, int blue, double alpha) => Value()
  ..color = (Value_Color()
    ..space = 'rgb'
    ..channel1 = red * 1.0
    ..channel2 = green * 1.0
    ..channel3 = blue * 1.0
    ..alpha = alpha);

/// Returns a [Value] that's an HSL color with the given fields.
Value _hsl(num hue, num saturation, num lightness, double alpha) => Value()
  ..color = (Value_Color()
    ..space = 'hsl'
    ..channel1 = hue * 1.0
    ..channel2 = saturation * 1.0
    ..channel3 = lightness * 1.0
    ..alpha = alpha);

/// Asserts that [process] emits a [CompileFailure] result with the given
/// [message] on its protobuf stream and causes the compilation to fail.
Future<void> _expectFunctionError(
    EmbeddedProcess process, Object message) async {
  var failure = await getCompileFailure(process);
  expect(failure.message, equals(message));
}
