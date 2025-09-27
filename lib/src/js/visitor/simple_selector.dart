// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../ast/selector.dart';
import '../../visitor/interface/selector.dart';

/// A wrapper around a JS object that implements the [SelectorVisitor] methods
/// for simple selectors.
class JSSimpleSelectorVisitor implements SelectorVisitor<Object?> {
  final JSSimpleSelectorVisitorObject _inner;

  JSSimpleSelectorVisitor(this._inner);

  Object? visitAttributeSelector(AttributeSelector node) =>
      _inner.visitAttributeSelector(node);
  Object? visitClassSelector(ClassSelector node) =>
      _inner.visitClassSelector(node);
  Object? visitIDSelector(IDSelector node) => _inner.visitIDSelector(node);
  Object? visitParentSelector(ParentSelector node) =>
      _inner.visitParentSelector(node);
  Object? visitPlaceholderSelector(PlaceholderSelector node) =>
      _inner.visitPlaceholderSelector(node);
  Object? visitPseudoSelector(PseudoSelector node) =>
      _inner.visitPseudoSelector(node);
  Object? visitTypeSelector(TypeSelector node) =>
      _inner.visitTypeSelector(node);
  Object? visitUniversalSelector(UniversalSelector node) =>
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
  external Object? visitAttributeSelector(AttributeSelector node);
  external Object? visitClassSelector(ClassSelector node);
  external Object? visitIDSelector(IDSelector node);
  external Object? visitParentSelector(ParentSelector node);
  external Object? visitPlaceholderSelector(PlaceholderSelector node);
  external Object? visitPseudoSelector(PseudoSelector node);
  external Object? visitTypeSelector(TypeSelector node);
  external Object? visitUniversalSelector(UniversalSelector node);
}
