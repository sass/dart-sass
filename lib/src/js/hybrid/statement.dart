// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../ast/sass/interpolation.dart';
import '../../ast/sass/statement.dart';
import '../../util/span.dart';
import '../../visitor/interface/statement.dart';

extension type JSStatement._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    ExtendRule(Interpolation.bogus, bogusSpan).toJS.constructor.superclass
      .defineMethod('accept'.toJS, ((JSStatement self, ExternalDartReference<StatementVisitor<JSAny?>> visitor) => self.toDart.accept(visitor.toDartObject)).toJS);
  }

  Statement get toDart => this as Statement;
}

extension StatementToJS on Statement {
  JSStatement get toJS => this as JSStatement;
}
