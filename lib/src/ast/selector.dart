// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../visitor/any_selector.dart';
import '../visitor/interface/selector.dart';
import '../visitor/serialize.dart';
import 'node.dart';
import 'selector/list.dart';
import 'selector/parent.dart';
import 'selector/placeholder.dart';
import 'selector/pseudo.dart';

export 'selector/attribute.dart';
export 'selector/class.dart';
export 'selector/combinator.dart';
export 'selector/complex.dart';
export 'selector/complex_component.dart';
export 'selector/compound.dart';
export 'selector/id.dart';
export 'selector/list.dart';
export 'selector/parent.dart';
export 'selector/placeholder.dart';
export 'selector/pseudo.dart';
export 'selector/qualified_name.dart';
export 'selector/simple.dart';
export 'selector/type.dart';
export 'selector/universal.dart';

/// A node in the abstract syntax tree for a selector.
///
/// This selector tree is mostly plain CSS, but also may contain a
/// [ParentSelector] or a [PlaceholderSelector].
///
/// Selectors have structural equality semantics.
///
/// {@category AST}
abstract base class Selector implements AstNode {
  /// Whether this selector, and complex selectors containing it, should not be
  /// emitted.
  ///
  /// @nodoc
  @internal
  bool get isInvisible => accept(const _IsInvisibleVisitor());

  /// Whether this selector contains a [ParentSelector].
  ///
  /// @nodoc
  @internal
  bool get containsParentSelector =>
      accept(const _ContainsParentSelectorVisitor());

  final FileSpan span;

  Selector(this.span);

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(SelectorVisitor<T> visitor);

  String toString() => serializeSelector(this, inspect: true);
}

/// The visitor used to implement [Selector.isInvisible].
final class _IsInvisibleVisitor with AnySelectorVisitor {
  const _IsInvisibleVisitor();

  bool visitSelectorList(SelectorList list) =>
      list.components.every(visitComplexSelector);

  bool visitPlaceholderSelector(PlaceholderSelector placeholder) => true;

  bool visitPseudoSelector(PseudoSelector pseudo) {
    if (pseudo.selector case var selector?) {
      // We don't consider `:not(%foo)` to be invisible because, semantically,
      // it means "doesn't match this selector that matches nothing", so it's
      // equivalent to *. If the entire compound selector is composed of `:not`s
      // with invisible lists, the serializer emits it as `*`.
      return pseudo.name != 'not' && selector.accept(this);
    } else {
      return false;
    }
  }
}

/// The visitor used to implement [Selector.containsParentSelector].
final class _ContainsParentSelectorVisitor with AnySelectorVisitor {
  const _ContainsParentSelectorVisitor();

  bool visitParentSelector(ParentSelector _) => true;
}
