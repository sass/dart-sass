// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../deprecation.dart';
import '../evaluation_context.dart';
import '../exception.dart';
import '../visitor/any_selector.dart';
import '../visitor/interface/selector.dart';
import '../visitor/serialize.dart';
import 'node.dart';
import 'selector/complex.dart';
import 'selector/list.dart';
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
  bool get isInvisible => accept(const _IsInvisibleVisitor(includeBogus: true));

  // Whether this selector would be invisible even if it didn't have bogus
  // combinators.
  ///
  /// @nodoc
  @internal
  bool get isInvisibleOtherThanBogusCombinators =>
      accept(const _IsInvisibleVisitor(includeBogus: false));

  /// Whether this selector is not valid CSS.
  ///
  /// This includes both selectors that are useful exclusively for build-time
  /// nesting (`> .foo)` and selectors with invalid combiantors that are still
  /// supported for backwards-compatibility reasons (`.foo + ~ .bar`).
  bool get isBogus =>
      accept(const _IsBogusVisitor(includeLeadingCombinator: true));

  /// Whether this selector is bogus other than having a leading combinator.
  ///
  /// @nodoc
  @internal
  bool get isBogusOtherThanLeadingCombinator =>
      accept(const _IsBogusVisitor(includeLeadingCombinator: false));

  /// Whether this is a useless selector (that is, it's bogus _and_ it can't be
  /// transformed into valid CSS by `@extend` or nesting).
  ///
  /// @nodoc
  @internal
  bool get isUseless => accept(const _IsUselessVisitor());

  final FileSpan span;

  Selector(this.span);

  /// Prints a warning if [this] is a bogus selector.
  ///
  /// This may only be called from within a custom Sass function. This will
  /// throw a [SassException] in Dart Sass 2.0.0.
  void assertNotBogus({String? name}) {
    if (!isBogus) return;
    warnForDeprecation(
        (name == null ? '' : '\$$name: ') +
            '$this is not valid CSS.\n'
                'This will be an error in Dart Sass 2.0.0.\n'
                '\n'
                'More info: https://sass-lang.com/d/bogus-combinators',
        Deprecation.bogusCombinators);
  }

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(SelectorVisitor<T> visitor);

  String toString() => serializeSelector(this, inspect: true);
}

/// The visitor used to implement [Selector.isInvisible].
class _IsInvisibleVisitor with AnySelectorVisitor {
  /// Whether to consider selectors with bogus combinators invisible.
  final bool includeBogus;

  const _IsInvisibleVisitor({required this.includeBogus});

  bool visitSelectorList(SelectorList list) =>
      list.components.every(visitComplexSelector);

  bool visitComplexSelector(ComplexSelector complex) =>
      super.visitComplexSelector(complex) ||
      (includeBogus && complex.isBogusOtherThanLeadingCombinator);

  bool visitPlaceholderSelector(PlaceholderSelector placeholder) => true;

  bool visitPseudoSelector(PseudoSelector pseudo) {
    if (pseudo.selector case var selector?) {
      // We don't consider `:not(%foo)` to be invisible because, semantically,
      // it means "doesn't match this selector that matches nothing", so it's
      // equivalent to *. If the entire compound selector is composed of `:not`s
      // with invisible lists, the serializer emits it as `*`.
      return pseudo.name == 'not'
          ? (includeBogus && selector.isBogus)
          : selector.accept(this);
    } else {
      return false;
    }
  }
}

/// The visitor used to implement [Selector.isBogus].
class _IsBogusVisitor with AnySelectorVisitor {
  /// Whether to consider selectors with leading combinators as bogus.
  final bool includeLeadingCombinator;

  const _IsBogusVisitor({required this.includeLeadingCombinator});

  bool visitComplexSelector(ComplexSelector complex) {
    if (complex.components.isEmpty) {
      return complex.leadingCombinators.isNotEmpty;
    } else {
      return complex.leadingCombinators.length >
              (includeLeadingCombinator ? 0 : 1) ||
          complex.components.last.combinators.isNotEmpty ||
          complex.components.any((component) =>
              component.combinators.length > 1 ||
              component.selector.accept(this));
    }
  }

  bool visitPseudoSelector(PseudoSelector pseudo) {
    var selector = pseudo.selector;
    if (selector == null) return false;

    // The CSS spec specifically allows leading combinators in `:has()`.
    return pseudo.name == 'has'
        ? selector.isBogusOtherThanLeadingCombinator
        : selector.isBogus;
  }
}

/// The visitor used to implement [Selector.isUseless]
class _IsUselessVisitor with AnySelectorVisitor {
  const _IsUselessVisitor();

  bool visitComplexSelector(ComplexSelector complex) =>
      complex.leadingCombinators.length > 1 ||
      complex.components.any((component) =>
          component.combinators.length > 1 || component.selector.accept(this));

  bool visitPseudoSelector(PseudoSelector pseudo) => pseudo.isBogus;
}
