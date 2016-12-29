// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

/// The state of an extension for a given source and target.
///
/// The source and target are represented externally, in the nested map that
/// contains this state.
class ExtendState {
  /// Whether this extension is optional.
  bool get isOptional => _span == null;

  /// Whether this extension matched a selector.
  var isUsed = false;

  /// The span for the `@extend` rule that should produce an error if this
  /// extension doesn't match anything.
  ///
  /// This is `null` if and only if this extension is optional.
  FileSpan get span => _span;
  FileSpan _span;

  /// Creates a new optional extend state.
  ExtendState.optional();

  /// Creates a new mandatory extend state.
  ///
  /// The [span] is used in the error that's thrown if this extension doesn't
  /// match anything.
  ExtendState.mandatory(this._span);

  /// Marks this extension as mandatory.
  ///
  /// The [span] is used in the error that's thrown if this extension doesn't
  /// match anything.
  void makeMandatory(FileSpan span) {
    _span = span;
  }
}
