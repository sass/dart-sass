// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:meta/meta.dart';

/// Contextual information used by importers' `canonicalize` method.
@internal
final class CanonicalizeContext {
  /// Whether the Sass compiler is currently evaluating an `@import` rule.
  bool get fromImport => _fromImport;
  bool _fromImport;

  /// The URL of the stylesheet that contains the current load.
  Uri? get containingUrl {
    _wasContainingUrlAccessed = true;
    return _containingUrl;
  }

  final Uri? _containingUrl;

  /// Returns the same value as [containingUrl], but doesn't mark it accessed.
  Uri? get containingUrlWithoutMarking => _containingUrl;

  /// Whether [containingUrl] has been accessed.
  ///
  /// This is used to determine whether canonicalize result is cacheable.
  bool get wasContainingUrlAccessed => _wasContainingUrlAccessed;
  var _wasContainingUrlAccessed = false;

  /// Runs [callback] in a context with specificed [fromImport].
  T withFromImport<T>(bool fromImport, T callback()) {
    assert(Zone.current[#_canonicalizeContext] == this);

    var oldFromImport = _fromImport;
    _fromImport = fromImport;
    try {
      return callback();
    } finally {
      _fromImport = oldFromImport;
    }
  }

  CanonicalizeContext(this._containingUrl, this._fromImport);
}
