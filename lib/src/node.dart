// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'node/exports.dart';
import 'node/legacy.dart';
import 'node/legacy/types.dart';
import 'node/legacy/value.dart';
import 'node/utils.dart';
import 'value.dart';

/// The entrypoint for the Node.js module.
///
/// This sets up exports that can be called from JS.
void main() {
  exports.render = allowInterop(render);
  exports.renderSync = allowInterop(renderSync);
  exports.info =
      "dart-sass\t${const String.fromEnvironment('version')}\t(Sass Compiler)\t"
      "[Dart]\n"
      "dart2js\t${const String.fromEnvironment('dart-version')}\t"
      "(Dart Compiler)\t[Dart]";

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
