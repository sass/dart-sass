// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:js_util';

import 'package:js/js.dart';
import 'package:test/test.dart';

import 'package:sass/src/io.dart';
import 'package:sass/src/node/function.dart';

import '../hybrid.dart';
import 'api.dart';

@JS('process.env')
external Object get _environment;

String sandbox;

void useSandbox() {
  setUp(() async {
    sandbox = await createTempDir();
  });

  tearDown(() async {
    if (sandbox != null) await deleteDirectory(sandbox);
  });
}

/// Validates that a [RenderError]'s `toString()` and `message` both equal
/// [text].
Matcher toStringAndMessageEqual(String text) => predicate((error) {
      expect(error.toString(), equals("Error: $text"));
      expect(error.message, equals(text));
      expect(error.formatted, equals("Error: $text"));
      return true;
    });

/// Returns the result of rendering via [options] as a string.
Future<String> render(RenderOptions options) {
  var completer = Completer<String>();
  sass.render(options,
      allowInterop(Zone.current.bindBinaryCallbackGuarded((error, result) {
    expect(error, isNull);
    completer.complete(utf8.decode(result.css));
  })));
  return completer.future;
}

/// Asserts that rendering via [options] produces an error, and returns that
/// error.
Future<RenderError> renderError(RenderOptions options) {
  var completer = Completer<RenderError>();
  sass.render(options,
      allowInterop(Zone.current.bindBinaryCallbackGuarded((error, result) {
    expect(result, isNull);
    completer.complete(error);
  })));
  return completer.future;
}

/// Returns the result of rendering via [options] as a string.
String renderSync(RenderOptions options) =>
    utf8.decode(sass.renderSync(options).css);

/// Like [renderSync], but goes through the untyped JS API.
///
/// This lets us test that we properly cast untyped collections without throwing
/// type errors.
String renderSyncJS(Map<String, Object> options) {
  var result = _renderSyncJS.call(sass, jsify(options)) as RenderResult;
  return utf8.decode(result.css);
}

final _renderSyncJS =
    JSFunction("sass", "args", "return sass.renderSync(args);");

/// Asserts that rendering via [options] produces an error, and returns that
/// error.
RenderError renderSyncError(RenderOptions options) {
  try {
    sass.renderSync(options);
  } catch (error) {
    return error as RenderError;
  }

  throw "Expected renderSync() to throw an error.";
}

/// Runs the rest of the test with the working directory in the sandbox
/// directory.
void runTestInSandbox() {
  // Make sure the module is loaded before we change the working directory.
  sass;

  var oldWorkingDirectory = currentPath;
  chdir(sandbox);
  addTearDown(() => chdir(oldWorkingDirectory));
}

/// Sets the environment variable [name] to [value] within this process.
void setEnvironmentVariable(String name, String value) {
  setProperty(_environment, name, value);
}

// Runs [callback] with the `SASS_PATH` environment variable set to [paths].
T withSassPath<T>(List<String> paths, T callback()) {
  setEnvironmentVariable("SASS_PATH", paths.join(isWindows ? ';' : ':'));

  try {
    return callback();
  } finally {
    setEnvironmentVariable("SASS_PATH", null);
  }
}
