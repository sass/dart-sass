// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import 'interpolation.dart';
import 'node.dart';

/// An abstract class for defining the condition a `@supports` rule selects.
///
/// {@category AST}
abstract interface class SupportsCondition implements SassNode {
  /// Converts this condition into an interpolation that produces the same
  /// value.
  ///
  /// @nodoc
  @internal
  Interpolation toInterpolation();

  /// Returns a copy of this condition with [span] as its span.
  ///
  /// @nodoc
  @internal
  SupportsCondition withSpan(FileSpan span);
}
