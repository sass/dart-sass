// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:sass_embedded/src/embedded_sass.pb.dart';

import 'embedded_process.dart';

/// Whether [ensureExecutableUpToDate] has been called.
var _ensuredExecutableUpToDate = false;

/// Returns the path to the executable to execute.
///
/// This may be a raw Dart executable, a script snapshot that ends in
/// `.snapshot`, or a native-code snapshot that ends in `.native`.
final String executablePath = () {
  expect(_ensuredExecutableUpToDate, isTrue,
      reason:
          "ensureExecutableUpToDate() must be called at top of the test file.");

  var nativeSnapshot = "build/dart_sass_embedded.dart.native";
  if (File(nativeSnapshot).existsSync()) return nativeSnapshot;

  var bytecodeSnapshot = "build/dart_sass_embedded.dart.snapshot";
  if (File(bytecodeSnapshot).existsSync()) return bytecodeSnapshot;

  return "bin/dart_sass_embedded.dart";
}();

/// Creates a [setUpAll] that verifies that the compiled form of the migrator
/// executable is up-to-date, if necessary.
///
/// This should always be called before [runMigrator].
void ensureExecutableUpToDate() {
  setUpAll(() {
    _ensuredExecutableUpToDate = true;

    if (!executablePath.endsWith(".dart")) {
      _ensureUpToDate(
          executablePath,
          "pub run grinder protobuf "
          "pkg-compile-${Platform.isWindows ? 'snapshot' : 'native'}");
    }
  });
}

/// Ensures that [path] (usually a compilation artifact) has been modified more
/// recently than all this package's source files.
///
/// If [path] isn't up-to-date, this throws an error encouraging the user to run
/// [commandToRun].
void _ensureUpToDate(String path, String commandToRun) {
  // Ensure path is relative so the error messages are more readable.
  path = p.relative(path);
  if (!File(path).existsSync()) {
    throw "$path does not exist. Run $commandToRun.";
  }

  var lastModified = File(path).lastModifiedSync();
  var entriesToCheck = Directory("lib").listSync(recursive: true).toList();

  // If we have a dependency override, "pub run" will touch the lockfile to mark
  // it as newer than the pubspec, which makes it unsuitable to use for
  // freshness checking.
  if (File("pubspec.yaml")
      .readAsStringSync()
      .contains("dependency_overrides")) {
    entriesToCheck.add(File("pubspec.yaml"));
  } else {
    entriesToCheck.add(File("pubspec.lock"));
  }

  for (var entry in entriesToCheck) {
    if (entry is File) {
      var entryLastModified = entry.lastModifiedSync();
      if (lastModified.isBefore(entryLastModified)) {
        throw "${entry.path} was modified after ${p.prettyUri(p.toUri(path))} "
            "was generated.\n"
            "Run $commandToRun.";
      }
    }
  }
}

/// Returns a [InboundMessage] that compiles the given plain CSS
/// string.
InboundMessage compileString(String css) => InboundMessage()
  ..compileRequest = (InboundMessage_CompileRequest()
    ..string = (InboundMessage_CompileRequest_StringInput()..source = css));

/// Asserts that [process] emits a [ProtocolError] parse error with the given
/// [message] on its protobuf stream and prints a notice on stderr.
Future<void> expectParseError(EmbeddedProcess process, message) async {
  await expectLater(process.outbound,
      emits(isProtocolError(-1, ProtocolError_ErrorType.PARSE, message)));
  await expectLater(process.stderr, emits("Host caused parse error: $message"));
}

/// Asserts that an [OutboundMessage] is a [ProtocolError] with the given [id],
/// [type], and optionally [message].
Matcher isProtocolError(int id, ProtocolError_ErrorType type, [message]) =>
    predicate((value) {
      expect(value, isA<OutboundMessage>());
      var outboundMessage = value as OutboundMessage;
      expect(outboundMessage.hasError(), isTrue,
          reason: "Expected $message to be a ProtocolError");
      expect(outboundMessage.error.id, equals(id));
      expect(outboundMessage.error.type, equals(type));
      if (message != null) expect(outboundMessage.error.message, message);
      return true;
    });

/// Asserts that [message] is an [OutboundMessage] with a [CompileResponse] and
/// returns it.
OutboundMessage_CompileResponse getCompileResponse(value) {
  expect(value, isA<OutboundMessage>());
  var message = value as OutboundMessage;
  expect(message.hasCompileResponse(), isTrue,
      reason: "Expected $message to have a CompileResponse");
  return message.compileResponse;
}

/// Asserts that an [OutboundMessage] is a [CompileResponse] with CSS that
/// matches [css].
///
/// If [css] is a [String], this automatically wraps it in
/// [equalsIgnoringWhitespace].
Matcher isSuccess(css) => predicate((value) {
      var response = getCompileResponse(value);
      expect(response.hasSuccess(), isTrue,
          reason: "Expected $response to be successful");
      expect(response.success.css,
          css is String ? equalsIgnoringWhitespace(css) : css);
      return true;
    });
