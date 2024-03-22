// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../selector.dart';
import 'node.dart';

/// A plain CSS style rule.
///
/// This applies style declarations to elements that match a given selector.
/// Note that this isn't *strictly* plain CSS, since [selector] may still
/// contain placeholder selectors.
abstract interface class CssStyleRule implements CssParentNode {
  /// The selector for this rule.
  SelectorList get selector;

  /// The selector for this rule, before any extensions were applied.
  SelectorList get originalSelector;

  /// Whether this style rule was originally defined in a plain CSS stylesheet.
  ///
  /// :nodoc:
  @internal
  bool get fromPlainCss;
}
