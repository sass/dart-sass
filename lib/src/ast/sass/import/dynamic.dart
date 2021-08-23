// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../expression/string.dart';
import '../dependency.dart';
import '../import.dart';

/// An import that will load a Sass file at runtime.
///
/// {@category AST}
@sealed
class DynamicImport implements Import, SassDependency {
  /// The URL of the file to import.
  ///
  /// If this is relative, it's relative to the containing file.
  Uri get url => Uri.parse(urlString);

  // TODO(nweiz): Make this a [Url] when dart-lang/sdk#32490 is fixed, or when
  // Node Sass imports no longer expose a leading `./`.
  /// The URL of the file to import, as a string so that a leading `./` is
  /// visible for Node Sass imports.
  ///
  /// If this is relative, it's relative to the containing file.
  ///
  /// @nodoc
  @internal
  final String urlString;

  final FileSpan span;
  FileSpan get urlSpan => span;

  DynamicImport(this.urlString, this.span);

  String toString() => StringExpression.quoteText(urlString);
}
