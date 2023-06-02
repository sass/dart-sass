// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')

import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:source_maps/source_maps.dart' as source_maps;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:sass/src/embedded/embedded_sass.pb.dart';
import 'package:sass/src/embedded/utils.dart';

import 'embedded_process.dart';
import 'utils.dart';

void main() {
  late EmbeddedProcess process;
  setUp(() async {
    process = await EmbeddedProcess.start();
  });

  group("exits upon protocol error", () {
    test("caused by an empty message", () async {
      process.send(InboundMessage());
      await expectParseError(process, "InboundMessage.message is not set.");
      await process.shouldExit(76);
    });

    test("caused by an unterminated compilation ID varint", () async {
      process.stdin.add([1, 0x81]);
      await expectParseError(
          process, "Invalid compilation ID: continuation bit always set.",
          compilationId: errorId);
      await process.shouldExit(76);
    });

    test("caused by a 33-bit compilation ID varint", () async {
      var varint = serializeVarint(0x100000000);
      process.stdin.add([...serializeVarint(varint.length), ...varint]);
      await expectParseError(
          process, "Varint compilation ID was longer than 32 bits.",
          compilationId: errorId);
      await process.shouldExit(76);
    });

    test("caused by an invalid protobuf", () async {
      process.stdin.add([2, 1, 0]);
      await expectParseError(
          process, "Protocol message contained an invalid tag (zero).",
          compilationId: 1);
      await process.shouldExit(76);
    });

    test("caused by a response to an inactive compilation", () async {
      process.send(InboundMessage()
        ..canonicalizeResponse =
            (InboundMessage_CanonicalizeResponse()..id = 1));
      await expectParamsError(
          process,
          errorId,
          "Response ID 1 doesn't match any outstanding requests in "
          "compilation $defaultCompilationId.");
      await process.shouldExit(76);
    });

    test("caused by duplicate compilation IDs", () async {
      process.send(compileString("@import 'other'", importers: [
        InboundMessage_CompileRequest_Importer()..importerId = 1
      ]));
      await getCanonicalizeRequest(process);

      process.send(compileString("a {b: c}"));
      await expectParamsError(
          process,
          errorId,
          "A CompileRequest with compilation ID $defaultCompilationId is "
          "already active.");
      await process.shouldExit(76);
    });
  });

  test("a version response is valid", () async {
    process.inbound.add((
      0,
      InboundMessage()
        ..versionRequest = (InboundMessage_VersionRequest()..id = 123)
    ));
    var (compilationId, OutboundMessage(versionResponse: response)) =
        await process.outbound.next;
    expect(compilationId, equals(0));
    expect(response.id, equals(123));

    Version.parse(response.protocolVersion); // shouldn't throw
    Version.parse(response.compilerVersion); // shouldn't throw
    Version.parse(response.implementationVersion); // shouldn't throw
    expect(response.implementationName, equals("Dart Sass"));
    await process.kill();
  });

  group("compiles CSS from", () {
    test("an SCSS string by default", () async {
      process.send(compileString("a {b: 1px + 2px}"));
      await expectSuccess(process, "a { b: 3px; }");
      await process.kill();
    });

    test("an SCSS string explicitly", () async {
      process.send(compileString("a {b: 1px + 2px}", syntax: Syntax.SCSS));
      await expectSuccess(process, "a { b: 3px; }");
      await process.kill();
    });

    test("an indented syntax string", () async {
      process.send(compileString("a\n  b: 1px + 2px", syntax: Syntax.INDENTED));
      await expectSuccess(process, "a { b: 3px; }");
      await process.kill();
    });

    test("a plain CSS string", () async {
      process.send(compileString("a {b: c}", syntax: Syntax.CSS));
      await expectSuccess(process, "a { b: c; }");
      await process.kill();
    });

    test("an absolute path", () async {
      await d.file("test.scss", "a {b: 1px + 2px}").create();

      process.send(InboundMessage()
        ..compileRequest = (InboundMessage_CompileRequest()
          ..path = p.absolute(d.path("test.scss"))));
      await expectSuccess(process, "a { b: 3px; }");
      await process.kill();
    });

    test("a relative path", () async {
      await d.file("test.scss", "a {b: 1px + 2px}").create();

      process.send(InboundMessage()
        ..compileRequest = (InboundMessage_CompileRequest()
          ..path = p.relative(d.path("test.scss"))));
      await expectSuccess(process, "a { b: 3px; }");
      await process.kill();
    });
  });

  group("compiles CSS in", () {
    test("expanded mode", () async {
      process
          .send(compileString("a {b: 1px + 2px}", style: OutputStyle.EXPANDED));
      await expectSuccess(process, equals("a {\n  b: 3px;\n}"));
      await process.kill();
    });

    test("compressed mode", () async {
      process.send(
          compileString("a {b: 1px + 2px}", style: OutputStyle.COMPRESSED));
      await expectSuccess(process, equals("a{b:3px}"));
      await process.kill();
    });
  });

  group("exits when stdin is closed", () {
  test("immediately", () async {
    process.stdin.close();
    await process.shouldExit(0);
  });

  test("after compiling CSS", () async {
    process
        .send(compileString("a {b: 1px + 2px}"));
    await expectSuccess(process, equals("a {\n  b: 3px;\n}"));
    process.stdin.close();
    await process.shouldExit(0);
  });

  test("while compiling CSS", () async {
    process.send(compileString("a {b: foo() + 2px}", functions: [r"foo()"]));
    await getFunctionCallRequest(process);
    process.stdin.close();
    await process.shouldExit(0);
  });
});

  test("handles many concurrent compilation requests", () async {
    var totalRequests = 1000;
    for (var i = 1; i <= totalRequests; i++) {
      process.inbound
          .add((i, compileString("a {b: foo() + 2px}", functions: [r"foo()"])));
    }

    var successes = 0;
    process.outbound.rest.listen((pair) {
      var (compilationId, message) = pair;
      expect(compilationId,
          allOf(greaterThan(0), lessThanOrEqualTo(totalRequests)));

      if (message.hasFunctionCallRequest()) {
        process.inbound.add((
          compilationId,
          InboundMessage()
            ..functionCallResponse = (InboundMessage_FunctionCallResponse()
              ..id = message.functionCallRequest.id
              ..success = (Value()
                ..number = (Value_Number()
                  ..value = 1
                  ..numerators.add("px"))))
        ));
      } else if (message.hasCompileResponse()) {
        var response = message.compileResponse;
        expect(response.hasSuccess(), isTrue);
        expect(response.success.css, equalsIgnoringWhitespace("a { b: 3px; }"));

        successes++;
        if (successes == totalRequests) {
          process.kill();
        }
      } else {
        fail("Unexpected message ${message.toDebugString()}");
      }
    });
  });

  test("doesn't include a source map by default", () async {
    process.send(compileString("a {b: 1px + 2px}"));
    await expectSuccess(process, "a { b: 3px; }", sourceMap: isEmpty);
    await process.kill();
  });

  test("doesn't include a source map with source_map: false", () async {
    process.send(compileString("a {b: 1px + 2px}", sourceMap: false));
    await expectSuccess(process, "a { b: 3px; }", sourceMap: isEmpty);
    await process.kill();
  });

  test("includes a source map if source_map is true", () async {
    process.send(compileString("a {b: 1px + 2px}", sourceMap: true));
    await expectSuccess(process, "a { b: 3px; }", sourceMap: (String map) {
      var mapping = source_maps.parse(map);
      var span = mapping.spanFor(2, 5)!;
      expect(span.start.line, equals(0));
      expect(span.start.column, equals(3));
      expect(span.end, equals(span.start));
      expect(mapping, isA<source_maps.SingleMapping>());
      expect((mapping as source_maps.SingleMapping).files[0], isNull);
      return true;
    });
    await process.kill();
  });

  test(
      "includes a source map without content if source_map is true and source_map_include_sources is false",
      () async {
    process.send(compileString("a {b: 1px + 2px}",
        sourceMap: true, sourceMapIncludeSources: false));
    await expectSuccess(process, "a { b: 3px; }", sourceMap: (String map) {
      var mapping = source_maps.parse(map);
      var span = mapping.spanFor(2, 5)!;
      expect(span.start.line, equals(0));
      expect(span.start.column, equals(3));
      expect(span.end, equals(span.start));
      expect(mapping, isA<source_maps.SingleMapping>());
      expect((mapping as source_maps.SingleMapping).files[0], isNull);
      return true;
    });
    await process.kill();
  });

  test(
      "includes a source map with content if source_map is true and source_map_include_sources is true",
      () async {
    process.send(compileString("a {b: 1px + 2px}",
        sourceMap: true, sourceMapIncludeSources: true));
    await expectSuccess(process, "a { b: 3px; }", sourceMap: (String map) {
      var mapping = source_maps.parse(map);
      var span = mapping.spanFor(2, 5)!;
      expect(span.start.line, equals(0));
      expect(span.start.column, equals(3));
      expect(span.end, equals(span.start));
      expect(mapping, isA<source_maps.SingleMapping>());
      expect((mapping as source_maps.SingleMapping).files[0], isNotNull);
      return true;
    });
    await process.kill();
  });

  group("emits a log event", () {
    group("for a @debug rule", () {
      test("with correct fields", () async {
        process.send(compileString("a {@debug hello}"));

        var logEvent = await getLogEvent(process);
        expect(logEvent.type, equals(LogEventType.DEBUG));
        expect(logEvent.message, equals("hello"));
        expect(logEvent.span.text, equals("@debug hello"));
        expect(logEvent.span.start, equals(location(3, 0, 3)));
        expect(logEvent.span.end, equals(location(15, 0, 15)));
        expect(logEvent.span.context, equals("a {@debug hello}"));
        expect(logEvent.stackTrace, isEmpty);
        expect(logEvent.formatted, equals('-:1 DEBUG: hello\n'));
        await process.kill();
      });

      test("formatted with terminal colors", () async {
        process.send(compileString("a {@debug hello}", alertColor: true));
        var logEvent = await getLogEvent(process);
        expect(
            logEvent.formatted, equals('-:1 \u001b[1mDebug\u001b[0m: hello\n'));
        await process.kill();
      });
    });

    group("for a @warn rule", () {
      test("with correct fields", () async {
        process.send(compileString("a {@warn hello}"));

        var logEvent = await getLogEvent(process);
        expect(logEvent.type, equals(LogEventType.WARNING));
        expect(logEvent.message, equals("hello"));
        expect(logEvent.span, equals(SourceSpan()));
        expect(logEvent.stackTrace, equals("- 1:4  root stylesheet\n"));
        expect(
            logEvent.formatted,
            equals('WARNING: hello\n'
                '    - 1:4  root stylesheet\n'));
        await process.kill();
      });

      test("formatted with terminal colors", () async {
        process.send(compileString("a {@warn hello}", alertColor: true));
        var logEvent = await getLogEvent(process);
        expect(
            logEvent.formatted,
            equals('\x1B[33m\x1B[1mWarning\x1B[0m: hello\n'
                '    - 1:4  root stylesheet\n'));
        await process.kill();
      });

      test("encoded in ASCII", () async {
        process.send(compileString("a {@debug a && b}", alertAscii: true));
        var logEvent = await getLogEvent(process);
        expect(
            logEvent.formatted,
            equals('WARNING on line 1, column 13: \n'
                'In Sass, "&&" means two copies of the parent selector. You probably want to use "and" instead.\n'
                '  ,\n'
                '1 | a {@debug a && b}\n'
                '  |             ^^\n'
                '  \'\n'));
        await process.kill();
      });
    });

    test("for a parse-time deprecation warning", () async {
      process.send(compileString("@if true {} @elseif true {}"));

      var logEvent = await getLogEvent(process);
      expect(logEvent.type, equals(LogEventType.DEPRECATION_WARNING));
      expect(
          logEvent.message,
          equals(
              '@elseif is deprecated and will not be supported in future Sass '
              'versions.\n'
              '\n'
              'Recommendation: @else if'));
      expect(logEvent.span.text, equals("@elseif"));
      expect(logEvent.span.start, equals(location(12, 0, 12)));
      expect(logEvent.span.end, equals(location(19, 0, 19)));
      expect(logEvent.span.context, equals("@if true {} @elseif true {}"));
      expect(logEvent.stackTrace, isEmpty);
      await process.kill();
    });

    test("for a runtime deprecation warning", () async {
      process.send(compileString("a {\$var: value !global}"));

      var logEvent = await getLogEvent(process);
      expect(logEvent.type, equals(LogEventType.DEPRECATION_WARNING));
      expect(
          logEvent.message,
          equals("As of Dart Sass 2.0.0, !global assignments won't be able to "
              "declare new variables.\n"
              "\n"
              "Recommendation: add `\$var: null` at the stylesheet root."));
      expect(logEvent.span.text, equals("\$var: value !global"));
      expect(logEvent.span.start, equals(location(3, 0, 3)));
      expect(logEvent.span.end, equals(location(22, 0, 22)));
      expect(logEvent.span.context, equals("a {\$var: value !global}"));
      expect(logEvent.stackTrace, "- 1:4  root stylesheet\n");
      await process.kill();
    });
  });

  group("gracefully handles an error", () {
    test("from invalid syntax", () async {
      process.send(compileString("a {b: }"));

      var failure = await getCompileFailure(process);
      expect(failure.message, equals("Expected expression."));
      expect(failure.span.text, isEmpty);
      expect(failure.span.start, equals(location(6, 0, 6)));
      expect(failure.span.end, equals(location(6, 0, 6)));
      expect(failure.span.url, isEmpty);
      expect(failure.span.context, equals("a {b: }"));
      expect(failure.stackTrace, equals("- 1:7  root stylesheet\n"));
      await process.kill();
    });

    test("from the runtime", () async {
      process.send(compileString("a {b: 1px + 1em}"));

      var failure = await getCompileFailure(process);
      expect(failure.message, equals("1px and 1em have incompatible units."));
      expect(failure.span.text, "1px + 1em");
      expect(failure.span.start, equals(location(6, 0, 6)));
      expect(failure.span.end, equals(location(15, 0, 15)));
      expect(failure.span.url, isEmpty);
      expect(failure.span.context, equals("a {b: 1px + 1em}"));
      expect(failure.stackTrace, equals("- 1:7  root stylesheet\n"));
      await process.kill();
    });

    test("from a missing file", () async {
      process.send(InboundMessage()
        ..compileRequest =
            (InboundMessage_CompileRequest()..path = d.path("test.scss")));

      var failure = await getCompileFailure(process);
      expect(failure.message, startsWith("Cannot open file: "));
      expect(failure.message.replaceFirst("Cannot open file: ", "").trim(),
          equalsPath(d.path('test.scss')));
      expect(failure.span.text, equals(''));
      expect(failure.span.context, equals(''));
      expect(failure.span.start, equals(SourceSpan_SourceLocation()));
      expect(failure.span.end, equals(SourceSpan_SourceLocation()));
      expect(failure.span.url, equals(p.toUri(d.path('test.scss')).toString()));
      expect(failure.stackTrace, isEmpty);
      await process.kill();
    });

    test("with a multi-line source span", () async {
      process.send(compileString("""
a {
  b: 1px +
     1em;
}
"""));

      var failure = await getCompileFailure(process);
      expect(failure.span.text, "1px +\n     1em");
      expect(failure.span.start, equals(location(9, 1, 5)));
      expect(failure.span.end, equals(location(23, 2, 8)));
      expect(failure.span.url, isEmpty);
      expect(failure.span.context, equals("  b: 1px +\n     1em;\n"));
      expect(failure.stackTrace, equals("- 2:6  root stylesheet\n"));
      await process.kill();
    });

    test("with multiple stack trace entries", () async {
      process.send(compileString("""
@function fail() {
  @return 1px + 1em;
}

a {
  b: fail();
}
"""));

      var failure = await getCompileFailure(process);
      expect(
          failure.stackTrace,
          equals("- 2:11  fail()\n"
              "- 6:6   root stylesheet\n"));
      await process.kill();
    });

    group("and includes the URL from", () {
      test("a string input", () async {
        process.send(compileString("a {b: 1px + 1em}", url: "foo://bar/baz"));

        var failure = await getCompileFailure(process);
        expect(failure.span.url, equals("foo://bar/baz"));
        expect(
            failure.stackTrace, equals("foo://bar/baz 1:7  root stylesheet\n"));
        await process.kill();
      });

      test("a path input", () async {
        await d.file("test.scss", "a {b: 1px + 1em}").create();
        var path = d.path("test.scss");
        process.send(InboundMessage()
          ..compileRequest = (InboundMessage_CompileRequest()..path = path));

        var failure = await getCompileFailure(process);
        expect(p.fromUri(failure.span.url), equalsPath(path));
        expect(failure.stackTrace, endsWith(" 1:7  root stylesheet\n"));
        expect(failure.stackTrace.split(" ").first, equalsPath(path));
        await process.kill();
      });
    });

    test("caused by using Sass features in CSS", () async {
      process.send(compileString("a {b: 1px + 2px}", syntax: Syntax.CSS));

      var failure = await getCompileFailure(process);
      expect(failure.message, equals("Operators aren't allowed in plain CSS."));
      expect(failure.span.text, "+");
      expect(failure.span.start, equals(location(10, 0, 10)));
      expect(failure.span.end, equals(location(11, 0, 11)));
      expect(failure.span.url, isEmpty);
      expect(failure.span.context, equals("a {b: 1px + 2px}"));
      expect(failure.stackTrace, equals("- 1:11  root stylesheet\n"));
      await process.kill();
    });

    group("and provides a formatted", () {
      test("message", () async {
        process.send(compileString("a {b: 1px + 1em}"));

        var failure = await getCompileFailure(process);
        expect(
            failure.formatted,
            equals('Error: 1px and 1em have incompatible units.\n'
                '  ╷\n'
                '1 │ a {b: 1px + 1em}\n'
                '  │       ^^^^^^^^^\n'
                '  ╵\n'
                '  - 1:7  root stylesheet'));
        await process.kill();
      });

      test("message with terminal colors", () async {
        process.send(compileString("a {b: 1px + 1em}", alertColor: true));

        var failure = await getCompileFailure(process);
        expect(
            failure.formatted,
            equals('Error: 1px and 1em have incompatible units.\n'
                '\x1B[34m  ╷\x1B[0m\n'
                '\x1B[34m1 │\x1B[0m a {b: \x1B[31m1px + 1em\x1B[0m}\n'
                '\x1B[34m  │\x1B[0m \x1B[31m      ^^^^^^^^^\x1B[0m\n'
                '\x1B[34m  ╵\x1B[0m\n'
                '  - 1:7  root stylesheet'));
        await process.kill();
      });

      test("message with ASCII encoding", () async {
        process.send(compileString("a {b: 1px + 1em}", alertAscii: true));

        var failure = await getCompileFailure(process);
        expect(
            failure.formatted,
            equals('Error: 1px and 1em have incompatible units.\n'
                '  ,\n'
                '1 | a {b: 1px + 1em}\n'
                '  |       ^^^^^^^^^\n'
                '  \'\n'
                '  - 1:7  root stylesheet'));
        await process.kill();
      });
    });
  });
}
