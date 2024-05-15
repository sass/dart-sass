// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../util/span.dart';
import '../../../visitor/interface/statement.dart';
import '../argument_invocation.dart';
import '../callable_invocation.dart';
import '../reference.dart';
import '../statement.dart';
import 'content_block.dart';

/// A mixin invocation.
///
/// {@category AST}
final class IncludeRule
    implements Statement, CallableInvocation, SassReference {
  /// The namespace of the mixin being invoked, or `null` if it's invoked
  /// without a namespace.
  final String? namespace;

  /// The name of the mixin being invoked, with underscores converted to
  /// hyphens.
  final String name;

  /// The original name of the mixin being invoked, without underscores
  /// converted to hyphens.
  final String originalName;

  /// The arguments to pass to the mixin.
  final ArgumentInvocation arguments;

  /// The block that will be invoked for [ContentRule]s in the mixin being
  /// invoked, or `null` if this doesn't pass a content block.
  final ContentBlock? content;

  final FileSpan span;

  /// Returns this include's span, without its content block (if it has one).
  FileSpan get spanWithoutContent => content == null
      ? span
      : span.file.span(span.start.offset, arguments.span.end.offset).trim();

  FileSpan get nameSpan {
    var startSpan = span.text.startsWith('+')
        ? span.subspan(1).trimLeft()
        : span.withoutInitialAtRule();
    if (namespace != null) startSpan = startSpan.withoutNamespace();
    return startSpan.initialIdentifier();
  }

  FileSpan? get namespaceSpan {
    if (namespace == null) return null;
    var startSpan = span.text.startsWith('+')
        ? span.subspan(1).trimLeft()
        : span.withoutInitialAtRule();
    return startSpan.initialIdentifier();
  }

  IncludeRule(this.originalName, this.arguments, this.span,
      {this.namespace, this.content})
      : name = originalName.replaceAll('_', '-');

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitIncludeRule(this);

  String toString() {
    var buffer = StringBuffer("@include ");
    if (namespace != null) buffer.write("$namespace.");
    buffer.write(name);
    if (!arguments.isEmpty) buffer.write("($arguments)");
    buffer.write(content == null ? ";" : " $content");
    return buffer.toString();
  }
}
