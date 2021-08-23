// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../util/span.dart';
import 'expression.dart';
import 'declaration.dart';
import 'node.dart';

/// A variable configured by a `with` clause in a `@use` or `@forward` rule.
///
/// {@category AST}
@sealed
class ConfiguredVariable implements SassNode, SassDeclaration {
  /// The name of the variable being configured.
  final String name;

  /// The variable's value.
  final Expression expression;

  /// Whether the variable can be further configured by outer modules.
  ///
  /// This is always `false` for `@use` rules.
  final bool isGuarded;

  final FileSpan span;

  FileSpan get nameSpan => span.initialIdentifier(includeLeading: 1);

  ConfiguredVariable(this.name, this.expression, this.span,
      {bool guarded = false})
      : isGuarded = guarded;

  String toString() => "\$$name: $expression${isGuarded ? ' !default' : ''}";
}
