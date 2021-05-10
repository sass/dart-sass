// Copyright 2019 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'ast/node.dart';
import 'value.dart';

/// A variable value that's been configured for a [Configuration].
class ConfiguredValue {
  /// The value of the variable.
  final Value value;

  /// The span where the variable's configuration was written, or `null` if this
  /// value was configured implicitly.
  final FileSpan? configurationSpan;

  /// The [AstNode] where the variable's value originated.
  final AstNode assignmentNode;

  /// Creates a variable value that's been configured explicitly with a `with`
  /// clause.
  ConfiguredValue.explicit(
      this.value, this.configurationSpan, this.assignmentNode);

  /// Creates a variable value that's implicitly configured by setting a
  /// variable prior to an `@import` of a file that contains a `@forward`.
  ConfiguredValue.implicit(this.value, this.assignmentNode)
      : configurationSpan = null;
}
