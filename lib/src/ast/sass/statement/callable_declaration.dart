// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../argument_declaration.dart';
import '../statement.dart';
import 'parent.dart';
import 'silent_comment.dart';

/// An abstract class for callables (functions or mixins) that are declared in
/// user code.
abstract class CallableDeclaration extends ParentStatement {
  /// The name of this callable, with underscores converted to hyphens.
  ///
  /// This may be `null` for callables without names.
  final String name;

  /// The comment immediately preceding this declaration.
  final SilentComment comment;

  /// The declared arguments this callable accepts.
  final ArgumentDeclaration arguments;

  final FileSpan span;

  CallableDeclaration(
      this.name, this.arguments, Iterable<Statement> children, this.span,
      {SilentComment comment})
      : comment = comment,
        super(List.unmodifiable(children));
}
