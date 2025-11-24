// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../ast/sass.dart';

/// An interface for [visitors] that traverse interpolated selectors.
///
/// [visitors]: https://en.wikipedia.org/wiki/Visitor_pattern
///
/// {@category Visitor}
abstract interface class InterpolatedSelectorVisitor<T> {
  T visitAttributeSelector(InterpolatedAttributeSelector attribute);
  T visitClassSelector(InterpolatedClassSelector klass);
  T visitComplexSelector(InterpolatedComplexSelector complex);
  T visitCompoundSelector(InterpolatedCompoundSelector compound);
  T visitIDSelector(InterpolatedIDSelector id);
  T visitParentSelector(InterpolatedParentSelector placeholder);
  T visitPlaceholderSelector(InterpolatedPlaceholderSelector placeholder);
  T visitPseudoSelector(InterpolatedPseudoSelector pseudo);
  T visitSelectorList(InterpolatedSelectorList list);
  T visitTypeSelector(InterpolatedTypeSelector type);
  T visitUniversalSelector(InterpolatedUniversalSelector universal);
}
