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
  /// The selector in which the `@extend` appeared.
  final ComplexSelector extender;

  /// The selector that's being extended.
  ///
  /// `null` for one-off extensions.
  final SimpleSelector target;

  /// The minimum specificity required for any selector generated from this
  /// extender.
  final int specificity;

  /// Whether this extension is optional.
  bool get isOptional => _isOptional;
  bool _isOptional;

  /// Whether this is a one-off extender representing a selector that was
  /// originally in the document, rather than one defined with `@extend`.
  final bool isOriginal;

  /// The media query context to which this extend is restricted, or `null` if
  /// it can apply within any context.
  List<CssMediaQuery> get mediaContext => _mediaContext;
  List<CssMediaQuery> _mediaContext;

  /// The span in which [extender] was defined.
  ///
  /// `null` for one-off extensions.
  final FileSpan extenderSpan;

  /// The span for an `@extend` rule that defined this extension.
  ///
  /// If any extend rule for this is extension is mandatory, this is guaranteed
  /// to be a span for a mandatory rule.
  FileSpan get span => _span;
  FileSpan _span;

  /// Creates a new extension.
  ///
  /// If [specificity] isn't passed, it defaults to `extender.maxSpecificity`.
  Extension(ComplexSelector extender, this.target, this.extenderSpan,
      this._span, this._mediaContext,
      {int specificity, bool optional: false})
      : extender = extender,
        specificity = specificity ?? extender.maxSpecificity,
        _isOptional = optional,
        isOriginal = false;

  /// Creates a one-off extension that's not intended to be modified over time.
  ///
  /// If [specificity] isn't passed, it defaults to `extender.maxSpecificity`.
  Extension.oneOff(ComplexSelector extender,
      {int specificity, this.isOriginal: false})
      : extender = extender,
        target = null,
        extenderSpan = null,
        specificity = specificity ?? extender.maxSpecificity,
        _isOptional = true,
        _mediaContext = null,
        _span = null;

  /// Asserts that the [mediaContext] for a selector is compatible with the
  /// query context for this extender.
  void assertCompatibleMediaContext(List<CssMediaQuery> mediaContext) {
    if (_mediaContext == null) return;
    if (mediaContext != null && listEquals(_mediaContext, mediaContext)) return;

    throw new SassException(
        "You may not @extend selectors across media queries.", _span);
  }

  /// Indicates that the stylesheet contains another `@extend` with the same
  /// source and target selectors, and the given [span] and [mediaContext].
  void addSource(FileSpan span, List<CssMediaQuery> mediaContext,
      {bool optional: false}) {
    if (mediaContext != null) {
      if (_mediaContext == null) {
        _mediaContext = mediaContext;
      } else if (!listEquals(_mediaContext, mediaContext)) {
        throw new SassException(
            "From ${_span.message('')}\n"
            "You may not @extend the same selector from within different media "
            "queries.",
            span);
      }
    }

    if (optional || !_isOptional) return;
    _span = span;
    _isOptional = false;
  }

  Extension withExtender(ComplexSelector newExtender) =>
      new Extension(newExtender, target, extenderSpan, _span, _mediaContext,
          specificity: specificity, optional: isOptional);

  String toString() => extender.toString();
}
