// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/css.dart';
import '../../visitor/serialize.dart';
import '../node.dart';

/// A statement in a plain CSS syntax tree.
abstract class CssNode extends AstNode {
  /// Whether this was generated from the last node in a nested Sass tree that
  /// got flattened during evaluation.
  bool get isGroupEnd;

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(CssVisitor<T> visitor);

  String toString() => serialize(this, inspect: true).css;
}

// NOTE: New at-rule implementations should add themselves to [AtRootRule]'s
// exclude logic.
/// A [CssNode] that can have child statements.
abstract class CssParentNode extends CssNode {
  /// The child statements of this node.
  List<CssNode> get children;

  /// Whether the rule has no children and should be emitted without curly
  /// braces.
  ///
  /// This implies `children.isEmpty`, but the reverse is not true—for a rule
  /// like `@foo {}`, [children] is empty but [isChildless] is `false`.
  bool get isChildless;
}
