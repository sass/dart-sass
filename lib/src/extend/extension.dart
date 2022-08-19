// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../ast/css.dart';
import '../ast/selector.dart';
import '../exception.dart';
import '../utils.dart';

/// The state of an extension for a given extender.
///
/// The target of the extension is represented externally, in the map that
/// contains this extender.
class Extension {
  /// The extender (such as `A` in `A {@extend B}`).
  final Extender extender;

  /// The selector that's being extended.
  final SimpleSelector target;

  /// The media query context to which this extension is restricted, or `null`
  /// if it can apply within any context.
  final List<CssMediaQuery>? mediaContext;

  /// Whether this extension is optional.
  final bool isOptional;

  /// The span for an `@extend` rule that defined this extension.
  ///
  /// If any extend rule for this is extension is mandatory, this is guaranteed
  /// to be a span for a mandatory rule.
  final FileSpan span;

  /// Creates a new extension.
  Extension(
      ComplexSelector extender, FileSpan extenderSpan, this.target, this.span,
      {this.mediaContext, bool optional = false})
      : extender = Extender(extender, extenderSpan),
        isOptional = optional {
    this.extender._extension = this;
  }

  Extension withExtender(ComplexSelector newExtender) =>
      Extension(newExtender, extender.span, target, span,
          mediaContext: mediaContext, optional: isOptional);

  String toString() =>
      "$extender {@extend $target${isOptional ? ' !optional' : ''}}";
}

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

  /// The extension that created this [Extender].
  ///
  /// Not all [Extender]s are created by extensions. Some simply represent the
  /// original selectors that exist in the document.
  Extension? _extension;

  /// The span in which this selector was defined.
  final FileSpan span;

  /// Creates a new extender.
  ///
  /// If [specificity] isn't passed, it defaults to `extender.specificity`.
  Extender(this.selector, this.span, {int? specificity, bool original = false})
      : specificity = specificity ?? selector.specificity,
        isOriginal = original;

  /// Asserts that the [mediaContext] for a selector is compatible with the
  /// query context for this extender.
  void assertCompatibleMediaContext(List<CssMediaQuery>? mediaContext) {
    var extension = _extension;
    if (extension == null) return;

    var expectedMediaContext = extension.mediaContext;
    if (expectedMediaContext == null) return;
    if (mediaContext != null &&
        listEquals(expectedMediaContext, mediaContext)) {
      return;
    }

    throw SassException(
        "You may not @extend selectors across media queries.", extension.span);
  }

  String toString() => selector.toString();
}
