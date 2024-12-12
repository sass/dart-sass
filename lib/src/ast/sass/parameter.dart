// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../utils.dart';
import '../../util/span.dart';
import 'expression.dart';
import 'declaration.dart';
import 'node.dart';

/// An parameter declared as part of an [ParameterList].
///
/// {@category AST}
final class Parameter implements SassNode, SassDeclaration {
  /// The parameter name.
  final String name;

  /// The default value of this parameter, or `null` if none was declared.
  final Expression? defaultValue;

  final FileSpan span;

  /// The variable name as written in the document, without underscores
  /// converted to hyphens and including the leading `$`.
  ///
  /// This isn't particularly efficient, and should only be used for error
  /// messages.
  String get originalName =>
      defaultValue == null ? span.text : declarationName(span);

  FileSpan get nameSpan =>
      defaultValue == null ? span : span.initialIdentifier(includeLeading: 1);

  Parameter(this.name, this.span, {this.defaultValue});

  String toString() => defaultValue == null ? name : "$name: $defaultValue";
}
