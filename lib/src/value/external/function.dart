// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../callable.dart';
import '../../value.dart' as internal;
import 'value.dart';

/// A SassScript function reference.
///
/// A function reference captures a function from the local environment so that
/// it may be passed between modules.
abstract class SassFunction extends Value {
  /// The callable that this function invokes.
  ///
  /// Note that this is typed as an [AsyncCallback] so that it will work with
  /// both synchronous and asynchronous evaluate visitors, but in practice the
  /// synchronous evaluate visitor will crash if this isn't a [Callback].
  AsyncCallable get callable;

  factory SassFunction(AsyncCallable callable) = internal.SassFunction;
}
