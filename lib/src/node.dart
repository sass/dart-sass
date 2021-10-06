// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'node/exception.dart';
import 'node/exports.dart';
import 'node/compile.dart';
import 'node/legacy.dart';
import 'node/legacy/types.dart';
import 'node/legacy/value.dart';
import 'node/logger.dart';
import 'node/source_span.dart';
import 'node/utils.dart';
import 'value.dart';

/// The entrypoint for the Node.js module.
///
/// This sets up exports that can be called from JS.
void main() {
  if (const bool.fromEnvironment("new-js-api")) {
    exports.compile = allowInterop(compile);
    exports.compileString = allowInterop(compileString);
    exports.compileAsync = allowInterop(compileAsync);
    exports.compileStringAsync = allowInterop(compileStringAsync);
    exports.Exception = exceptionConstructor;
    exports.Logger = LoggerNamespace(
        silent: NodeLogger(
            warn: allowInterop((_, __) {}), debug: allowInterop((_, __) {})));
  }

  exports.info =
      "dart-sass\t${const String.fromEnvironment('version')}\t(Sass Compiler)\t"
      "[Dart]\n"
      "dart2js\t${const String.fromEnvironment('dart-version')}\t"
      "(Dart Compiler)\t[Dart]";

  updateSourceSpanPrototype();

  // Legacy API
  exports.render = allowInterop(render);
  exports.renderSync = allowInterop(renderSync);

  exports.types = Types(
      Boolean: booleanConstructor,
      Color: colorConstructor,
      List: listConstructor,
      Map: mapConstructor,
      Null: nullConstructor,
      Number: numberConstructor,
      String: stringConstructor,
      Error: jsErrorConstructor);
  exports.NULL = sassNull;
  exports.TRUE = sassTrue;
  exports.FALSE = sassFalse;
}
