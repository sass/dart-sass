// Copyright 2020 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../interpolation.dart';
import '../supports_condition.dart';

/// A function-syntax condition.
class SupportsFunction implements SupportsCondition {
  /// The name of the function.
  final Interpolation name;

  /// The arguments to the function.
  final Interpolation arguments;

  final FileSpan span;

  SupportsFunction(this.name, this.arguments, this.span);

  String toString() => "$name($arguments)";
}
