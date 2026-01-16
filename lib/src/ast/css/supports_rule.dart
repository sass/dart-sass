// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import 'node.dart';
import 'value.dart';

/// A plain CSS `@supports` rule.
@sealed
abstract interface class CssSupportsRule implements CssParentNode {
  /// The supports condition.
  CssValue<String> get condition;
}
