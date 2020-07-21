// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';

import 'package:sass_embedded/src/embedded_sass.pb.dart';

import 'embedded_process.dart';
import 'utils.dart';

final _true = Value()..singleton = Value_Singleton.TRUE;
final _false = Value()..singleton = Value_Singleton.FALSE;
final _null = Value()..singleton = Value_Singleton.NULL;

EmbeddedProcess _process;

void main() {
  ensureExecutableUpToDate();

  setUp(() async {
    _process = await EmbeddedProcess.start();
  });

  group("emits a protocol error", () {
    test("for an empty signature", () async {
      _process.inbound.add(compileString("a {b: c}", functions: [r""]));
      await expectParamsError(
          _process, 0, 'CompileRequest.global_functions: "" is missing "("');
      await _process.kill();
    });

    test("for a signature with just a name", () async {
      _process.inbound.add(compileString("a {b: c}", functions: [r"foo"]));
      await expectParamsError(
          _process, 0, 'CompileRequest.global_functions: "foo" is missing "("');
      await _process.kill();
    });

    test("for a signature without a closing paren", () async {
      _process.inbound.add(compileString("a {b: c}", functions: [r"foo($bar"]));
      await expectParamsError(_process, 0,
          'CompileRequest.global_functions: "foo(\$bar" doesn\'t end with ")"');
      await _process.kill();
    });

    test("for a signature with text after the closing paren", () async {
      _process.inbound.add(compileString("a {b: c}", functions: [r"foo() "]));
      await expectParamsError(_process, 0,
          'CompileRequest.global_functions: "foo() " doesn\'t end with ")"');
      await _process.kill();
    });

    test("for a signature with invalid arguments", () async {
      _process.inbound.add(compileString("a {b: c}", functions: [r"foo($)"]));
      await expectParamsError(
          _process,
          0,
          'CompileRequest.global_functions: Error: Expected identifier.\n'
          '  ╷\n'
          '1 │ @function foo(\$) {\n'
          '  │                ^\n'
          '  ╵\n'
          '  - 1:16  root stylesheet');
      await _process.kill();
    });
  });

  group("includes in FunctionCallRequest", () {
    var compilationId = 1234;
    OutboundMessage_FunctionCallRequest request;
    setUp(() async {
      _process.inbound.add(compileString("a {b: foo()}",
          id: compilationId, functions: ["foo()"]));
      request = getFunctionCallRequest(await _process.outbound.next);
    });

    test("the same compilationId as the compilation", () async {
      expect(request.compilationId, equals(compilationId));
      await _process.kill();
    });

    test("the function name", () async {
      expect(request.name, equals("foo"));
      await _process.kill();
    });

    group("arguments", () {
      test("that are empty", () async {
        _process.inbound
            .add(compileString("a {b: foo()}", functions: ["foo()"]));
        var request = getFunctionCallRequest(await _process.outbound.next);
        expect(request.arguments, isEmpty);
        await _process.kill();
      });

      test("by position", () async {
        _process.inbound.add(compileString("a {b: foo(true, null, false)}",
            functions: [r"foo($arg1, $arg2, $arg3)"]));
        var request = getFunctionCallRequest(await _process.outbound.next);
        expect(request.arguments, equals([_true, _null, _false]));
        await _process.kill();
      });

      test("by name", () async {
        _process.inbound.add(compileString(
            r"a {b: foo($arg3: true, $arg1: null, $arg2: false)}",
            functions: [r"foo($arg1, $arg2, $arg3)"]));
        var request = getFunctionCallRequest(await _process.outbound.next);
        expect(request.arguments, equals([_null, _false, _true]));
        await _process.kill();
      });

      test("by position and name", () async {
        _process.inbound.add(compileString(
            r"a {b: foo(true, $arg3: null, $arg2: false)}",
            functions: [r"foo($arg1, $arg2, $arg3)"]));
        var request = getFunctionCallRequest(await _process.outbound.next);
        expect(request.arguments, equals([_true, _false, _null]));
        await _process.kill();
      });

      test("from defaults", () async {
        _process.inbound.add(compileString(r"a {b: foo(1, $arg3: 2)}",
            functions: [r"foo($arg1: null, $arg2: true, $arg3: false)"]));
        var request = getFunctionCallRequest(await _process.outbound.next);
        expect(
            request.arguments,
            equals([
              Value()..number = (Value_Number()..value = 1.0),
              _true,
              Value()..number = (Value_Number()..value = 2.0)
            ]));
        await _process.kill();
      });

      test("from argument lists", () async {
        _process.inbound.add(compileString("a {b: foo(true, false, null)}",
            functions: [r"foo($arg, $args...)"]));
        var request = getFunctionCallRequest(await _process.outbound.next);

        expect(
            request.arguments,
            equals([
              _true,
              Value()
                ..list = (Value_List()
                  ..separator = Value_List_Separator.COMMA
                  ..hasBrackets = false
                  ..contents.addAll([_false, _null]))
            ]));
        await _process.kill();
      });
    });
  });

  test("returns the result as a SassScript value", () async {
    _process.inbound
        .add(compileString("a {b: foo() + 2px}", functions: [r"foo()"]));
    var request = getFunctionCallRequest(await _process.outbound.next);

    _process.inbound.add(InboundMessage()
      ..functionCallResponse = (InboundMessage_FunctionCallResponse()
        ..id = request.id
        ..success = (Value()
          ..number = (Value_Number()
            ..value = 1
            ..numerators.add("px")))));

    await expectLater(
        _process.outbound, emits(isSuccess(equals("a {\n  b: 3px;\n}"))));
    await _process.kill();
  });

  group("calls a first-class function", () {
    test("defined in the compiler and passed to and from the host", () async {
      _process.inbound.add(compileString(r"""
        @use "sass:math";
        @use "sass:meta";

        a {b: call(foo(meta.get-function("abs", $module: "math")), -1)}
      """, functions: [r"foo($arg)"]));

      var request = getFunctionCallRequest(await _process.outbound.next);
      var value = request.arguments.single;
      expect(value.hasCompilerFunction(), isTrue);
      _process.inbound.add(InboundMessage()
        ..functionCallResponse = (InboundMessage_FunctionCallResponse()
          ..id = request.id
          ..success = value));

      await expectLater(
          _process.outbound, emits(isSuccess(equals("a {\n  b: 1;\n}"))));
      await _process.kill();
    });

    test("defined in the host", () async {
      var compilationId = 1234;
      _process.inbound.add(compileString("a {b: call(foo(), true)}",
          id: compilationId, functions: [r"foo()"]));

      var hostFunctionId = 5678;
      var request = getFunctionCallRequest(await _process.outbound.next);
      _process.inbound.add(InboundMessage()
        ..functionCallResponse = (InboundMessage_FunctionCallResponse()
          ..id = request.id
          ..success = (Value()
            ..hostFunction = (Value_HostFunction()
              ..id = hostFunctionId
              ..signature = r"bar($arg)"))));

      request = getFunctionCallRequest(await _process.outbound.next);
      expect(request.compilationId, equals(compilationId));
      expect(request.functionId, equals(hostFunctionId));
      expect(request.arguments, equals([_true]));

      _process.inbound.add(InboundMessage()
        ..functionCallResponse = (InboundMessage_FunctionCallResponse()
          ..id = request.id
          ..success = _false));

      await expectLater(
          _process.outbound, emits(isSuccess(equals("a {\n  b: false;\n}"))));
      await _process.kill();
    });

    test("defined in the host and passed to and from the host", () async {
      var compilationId = 1234;
      _process.inbound.add(compileString(
          r"""
            $function: get-host-function();
            $function: round-trip($function);
            a {b: call($function, true)}
          """,
          id: compilationId,
          functions: [r"get-host-function()", r"round-trip($function)"]));

      var hostFunctionId = 5678;
      var request = getFunctionCallRequest(await _process.outbound.next);
      expect(request.name, equals("get-host-function"));
      _process.inbound.add(InboundMessage()
        ..functionCallResponse = (InboundMessage_FunctionCallResponse()
          ..id = request.id
          ..success = (Value()
            ..hostFunction = (Value_HostFunction()
              ..id = hostFunctionId
              ..signature = r"bar($arg)"))));

      request = getFunctionCallRequest(await _process.outbound.next);
      expect(request.name, equals("round-trip"));
      var value = request.arguments.single;
      expect(value.hasCompilerFunction(), isTrue);
      _process.inbound.add(InboundMessage()
        ..functionCallResponse = (InboundMessage_FunctionCallResponse()
          ..id = request.id
          ..success = value));

      request = getFunctionCallRequest(await _process.outbound.next);
      expect(request.compilationId, equals(compilationId));
      expect(request.functionId, equals(hostFunctionId));
      expect(request.arguments, equals([_true]));

      _process.inbound.add(InboundMessage()
        ..functionCallResponse = (InboundMessage_FunctionCallResponse()
          ..id = request.id
          ..success = _false));

      await expectLater(
          _process.outbound, emits(isSuccess(equals("a {\n  b: false;\n}"))));
      await _process.kill();
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
        var value = (await _protofy('1/1em')).number;
        expect(value.value, equals(1.0));
        expect(value.numerators, isEmpty);
        expect(value.denominators, ["em"]);
      });

      test("with multiple denominators", () async {
        var value = (await _protofy('1/1em/1px/1foo')).number;
        expect(value.value, equals(1.0));
        expect(value.numerators, isEmpty);
        expect(value.denominators, unorderedEquals(["em", "px", "foo"]));
      });

      test("with numerators and denominators", () async {
        var value = (await _protofy('1em * 1px/1s/1foo')).number;
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
              expect(await _protofy('hsl(0, 50, 50)'), _rgb(191, 64, 64, 1.0));
            });

            test("360", () async {
              expect(
                  await _protofy('hsl(360, 50, 50)'), _rgb(191, 64, 64, 1.0));
            });

            test("below 0", () async {
              expect(
                  await _protofy('hsl(-100, 50, 50)'), _rgb(106, 64, 191, 1.0));
            });

            test("between 0 and 360", () async {
              expect(
                  await _protofy('hsl(100, 50, 50)'), _rgb(106, 191, 64, 1.0));
            });

            test("above 360", () async {
              expect(
                  await _protofy('hsl(560, 50, 50)'), _rgb(64, 149, 191, 1.0));
            });
          });

          group("saturation", () {
            test("0", () async {
              expect(await _protofy('hsl(0, 0, 50)'), _rgb(128, 128, 128, 1.0));
            });

            test("100", () async {
              expect(await _protofy('hsl(0, 100, 50)'), _rgb(255, 0, 0, 1.0));
            });

            test("in the middle", () async {
              expect(await _protofy('hsl(0, 42, 50)'), _rgb(181, 74, 74, 1.0));
            });
          });

          group("lightness", () {
            test("0", () async {
              expect(await _protofy('hsl(0, 50, 0)'), _rgb(0, 0, 0, 1.0));
            });

            test("100", () async {
              expect(
                  await _protofy('hsl(0, 50, 100)'), _rgb(255, 255, 255, 1.0));
            });

            test("in the middle", () async {
              expect(await _protofy('hsl(0, 50, 42)'), _rgb(161, 54, 54, 1.0));
            });
          });
        });

        group("with alpha", () {
          test("0", () async {
            expect(await _protofy('hsl(10, 20, 30, 0)'),
                equals(_rgb(92, 66, 61, 0.0)));
          });

          test("1", () async {
            expect(await _protofy('hsl(10, 20, 30, 1)'),
                equals(_rgb(92, 66, 61, 1.0)));
          });

          test("between 0 and 1", () async {
            expect(await _protofy('hsl(10, 20, 30, 0.123)'),
                equals(_rgb(92, 66, 61, 0.123)));
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
            expect(list.separator, equals(Value_List_Separator.UNDECIDED));
          });

          test("with a comma separator", () async {
            var list =
                (await _protofy(r"list.join([], [], $separator: comma)")).list;
            expect(list.contents, isEmpty);
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(Value_List_Separator.COMMA));
          });

          test("with a space separator", () async {
            var list =
                (await _protofy(r"list.join([], [], $separator: space)")).list;
            expect(list.contents, isEmpty);
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(Value_List_Separator.SPACE));
          });
        });

        group("without brackets", () {
          test("with unknown separator", () async {
            var list = (await _protofy("()")).list;
            expect(list.contents, isEmpty);
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(Value_List_Separator.UNDECIDED));
          });

          test("with a comma separator", () async {
            var list =
                (await _protofy(r"list.join((), (), $separator: comma)")).list;
            expect(list.contents, isEmpty);
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(Value_List_Separator.COMMA));
          });

          test("with a space separator", () async {
            var list =
                (await _protofy(r"list.join((), (), $separator: space)")).list;
            expect(list.contents, isEmpty);
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(Value_List_Separator.SPACE));
          });
        });
      });

      group("with one element", () {
        group("with brackets", () {
          test("with unknown separator", () async {
            var list = (await _protofy("[true]")).list;
            expect(list.contents, equals([_true]));
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(Value_List_Separator.UNDECIDED));
          });

          test("with a comma separator", () async {
            var list = (await _protofy(r"[true,]")).list;
            expect(list.contents, equals([_true]));
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(Value_List_Separator.COMMA));
          });

          test("with a space separator", () async {
            var list =
                (await _protofy(r"list.join([true], [], $separator: space)"))
                    .list;
            expect(list.contents, equals([_true]));
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(Value_List_Separator.SPACE));
          });
        });

        group("without brackets", () {
          test("with a comma separator", () async {
            var list = (await _protofy(r"(true,)")).list;
            expect(list.contents, equals([_true]));
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(Value_List_Separator.COMMA));
          });

          test("with a space separator", () async {
            var list =
                (await _protofy(r"list.join(true, (), $separator: space)"))
                    .list;
            expect(list.contents, equals([_true]));
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(Value_List_Separator.SPACE));
          });
        });
      });

      group("with multiple elements", () {
        group("with brackets", () {
          test("with a comma separator", () async {
            var list = (await _protofy(r"[true, null, false]")).list;
            expect(list.contents, equals([_true, _null, _false]));
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(Value_List_Separator.COMMA));
          });

          test("with a space separator", () async {
            var list = (await _protofy(r"[true null false]")).list;
            expect(list.contents, equals([_true, _null, _false]));
            expect(list.hasBrackets, isTrue);
            expect(list.separator, equals(Value_List_Separator.SPACE));
          });
        });

        group("without brackets", () {
          test("with a comma separator", () async {
            var list = (await _protofy(r"true, null, false")).list;
            expect(list.contents, equals([_true, _null, _false]));
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(Value_List_Separator.COMMA));
          });

          test("with a space separator", () async {
            var list = (await _protofy(r"true null false")).list;
            expect(list.contents, equals([_true, _null, _false]));
            expect(list.hasBrackets, isFalse);
            expect(list.separator, equals(Value_List_Separator.SPACE));
          });
        });
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
              expect(await _deprotofy(_hsl(0, 50, 50, 1.0)), "#bf4040");
            });

            test("360", () async {
              expect(await _deprotofy(_hsl(360, 50, 50, 1.0)), "#bf4040");
            });

            test("below 0", () async {
              expect(await _deprotofy(_hsl(-100, 50, 50, 1.0)), "#6a40bf");
            });

            test("between 0 and 360", () async {
              expect(await _deprotofy(_hsl(100, 50, 50, 1.0)), "#6abf40");
            });

            test("above 360", () async {
              expect(await _deprotofy(_hsl(560, 50, 50, 1.0)), "#4095bf");
            });
          });

          group("saturation", () {
            test("0", () async {
              expect(await _deprotofy(_hsl(0, 0, 50, 1.0)), "gray");
            });

            test("100", () async {
              expect(await _deprotofy(_hsl(0, 100, 50, 1.0)), "red");
            });

            test("in the middle", () async {
              expect(await _deprotofy(_hsl(0, 42, 50, 1.0)), "#b54a4a");
            });
          });

          group("lightness", () {
            test("0", () async {
              expect(await _deprotofy(_hsl(0, 50, 0, 1.0)), "black");
            });

            test("100", () async {
              expect(await _deprotofy(_hsl(0, 50, 100, 1.0)), "white");
            });

            test("in the middle", () async {
              expect(await _deprotofy(_hsl(0, 50, 42, 1.0)), "#a13636");
            });
          });
        });

        group("with alpha", () {
          test("0", () async {
            expect(
                await _deprotofy(_hsl(10, 20, 30, 0.0)), "rgba(92, 66, 61, 0)");
          });

          test("between 0 and 1", () async {
            expect(await _deprotofy(_hsl(10, 20, 30, 0.123)),
                "rgba(92, 66, 61, 0.123)");
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
                    ..separator = Value_List_Separator.UNDECIDED),
                "[]");
          });

          group("with a comma separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..hasBrackets = true
                    ..separator = Value_List_Separator.COMMA),
                "[]");
          });

          group("with a space separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..hasBrackets = true
                    ..separator = Value_List_Separator.SPACE),
                "[]");
          });
        });

        group("without brackets", () {
          group("with unknown separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..hasBrackets = false
                    ..separator = Value_List_Separator.UNDECIDED),
                "()",
                inspect: true);
          });

          group("with a comma separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..hasBrackets = false
                    ..separator = Value_List_Separator.COMMA),
                "()",
                inspect: true);
          });

          group("with a space separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..hasBrackets = false
                    ..separator = Value_List_Separator.SPACE),
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
                    ..separator = Value_List_Separator.UNDECIDED),
                "[true]");
          });

          test("with a comma separator", () async {
            expect(
                await _deprotofy(
                    Value()
                      ..list = (Value_List()
                        ..contents.add(_true)
                        ..hasBrackets = true
                        ..separator = Value_List_Separator.COMMA),
                    inspect: true),
                "[true,]");
          });

          group("with a space separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..contents.add(_true)
                    ..hasBrackets = true
                    ..separator = Value_List_Separator.SPACE),
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
                    ..separator = Value_List_Separator.UNDECIDED),
                "true");
          });

          test("with a comma separator", () async {
            expect(
                await _deprotofy(
                    Value()
                      ..list = (Value_List()
                        ..contents.add(_true)
                        ..hasBrackets = false
                        ..separator = Value_List_Separator.COMMA),
                    inspect: true),
                "(true,)");
          });

          group("with a space separator", () {
            _testSerializationAndRoundTrip(
                Value()
                  ..list = (Value_List()
                    ..contents.add(_true)
                    ..hasBrackets = false
                    ..separator = Value_List_Separator.SPACE),
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
                        ..separator = Value_List_Separator.COMMA),
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
                        ..separator = Value_List_Separator.SPACE),
                    inspect: true),
                "[true null false]");
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
                        ..separator = Value_List_Separator.COMMA),
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
                        ..separator = Value_List_Separator.SPACE),
                    inspect: true),
                "true null false");
          });
        });
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
        test("with red above 255", () async {
          await _expectDeprotofyError(_rgb(256, 0, 0, 1.0),
              "RgbColor.red must be less than or equal to 255, was 256");
        });

        test("with green above 255", () async {
          await _expectDeprotofyError(_rgb(0, 256, 0, 1.0),
              "RgbColor.green must be less than or equal to 255, was 256");
        });

        test("with blue above 255", () async {
          await _expectDeprotofyError(_rgb(0, 0, 256, 1.0),
              "RgbColor.blue must be less than or equal to 255, was 256");
        });

        test("with RGB alpha below 0", () async {
          await _expectDeprotofyError(_rgb(0, 0, 0, -0.1),
              "RgbColor.alpha must be greater than or equal to 0, was -0.1");
        });

        test("with RGB alpha above 1", () async {
          await _expectDeprotofyError(_rgb(0, 0, 0, 1.1),
              "RgbColor.alpha must be less than or equal to 1, was 1.1");
        });

        test("with saturation below 0", () async {
          await _expectDeprotofyError(_hsl(0, -0.1, 0, 1.0),
              "HslColor.saturation must be greater than or equal to 0, was -0.1");
        });

        test("with saturation above 100", () async {
          await _expectDeprotofyError(
              _hsl(0, 100.1, 0, 1.0),
              "HslColor.saturation must be less than or equal to 100, was "
              "100.1");
        });

        test("with lightness below 0", () async {
          await _expectDeprotofyError(_hsl(0, 0, -0.1, 1.0),
              "HslColor.lightness must be greater than or equal to 0, was -0.1");
        });

        test("with lightness above 100", () async {
          await _expectDeprotofyError(
              _hsl(0, 0, 100.1, 1.0),
              "HslColor.lightness must be less than or equal to 100, was "
              "100.1");
        });

        test("with HSL alpha below 0", () async {
          await _expectDeprotofyError(_hsl(0, 0, 0, -0.1),
              "HslColor.alpha must be greater than or equal to 0, was -0.1");
        });

        test("with HSL alpha above 1", () async {
          await _expectDeprotofyError(_hsl(0, 0, 0, 1.1),
              "HslColor.alpha must be less than or equal to 1, was 1.1");
        });
      });

      test("a list with multiple elements and an unknown separator", () async {
        await _expectDeprotofyError(
            Value()
              ..list = (Value_List()
                ..contents.addAll([_true, _false])
                ..separator = Value_List_Separator.UNDECIDED),
            endsWith("can't have an undecided separator because it has 2 "
                "elements"));
      });
    });
  });
}

/// Evaluates [sassScript] in the compiler, passes it to a custom function, and
/// returns the protocol buffer result.
Future<Value> _protofy(String sassScript) async {
  _process.inbound.add(compileString("""
@use 'sass:list';
@use 'sass:map';

\$_: foo(($sassScript));
""", functions: [r"foo($arg)"]));
  var request = getFunctionCallRequest(await _process.outbound.next);
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
  _process.inbound.add(compileString(
      inspect ? "a {b: inspect(foo())}" : "a {b: foo()}",
      functions: [r"foo()"]));

  var request = getFunctionCallRequest(await _process.outbound.next);
  expect(request.arguments, isEmpty);
  _process.inbound.add(InboundMessage()
    ..functionCallResponse = (InboundMessage_FunctionCallResponse()
      ..id = request.id
      ..success = value));

  var success = await getCompileSuccess(await _process.outbound.next);
  expect(_process.kill(), completes);
  return RegExp(r"  b: (.*);").firstMatch(success.css)[1];
}

/// Asserts that [value] causes a parameter error with a message matching
/// [message] when deserializing it from a protocol buffer.
Future<void> _expectDeprotofyError(Value value, message) async {
  _process.inbound.add(compileString("a {b: foo()}", functions: [r"foo()"]));

  var request = getFunctionCallRequest(await _process.outbound.next);
  expect(request.arguments, isEmpty);
  _process.inbound.add(InboundMessage()
    ..functionCallResponse = (InboundMessage_FunctionCallResponse()
      ..id = request.id
      ..success = value));

  await expectParamsError(_process, -1, message);
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
  _process.inbound.add(compileString("""
\$_: outbound(inbound());
""", functions: ["inbound()", r"outbound($arg)"]));

  var request = getFunctionCallRequest(await _process.outbound.next);
  expect(request.arguments, isEmpty);
  _process.inbound.add(InboundMessage()
    ..functionCallResponse = (InboundMessage_FunctionCallResponse()
      ..id = request.id
      ..success = value));

  request = getFunctionCallRequest(await _process.outbound.next);
  expect(_process.kill(), completes);
  return request.arguments.single;
}

/// Returns a [Value] that's an RGB color with the given fields.
Value _rgb(int red, int green, int blue, double alpha) => Value()
  ..rgbColor = (Value_RgbColor()
    ..red = red
    ..green = green
    ..blue = blue
    ..alpha = alpha);

/// Returns a [Value] that's an HSL color with the given fields.
Value _hsl(num hue, num saturation, num lightness, double alpha) => Value()
  ..hslColor = (Value_HslColor()
    ..hue = hue * 1.0
    ..saturation = saturation * 1.0
    ..lightness = lightness * 1.0
    ..alpha = alpha);
