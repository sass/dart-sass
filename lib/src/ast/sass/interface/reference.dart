// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../node.dart';

/// A common interface any node that references a Sass member.
///
/// {@category AST}
@sealed
abstract class SassReference extends SassNode {
  /// The namespace of the member being referenced, or `null` if it's referenced
  /// without a namespace.
  String? get namespace;

  /// The name of the member being referenced, with underscores converted to
  /// hyphens.
  ///
  /// For [VariableExpression]s and [IncludeRule]s, this will never be null.
  /// For [FunctionExpression]s, this will be null if the actual name is an
  /// interpolation (in which case this is a plain CSS function, not a reference
  /// to a Sass function).
  ///
  /// This does not include the `$` for variables.
  String? get name;

  /// The span containing this reference's name.
  ///
  /// For variables, this should include the `$`.
  FileSpan get nameSpan;

  /// The span containing this reference's namespace, or an empty span
  /// immediately before the name if the namespace is null.
  FileSpan get namespaceSpan;
}
