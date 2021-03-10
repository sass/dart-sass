// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../expression.dart';
import '../supports_condition.dart';

/// A condition that selects for browsers where a given declaration is
/// supported.
class SupportsDeclaration implements SupportsCondition {
  /// The name of the declaration being tested.
  final Expression/*!*/ name;

  /// The value of the declaration being tested.
  final Expression/*!*/ value;

  final FileSpan span;

  SupportsDeclaration(this.name, this.value, this.span);

  String toString() => "($name: $value)";
}
