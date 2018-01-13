// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../value.dart' as internal;
import 'value.dart';

/// The SassScript `true` value.
SassBoolean get sassTrue => internal.sassTrue;

/// The SassScript `false` value.
SassBoolean get sassFalse => internal.sassFalse;

/// A SassScript boolean value.
abstract class SassBoolean extends Value {
  /// Whether this value is `true` or `false`.
  bool get value;

  /// Returns a [SassBoolean] corresponding to [value].
  ///
  /// This just returns [sassTrue] or [sassFalse]; it doesn't allocate a new
  /// value.
  factory SassBoolean(bool value) = internal.SassBoolean;
}
