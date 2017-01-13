// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../ast/css.dart';
import '../exception.dart';
import '../utils.dart';

/// The state of an extension for a given source and target.
///
/// The source and target are represented externally, in the nested map that
/// contains this state.
class ExtendState {
  /// Whether this extension is optional.
  bool get isOptional => _isOptional;
  bool _isOptional;

  /// Whether this extension matched a selector.
  var isUsed = false;

  /// The media query context to which this extend is restricted, or `null` if
  /// it can apply within any context.
  List<CssMediaQuery> get mediaContext => _mediaContext;
  List<CssMediaQuery> _mediaContext;

  /// The span for an `@extend` rule that defined this extension.
  ///
  /// If any extend rule for this is extension is mandatory, this is guaranteed
  /// to be a span for a mandatory rule.
  FileSpan get span => _span;
  FileSpan _span;

  /// Creates a new extend state.
  ExtendState(this._span, this._mediaContext, {bool optional: false})
      : _isOptional = optional;

  /// Creates a one-off extend state that's not intended to be modified over time.
  ExtendState.oneOff()
      : _isOptional = true,
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
}
