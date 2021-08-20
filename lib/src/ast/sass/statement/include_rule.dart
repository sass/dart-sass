// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../../utils.dart';
import '../../../visitor/interface/statement.dart';
import '../argument_invocation.dart';
import '../callable_invocation.dart';
import '../interface/reference.dart';
import '../statement.dart';
import 'content_block.dart';

/// A mixin invocation.
///
/// {@category AST}
@sealed
class IncludeRule implements Statement, CallableInvocation, SassReference {
  /// The namespace of the mixin being invoked, or `null` if it's invoked
  /// without a namespace.
  final String? namespace;

  /// The name of the mixin being invoked, with underscores converted to
  /// hyphens.
  final String name;

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
    var match = RegExp(r'(\+|@include)\s*').matchAsPrefix(span.text);
    var start = match!.end;
    if (namespace != null) start += namespace!.length + 1;
    return span.subspan(start, start + name.length);
  }

  FileSpan get namespaceSpan {
    var match = RegExp(r'(\+|@include)\s*').matchAsPrefix(span.text);
    var start = match!.end;
    return span.subspan(start, start + (namespace?.length ?? 0));
  }

  IncludeRule(this.name, this.arguments, this.span,
      {this.namespace, this.content});

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
