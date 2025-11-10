// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../ast/sass.dart';
import '../../visitor/interface/interpolated_selector.dart';

/// A wrapper around a JS object that implements the [SelectorVisitor] methods
/// for simple selectors.
class JSSimpleSelectorVisitor implements InterpolatedSelectorVisitor<Object?> {
  final JSSimpleSelectorVisitorObject _inner;

  JSSimpleSelectorVisitor(this._inner);

  Object? visitAttributeSelector(InterpolatedAttributeSelector node) =>
      _inner.visitAttributeSelector(node);
  Object? visitClassSelector(InterpolatedClassSelector node) =>
      _inner.visitClassSelector(node);
  Object? visitIDSelector(InterpolatedIDSelector node) =>
      _inner.visitIDSelector(node);
  Object? visitParentSelector(InterpolatedParentSelector node) =>
      _inner.visitParentSelector(node);
  Object? visitPlaceholderSelector(InterpolatedPlaceholderSelector node) =>
      _inner.visitPlaceholderSelector(node);
  Object? visitPseudoSelector(InterpolatedPseudoSelector node) =>
      _inner.visitPseudoSelector(node);
  Object? visitTypeSelector(InterpolatedTypeSelector node) =>
      _inner.visitTypeSelector(node);
  Object? visitUniversalSelector(InterpolatedUniversalSelector node) =>
      _inner.visitUniversalSelector(node);

  Never visitSelectorList(_) => _simpleSelectorError();
  Never visitComplexSelector(_) => _simpleSelectorError();
  Never visitCompoundSelector(_) => _simpleSelectorError();

  /// Throws an error for non-simple selectors.
  Never _simpleSelectorError() => throw UnsupportedError(
      "SimpleSelectorVisitor only supports SimpleSelectors");
}

@JS()
class JSSimpleSelectorVisitorObject {
  external Object? visitAttributeSelector(InterpolatedAttributeSelector node);
  external Object? visitClassSelector(InterpolatedClassSelector node);
  external Object? visitIDSelector(InterpolatedIDSelector node);
  external Object? visitParentSelector(InterpolatedParentSelector node);
  external Object? visitPlaceholderSelector(
      InterpolatedPlaceholderSelector node);
  external Object? visitPseudoSelector(InterpolatedPseudoSelector node);
  external Object? visitTypeSelector(InterpolatedTypeSelector node);
  external Object? visitUniversalSelector(InterpolatedUniversalSelector node);
}
