// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../visitor/every_css.dart';
import '../../visitor/interface/css.dart';
import '../../visitor/serialize.dart';
import '../node.dart';
import 'at_rule.dart';
import 'comment.dart';
import 'style_rule.dart';

/// A statement in a plain CSS syntax tree.
abstract class CssNode extends AstNode {
  /// Whether this was generated from the last node in a nested Sass tree that
  /// got flattened during evaluation.
  bool get isGroupEnd;

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(CssVisitor<T> visitor);

  /// Whether this is invisible and won't be emitted to the compiled stylesheet.
  ///
  /// Note that this doesn't consider nodes that contain loud comments to be
  /// invisible even though they're omitted in compressed mode.
  @internal
  bool get isInvisible => accept(
      const _IsInvisibleVisitor(includeBogus: true, includeComments: false));

  // Whether this node would be invisible even if style rule selectors within it
  // didn't have bogus combinators.
  ///
  /// Note that this doesn't consider nodes that contain loud comments to be
  /// invisible even though they're omitted in compressed mode.
  @internal
  bool get isInvisibleOtherThanBogusCombinators => accept(
      const _IsInvisibleVisitor(includeBogus: false, includeComments: false));

  // Whether this node will be invisible when loud comments are stripped.
  @internal
  bool get isInvisibleHidingComments => accept(
      const _IsInvisibleVisitor(includeBogus: true, includeComments: true));

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

/// The visitor used to implement [CssNode.isInvisible]
class _IsInvisibleVisitor extends EveryCssVisitor {
  /// Whether to consider selectors with bogus combinators invisible.
  final bool includeBogus;

  /// Whether to consider comments invisible.
  final bool includeComments;

  const _IsInvisibleVisitor(
      {required this.includeBogus, required this.includeComments});

  // An unknown at-rule is never invisible. Because we don't know the semantics
  // of unknown rules, we can't guarantee that (for example) `@foo {}` isn't
  // meaningful.
  bool visitCssAtRule(CssAtRule rule) => false;

  bool visitCssComment(CssComment comment) =>
      includeComments && !comment.isPreserved;

  bool visitCssStyleRule(CssStyleRule rule) =>
      (includeBogus
          ? rule.selector.value.isInvisible
          : rule.selector.value.isInvisibleOtherThanBogusCombinators) ||
      super.visitCssStyleRule(rule);
}
