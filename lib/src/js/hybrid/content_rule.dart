// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../ast/sass/argument_list.dart';
import '../../ast/sass/statement/content_rule.dart';
import '../../util/span.dart';
import 'argument_list.dart';

extension ContentRuleToJS on ContentRule {
  /// Modifies the Dart type's JS prototype to provide access to Dart methods
  /// from JS.
  static void updatePrototype() {
    ContentRule(ArgumentList.bogus, bogusSpan).toJS.constructor.defineGetter(
        'arguments'.toJS,
        (UnsafeDartWrapper<ContentRule> self) => self.toDart.arguments.toJS);
  }

  UnsafeDartWrapper<ContentRule> get toJS => toUnsafeWrapper;
}
