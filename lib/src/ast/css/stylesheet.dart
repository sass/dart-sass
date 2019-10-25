// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';
import 'dart:math';

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

  // TODO(nbehrens): How to avoid duplicating the impl here and in
  // CssParentNode?  I really want to define this impl in CssParentNode
  // and have everyone that extends/implements CssParentNode inherit the
  // implementation... but that doesn't seem to work.
  FileSpan get beforeChildren {
    var endOffsetInclusive = max(0, this.span.text.indexOf('{') - 1);
    return this.span.file.span(
        this.span.start.offset, this.span.start.offset + endOffsetInclusive);
  }

  /// Creates an unmodifiable stylesheet containing [children].
  CssStylesheet(Iterable<CssNode> children, this.span)
      // Use [UnmodifiableListView] rather than [List.unmodifiable] because
      // the underlying nodes are mutable anyway, so it's better to have the
      // whole thing consistently represent mutation of the underlying data.
      : children = UnmodifiableListView(children);

  /// Creates an empty stylesheet with the given source URL.
  CssStylesheet.empty({url})
      : children = const [],
        span = SourceFile.decoded(const [], url: url).span(0, 0);

  T accept<T>(CssVisitor<T> visitor) => visitor.visitCssStylesheet(this);
}
