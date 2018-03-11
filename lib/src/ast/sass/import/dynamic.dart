// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../expression/string.dart';
import '../import.dart';

/// An import that will load a Sass file at runtime.
class DynamicImport implements Import {
  // TODO(nweiz): Make this a [Url] when dart-lang/sdk#32490 is fixed, or when
  // Node Sass imports no longer expose a leading `./`.
  /// The URI of the file to import.
  ///
  /// If this is relative, it's relative to the containing file.
  final String url;

  final FileSpan span;

  DynamicImport(this.url, this.span);

  String toString() => StringExpression.quoteText(url);
}
