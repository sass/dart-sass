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

  /// The span where the variable's configuration was written.
  final FileSpan configurationSpan;

  /// The [AstNode] where the variable's value originated.
  ///
  /// This is used to generate source maps and can be `null` if source map
  /// generation is disabled.
  final AstNode assignmentNode;

  ConfiguredValue(this.value, this.configurationSpan, [this.assignmentNode]);
}
