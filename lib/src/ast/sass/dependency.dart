// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import 'node.dart';

/// A common interface for [UseRule]s, [ForwardRule]s, and [DynamicImport]s.
///
/// {@category AST}
@sealed
abstract class SassDependency extends SassNode {
  /// The URL of the dependency this rule loads.
  Uri get url;

  /// The span of the URL for this dependency, including the quotes.
  FileSpan get urlSpan;
}
