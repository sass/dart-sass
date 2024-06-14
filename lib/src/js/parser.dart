// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: non_constant_identifier_names
// See dart-lang/sdk#47374

import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import '../ast/sass.dart';
import '../logger.dart';
import '../logger/js_to_dart.dart';
import '../syntax.dart';
import '../util/nullable.dart';
import '../util/span.dart';
import 'logger.dart';
import 'reflection.dart';

@JS()
@anonymous
class ParserExports {
  external factory ParserExports({required Function parse, required JSClass StyleRule});

  external set parse(Function function);
  external set StyleRule(JSClass klass);
}

/// Loads and etrurns all the exports needed for the `sass-parser` package.
ParserExports loadParserExports() {
  _updateAstPrototypes();
  return ParserExports(parse: allowInterop(_parse), StyleRule: getJSClass(StyleRule(Interpolation(const [], bogusSpan), const [], bogusSpan)));
}

/// Modifies the prototypes of the Sass AST classes to provide access to JS.
///
/// This API is not intended to be used directly to end users and is subject to
/// breaking changes without notice. Instead, it's wrapped by the `sass-parser`
/// package which exposes a PostCSS-style API.
void _updateAstPrototypes() {
  // We don't need explicit getters for field names, becuase dart2js preserves
  // them as-is, so we actually need to expose very little to JS manually.
  var file = SourceFile.fromString('');
  getJSClass(file).defineMethod('getText', (SourceFile self, int start, [int? end]) => self.getText(start, end));
  getJSClass(Interpolation(const [], bogusSpan)).defineGetter('asPlain', (Interpolation self) => self.asPlain);
}

/// A JavaScript-friendly method to parse a stylesheet.
Stylesheet _parse(String css, String syntax, String? path, JSLogger? logger) =>
    Stylesheet.parse(
        css,
        switch (syntax) {
          'scss' => Syntax.scss,
          'sass' => Syntax.sass,
          'css' => Syntax.css,
          _ => throw UnsupportedError('Unknown syntax "$syntax"')
        },
        url: path.andThen(p.toUri),
        logger: JSToDartLogger(logger, Logger.stderr()));
