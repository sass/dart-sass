// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';

import 'package:js/js.dart';
import 'package:test/test.dart';

import 'package:sass/src/util/path.dart';

import '../ensure_npm_package.dart';
import '../hybrid.dart';
import 'api.dart';

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
      return true;
    });

/// Returns the result of rendering via [options] as a string.
Future<String> render(RenderOptions options) {
  var completer = new Completer<String>();
  sass.render(options,
      allowInterop(Zone.current.bindBinaryCallback((error, result) {
    expect(error, isNull);
    completer.complete(UTF8.decode(result.css));
  })));
  return completer.future;
}

/// Asserts that rendering via [options] produces an error, and returns that
/// error.
Future<RenderError> renderError(RenderOptions options) {
  var completer = new Completer<RenderError>();
  sass.render(options,
      allowInterop(Zone.current.bindBinaryCallback((error, result) {
    expect(result, isNull);
    completer.complete(error);
  })));
  return completer.future;
}

/// Returns the result of rendering via [options] as a string.
String renderSync(RenderOptions options) =>
    UTF8.decode(sass.renderSync(options).css);

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
