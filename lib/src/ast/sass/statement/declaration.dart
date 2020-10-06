// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../expression.dart';
import '../interpolation.dart';
import '../statement.dart';
import 'parent.dart';

/// A declaration (that is, a `name: value` pair).
class Declaration extends ParentStatement {
  /// The name of this declaration.
  final Interpolation name;

  /// The value of this declaration.
  final Expression value;

  final FileSpan span;

  /// Returns whether this is a CSS Custom Property declaration.
  ///
  /// Note that this can return `false` for declarations that will ultimately be
  /// serialized as custom properties if they aren't *parsed as* custom
  /// properties, such as `#{--foo}: ...`.
  bool get isCustomProperty => name.initialPlain.startsWith('--');

  Declaration(this.name, this.span, {this.value, Iterable<Statement> children})
      : super(children = children == null ? null : List.unmodifiable(children));

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitDeclaration(this);
}
