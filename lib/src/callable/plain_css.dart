// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../callable.dart';

/// A callable that emits a plain CSS function.
///
/// This can't be used for mixins.
@internal
final class PlainCssCallable(@override final String name) implements Callable {
  @override
  bool operator ==(Object other) =>
      other is PlainCssCallable && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
