// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../util/character.dart' as character;
import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// A placeholder selector.
///
/// This doesn't match any elements. It's intended to be extended using
/// `@extend`. It's not a plain CSS selector—it should be removed before
/// emitting a CSS document.
///
/// {@category AST}
@sealed
class PlaceholderSelector extends SimpleSelector {
  /// The name of the placeholder.
  final String name;

  /// Returns whether this is a private selector (that is, whether it begins
  /// with `-` or `_`).
  bool get isPrivate => character.isPrivate(name);

  PlaceholderSelector(this.name, FileSpan span) : super(span);

  T accept<T>(SelectorVisitor<T> visitor) =>
      visitor.visitPlaceholderSelector(this);

  /// @nodoc
  @internal
  PlaceholderSelector addSuffix(String suffix) =>
      PlaceholderSelector(name + suffix, span);

  bool operator ==(Object other) =>
      other is PlaceholderSelector && other.name == name;

  int get hashCode => name.hashCode;
}
