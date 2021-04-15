// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../ast/css.dart';
import '../ast/selector.dart';
import '../exception.dart';
import '../utils.dart';

/// A selector that's extending another selector, such as `A` in `A {@extend
/// B}`.
class Extender {
  /// The selector in which the `@extend` appeared.
  final ComplexSelector selector;

  /// The minimum specificity required for any selector generated from this
  /// extender.
  final int specificity;

  /// Whether this extender represents a selector that was originally in the
  /// document, rather than one defined with `@extend`.
  final bool isOriginal;

  /// The media query context to which this extension is restricted, or `null`
  /// if it can apply within any context.
  final List<CssMediaQuery>? mediaContext;

  /// The span in which this selector was defined.
  final FileSpan span;

  /// Creates a new extender.
  ///
  /// If [specificity] isn't passed, it defaults to `extender.maxSpecificity`.
  Extender(this.selector, this.span,
      {this.mediaContext, int? specificity, bool original = false})
      : specificity = specificity ?? selector.maxSpecificity,
        isOriginal = original;

  /// Asserts that the [mediaContext] for a selector is compatible with the
  /// query context for this extender.
  void assertCompatibleMediaContext(List<CssMediaQuery>? mediaContext) {
    if (this.mediaContext == null) return;
    if (mediaContext != null && listEquals(this.mediaContext, mediaContext)) {
      return;
    }

    throw SassException(
        "You may not @extend selectors across media queries.", span);
  }

  Extender withSelector(ComplexSelector newSelector) =>
      Extender(newSelector, span,
          mediaContext: mediaContext,
          specificity: specificity,
          original: isOriginal);

  String toString() => selector.toString();
}
