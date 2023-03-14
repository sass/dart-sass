// Copyright 2023 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

/// A wrapper for [FileSpan] that allows an expensive creation process to be
/// deferred until the span is actually needed.
class LazyFileSpan implements FileSpan {
  /// The function that creates the underlying span.
  final FileSpan Function() _builder;

  /// The underlying span this wraps, which is created the first time this
  /// getter is referenced.
  FileSpan get span => _span ??= _builder();
  FileSpan? _span;

  /// Creates a new [LazyFileSpan] that defers calling [builder] until the
  /// underlying span is needed.
  LazyFileSpan(FileSpan Function() builder) : _builder = builder;

  @override
  int compareTo(SourceSpan other) => span.compareTo(other);

  @override
  String get context => span.context;

  @override
  FileLocation get end => span.end;

  @override
  FileSpan expand(FileSpan other) => span.expand(other);

  @override
  SourceFile get file => span.file;

  @override
  String highlight({color}) => span.highlight(color: color);

  @override
  int get length => span.length;

  @override
  String message(String message, {color}) =>
      span.message(message, color: color);

  @override
  Uri? get sourceUrl => span.sourceUrl;

  @override
  FileLocation get start => span.start;

  @override
  String get text => span.text;

  @override
  SourceSpan union(SourceSpan other) => span.union(other);
}
