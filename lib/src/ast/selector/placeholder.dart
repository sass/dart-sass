// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// A placeholder selector.
///
/// This doesn't match any elements. It's intended to be extended using
/// `@extend`. It's not a plain CSS selector—it should be removed before
/// emitting a CSS document.
class PlaceholderSelector extends SimpleSelector {
  /// The name of the placeholder.
  final String name;

  bool get isInvisible => true;

  PlaceholderSelector(this.name);

  T accept<T>(SelectorVisitor<T> visitor) =>
      visitor.visitPlaceholderSelector(this);

  PlaceholderSelector addSuffix(String suffix) =>
      new PlaceholderSelector(name + suffix);

  bool operator ==(other) => other is PlaceholderSelector && other.name == name;

  int get hashCode => name.hashCode;
}
