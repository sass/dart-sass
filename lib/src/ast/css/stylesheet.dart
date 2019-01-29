// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/css.dart';
import 'node.dart';

/// A plain CSS stylesheet.
///
/// This is the root plain CSS node. It contains top-level statements.
class CssStylesheet extends CssParentNode {
  final List<CssNode> children;
  final FileSpan span;
  bool get isGroupEnd => false;
  bool get isChildless => false;

  /// Creates an unmodifiable stylesheet containing [children].
  CssStylesheet(Iterable<CssNode> children, this.span)
      : children = List.unmodifiable(children);

  T accept<T>(CssVisitor<T> visitor) => visitor.visitStylesheet(this);
}
