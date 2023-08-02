// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// A selector that matches the parent in the Sass stylesheet.
///
/// This is not a plain CSS selector—it should be removed before emitting a CSS
/// document.
///
/// {@category AST}
final class ParentSelector extends SimpleSelector {
  /// The suffix that will be added to the parent selector after it's been
  /// resolved.
  ///
  /// This is assumed to be a valid identifier suffix. It may be `null`,
  /// indicating that the parent selector will not be modified.
  final String? suffix;

  ParentSelector(FileSpan span, {this.suffix}) : super(span);

  T accept<T>(SelectorVisitor<T> visitor) => visitor.visitParentSelector(this);

  /// @nodoc
  @internal
  List<SimpleSelector> unify(List<SimpleSelector> compound) =>
      throw UnsupportedError("& doesn't support unification.");
}
