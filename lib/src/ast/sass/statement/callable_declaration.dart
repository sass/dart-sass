// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../parameter_list.dart';
import '../statement.dart';
import 'parent.dart';
import 'silent_comment.dart';

/// An abstract class for callables (functions or mixins) that are declared in
/// user code.
///
/// {@category AST}
abstract base class CallableDeclaration
    extends ParentStatement<List<Statement>> {
  /// The name of this callable, with underscores converted to hyphens.
  final String name;

  /// The callable's original name, without underscores converted to hyphens.
  final String originalName;

  /// The comment immediately preceding this declaration.
  final SilentComment? comment;

  /// The declared parameters this callable accepts.
  final ParameterList parameters;

  final FileSpan span;

  CallableDeclaration(
    this.originalName,
    this.parameters,
    Iterable<Statement> children,
    this.span, {
    this.comment,
  })  : name = originalName.replaceAll('_', '-'),
        super(List.unmodifiable(children));
}
