// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../ast/sass/argument_list.dart';
import '../../ast/sass/statement/content_rule.dart';
import '../../util/span.dart';

extension type JSContentRule._(JSObject _) implements JSObject {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    ContentRule('a', ArgumentList.bogus, bogusSpan).toJS.constructor
      .defineGetter('arguments'.toJS, ((JSContentRule self) => self.toDart.arguments as JSObject).toJS);
  }

  ContentRule get toDart => this as ContentRule;
}

extension ContentRuleToJS on ContentRule {
  JSContentRule get toJS => this as JSContentRule;
}
