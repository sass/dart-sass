// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../util/span.dart';
import 'expression.dart';
import 'declaration.dart';
import 'node.dart';

/// A variable configured by a `with` clause in a `@use` or `@forward` rule.
///
/// {@category AST}
final class ConfiguredVariable(
  /// The name of the variable being configured.
  @override final String name,

  /// The variable's value.
  final Expression expression,
  @override final FileSpan span, {
  bool guarded = false,
}) implements SassNode, SassDeclaration {
  /// Whether the variable can be further configured by outer modules.
  ///
  /// This is always `false` for `@use` rules.
  final bool isGuarded = guarded;

  @override
  FileSpan get nameSpan => span.initialIdentifier(includeLeading: 1);

  @override
  String toString() => "\$$name: $expression${isGuarded ? ' !default' : ''}";
}
