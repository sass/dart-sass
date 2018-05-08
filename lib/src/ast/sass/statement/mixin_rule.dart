// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../argument_declaration.dart';
import '../statement.dart';
import 'callable_declaration.dart';

/// A mixin declaration.
///
/// This declares a mixin that's invoked using `@include`.
class MixinRule extends CallableDeclaration {
  /// Whether the mixin contains a `@content` rule.
  final bool hasContent;

  /// Creates a [MixinRule].
  ///
  /// It's important that the caller passes [hasContent] if the mixin
  /// recursively contains a `@content` rule. Otherwise, invoking this mixin
  /// won't work correctly.
  MixinRule(String name, ArgumentDeclaration arguments,
      Iterable<Statement> children, FileSpan span,
      {this.hasContent: false})
      : super(name, arguments, children, span);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitMixinRule(this);

  String toString() => "@mixin $name($arguments) {${children.join(' ')}}";
}
