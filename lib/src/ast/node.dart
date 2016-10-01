// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

/// A node in an abstract syntax tree.
abstract class AstNode {
  /// The source span associated with the node.
  ///
  /// This indicates where in the source Sass or SCSS stylesheet the node was
  /// defined.
  FileSpan get span;
}
