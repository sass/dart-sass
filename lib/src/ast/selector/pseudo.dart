// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../utils.dart';
import '../../util/nullable.dart';
import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// A pseudo-class or pseudo-element selector.
///
/// The semantics of a specific pseudo selector depends on its name. Some
/// selectors take arguments, including other selectors. Sass manually encodes
/// logic for each pseudo selector that takes a selector as an argument, to
/// ensure that extension and other selector operations work properly.
///
/// {@category AST}
final class PseudoSelector extends SimpleSelector {
  /// The name of this selector.
  final String name;

  /// Like [name], but without any vendor prefixes.
  ///
  /// @nodoc
  @internal
  final String normalizedName;

  /// Whether this is a pseudo-class selector.
  ///
  /// This is `true` if and only if [isElement] is `false`.
  final bool isClass;

  /// Whether this is a pseudo-element selector.
  ///
  /// This is `true` if and only if [isClass] is `false`.
  bool get isElement => !isClass;

  /// Whether this is syntactically a pseudo-class selector.
  ///
  /// This is the same as [isClass] unless this selector is a pseudo-element
  /// that was written syntactically as a pseudo-class (`:before`, `:after`,
  /// `:first-line`, or `:first-letter`).
  ///
  /// This is `true` if and only if [isSyntacticElement] is `false`.
  final bool isSyntacticClass;

  /// Whether this is syntactically a pseudo-element selector.
  ///
  /// This is `true` if and only if [isSyntacticClass] is `false`.
  bool get isSyntacticElement => !isSyntacticClass;

  /// Whether this is a valid `:host` selector.
  ///
  /// @nodoc
  @internal
  bool get isHost => isClass && name == 'host';

  /// Whether this is a valid `:host-context` selector.
  ///
  /// @nodoc
  @internal
  bool get isHostContext =>
      isClass && name == 'host-context' && selector != null;

  @internal
  bool get hasComplicatedSuperselectorSemantics =>
      isElement || selector != null;

  /// The non-selector argument passed to this selector.
  ///
  /// This is `null` if there's no argument. If [argument] and [selector] are
  /// both non-`null`, the selector follows the argument.
  final String? argument;

  /// The selector argument passed to this selector.
  ///
  /// This is `null` if there's no selector. If [argument] and [selector] are
  /// both non-`null`, the selector follows the argument.
  final SelectorList? selector;

  late final int specificity = () {
    if (isElement) return 1;
    var selector = this.selector;
    if (selector == null) return super.specificity;

    // https://drafts.csswg.org/selectors/#specificity-rules
    switch (normalizedName) {
      case 'where':
        return 0;
      case 'is':
      case 'not':
      case 'has':
      case 'matches':
        return selector.components
            .map((component) => component.specificity)
            .max;
      case 'nth-child':
      case 'nth-last-child':
        return super.specificity +
            selector.components.map((component) => component.specificity).max;
      default:
        return super.specificity;
    }
  }();

  PseudoSelector(this.name, FileSpan span,
      {bool element = false, this.argument, this.selector})
      : isClass = !element && !_isFakePseudoElement(name),
        isSyntacticClass = !element,
        normalizedName = unvendor(name),
        super(span);

  /// Returns whether [name] is the name of a pseudo-element that can be written
  /// with pseudo-class syntax (`:before`, `:after`, `:first-line`, or
  /// `:first-letter`)
  static bool _isFakePseudoElement(String name) {
    switch (name.codeUnitAt(0)) {
      case $a:
      case $A:
        return equalsIgnoreCase(name, "after");

      case $b:
      case $B:
        return equalsIgnoreCase(name, "before");

      case $f:
      case $F:
        return equalsIgnoreCase(name, "first-line") ||
            equalsIgnoreCase(name, "first-letter");

      default:
        return false;
    }
  }

  /// Returns a new [PseudoSelector] based on this, but with the selector
  /// replaced with [selector].
  PseudoSelector withSelector(SelectorList selector) =>
      PseudoSelector(name, span,
          element: isElement, argument: argument, selector: selector);

  /// @nodoc
  @internal
  PseudoSelector addSuffix(String suffix) {
    if (argument != null || selector != null) super.addSuffix(suffix);
    return PseudoSelector(name + suffix, span, element: isElement);
  }

  /// @nodoc
  @internal
  List<SimpleSelector>? unify(List<SimpleSelector> compound) {
    if (name == 'host' || name == 'host-context') {
      if (!compound.every((simple) =>
          simple is PseudoSelector &&
          (simple.isHost || simple.selector != null))) {
        return null;
      }
    } else if (compound case [var other]
        when other is UniversalSelector ||
            (other is PseudoSelector &&
                (other.isHost || other.isHostContext))) {
      return other.unify([this]);
    }

    if (compound.contains(this)) return compound;

    var result = <SimpleSelector>[];
    var addedThis = false;
    for (var simple in compound) {
      if (simple case PseudoSelector(isElement: true)) {
        // A given compound selector may only contain one pseudo element. If
        // [compound] has a different one than [this], unification fails.
        if (isElement) return null;

        // Otherwise, this is a pseudo selector and should come before pseudo
        // elements.
        result.add(this);
        addedThis = true;
      }

      result.add(simple);
    }
    if (!addedThis) result.add(this);

    return result;
  }

  bool isSuperselector(SimpleSelector other) {
    if (super.isSuperselector(other)) return true;

    var selector = this.selector;
    if (selector == null) return this == other;
    if (other is PseudoSelector &&
        isElement &&
        other.isElement &&
        normalizedName == 'slotted' &&
        other.name == name) {
      return other.selector.andThen(selector.isSuperselector) ?? false;
    }

    // Fall back to the logic defined in functions.dart, which knows how to
    // compare selector pseudoclasses against raw selectors.
    return CompoundSelector([this], span)
        .isSuperselector(CompoundSelector([other], span));
  }

  T accept<T>(SelectorVisitor<T> visitor) => visitor.visitPseudoSelector(this);

  // This intentionally uses identity for the selector list, if one is available.
  bool operator ==(Object other) =>
      other is PseudoSelector &&
      other.name == name &&
      other.isClass == isClass &&
      other.argument == argument &&
      other.selector == selector;

  int get hashCode =>
      name.hashCode ^
      isElement.hashCode ^
      argument.hashCode ^
      selector.hashCode;
}
