// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/interpolated_selector.dart';
import '../../sass/interpolation.dart';
import '../../selector.dart';
import 'list.dart';
import 'simple.dart';

/// A psueod-class or pseudo-element selector.
///
/// Unlike [PseudoSelector], this is parsed during the initial stylesheet parse
/// when `parseSelectors: true` is passed to [Stylesheet.parse].
///
/// {@category AST}
final class InterpolatedPseudoSelector extends InterpolatedSimpleSelector {
  /// The name of this selector (including any vendor prefixes).
  final Interpolation name;

  /// Whether this is syntactically a pseudo-class selector.
  ///
  /// This is `true` if and only if [isSyntacticElement] is `false`.
  final bool isSyntacticClass;

  /// Whether this is syntactically a pseudo-element selector.
  ///
  /// This is `true` if and only if [isSyntacticClass] is `false`.
  bool get isSyntacticElement => !isSyntacticClass;

  /// The non-selector argument passed to this selector.
  ///
  /// This is `null` if there's no argument. If [argument] and [selector] are
  /// both non-`null`, the selector follows the argument.
  final Interpolation? argument;

  /// The selector argument passed to this selector.
  ///
  /// This is `null` if there's no selector. If [argument] and [selector] are
  /// both non-`null`, the selector follows the argument.
  final InterpolatedSelectorList? selector;

  final FileSpan span;

  InterpolatedPseudoSelector(
    this.name,
    this.span, {
    bool element = false,
    this.argument,
    this.selector,
  }) : isSyntacticClass = !element;

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(InterpolatedSelectorVisitor<T> visitor) =>
      visitor.visitPseudoSelector(this);

  String toString() {
    var result = '${isSyntacticClass ? ':' : '::'}$name';
    if (argument != null || selector != null) {
      result += '(';
      if (argument case var argument?) {
        result += argument.toString();
        if (selector != null) result += ' ';
      }
      if (selector case var selector?) result += selector.toString();
      result += ')';
    }
    return result;
  }
}
